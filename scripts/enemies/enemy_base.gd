class_name EnemyBase
extends CharacterBody2D

enum EnemyState {
	IDLE,
	PATROL,
	CHASE
}

@export var max_health: int = 1
@export var move_speed: float = 62.0
@export var fire_rate: float = 1.4
@export var telegraph_time: float = 0.6
@export var bullet_speed: float = 140.0
@export var detection_radius: float = 155.0
@export var ammo_drop_amount: int = 3
@export var lose_player_delay: float = 2.0
@export var attack_range: float = 130.0
@export var bullet_scene: PackedScene = preload("res://scenes/enemies/enemy_bullet.tscn")
@export var ammo_drop_scene: PackedScene = preload("res://scenes/pickups/ammo_drop.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var line_of_sight: RayCast2D = $LineOfSight
@onready var patrol_points_root: Node2D = $PatrolPoints

var current_state: EnemyState = EnemyState.IDLE
var current_health: int = 1
var fire_cooldown_remaining: float = 0.0
var telegraph_remaining: float = 0.0
var lose_player_timer: float = 0.0
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0
var player: PlayerController
var is_player_in_detection: bool = false

func _ready() -> void:
	current_health = max_health
	_configure_detection_radius()
	_collect_patrol_points()
	current_state = EnemyState.PATROL if not patrol_points.is_empty() else EnemyState.IDLE
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	player = get_tree().get_first_node_in_group("player") as PlayerController

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as PlayerController

	fire_cooldown_remaining = maxf(fire_cooldown_remaining - delta, 0.0)
	_update_telegraph(delta)

	match current_state:
		EnemyState.IDLE:
			velocity = Vector2.ZERO
			if _can_engage_player():
				current_state = EnemyState.CHASE
		EnemyState.PATROL:
			_patrol()
			if _can_engage_player():
				current_state = EnemyState.CHASE
		EnemyState.CHASE:
			_chase_and_attack(delta)

	move_and_slide()

func _configure_detection_radius() -> void:
	var circle := detection_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = detection_radius

func _collect_patrol_points() -> void:
	patrol_points.clear()
	for child in patrol_points_root.get_children():
		if child is Marker2D:
			patrol_points.append((child as Marker2D).global_position)

func _patrol() -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return

	var target := patrol_points[patrol_index]
	var to_target := target - global_position
	if to_target.length() <= 4.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		velocity = Vector2.ZERO
		return

	velocity = to_target.normalized() * move_speed
	_face_direction(velocity.normalized())

func _chase_and_attack(delta: float) -> void:
	if player == null:
		current_state = EnemyState.PATROL
		velocity = Vector2.ZERO
		return

	var has_line_of_sight := _has_line_of_sight_to_player()
	if has_line_of_sight and is_player_in_detection:
		lose_player_timer = 0.0
	else:
		lose_player_timer += delta
		if lose_player_timer >= lose_player_delay:
			current_state = EnemyState.PATROL
			velocity = Vector2.ZERO
			return

	var to_player := player.global_position - global_position
	var distance_to_player := to_player.length()
	if distance_to_player > attack_range:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	if distance_to_player > 0.001:
		_face_direction(to_player.normalized())

	if has_line_of_sight and is_player_in_detection:
		_try_shoot()

func _face_direction(direction: Vector2) -> void:
	if direction.length_squared() <= 0.0001:
		return
	muzzle.rotation = direction.angle()

func _can_engage_player() -> bool:
	return player != null and is_player_in_detection and _has_line_of_sight_to_player()

func _has_line_of_sight_to_player() -> bool:
	if player == null:
		return false

	var to_player := player.global_position - global_position
	line_of_sight.target_position = to_player
	line_of_sight.force_raycast_update()
	if not line_of_sight.is_colliding():
		return true

	var collider := line_of_sight.get_collider()
	return collider == player

func _try_shoot() -> void:
	if telegraph_remaining > 0.0 or fire_cooldown_remaining > 0.0:
		return

	telegraph_remaining = telegraph_time
	sprite.modulate = Color(1.4, 1.4, 1.4, 1.0)

func _update_telegraph(delta: float) -> void:
	if telegraph_remaining <= 0.0:
		return

	telegraph_remaining = maxf(telegraph_remaining - delta, 0.0)
	if telegraph_remaining > 0.0:
		return

	_spawn_enemy_bullet()
	fire_cooldown_remaining = fire_rate
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _spawn_enemy_bullet() -> void:
	if bullet_scene == null or player == null:
		return

	var bullet_instance := bullet_scene.instantiate()
	if not bullet_instance is Area2D:
		return
	var bullet := bullet_instance as Area2D

	var shoot_direction := (player.global_position - global_position).normalized()
	bullet.global_position = muzzle.global_position
	bullet.rotation = shoot_direction.angle()
	bullet.set("direction", shoot_direction)
	bullet.set("speed", bullet_speed)

	get_tree().current_scene.add_child(bullet)

func take_bullet_hit(amount: int) -> void:
	_apply_hit(maxi(amount, 1))

func _apply_hit(amount: int) -> void:
	current_health = maxi(current_health - amount, 0)
	var hit_tween := create_tween()
	hit_tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
	hit_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
	if current_health == 0:
		_die()

func _die() -> void:
	_spawn_death_effect()
	_spawn_ammo_drop()
	queue_free()

func _spawn_death_effect() -> void:
	var effect := Polygon2D.new()
	effect.polygon = PackedVector2Array([
		Vector2(0, -8),
		Vector2(8, 0),
		Vector2(0, 8),
		Vector2(-8, 0)
	])
	effect.color = Color(1.0, 0.5, 0.2, 0.9)
	effect.global_position = global_position
	get_tree().current_scene.add_child(effect)

	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector2(1.8, 1.8), 0.16)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, 0.16)
	tween.finished.connect(effect.queue_free)

func _spawn_ammo_drop() -> void:
	if ammo_drop_scene == null:
		return

	var drop_instance := ammo_drop_scene.instantiate()
	if not drop_instance is AmmoDrop:
		return
	var ammo_drop := drop_instance as AmmoDrop
	ammo_drop.amount = ammo_drop_amount
	ammo_drop.global_position = global_position
	get_tree().current_scene.add_child(ammo_drop)

func _on_detection_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		is_player_in_detection = true
		player = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player:
		is_player_in_detection = false
