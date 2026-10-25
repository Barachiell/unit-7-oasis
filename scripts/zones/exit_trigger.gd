extends Area2D

@export_file("*.tscn") var target_zone: String = ""
@export var target_spawn_id: String = "start"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController:
		return
	if target_zone.is_empty():
		push_error("ExitTrigger has no target_zone configured.")
		return
	var zone_root := get_parent().get_parent()
	if zone_root == null:
		return
	if zone_root.has_method("request_zone_change"):
		zone_root.call("request_zone_change", target_zone, target_spawn_id)
