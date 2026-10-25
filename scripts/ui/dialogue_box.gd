class_name OasisDialogueBox
extends CanvasLayer

signal dialogue_completed

const LETTERS_PER_SECOND := 52.0

@onready var speaker_label: Label = $BottomContainer/Panel/MarginContainer/Rows/SpeakerLabel
@onready var text_label: RichTextLabel = $BottomContainer/Panel/MarginContainer/Rows/DialogueText
@onready var hint_label: Label = $BottomContainer/Panel/MarginContainer/Rows/HintLabel

var pages: Array[Dictionary] = []
var page_index: int = -1
var is_typing: bool = false
var current_tween: Tween

func show_pages(dialogue_pages: Array[Dictionary]) -> void:
	pages = dialogue_pages
	page_index = -1
	visible = true
	_next_page()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if not event.is_action_pressed("interact") and not event.is_action_pressed("advance_dialogue"):
		return

	get_viewport().set_input_as_handled()
	if is_typing:
		_finish_current_page()
	else:
		_next_page()

func _next_page() -> void:
	page_index += 1
	if page_index >= pages.size():
		visible = false
		dialogue_completed.emit()
		return

	var page: Dictionary = pages[page_index]
	speaker_label.text = str(page.get("speaker", ""))
	text_label.text = str(page.get("text", ""))
	text_label.visible_ratio = 0.0
	_start_typewriter()

func _start_typewriter() -> void:
	if current_tween != null and current_tween.is_valid():
		current_tween.kill()

	var text_length: int = maxi(text_label.text.length(), 1)
	var duration: float = maxf(float(text_length) / LETTERS_PER_SECOND, 0.1)
	is_typing = true
	hint_label.text = "E / Enter: Skip"
	current_tween = create_tween()
	current_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	current_tween.finished.connect(_on_typewriter_finished)

func _on_typewriter_finished() -> void:
	is_typing = false
	hint_label.text = "E / Enter: Next"

func _finish_current_page() -> void:
	if current_tween != null and current_tween.is_valid():
		current_tween.kill()
	text_label.visible_ratio = 1.0
	is_typing = false
	hint_label.text = "E / Enter: Next"
