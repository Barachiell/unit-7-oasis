extends Node2D

const TILE_SOURCE_ID := 0
const TILE_GROUND := Vector2i(0, 0)
const TILE_DETAIL := Vector2i(1, 0)
const TILE_SOLID := Vector2i(2, 0)
const TILE_OVERHEAD := Vector2i(3, 0)
const ROOM_WIDTH := 40
const ROOM_HEIGHT := 24

@onready var ground_layer: TileMapLayer = $Ground
@onready var detail_layer: TileMapLayer = $GroundDetail
@onready var objects_layer: TileMapLayer = $Objects
@onready var overhead_layer: TileMapLayer = $Overhead
@onready var player: PlayerController = $Player
@onready var stamina_ring: StaminaRing = $Hud/StaminaRing
@onready var cells_label: Label = $Hud/DebugPanel/MarginContainer/Rows/CellsLabel
@onready var coolant_label: Label = $Hud/DebugPanel/MarginContainer/Rows/CoolantLabel
@onready var ammo_label: Label = $Hud/DebugPanel/MarginContainer/Rows/AmmoLabel
@onready var death_label: Label = $Hud/DebugPanel/MarginContainer/Rows/DeathLabel
@onready var death_overlay: Control = $Hud/DeathOverlay
@onready var fade_rect: ColorRect = $Hud/DeathOverlay/FadeRect
@onready var failure_panel: PanelContainer = $Hud/DeathOverlay/FailurePanel
@onready var reboot_button: Button = $Hud/DeathOverlay/FailurePanel/MarginContainer/Rows/RebootButton

var is_restart_pending: bool = false

func _ready() -> void:
	death_overlay.visible = false
	fade_rect.color.a = 0.0
	failure_panel.visible = false
	reboot_button.pressed.connect(_on_reboot_pressed)
	reboot_button.focus_mode = Control.FOCUS_ALL

	y_sort_enabled = true
	objects_layer.y_sort_enabled = true
	overhead_layer.z_index = 10
	objects_layer.collision_enabled = true

	var game_manager := get_node("/root/GameManager") as OasisGameManager
	game_manager.current_zone = scene_file_path

	var tile_set := _build_tileset()
	ground_layer.tile_set = tile_set
	detail_layer.tile_set = tile_set
	objects_layer.tile_set = tile_set
	overhead_layer.tile_set = tile_set

	_paint_ground()
	_paint_details()
	_paint_objects()
	_paint_overhead()
	_apply_camera_limits()
	_connect_stamina_ui()
	_connect_player_debug_ui()
	game_manager.apply_to_player(player)
	_refresh_debug_values()

func _input(event: InputEvent) -> void:
	if not is_restart_pending:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("advance_dialogue"):
		_on_reboot_pressed()

func _build_tileset() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1 << 4)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/sprites/debug_tiles.svg")
	atlas.texture_region_size = Vector2i(16, 16)

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

func _paint_ground() -> void:
	for x in range(ROOM_WIDTH):
		for y in range(ROOM_HEIGHT):
			ground_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_GROUND)

func _paint_details() -> void:
	for x in range(2, ROOM_WIDTH - 2, 4):
		for y in range(2, ROOM_HEIGHT - 2, 5):
			detail_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_DETAIL)

func _paint_objects() -> void:
	for x in range(ROOM_WIDTH):
		objects_layer.set_cell(Vector2i(x, 0), TILE_SOURCE_ID, TILE_SOLID)
		objects_layer.set_cell(Vector2i(x, ROOM_HEIGHT - 1), TILE_SOURCE_ID, TILE_SOLID)

	for y in range(ROOM_HEIGHT):
		objects_layer.set_cell(Vector2i(0, y), TILE_SOURCE_ID, TILE_SOLID)
		objects_layer.set_cell(Vector2i(ROOM_WIDTH - 1, y), TILE_SOURCE_ID, TILE_SOLID)

	for x in range(18, 22):
		for y in range(8, 12):
			objects_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_SOLID)

func _paint_overhead() -> void:
	for x in range(12, 19):
		overhead_layer.set_cell(Vector2i(x, 6), TILE_SOURCE_ID, TILE_OVERHEAD)

func _apply_camera_limits() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = ROOM_WIDTH * 16
	camera.limit_bottom = ROOM_HEIGHT * 16

func _connect_stamina_ui() -> void:
	player.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(player.current_stamina, player.max_stamina)

func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_ring.set_stamina(current, maximum)

func _connect_player_debug_ui() -> void:
	player.cells_changed.connect(_on_cells_changed)
	player.coolant_changed.connect(_on_coolant_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.player_died.connect(_on_player_died)
	player.cells_changed.connect(_sync_game_manager_state)
	player.coolant_changed.connect(_sync_game_manager_state)
	player.ammo_changed.connect(_sync_game_manager_state)

func _refresh_debug_values() -> void:
	_on_cells_changed(player.current_cells, player.max_cells)
	_on_coolant_changed(player.coolant_count)
	_on_ammo_changed(player.current_ammo, player.max_ammo)
	_sync_game_manager_state()

func _on_cells_changed(current: int, maximum: int) -> void:
	cells_label.text = "Cells: %d/%d" % [current, maximum]
	if current > 0:
		death_label.text = ""

func _on_coolant_changed(current: int) -> void:
	coolant_label.text = "Coolant: %d" % current

func _on_ammo_changed(current: int, maximum: int) -> void:
	ammo_label.text = "Ammo: %d/%d" % [current, maximum]

func _on_player_died() -> void:
	death_label.text = "SYSTEM FAILURE"
	_start_death_sequence()

func _start_death_sequence() -> void:
	if is_restart_pending:
		return

	is_restart_pending = true
	player.set_input_enabled(false)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node:
			(enemy as Node).process_mode = Node.PROCESS_MODE_DISABLED

	death_overlay.visible = true
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.78, 0.35)
	await fade_tween.finished
	failure_panel.visible = true
	reboot_button.grab_focus()

func _on_reboot_pressed() -> void:
	if not is_restart_pending:
		return

	var game_manager := get_node("/root/GameManager") as OasisGameManager
	game_manager.handle_player_death()
	is_restart_pending = false
	get_tree().change_scene_to_file(game_manager.get_restart_scene_path())

func _sync_game_manager_state(_current_value: Variant = null, _maximum_value: Variant = null) -> void:
	var game_manager := get_node("/root/GameManager") as OasisGameManager
	game_manager.sync_from_player(player)
