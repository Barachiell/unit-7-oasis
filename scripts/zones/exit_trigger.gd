extends Area2D

@export_file("*.tscn") var target_zone: String = ""
@export var target_spawn_id: String = "start"
@export var required_component_id: String = ""

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
	if not required_component_id.is_empty():
		var game_manager := get_node_or_null("/root/GameManager")
		if game_manager == null:
			push_error("ExitTrigger cannot validate required component without GameManager.")
			return
		if not game_manager.has_method("has_component"):
			push_error("ExitTrigger expected GameManager.has_component().")
			return
		var can_travel: Variant = game_manager.call("has_component", required_component_id)
		if not (can_travel is bool):
			push_error("ExitTrigger received non-boolean from GameManager.has_component().")
			return
		if not bool(can_travel):
			if zone_root.has_method("show_locked_exit_hint"):
				zone_root.call("show_locked_exit_hint", required_component_id)
			return
	if zone_root.has_method("request_zone_change"):
		zone_root.call("request_zone_change", target_zone, target_spawn_id)
