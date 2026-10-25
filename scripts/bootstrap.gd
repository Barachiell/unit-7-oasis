extends Node2D

const ACTION_DEADZONE := 0.5

func _ready() -> void:
	_define_input_actions()

func _define_input_actions() -> void:
	_ensure_action_with_events("move_up", [_key_event(KEY_W), _key_event(KEY_UP)])
	_ensure_action_with_events("move_down", [_key_event(KEY_S), _key_event(KEY_DOWN)])
	_ensure_action_with_events("move_left", [_key_event(KEY_A), _key_event(KEY_LEFT)])
	_ensure_action_with_events("move_right", [_key_event(KEY_D), _key_event(KEY_RIGHT)])
	_ensure_action_with_events("shoot", [_mouse_button_event(MOUSE_BUTTON_LEFT), _key_event(KEY_K)])
	_ensure_action_with_events("run", [_key_event(KEY_SHIFT)])
	_ensure_action_with_events("use_coolant", [_key_event(KEY_R)])
	_ensure_action_with_events("dash", [_key_event(KEY_SPACE)])
	_ensure_action_with_events("interact", [_key_event(KEY_E)])
	_ensure_action_with_events("advance_dialogue", [_key_event(KEY_ENTER), _key_event(KEY_KP_ENTER)])
	_ensure_action_with_events("pause", [_key_event(KEY_ESCAPE)])

func _ensure_action_with_events(action_name: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, ACTION_DEADZONE)

	for event in events:
		if not InputMap.action_has_event(action_name, event):
			InputMap.action_add_event(action_name, event)

func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event

func _mouse_button_event(button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event
