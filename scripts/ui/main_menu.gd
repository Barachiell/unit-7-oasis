extends Control

const VILLAGE_SCENE_PATH := "res://scenes/zones/village.tscn"
const CONTROLS_SCENE_PATH := "res://ui/controls.tscn"

@onready var start_button: Button = $CenterContainer/MenuPanel/MarginContainer/Rows/StartButton
@onready var controls_button: Button = $CenterContainer/MenuPanel/MarginContainer/Rows/ControlsButton
@onready var quit_button: Button = $CenterContainer/MenuPanel/MarginContainer/Rows/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	if OS.has_feature("web"):
		quit_button.visible = false
		start_button.focus_neighbor_bottom = start_button.get_path_to(controls_button)
		controls_button.focus_neighbor_top = controls_button.get_path_to(start_button)
	else:
		start_button.focus_neighbor_bottom = start_button.get_path_to(controls_button)
		controls_button.focus_neighbor_top = controls_button.get_path_to(start_button)
		controls_button.focus_neighbor_bottom = controls_button.get_path_to(quit_button)
		quit_button.focus_neighbor_top = quit_button.get_path_to(controls_button)

	start_button.grab_focus()

func _on_start_pressed() -> void:
	var game_manager := get_node("/root/GameManager") as OasisGameManager
	game_manager.reset_run_state()
	get_tree().change_scene_to_file(VILLAGE_SCENE_PATH)

func _on_controls_pressed() -> void:
	get_tree().change_scene_to_file(CONTROLS_SCENE_PATH)

func _on_quit_pressed() -> void:
	get_tree().quit()
