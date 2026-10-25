class_name OasisGameManager
extends Node

const RESTART_MODE := "FULL"
const DEFAULT_ZONE_PATH := "res://scenes/zones/village.tscn"
const DEFAULT_AMMO := 20
const DEFAULT_COOLANT_COUNT := 3
const DEFAULT_CELLS := 5
const DEFAULT_WEAPONS: Array[String] = ["starter_gun"]

var current_zone: String = DEFAULT_ZONE_PATH
var components_collected: int = 0
var ammo: int = DEFAULT_AMMO
var coolant_count: int = DEFAULT_COOLANT_COUNT
var current_cells: int = DEFAULT_CELLS
var weapons_owned: Array[String] = []

func _ready() -> void:
	reset_run_state()

func reset_run_state() -> void:
	current_zone = DEFAULT_ZONE_PATH
	components_collected = 0
	ammo = DEFAULT_AMMO
	coolant_count = DEFAULT_COOLANT_COUNT
	current_cells = DEFAULT_CELLS
	weapons_owned.clear()
	for weapon_id in DEFAULT_WEAPONS:
		weapons_owned.append(weapon_id)

func apply_to_player(player: PlayerController) -> void:
	if player == null:
		return
	player.set_runtime_stats(ammo, coolant_count, current_cells)

func sync_from_player(player: PlayerController) -> void:
	if player == null:
		return
	ammo = player.current_ammo
	coolant_count = player.coolant_count
	current_cells = player.current_cells

func handle_player_death() -> void:
	if RESTART_MODE == "FULL":
		reset_run_state()
		return

	if RESTART_MODE == "CHECKPOINT":
		current_cells = DEFAULT_CELLS
		coolant_count = DEFAULT_COOLANT_COUNT
		ammo = DEFAULT_AMMO
		return

	push_error("Unsupported RESTART_MODE '%s'." % RESTART_MODE)

func get_restart_scene_path() -> String:
	if RESTART_MODE == "CHECKPOINT" and not current_zone.is_empty():
		return current_zone
	return DEFAULT_ZONE_PATH
