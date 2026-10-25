class_name AmmoDrop
extends Area2D

@export var amount: int = 3

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("add_ammo"):
		return

	body.call("add_ammo", amount)
	queue_free()
