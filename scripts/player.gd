class_name PlayerController
extends CharacterBody2D

signal stamina_changed(current: float, maximum: float)

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

@onready var muzzle: Marker2D = $Muzzle
@onready var camera: Camera2D = $Camera2D

var aim_direction: Vector2 = Vector2.RIGHT
var current_stamina: float = max_stamina
var run_locked: bool = false
var regen_delay_remaining: float = 0.0

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

func _ready() -> void:
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)

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
