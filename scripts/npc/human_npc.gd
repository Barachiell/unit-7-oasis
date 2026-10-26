extends Area2D

@export var dialogue_id: String = ""
@export var npc_name: String = "Villager"

@onready var prompt_label: Label = $PromptLabel

var player_in_range: bool = false
var player_ref: PlayerController

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label.visible = false
	prompt_label.text = "E: Talk"

func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return
	if not event.is_action_pressed("interact"):
		return
	if dialogue_id.is_empty():
		return

	var dialogue_manager: Node = get_node("/root/DialogueManager")
	var active_dialogue_id: Variant = dialogue_manager.get("current_dialogue_id")
	if active_dialogue_id is String and not String(active_dialogue_id).is_empty():
		return

	dialogue_manager.show_dialogue(dialogue_id, player_ref)
	get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController:
		return
	player_in_range = true
	player_ref = body
	prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body != player_ref:
		return
	player_in_range = false
	player_ref = null
	prompt_label.visible = false
