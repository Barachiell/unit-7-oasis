class_name VideoSequence
extends Control

const DIALOGUE_MANAGER_PATH := "/root/DialogueManager"
const GAME_MANAGER_PATH := "/root/GameManager"
const DEFAULT_NEXT_SCENE_PATH := "res://ui/main_menu.tscn"
const VIDEO_SOURCE_SIZE := Vector2(1280.0, 720.0)

@export_file("*.ogv") var video_path: String = ""
@export var dialogue_id: String = ""
@export_file("*.tscn") var next_scene_path: String = ""
@export var resets_run_state_on_exit: bool = false
@export var video_zoom: float = 1.35
@export var continue_text: String = "Press Enter to continue"
@export var is_skippable: bool = true

@onready var video_player: VideoStreamPlayer = $VideoCenter/VideoPlayer
@onready var continue_label: Label = $ContinuePrompt/ContinueLabel

var is_awaiting_continue: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	continue_label.visible = false
	continue_label.text = continue_text
	video_player.custom_minimum_size = _zoomed_video_size()
	_play_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return

	if is_awaiting_continue:
		if event.is_action_pressed("interact") or event.is_action_pressed("advance_dialogue"):
			get_viewport().set_input_as_handled()
			_go_to_next_scene()
		return

	if not is_skippable:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if not video_player.is_playing():
		return

	get_viewport().set_input_as_handled()
	video_player.stop()
	_await_player_continue()

func _play_sequence() -> void:
	await get_tree().process_frame
	await _show_dialogue()
	if is_transitioning:
		return

	await _play_video()
	if is_transitioning:
		return

	_await_player_continue()

func _show_dialogue() -> void:
	if dialogue_id.is_empty():
		return

	var dialogue_manager: Node = get_node_or_null(DIALOGUE_MANAGER_PATH)
	if dialogue_manager == null:
		push_warning("DialogueManager autoload missing; skipping dialogue.")
		return

	var started: bool = dialogue_manager.show_dialogue(dialogue_id)
	if not started:
		return

	while true:
		var finished_id: String = await dialogue_manager.dialogue_finished
		if finished_id == dialogue_id:
			return

func _play_video() -> void:
	var stream: VideoStream = _load_video_stream()
	if stream == null:
		push_warning("Video stream '%s' could not be loaded; skipping playback." % video_path)
		return

	video_player.stream = stream
	video_player.visible = true
	video_player.play()
	await video_player.finished

func _zoomed_video_size() -> Vector2:
	var viewport_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var scale: float = (viewport_width / VIDEO_SOURCE_SIZE.x) * video_zoom
	return (VIDEO_SOURCE_SIZE * scale).round()

func _load_video_stream() -> VideoStream:
	if video_path.is_empty():
		push_warning("Video path is empty; skipping playback.")
		return null
	if not ResourceLoader.exists(video_path):
		return null

	var loaded_stream: Resource = ResourceLoader.load(video_path)
	if loaded_stream is VideoStream:
		return loaded_stream

	return null

func _await_player_continue() -> void:
	if is_awaiting_continue:
		return
	continue_label.visible = true
	is_awaiting_continue = true

func _go_to_next_scene() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	is_awaiting_continue = false
	continue_label.visible = false

	if resets_run_state_on_exit:
		var game_manager: OasisGameManager = get_node_or_null(GAME_MANAGER_PATH)
		if game_manager == null:
			push_error("GameManager autoload missing; cannot reset run state.")
		else:
			game_manager.reset_run_state()

	var target_scene_path: String = _resolve_next_scene_path()
	get_tree().change_scene_to_file(target_scene_path)

func _resolve_next_scene_path() -> String:
	if not next_scene_path.is_empty():
		return next_scene_path
	push_error("VideoSequence next_scene_path is empty. Falling back to main menu.")
	return DEFAULT_NEXT_SCENE_PATH
