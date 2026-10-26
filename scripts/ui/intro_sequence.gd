extends Control

const VILLAGE_SCENE_PATH := "res://scenes/zones/village.tscn"
const INTRO_VIDEO_PATH := "res://assets/video/oasis_intro.ogv"
const INTRO_DIALOGUE_ID := "intro_opening"
const DIALOGUE_MANAGER_PATH := "/root/DialogueManager"
const GAME_MANAGER_PATH := "/root/GameManager"
const VIDEO_SOURCE_SIZE := Vector2(1280.0, 720.0)
const VIDEO_ZOOM := 1.35

@onready var intro_video_player: VideoStreamPlayer = $VideoCenter/IntroVideoPlayer
@onready var continue_label: Label = $ContinuePrompt/ContinueLabel

var is_awaiting_continue: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	continue_label.visible = false
	intro_video_player.custom_minimum_size = _zoomed_video_size()
	_play_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if not is_awaiting_continue or is_transitioning:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("advance_dialogue"):
		get_viewport().set_input_as_handled()
		_start_game()

func _play_sequence() -> void:
	await get_tree().process_frame
	await _show_intro_dialogue()
	if is_transitioning:
		return

	await _play_intro_video()
	if is_transitioning:
		return

	_await_player_continue()

func _show_intro_dialogue() -> void:
	var dialogue_manager: Node = get_node_or_null(DIALOGUE_MANAGER_PATH)
	if dialogue_manager == null:
		push_warning("DialogueManager autoload missing; skipping intro dialogue.")
		return

	var started: bool = dialogue_manager.show_dialogue(INTRO_DIALOGUE_ID)
	if not started:
		return

	while true:
		var finished_id: String = await dialogue_manager.dialogue_finished
		if finished_id == INTRO_DIALOGUE_ID:
			return

func _play_intro_video() -> void:
	var intro_stream: VideoStream = _load_intro_stream()
	if intro_stream == null:
		push_warning("Intro video stream could not be loaded; skipping playback.")
		return

	intro_video_player.stream = intro_stream
	intro_video_player.visible = true
	intro_video_player.play()
	await intro_video_player.finished

func _zoomed_video_size() -> Vector2:
	var viewport_width: float = float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var scale: float = (viewport_width / VIDEO_SOURCE_SIZE.x) * VIDEO_ZOOM
	return (VIDEO_SOURCE_SIZE * scale).round()

func _load_intro_stream() -> VideoStream:
	if not ResourceLoader.exists(INTRO_VIDEO_PATH):
		return null

	var loaded_stream: Resource = ResourceLoader.load(INTRO_VIDEO_PATH)
	if loaded_stream is VideoStream:
		return loaded_stream

	return null

func _await_player_continue() -> void:
	continue_label.visible = true
	is_awaiting_continue = true

func _start_game() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	is_awaiting_continue = false
	continue_label.visible = false
	var game_manager: OasisGameManager = get_node(GAME_MANAGER_PATH)
	game_manager.reset_run_state()
	get_tree().change_scene_to_file(VILLAGE_SCENE_PATH)
