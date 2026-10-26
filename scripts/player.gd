class_name PlayerController
extends CharacterBody2D

signal stamina_changed(current: float, maximum: float)
signal ammo_changed(current: int, maximum: int)
signal cells_changed(current: int, maximum: int)
signal coolant_changed(current: int)
signal player_died

@export var walk_speed: float = 90.0
@export var muzzle_radius: float = 12.0
@export var look_ahead_distance: float = 24.0
@export var look_ahead_smoothing: float = 10.0
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 45.0
@export var stamina_regen_rate: float = 30.0
@export var stamina_regen_delay: float = 0.75
@export var run_speed_multiplier: float = 1.8
@export_range(0.1, 1.0, 0.05) var run_unlock_threshold_ratio: float = 0.25
@export var max_ammo: int = 50
@export var starting_ammo: int = 20
@export var fire_rate: float = 0.15
@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")
@export var max_cells: int = 5
@export var invincibility_duration: float = 0.8
@export var contact_damage_amount: int = 2
@export var contact_damage_interval: float = 1.0
@export var starting_coolant_count: int = 3
@export var coolant_heal_amount: int = 2

@onready var muzzle: Marker2D = $Muzzle
@onready var camera: Camera2D = $Camera2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var contact_damage_area: Area2D = $ContactDamageArea

@export var aim_facing_hold_duration: float = 0.3

var aim_direction: Vector2 = Vector2.RIGHT
var facing_direction: Vector2 = Vector2.DOWN
var current_stamina: float = max_stamina
var run_locked: bool = false
var regen_delay_remaining: float = 0.0
var current_ammo: int = starting_ammo
var fire_cooldown_remaining: float = 0.0
var current_cells: int = max_cells
var coolant_count: int = starting_coolant_count
var invincibility_remaining: float = 0.0
var flash_timer: float = 0.0
var flash_visible_state: bool = true
var contact_damage_tick_remaining: float = 0.0
var contact_damage_sources: Dictionary = {}
var input_enabled: bool = true
var shooting_pose_remaining: float = 0.0
var sprite_director: PlayerSpriteDirector = PlayerSpriteDirector.new()

func _physics_process(delta: float) -> void:
	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_sprite(delta, Vector2.ZERO, 1.0)
		_update_invincibility(delta)
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var movement_direction := input_direction.normalized()
	var is_moving := movement_direction.length_squared() > 0.0
	var can_run := not run_locked and current_stamina > 0.0
	var wants_run := is_moving and can_run and Input.is_action_pressed("run")

	_update_stamina(delta, wants_run)

	var speed_multiplier := run_speed_multiplier if wants_run else 1.0
	velocity = movement_direction * walk_speed * speed_multiplier
	move_and_slide()
	_update_aim_direction()
	_update_camera_look_ahead(delta)
	_update_shooting(delta)
	_update_sprite(delta, movement_direction, speed_multiplier)
	_update_invincibility(delta)
	_update_contact_damage(delta)
	_try_use_coolant()

func _ready() -> void:
	add_to_group("player")
	current_stamina = max_stamina
	current_ammo = mini(starting_ammo, max_ammo)
	current_cells = max_cells
	coolant_count = starting_coolant_count
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	contact_damage_area.body_entered.connect(_on_contact_body_entered)
	contact_damage_area.body_exited.connect(_on_contact_body_exited)
	contact_damage_area.area_entered.connect(_on_contact_area_entered)
	contact_damage_area.area_exited.connect(_on_contact_area_exited)
	cells_changed.emit(current_cells, max_cells)
	coolant_changed.emit(coolant_count)
	stamina_changed.emit(current_stamina, max_stamina)
	ammo_changed.emit(current_ammo, max_ammo)

func _update_aim_direction() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.0001:
		aim_direction = to_mouse.normalized()

	muzzle.position = aim_direction * muzzle_radius
	muzzle.rotation = aim_direction.angle()

func _update_camera_look_ahead(delta: float) -> void:
	var target_offset: Vector2 = aim_direction * look_ahead_distance
	var weight: float = clampf(delta * look_ahead_smoothing, 0.0, 1.0)
	camera.offset = camera.offset.lerp(target_offset, weight)

func _update_stamina(delta: float, is_running: bool) -> void:
	var previous_stamina := current_stamina

	if is_running:
		current_stamina = maxf(current_stamina - stamina_drain_rate * delta, 0.0)
		regen_delay_remaining = stamina_regen_delay
		if is_zero_approx(current_stamina):
			run_locked = true
	elif regen_delay_remaining > 0.0:
		regen_delay_remaining = maxf(regen_delay_remaining - delta, 0.0)
	else:
		current_stamina = minf(current_stamina + stamina_regen_rate * delta, max_stamina)

	if run_locked:
		var unlock_stamina_threshold: float = max_stamina * run_unlock_threshold_ratio
		if current_stamina >= unlock_stamina_threshold:
			run_locked = false

	if absf(current_stamina - previous_stamina) > 0.001:
		stamina_changed.emit(current_stamina, max_stamina)

func _update_shooting(delta: float) -> void:
	fire_cooldown_remaining = maxf(fire_cooldown_remaining - delta, 0.0)
	if fire_cooldown_remaining > 0.0:
		return

	if not Input.is_action_pressed("shoot"):
		return

	if current_ammo <= 0:
		_try_play_dry_click()
		fire_cooldown_remaining = fire_rate
		return

	_spawn_player_bullet()
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	fire_cooldown_remaining = fire_rate
	shooting_pose_remaining = maxf(fire_rate, aim_facing_hold_duration)

