extends Node2D

const TILE_SOURCE_ID := 0
const TILE_GROUND := Vector2i(0, 0)
const TILE_DETAIL := Vector2i(1, 0)
const TILE_SOLID := Vector2i(2, 0)
const TILE_OVERHEAD := Vector2i(3, 0)
const TILE_SIZE := 16
const ZONES_DATA_PATH := "res://data/zones.json"
const SCRAPPER_SCENE := preload("res://scenes/enemies/scrapper.tscn")
const HAULER_SCENE := preload("res://scenes/enemies/hauler.tscn")

@export var zone_id: String = ""
@export var room_width: int = 46
@export var room_height: int = 30
@export var intro_dialogue_id: String = ""

@onready var ground_layer: TileMapLayer = $Ground
@onready var detail_layer: TileMapLayer = $GroundDetail
@onready var objects_layer: TileMapLayer = $Objects
@onready var overhead_layer: TileMapLayer = $Overhead
@onready var player: PlayerController = $Player
@onready var spawn_points: Node2D = $SpawnPoints
@onready var entities: Node2D = $Entities
@onready var components_label: Label = $Hud/TopPanel/MarginContainer/Rows/ComponentsLabel
@onready var info_label: Label = $Hud/TopPanel/MarginContainer/Rows/InfoLabel
@onready var fade_rect: ColorRect = $Hud/FadeRect
@onready var death_overlay: Control = $Hud/DeathOverlay
@onready var reboot_button: Button = $Hud/DeathOverlay/PanelContainer/MarginContainer/Rows/RebootButton

var zone_data: Dictionary = {}
var is_transitioning: bool = false
var is_restart_pending: bool = false

func _ready() -> void:
	zone_data = _load_zone_data()
	_setup_hud_state()
	_setup_tilemaps()
	_paint_zone()
	apply_overhead_depth()
	_position_player_from_spawn()
	_apply_camera_limits()
	_connect_player_signals()
	_spawn_zone_enemies()
	_update_hud_text()
	_sync_state_to_game_manager()
	_try_show_intro_dialogue()

func _input(event: InputEvent) -> void:
	if not is_restart_pending:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("advance_dialogue"):
		_on_reboot_pressed()

func request_zone_change(target_zone: String, target_spawn_id: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	player.set_input_enabled(false)
	_sync_state_to_game_manager()
	await _fade_to_black(0.35, 1.0)
	var game_manager: Node = get_node("/root/GameManager")
	game_manager.change_zone(target_zone, target_spawn_id)

func on_axion_component_collected(component_id: String, dialogue_id: String) -> void:
	var game_manager: Node = get_node("/root/GameManager")
	if game_manager.has_component(component_id):
		return

	var was_collected: bool = game_manager.collect_component(component_id)
	if not was_collected:
		return

	_update_hud_text()
	if dialogue_id != "":
		await _show_dialogue(dialogue_id)
	_update_hud_text()

	if game_manager.components_collected >= 3:
		await _show_dialogue("ending_return")
		await _fade_to_black(0.35, 1.0)
		game_manager.reset_run_state()
		get_tree().change_scene_to_file(game_manager.MAIN_MENU_SCENE_PATH)

func apply_overhead_depth() -> void:
	y_sort_enabled = true
	objects_layer.y_sort_enabled = true
	overhead_layer.z_index = 10

func _setup_hud_state() -> void:
	fade_rect.color.a = 1.0
	death_overlay.visible = false
	reboot_button.pressed.connect(_on_reboot_pressed)
	reboot_button.focus_mode = Control.FOCUS_ALL

func _setup_tilemaps() -> void:
	var tile_set := _build_tileset()
	ground_layer.tile_set = tile_set
	detail_layer.tile_set = tile_set
	objects_layer.tile_set = tile_set
	overhead_layer.tile_set = tile_set
	objects_layer.collision_enabled = true

func _build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1 << 4)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/sprites/debug_tiles.svg")
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for tile_x in range(4):
		atlas.create_tile(Vector2i(tile_x, 0))

	tile_set.add_source(atlas, TILE_SOURCE_ID)
	var solid_tile := atlas.get_tile_data(TILE_SOLID, 0)
	solid_tile.set_collision_polygons_count(0, 1)
	solid_tile.set_collision_polygon_points(
		0,
		0,
		PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	)
	return tile_set

func _paint_zone() -> void:
	for x in range(room_width):
		for y in range(room_height):
			ground_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_GROUND)
			if x % 5 == 0 and y % 4 == 0:
				detail_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_DETAIL)

	for x in range(room_width):
		objects_layer.set_cell(Vector2i(x, 0), TILE_SOURCE_ID, TILE_SOLID)
		objects_layer.set_cell(Vector2i(x, room_height - 1), TILE_SOURCE_ID, TILE_SOLID)
	for y in range(room_height):
		objects_layer.set_cell(Vector2i(0, y), TILE_SOURCE_ID, TILE_SOLID)
		objects_layer.set_cell(Vector2i(room_width - 1, y), TILE_SOURCE_ID, TILE_SOLID)

	for x in range(14, 20):
		for y in range(11, 13):
			objects_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_SOLID)

	for x in range(28, 34):
		for y in range(18, 20):
			objects_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_SOLID)

	for x in range(10, 17):
		overhead_layer.set_cell(Vector2i(x, 7), TILE_SOURCE_ID, TILE_OVERHEAD)

	_paint_zone_obstacles_from_data()

