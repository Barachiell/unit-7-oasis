class_name PlayerBullet
extends Area2D

@export var speed: float = 400.0
@export var damage: int = 1
@export var lifetime: float = 1.2

var direction: Vector2 = Vector2.RIGHT
var lifetime_elapsed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_hit_body)
	area_entered.connect(_on_hit_area)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime_elapsed += delta
	if lifetime_elapsed >= lifetime:
		queue_free()

func _on_hit_body(_body: Node2D) -> void:
	queue_free()

func _on_hit_area(_area: Area2D) -> void:
	queue_free()
