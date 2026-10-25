extends Control

const MAIN_MENU_SCENE_PATH := "res://ui/main_menu.tscn"

@onready var back_button: Button = $CenterContainer/ControlsPanel/MarginContainer/Rows/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
