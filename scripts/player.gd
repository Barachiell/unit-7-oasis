class_name PlayerController
extends CharacterBody2D

signal stamina_changed(current: float, maximum: float)
signal ammo_changed(current: int, maximum: int)

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
@export var max_ammo: int = 20
@export var fire_rate: float = 0.15
@export var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn")

@onready var muzzle: Marker2D = $Muzzle
@onready var camera: Camera2D = $Camera2D

var aim_direction: Vector2 = Vector2.RIGHT
var current_stamina: float = max_stamina
var run_locked: bool = false
var regen_delay_remaining: float = 0.0
var current_ammo: int = max_ammo
var fire_cooldown_remaining: float = 0.0

func _physics_process(delta: float) -> void:
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

func _ready() -> void:
	current_stamina = max_stamina
	current_ammo = max_ammo
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
	bullet.rotation = aim_direction.angle()

	var level_root := get_tree().current_scene
	if level_root == null:
		push_error("Cannot spawn bullet: current scene is unavailable.")
		bullet.queue_free()
		return

	level_root.add_child(bullet)

func _try_play_dry_click() -> void:
	# Audio bus wiring is added in Block 14.
	pass
