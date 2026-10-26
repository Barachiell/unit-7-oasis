class_name EnemySpriteDirector
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
const WALK_CYCLE_FRAME_COUNT: int = 2

var _asset_root: String
var _walk_frame_duration: float
var _last_octant_name: String = "south"
var _walk_cycle_elapsed: float = 0.0
var _walk_cycle_frame: int = 0
var _texture_by_key: Dictionary = {}

func _init(asset_root: String, walk_frame_duration: float = 0.22) -> void:
	_asset_root = asset_root.rstrip("/")
	_walk_frame_duration = maxf(walk_frame_duration, 0.01)

func next_texture(delta: float, visual_state: int, direction: Vector2, speed_multiplier: float) -> Texture2D:
	if visual_state != VisualState.WALKING:
		_walk_cycle_elapsed = 0.0
		_walk_cycle_frame = 0
		return resolve_texture(visual_state, direction)

	_walk_cycle_elapsed += delta * maxf(speed_multiplier, 0.01)
	while _walk_cycle_elapsed >= _walk_frame_duration:
		_walk_cycle_elapsed -= _walk_frame_duration
		_walk_cycle_frame = wrapi(_walk_cycle_frame + 1, 0, WALK_CYCLE_FRAME_COUNT)

	var cycle_state: int = VisualState.WALKING if _walk_cycle_frame == 0 else VisualState.STANDING
	return resolve_texture(cycle_state, direction)

func resolve_texture(visual_state: int, direction: Vector2) -> Texture2D:
	var state_folder: String = STATE_FOLDER_BY_VISUAL_STATE.get(visual_state, "standing")
	var octant_name: String = direction_to_octant(direction)
	var texture_key: String = "%s/%s" % [state_folder, octant_name]
	var texture: Texture2D = _load_texture(texture_key)
	if texture != null:
		return texture

	# Some enemy sprite sets only provide a subset of states (e.g. no
	# dedicated walking frames). Fall back to the standing pose for the
	# same direction instead of treating it as an error.
	if state_folder != "standing":
		var standing_key: String = "standing/%s" % octant_name
		var standing_texture: Texture2D = _load_texture(standing_key)
		if standing_texture != null:
			return standing_texture

	push_error("Missing enemy sprite texture for key: %s under %s" % [texture_key, _asset_root])
	return _load_texture(FALLBACK_TEXTURE_KEY)

func direction_to_octant(direction: Vector2) -> String:
	if direction.length_squared() <= 0.0001:
		return _last_octant_name

	var octant_index: int = wrapi(int(round(direction.angle() / (PI / 4.0))), 0, 8)
	_last_octant_name = OCTANT_NAMES[octant_index]
	return _last_octant_name

func _load_texture(texture_key: String) -> Texture2D:
	if _texture_by_key.has(texture_key):
		return _texture_by_key[texture_key] as Texture2D

	var texture_path: String = "%s/%s.png" % [_asset_root, texture_key]
	if not ResourceLoader.exists(texture_path):
		return null

	var loaded_resource: Resource = ResourceLoader.load(texture_path)
	if not loaded_resource is Texture2D:
		return null

	var texture: Texture2D = loaded_resource as Texture2D
	_texture_by_key[texture_key] = texture
	return texture
