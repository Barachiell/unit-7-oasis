class_name PlayerBullet
extends Area2D

enum SpritePalette {
	PLAYER,
	ENEMY,
}

@export var speed: float = 400.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export_flags_2d_physics var damageable_layers: int = 0
@export var sprite_palette: SpritePalette = SpritePalette.PLAYER

const OCTANT_NAMES: Array[String] = [
	"east",
	"south-east",
	"south",
	"south-west",
	"west",
	"north-west",
	"north",
	"north-east",
]

const PLAYER_TEXTURE_BY_OCTANT: Dictionary = {
	"east": preload("res://assets/sprites/bullets/player/east.png"),
	"north-east": preload("res://assets/sprites/bullets/player/north-east.png"),
	"north": preload("res://assets/sprites/bullets/player/north.png"),
	"north-west": preload("res://assets/sprites/bullets/player/north-west.png"),
	"west": preload("res://assets/sprites/bullets/player/west.png"),
	"south-west": preload("res://assets/sprites/bullets/player/south-west.png"),
	"south": preload("res://assets/sprites/bullets/player/south.png"),
	"south-east": preload("res://assets/sprites/bullets/player/south-east.png"),
}

const ENEMY_TEXTURE_BY_OCTANT: Dictionary = {
	"east": preload("res://assets/sprites/bullets/enemy/east.png"),
	"north-east": preload("res://assets/sprites/bullets/enemy/north-east.png"),
	"north": preload("res://assets/sprites/bullets/enemy/north.png"),
	"north-west": preload("res://assets/sprites/bullets/enemy/north-west.png"),
	"west": preload("res://assets/sprites/bullets/enemy/west.png"),
	"south-west": preload("res://assets/sprites/bullets/enemy/south-west.png"),
	"south": preload("res://assets/sprites/bullets/enemy/south.png"),
	"south-east": preload("res://assets/sprites/bullets/enemy/south-east.png"),
}

var direction: Vector2 = Vector2.RIGHT
var lifetime_elapsed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if sprite_palette == SpritePalette.ENEMY:
		add_to_group("enemy_projectile")

	_apply_directional_sprite()
	body_entered.connect(_on_hit_body)
	area_entered.connect(_on_hit_area)

func _apply_directional_sprite() -> void:
	if sprite == null:
		push_error("Bullet sprite node is missing.")
		return

	var texture_set: Dictionary = _texture_set_for_palette()
	var octant_name: String = _direction_to_octant(direction)
	var texture: Texture2D = texture_set.get(octant_name)
	if texture == null:
		push_error("Missing bullet texture for octant %s and palette %d." % [octant_name, sprite_palette])
		return

	sprite.texture = texture
	rotation = 0.0
	sprite.rotation = 0.0

func _texture_set_for_palette() -> Dictionary:
	return PLAYER_TEXTURE_BY_OCTANT if sprite_palette == SpritePalette.PLAYER else ENEMY_TEXTURE_BY_OCTANT

func _direction_to_octant(value: Vector2) -> String:
	if value.length_squared() <= 0.0001:
		return "east"
	var octant_index: int = wrapi(int(round(value.angle() / (PI / 4.0))), 0, 8)
	return OCTANT_NAMES[octant_index]

func _physics_process(delta: float) -> void:
	var start_position := global_position
	var end_position := start_position + direction * speed * delta
	var hit := _find_collision_on_path(start_position, end_position)
	if not hit.is_empty():
		global_position = hit.get("position", start_position)
		if _handle_raycast_hit(hit.get("collider")):
			return

	global_position = end_position
	lifetime_elapsed += delta
	if lifetime_elapsed >= lifetime:
		queue_free()

func _find_collision_on_path(start: Vector2, finish: Vector2) -> Dictionary:
	if start.is_equal_approx(finish):
		return {}

	var query := PhysicsRayQueryParameters2D.create(start, finish)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self]
	return get_world_2d().direct_space_state.intersect_ray(query)

func _handle_raycast_hit(collider: Variant) -> bool:
	if collider == null:
		return false

	if collider is TileMapLayer:
		queue_free()
		return true

	if collider is Area2D:
		_on_hit_area(collider as Area2D)
		return is_queued_for_deletion()

	if collider is Node2D:
		_on_hit_body(collider as Node2D)
		return is_queued_for_deletion()

	return false

func _on_hit_body(body: Node2D) -> void:
	if not body is CollisionObject2D:
		return

	var collision_body := body as CollisionObject2D
	var is_world_collision := (collision_body.collision_layer & (1 << 4)) != 0
	if _can_damage_target(collision_body) and body.has_method("take_bullet_hit"):
		body.call("take_bullet_hit", damage)
		queue_free()
	elif is_world_collision:
		queue_free()

func _on_hit_area(area: Area2D) -> void:
	if _can_damage_target(area) and area.has_method("take_bullet_hit"):
		area.call("take_bullet_hit", damage)
		queue_free()
	elif area.get_parent() is CollisionObject2D and _can_damage_target(area.get_parent() as CollisionObject2D) and area.get_parent().has_method("take_bullet_hit"):
		area.get_parent().call("take_bullet_hit", damage)
		queue_free()

func _can_damage_target(target: CollisionObject2D) -> bool:
	if damageable_layers == 0:
		return true
	return (target.collision_layer & damageable_layers) != 0
