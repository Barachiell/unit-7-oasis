class_name PlayerSpriteDirector
extends RefCounted

enum VisualState {
	STANDING,
	WALKING,
	SHOOTING,
}

const OCTANT_NAMES: Array[String] = [
	"east",
	"south-east",
	"south",
	"south-west",
	"west",
	"north-west",
	"north",
	"north-east",
]

const STATE_FOLDER_BY_VISUAL_STATE: Dictionary = {
	VisualState.STANDING: "standing",
	VisualState.WALKING: "walking",
	VisualState.SHOOTING: "shooting",
}

const FALLBACK_TEXTURE_KEY: String = "standing/south"
const WALK_FRAME_DURATION: float = 0.16
const WALK_CYCLE_FRAME_COUNT: int = 2

const SPRITE_TEXTURE_BY_KEY: Dictionary = {
	"standing/east": preload("res://assets/sprites/player/standing/east.png"),
	"standing/north-east": preload("res://assets/sprites/player/standing/north-east.png"),
	"standing/north": preload("res://assets/sprites/player/standing/north.png"),
	"standing/north-west": preload("res://assets/sprites/player/standing/north-west.png"),
	"standing/west": preload("res://assets/sprites/player/standing/west.png"),
	"standing/south-west": preload("res://assets/sprites/player/standing/south-west.png"),
	"standing/south": preload("res://assets/sprites/player/standing/south.png"),
	"standing/south-east": preload("res://assets/sprites/player/standing/south-east.png"),
	"walking/east": preload("res://assets/sprites/player/walking/east.png"),
	"walking/north-east": preload("res://assets/sprites/player/walking/north-east.png"),
	"walking/north": preload("res://assets/sprites/player/walking/north.png"),
	"walking/north-west": preload("res://assets/sprites/player/walking/north-west.png"),
	"walking/west": preload("res://assets/sprites/player/walking/west.png"),
	"walking/south-west": preload("res://assets/sprites/player/walking/south-west.png"),
	"walking/south": preload("res://assets/sprites/player/walking/south.png"),
	"walking/south-east": preload("res://assets/sprites/player/walking/south-east.png"),
	"shooting/east": preload("res://assets/sprites/player/shooting/east.png"),
	"shooting/north-east": preload("res://assets/sprites/player/shooting/north-east.png"),
	"shooting/north": preload("res://assets/sprites/player/shooting/north.png"),
	"shooting/north-west": preload("res://assets/sprites/player/shooting/north-west.png"),
	"shooting/west": preload("res://assets/sprites/player/shooting/west.png"),
	"shooting/south-west": preload("res://assets/sprites/player/shooting/south-west.png"),
	"shooting/south": preload("res://assets/sprites/player/shooting/south.png"),
	"shooting/south-east": preload("res://assets/sprites/player/shooting/south-east.png"),
}

var _last_octant_name: String = "south"
var _walk_cycle_elapsed: float = 0.0
var _walk_cycle_frame: int = 0

func next_texture(delta: float, visual_state: int, direction: Vector2, speed_multiplier: float) -> Texture2D:
	if visual_state != VisualState.WALKING:
		_walk_cycle_elapsed = 0.0
		_walk_cycle_frame = 0
		return resolve_texture(visual_state, direction)

	_walk_cycle_elapsed += delta * maxf(speed_multiplier, 0.01)
	while _walk_cycle_elapsed >= WALK_FRAME_DURATION:
		_walk_cycle_elapsed -= WALK_FRAME_DURATION
		_walk_cycle_frame = wrapi(_walk_cycle_frame + 1, 0, WALK_CYCLE_FRAME_COUNT)

	var cycle_state: int = VisualState.WALKING if _walk_cycle_frame == 0 else VisualState.STANDING
	return resolve_texture(cycle_state, direction)

func resolve_texture(visual_state: int, direction: Vector2) -> Texture2D:
	var state_folder: String = STATE_FOLDER_BY_VISUAL_STATE.get(visual_state, "standing")
	var octant_name: String = direction_to_octant(direction)
	var texture_key: String = "%s/%s" % [state_folder, octant_name]
	if not SPRITE_TEXTURE_BY_KEY.has(texture_key):
		push_error("Missing player sprite texture for key: %s" % texture_key)
		return SPRITE_TEXTURE_BY_KEY[FALLBACK_TEXTURE_KEY]
	return SPRITE_TEXTURE_BY_KEY[texture_key]

func direction_to_octant(direction: Vector2) -> String:
	if direction.length_squared() <= 0.0001:
		return _last_octant_name

	var octant_index: int = wrapi(int(round(direction.angle() / (PI / 4.0))), 0, 8)
	_last_octant_name = OCTANT_NAMES[octant_index]
	return _last_octant_name
