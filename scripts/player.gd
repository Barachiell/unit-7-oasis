extends CharacterBody2D

@export var walk_speed: float = 90.0
@export var muzzle_radius: float = 12.0

@onready var muzzle: Marker2D = $Muzzle

var aim_direction: Vector2 = Vector2.RIGHT

func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction.normalized() * walk_speed
	move_and_slide()
	_update_aim_direction()

func _update_aim_direction() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.0001:
		aim_direction = to_mouse.normalized()

	muzzle.position = aim_direction * muzzle_radius
	muzzle.rotation = aim_direction.angle()