func _update_sprite(delta: float, movement_direction: Vector2, speed_multiplier: float) -> void:
	shooting_pose_remaining = maxf(shooting_pose_remaining - delta, 0.0)
	var is_moving: bool = movement_direction.length_squared() > 0.0
	var is_shooting: bool = shooting_pose_remaining > 0.0

	var visual_state: int = PlayerSpriteDirector.VisualState.STANDING
	if is_shooting:
		visual_state = PlayerSpriteDirector.VisualState.SHOOTING
	elif is_moving:
		visual_state = PlayerSpriteDirector.VisualState.WALKING

	facing_direction = _resolve_facing_direction(movement_direction, is_shooting)
	sprite.texture = sprite_director.next_texture(delta, visual_state, facing_direction, speed_multiplier)

func _resolve_facing_direction(movement_direction: Vector2, is_shooting: bool) -> Vector2:
	if is_shooting:
		return aim_direction
	if movement_direction.length_squared() > 0.0:
		return movement_direction
	return facing_direction

func _spawn_player_bullet() -> void:
	if bullet_scene == null:
		push_error("Player bullet scene is not configured.")
		return

	var bullet_instance := bullet_scene.instantiate()
	if not bullet_instance is Area2D:
		push_error("Configured bullet scene does not instantiate an Area2D bullet.")
		return
	var bullet := bullet_instance as Area2D

	bullet.global_position = muzzle.global_position
	bullet.set("direction", aim_direction)

	var level_root := get_tree().current_scene
	if level_root == null:
		push_error("Cannot spawn bullet: current scene is unavailable.")
		bullet.queue_free()
		return

	level_root.add_child(bullet)

func _try_play_dry_click() -> void:
	# Audio bus wiring is added in Block 14.
	print("dry_click")

func add_ammo(amount: int) -> void:
	if amount <= 0:
		return

	current_ammo = mini(current_ammo + amount, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)

func add_coolant(amount: int) -> void:
	if amount <= 0:
		return

	coolant_count += amount
	coolant_changed.emit(coolant_count)

func set_runtime_stats(ammo_value: int, coolant_value: int, cells_value: int) -> void:
	current_ammo = clampi(ammo_value, 0, max_ammo)
	coolant_count = maxi(coolant_value, 0)
	current_cells = clampi(cells_value, 0, max_cells)
	ammo_changed.emit(current_ammo, max_ammo)
	coolant_changed.emit(coolant_count)
	cells_changed.emit(current_cells, max_cells)

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO

func take_bullet_hit(amount: int) -> void:
	take_damage(maxi(amount, 1))

func take_damage(amount: int) -> void:
	if amount <= 0 or invincibility_remaining > 0.0 or current_cells <= 0:
		return

	current_cells = maxi(current_cells - amount, 0)
	cells_changed.emit(current_cells, max_cells)
	_start_invincibility()

	if current_cells == 0:
		player_died.emit()

func _try_use_coolant() -> void:
	if not Input.is_action_just_pressed("use_coolant"):
		return
	if coolant_count <= 0 or current_cells >= max_cells:
		return

	coolant_count -= 1
	coolant_changed.emit(coolant_count)
	current_cells = mini(current_cells + coolant_heal_amount, max_cells)
	cells_changed.emit(current_cells, max_cells)

func _start_invincibility() -> void:
	invincibility_remaining = invincibility_duration
	flash_timer = 0.0
	flash_visible_state = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.35)

func _update_invincibility(delta: float) -> void:
	if invincibility_remaining <= 0.0:
		if not flash_visible_state:
			flash_visible_state = true
			sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return

	invincibility_remaining = maxf(invincibility_remaining - delta, 0.0)
	flash_timer += delta
	if flash_timer >= 0.08:
		flash_timer = 0.0
		flash_visible_state = not flash_visible_state
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0 if flash_visible_state else 0.35)

	if invincibility_remaining <= 0.0:
		flash_visible_state = true
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _update_contact_damage(delta: float) -> void:
	if contact_damage_sources.is_empty():
		contact_damage_tick_remaining = 0.0
		return

	contact_damage_tick_remaining = maxf(contact_damage_tick_remaining - delta, 0.0)
	if contact_damage_tick_remaining > 0.0:
		return

	take_damage(contact_damage_amount)
	contact_damage_tick_remaining = contact_damage_interval

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if not _is_enemy_bullet(area):
		return

	var bullet_damage: int = 1
	var damage_value: Variant = area.get("damage")
	if typeof(damage_value) in [TYPE_INT, TYPE_FLOAT]:
		bullet_damage = maxi(int(damage_value), 1)

	take_damage(bullet_damage)
	area.queue_free()

func _on_contact_body_entered(body: Node2D) -> void:
	if _is_enemy_contact_source(body):
		contact_damage_sources[body.get_instance_id()] = body
		contact_damage_tick_remaining = 0.0

func _on_contact_body_exited(body: Node2D) -> void:
	contact_damage_sources.erase(body.get_instance_id())

func _on_contact_area_entered(area: Area2D) -> void:
	if _is_enemy_contact_source(area):
		contact_damage_sources[area.get_instance_id()] = area
		contact_damage_tick_remaining = 0.0

func _on_contact_area_exited(area: Area2D) -> void:
	contact_damage_sources.erase(area.get_instance_id())

func _is_enemy_bullet(area: Area2D) -> bool:
	return (area.collision_layer & (1 << 3)) != 0

func _is_enemy_contact_source(node: Node) -> bool:
	if not node is CollisionObject2D:
		return false
	var collision_object := node as CollisionObject2D
	return (collision_object.collision_layer & (1 << 2)) != 0