func _paint_zone_obstacles_from_data() -> void:
	var config: Variant = zone_data.get(zone_id, {})
	if not config is Dictionary:
		return
	var obstacle_config: Variant = (config as Dictionary).get("obstacles", [])
	if not obstacle_config is Array:
		return

	for obstacle in obstacle_config:
		if not obstacle is Dictionary:
			continue
		_paint_solid_rect(obstacle as Dictionary)

func _paint_solid_rect(obstacle: Dictionary) -> void:
	var start_x: int = int(obstacle.get("x", 0))
	var start_y: int = int(obstacle.get("y", 0))
	var width: int = maxi(int(obstacle.get("w", 1)), 1)
	var height: int = maxi(int(obstacle.get("h", 1)), 1)

	for x in range(start_x, start_x + width):
		for y in range(start_y, start_y + height):
			if x <= 0 or y <= 0 or x >= room_width - 1 or y >= room_height - 1:
				continue
			objects_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_SOLID)

func _position_player_from_spawn() -> void:
	var game_manager: Node = get_node("/root/GameManager")
	var spawn_id: String = game_manager.pending_spawn_id
	if spawn_id.is_empty():
		spawn_id = "start"
	var marker_name := "Spawn_%s" % spawn_id
	var marker := spawn_points.get_node_or_null(marker_name) as Marker2D
	if marker == null:
		marker = spawn_points.get_node_or_null("Spawn_start") as Marker2D
	if marker != null:
		player.global_position = marker.global_position

	game_manager.current_zone = scene_file_path
	game_manager.apply_to_player(player)

func _apply_camera_limits() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = room_width * TILE_SIZE
	camera.limit_bottom = room_height * TILE_SIZE

func _connect_player_signals() -> void:
	player.player_died.connect(_on_player_died)
	player.cells_changed.connect(_sync_state_to_game_manager)
	player.coolant_changed.connect(_sync_state_to_game_manager)
	player.ammo_changed.connect(_sync_state_to_game_manager)

func _spawn_zone_enemies() -> void:
	var config: Variant = zone_data.get(zone_id, {})
	if not config is Dictionary:
		return
	var enemies_config: Variant = (config as Dictionary).get("enemies", [])
	if not enemies_config is Array:
		return
	for enemy_config in enemies_config:
		if not enemy_config is Dictionary:
			continue
		_spawn_enemy(enemy_config as Dictionary)

func _spawn_enemy(enemy_config: Dictionary) -> void:
	var enemy_type := str(enemy_config.get("type", ""))
	var enemy_scene: PackedScene
	if enemy_type == "Scrapper":
		enemy_scene = SCRAPPER_SCENE
	elif enemy_type == "Hauler":
		enemy_scene = HAULER_SCENE
	else:
		return

	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		return
	var x_pos := float(enemy_config.get("x", 0.0))
	var y_pos := float(enemy_config.get("y", 0.0))
	enemy.global_position = Vector2(x_pos, y_pos)
	entities.add_child(enemy)

func _load_zone_data() -> Dictionary:
	var file := FileAccess.open(ZONES_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing zone data at %s." % ZONES_DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Zone data file must contain a JSON object.")
		return {}
	return parsed as Dictionary

func _on_player_died() -> void:
	if is_restart_pending:
		return
	is_restart_pending = true
	player.set_input_enabled(false)
	_sync_state_to_game_manager()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		(enemy as Node).process_mode = Node.PROCESS_MODE_DISABLED

	await _fade_to_black(0.35, 0.78)
	death_overlay.visible = true
	reboot_button.grab_focus()

func _on_reboot_pressed() -> void:
	if not is_restart_pending:
		return
	var game_manager: Node = get_node("/root/GameManager")
	game_manager.handle_player_death()
	is_restart_pending = false
	get_tree().change_scene_to_file(game_manager.get_restart_scene_path())

func _show_dialogue(dialogue_id: String) -> void:
	var dialogue_manager: Node = get_node("/root/DialogueManager")
	if dialogue_manager == null:
		return
	dialogue_manager.show_dialogue(dialogue_id, player)
	await dialogue_manager.dialogue_finished

func _try_show_intro_dialogue() -> void:
	if intro_dialogue_id.is_empty():
		await _fade_to_black(0.25, 0.0)
		return
	var game_manager: Node = get_node("/root/GameManager")
	if game_manager.intro_played:
		await _fade_to_black(0.25, 0.0)
		return

	await _fade_to_black(0.25, 0.0)
	game_manager.intro_played = true
	await _show_dialogue(intro_dialogue_id)

func _fade_to_black(duration: float, target_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", target_alpha, duration)
	await tween.finished

func _sync_state_to_game_manager(_a: Variant = null, _b: Variant = null) -> void:
	var game_manager: Node = get_node("/root/GameManager")
	game_manager.sync_from_player(player)

func _update_hud_text() -> void:
	var game_manager: Node = get_node("/root/GameManager")
	components_label.text = "AXION: %d/3" % game_manager.components_collected
	info_label.text = "Zone: %s" % zone_id
