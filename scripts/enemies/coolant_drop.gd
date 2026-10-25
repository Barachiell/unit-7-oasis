class_name CoolantDrop
extends Area2D

@export var amount: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("add_coolant"):
		return

	body.call("add_coolant", amount)
	queue_free()
