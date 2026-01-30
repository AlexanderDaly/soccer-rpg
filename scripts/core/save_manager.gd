extends Node
## SaveManager - Handles saving and loading game data

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)

const SAVE_DIR = "user://saves/"
const SAVE_EXTENSION = ".sav"
const MAX_SAVE_SLOTS = 5
const SAVE_VERSION = 1

var current_slot: int = -1
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes

var _auto_save_timer: Timer


func _ready() -> void:
	print("[SaveManager] Initialized")
	_ensure_save_directory()
	_setup_auto_save()


func _ensure_save_directory() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")


func _setup_auto_save() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = auto_save_interval
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)

	# Start timer if auto-save is enabled by default
	if auto_save_enabled:
		_auto_save_timer.start()


func _on_auto_save() -> void:
	if auto_save_enabled and current_slot >= 0:
		save_game(current_slot)


func start_auto_save() -> void:
	if auto_save_enabled:
		_auto_save_timer.start()


func stop_auto_save() -> void:
	_auto_save_timer.stop()


func save_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid save slot: %d" % slot)
		save_completed.emit(slot, false)
		return false
	
	var save_data = _collect_save_data()
	var save_path = _get_save_path(slot)
	
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Failed to open save file: %s" % save_path)
		save_completed.emit(slot, false)
		return false
	
	var json_string = JSON.stringify(save_data, "  ")
	file.store_string(json_string)
	file.close()
	
	current_slot = slot
	print("[SaveManager] Game saved to slot %d" % slot)
	save_completed.emit(slot, true)
	return true


func load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid save slot: %d" % slot)
		load_completed.emit(slot, false)
		return false
	
	var save_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		push_warning("[SaveManager] Save file not found: %s" % save_path)
		load_completed.emit(slot, false)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Failed to open save file: %s" % save_path)
		load_completed.emit(slot, false)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var save_data = JSON.parse_string(json_string)
	if not save_data:
		push_error("[SaveManager] Failed to parse save data")
		load_completed.emit(slot, false)
		return false
	
	if not _validate_save_data(save_data):
		push_error("[SaveManager] Invalid save data format")
		load_completed.emit(slot, false)
		return false
	
	_apply_save_data(save_data)
	
	current_slot = slot
	print("[SaveManager] Game loaded from slot %d" % slot)
	load_completed.emit(slot, true)
	return true


func delete_save(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return false
	
	var save_path = _get_save_path(slot)
	
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(save_path.get_file())
			print("[SaveManager] Deleted save slot %d" % slot)
			return true
	
	return false


func get_save_info(slot: int) -> Dictionary:
	if slot < 0 or slot >= MAX_SAVE_SLOTS:
		return {}
	
	var save_path = _get_save_path(slot)
	
	if not FileAccess.file_exists(save_path):
		return {"exists": false}
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return {"exists": false}
	
	var json_string = file.get_as_text()
	file.close()
	
	var save_data = JSON.parse_string(json_string)
	if not save_data:
		return {"exists": false}
	
	return {
		"exists": true,
		"player_name": save_data.get("player", {}).get("name", "Unknown"),
		"career_phase": save_data.get("career_phase", "Unknown"),
		"playtime": save_data.get("playtime", 0),
		"save_date": save_data.get("save_date", ""),
		"version": save_data.get("version", 0)
	}


func get_all_save_info() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	for i in range(MAX_SAVE_SLOTS):
		saves.append(get_save_info(i))
	return saves


func _get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_%d%s" % [slot, SAVE_EXTENSION]


func _collect_save_data() -> Dictionary:
	var data = {
		"version": SAVE_VERSION,
		"save_date": Time.get_datetime_string_from_system(),
		"playtime": _get_playtime(),

		# Game state
		"game_state": GameManager.current_state,
		"career_phase": GameManager.current_career_phase,
		"prefecture": GameManager.current_prefecture,

		# Player data
		"player": _serialize_player(),

		# Team data
		"team": _serialize_team(),

		# Career data
		"career": _serialize_career(),

		# Season data
		"season": _serialize_season(),

		# Narrative context
		"narrative": _serialize_narrative(),

		# Settings
		"settings": _serialize_settings()
	}

	return data


func _serialize_player() -> Dictionary:
	if not GameManager.player_data:
		return {}

	# Use the complete to_dict() to preserve all player data
	return GameManager.player_data.to_dict()


func _serialize_team() -> Dictionary:
	if not GameManager.current_team:
		return {}

	return GameManager.current_team.to_dict()


func _serialize_career() -> Dictionary:
	return {
		"match_history": CareerManager.match_history,
		"career_stats": CareerManager.career_stats,
		"reputation": CareerManager.reputation,
		"scout_attention": CareerManager.scout_attention,
		"completed_milestones": CareerManager.completed_milestones,
		"rivals": CareerManager.rivals
	}


func _serialize_season() -> Dictionary:
	return SeasonManager.to_dict()


func _serialize_narrative() -> Dictionary:
	return NarrativeEngine.narrative_context.duplicate()


func _serialize_settings() -> Dictionary:
	return {
		"music_volume": AudioManager.music_volume,
		"sfx_volume": AudioManager.sfx_volume,
		"auto_save": auto_save_enabled
	}


func _validate_save_data(data: Dictionary) -> bool:
	# Check for required fields
	var required = ["version", "player", "career_phase"]
	for field in required:
		if field not in data:
			return false
	
	# Version compatibility check
	if data.version > SAVE_VERSION:
		push_warning("[SaveManager] Save version newer than game version")
		# Could implement migration here
	
	return true


func _apply_save_data(data: Dictionary) -> void:
	# Restore game state
	GameManager.current_career_phase = data.get("career_phase", 0)
	GameManager.current_prefecture = data.get("prefecture", "Kanagawa")

	# Restore player
	if "player" in data and data.player:
		GameManager.player_data = PlayerData.new()
		GameManager.player_data.from_dict(data.player)

	# Restore team
	if "team" in data and data.team:
		GameManager.current_team = TeamData.new()
		GameManager.current_team.from_dict(data.team)

	# Restore career
	if "career" in data:
		var career = data.career
		CareerManager.match_history.assign(career.get("match_history", []))
		CareerManager.career_stats = career.get("career_stats", {})
		CareerManager.reputation = career.get("reputation", 10)
		CareerManager.scout_attention = career.get("scout_attention", {})
		CareerManager.completed_milestones.assign(career.get("completed_milestones", []))
		CareerManager.rivals.assign(career.get("rivals", []))

	# Restore season data
	if "season" in data:
		SeasonManager.from_dict(data.season)

	# Restore narrative context
	if "narrative" in data:
		NarrativeEngine.narrative_context = data.narrative

	# Restore settings
	if "settings" in data:
		var settings = data.settings
		AudioManager.set_music_volume(settings.get("music_volume", 0.8))
		AudioManager.set_sfx_volume(settings.get("sfx_volume", 1.0))
		auto_save_enabled = settings.get("auto_save", true)


func _get_playtime() -> float:
	# This would track actual playtime in a full implementation
	return 0.0
