extends Control

const MAIN_MENU_SCENE_PATH := "res://ui/main_menu.tscn"

@onready var play_button: Button = $CenterContainer/PlayButton

var is_transitioning: bool = false

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	play_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_play_pressed()

func _on_play_pressed() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
