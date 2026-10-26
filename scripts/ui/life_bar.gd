class_name LifeBar
extends Control

const BACKGROUND_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const BORDER_COLOR := Color(0.86, 0.86, 0.86, 1.0)
const FILLED_COLOR := Color(0.36, 0.93, 0.58, 1.0)
const EMPTY_COLOR := Color(0.2, 0.2, 0.2, 0.9)
const PADDING := 3.0
const SEGMENT_GAP := 2.0
const SEGMENT_SIZE := Vector2(14.0, 14.0)

var _max_lives: int = 7
var _current_lives: int = 7

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_minimum_size()
	queue_redraw()

func set_lives(current: int, maximum: int) -> void:
	_max_lives = maxi(maximum, 1)
	_current_lives = clampi(current, 0, _max_lives)
	_update_minimum_size()
	queue_redraw()

func _draw() -> void:
	var max_lives_float: float = float(_max_lives)
	var bar_width: float = PADDING * 2.0 + (SEGMENT_SIZE.x * max_lives_float) + (SEGMENT_GAP * float(_max_lives - 1))
	var bar_height: float = PADDING * 2.0 + SEGMENT_SIZE.y
	var bar_rect := Rect2(Vector2.ZERO, Vector2(bar_width, bar_height))

	draw_rect(bar_rect, BACKGROUND_COLOR, true)
	draw_rect(bar_rect, BORDER_COLOR, false, 1.0)

	for index in range(_max_lives):
		var segment_x: float = PADDING + float(index) * (SEGMENT_SIZE.x + SEGMENT_GAP)
		var segment_rect := Rect2(Vector2(segment_x, PADDING), SEGMENT_SIZE)
		var segment_color: Color = FILLED_COLOR if index < _current_lives else EMPTY_COLOR
		draw_rect(segment_rect, segment_color, true)
		draw_rect(segment_rect, BORDER_COLOR, false, 1.0)

func _update_minimum_size() -> void:
	var max_lives_float: float = float(maxi(_max_lives, 1))
	var width: float = PADDING * 2.0 + (SEGMENT_SIZE.x * max_lives_float) + (SEGMENT_GAP * float(maxi(_max_lives - 1, 0)))
	var height: float = PADDING * 2.0 + SEGMENT_SIZE.y
	custom_minimum_size = Vector2(width, height)
