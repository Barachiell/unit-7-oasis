extends Node

signal dialogue_finished(dialogue_id: String)

const DIALOGUE_FILE_PATH := "res://data/dialogue.json"
const DIALOGUE_BOX_SCENE := preload("res://ui/dialogue_box.tscn")

var dialogue_data: Dictionary = {}
var current_dialogue_box: CanvasLayer
var blocked_player: PlayerController
var current_dialogue_id: String = ""

func _ready() -> void:
	_load_dialogue_data()

func show_dialogue(dialogue_id: String, player: PlayerController = null) -> bool:
	if dialogue_id.is_empty():
		push_error("DialogueManager.show_dialogue called with empty id.")
		return false
	if not dialogue_data.has(dialogue_id):
		push_error("Dialogue id '%s' does not exist in %s." % [dialogue_id, DIALOGUE_FILE_PATH])
		return false
	if current_dialogue_box != null and is_instance_valid(current_dialogue_box):
		push_error("Cannot start dialogue '%s' while '%s' is active." % [dialogue_id, current_dialogue_id])
		return false

	var raw_pages: Variant = dialogue_data[dialogue_id]
	if not raw_pages is Array:
		push_error("Dialogue id '%s' must map to an array of pages." % dialogue_id)
		return false
	var raw_pages_array: Array = raw_pages

	var pages: Array[Dictionary] = []
	for raw_page in raw_pages_array:
		if not raw_page is Dictionary:
			continue
		pages.append(raw_page)
	if pages.is_empty():
		push_error("Dialogue id '%s' has no valid pages." % dialogue_id)
		return false

	current_dialogue_id = dialogue_id
	blocked_player = player
	if blocked_player != null:
		blocked_player.set_input_enabled(false)

	var dialogue_box_variant := DIALOGUE_BOX_SCENE.instantiate()
	var dialogue_box := dialogue_box_variant as CanvasLayer
	if dialogue_box == null:
		push_error("Failed to instantiate dialogue box scene.")
		return false
	current_dialogue_box = dialogue_box
	get_tree().root.add_child(current_dialogue_box)
	current_dialogue_box.connect("dialogue_completed", Callable(self, "_on_dialogue_completed"))
	current_dialogue_box.call("show_pages", pages)
	return true

func _on_dialogue_completed() -> void:
	if blocked_player != null:
		blocked_player.set_input_enabled(true)
		blocked_player = null

	if current_dialogue_box != null and is_instance_valid(current_dialogue_box):
		current_dialogue_box.queue_free()
	current_dialogue_box = null

	var finished_id: String = current_dialogue_id
	current_dialogue_id = ""
	dialogue_finished.emit(finished_id)

func _load_dialogue_data() -> void:
	var file := FileAccess.open(DIALOGUE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot read dialogue file at %s." % DIALOGUE_FILE_PATH)
		return

	var parse: Variant = JSON.parse_string(file.get_as_text())
	if not parse is Dictionary:
		push_error("Dialogue file %s must contain a top-level JSON object." % DIALOGUE_FILE_PATH)
		return

	dialogue_data = parse as Dictionary
