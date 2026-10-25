extends Area2D

@export var component_id: String = ""
@export var pickup_dialogue_id: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var game_manager: Node = get_node("/root/GameManager")
	if game_manager.has_component(component_id):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController:
		return
	var zone_root := get_parent().get_parent()
	if zone_root != null and zone_root.has_method("on_axion_component_collected"):
		zone_root.call("on_axion_component_collected", component_id, pickup_dialogue_id)
		queue_free()
