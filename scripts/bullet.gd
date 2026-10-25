class_name PlayerBullet
extends Area2D

@export var speed: float = 400.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export_flags_2d_physics var damageable_layers: int = 0

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

func _on_hit_body(body: Node2D) -> void:
	if body is CollisionObject2D and _can_damage_target(body as CollisionObject2D) and body.has_method("take_bullet_hit"):
		body.call("take_bullet_hit", damage)
	queue_free()

func _on_hit_area(area: Area2D) -> void:
	if _can_damage_target(area) and area.has_method("take_bullet_hit"):
		area.call("take_bullet_hit", damage)
	elif area.get_parent() is CollisionObject2D and _can_damage_target(area.get_parent() as CollisionObject2D) and area.get_parent().has_method("take_bullet_hit"):
		area.get_parent().call("take_bullet_hit", damage)
	queue_free()

func _can_damage_target(target: CollisionObject2D) -> bool:
	if damageable_layers == 0:
		return true
	return (target.collision_layer & damageable_layers) != 0
