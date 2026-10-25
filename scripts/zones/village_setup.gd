extends Node2D

@onready var player: PlayerController = $Player
@onready var hud_label: Label = $Hud/InfoPanel/MarginContainer/Rows/RunStateLabel

func _ready() -> void:
	var game_manager := get_node("/root/GameManager") as OasisGameManager
	game_manager.current_zone = scene_file_path
	game_manager.apply_to_player(player)
	_update_state_label()
	await get_tree().process_frame
	_show_intro_dialogue()

func _update_state_label() -> void:
	hud_label.text = "Village | Cells %d/%d | Ammo %d/%d | Coolant %d" % [
		player.current_cells,
		player.max_cells,
		player.current_ammo,
		player.max_ammo,
		player.coolant_count
	]

func _show_intro_dialogue() -> void:
	var dialogue_manager := get_node("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("DialogueManager autoload is missing.")
		return
	dialogue_manager.show_dialogue("intro_transmission", player)
