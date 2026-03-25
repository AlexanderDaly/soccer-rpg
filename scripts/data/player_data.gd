extends Resource
class_name PlayerData
## PlayerData - Stores all data for the player character

@export var id: String = ""
@export var name: String = ""
@export var position: String = ""  # GK, CB, FB, CDM, CM, CAM, WNG, ST
@export var nationality: String = "USA"
@export var dominant_foot: String = "right"  # left, right, both
@export var age: int = 14  # Starting age for high school
@export var school_year: int = 1
@export var background_story: String = "academy_product"
@export var career_difficulty: String = "normal"

# Primary stats (1-99)
@export var stats: Dictionary = {
	"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50,
	"SHO": 50, "DEF": 50, "PHY": 50, "MEN": 50
}

# Progression
@export var level: int = 1
@export var xp: int = 0
@export var stat_xp: Dictionary = {}  # Individual stat progression

# Skills and abilities
@export var unlocked_skills: Array[String] = []
@export var equipped_skills: Array[String] = []  # Max 4 active
@export var skill_points: int = 0

# Current state
@export var current_form: String = "average"  # terrible, poor, average, good, excellent
@export var stamina_current: int = 100
@export var morale: int = 50  # 0-100
@export var injury_status: String = ""  # Empty if healthy
@export var injury: Dictionary = {
	"type": "",
	"injury_type": "",
	"matches_remaining": 0,
	"matches_total": 0,
	"description": ""
}
@export var discipline: Dictionary = {
	"competitions": {}
}

# Training records (best scores for simulation)
@export var training_records: Dictionary = {}  # e.g., {"penalty_drill": {"best_score": 7, "attempts": 10}}

# Appearance (for AI art generation prompts)
@export var appearance: Dictionary = {
	"hair_color": "black",
	"hair_style": "short",
	"eye_color": "brown",
	"skin_tone": "medium",
	"height": "average",
	"build": "athletic"
}

# Personality traits (affects narrative generation)
@export var personality_traits: Array[String] = []

const BACKGROUND_STORIES := {
	"academy_product": {
		"reputation_bonus": 5,
		"coach_trust_bonus": 10,
		"stat_bonuses": {"PAS": 2, "MEN": 2},
		"stat_xp_multiplier": 1.0,
		"positive_relationship_multiplier": 1.0,
		"poor_match_penalty_multiplier": 1.0
	},
	"late_bloomer": {
		"reputation_bonus": -5,
		"coach_trust_bonus": 0,
		"all_stats_delta": -1,
		"stat_xp_multiplier": 1.2,
		"positive_relationship_multiplier": 1.1,
		"poor_match_penalty_multiplier": 1.0
	},
	"prodigy": {
		"reputation_bonus": 10,
		"coach_trust_bonus": 5,
		"top_weighted_stat_bonus": 3,
		"top_weighted_stat_count": 3,
		"stat_xp_multiplier": 0.95,
		"positive_relationship_multiplier": 1.0,
		"poor_match_penalty_multiplier": 1.35
	}
}

const CAREER_DIFFICULTIES := {
	"casual": {
		"match_xp_multiplier": 1.2,
		"stat_xp_multiplier": 1.15,
		"opponent_difficulty_multiplier": 0.9,
		"scout_threshold_multiplier": 0.85,
		"relationship_loss_multiplier": 0.75
	},
	"normal": {
		"match_xp_multiplier": 1.0,
		"stat_xp_multiplier": 1.0,
		"opponent_difficulty_multiplier": 1.0,
		"scout_threshold_multiplier": 1.0,
		"relationship_loss_multiplier": 1.0
	},
	"hardcore": {
		"match_xp_multiplier": 0.8,
		"stat_xp_multiplier": 0.85,
		"opponent_difficulty_multiplier": 1.1,
		"scout_threshold_multiplier": 1.15,
		"relationship_loss_multiplier": 1.5
	}
}

const MINOR_INJURY_STAT_PENALTIES: Dictionary = {
	"muscle_tightness": {"STA": 6, "SPD": 4, "TEC": 2},
	"light_bruising": {"PHY": 5, "DEF": 2, "MEN": 2},
	"ankle_niggle": {"SPD": 6, "TEC": 4, "PAS": 2},
	"minor_cramp": {"STA": 7, "SPD": 3, "PHY": 2},
	"_default": {"STA": 4, "SPD": 2, "MEN": 1}
}

const MODERATE_INJURY_MULTIPLIER: float = 1.65


func initialize(player_name: String, player_position: String, player_nationality: String = "USA", player_appearance: Dictionary = {}, player_dominant_foot: String = "right", player_traits: Array[String] = [], player_background_story: String = "academy_product", player_career_difficulty: String = "normal") -> void:
	id = _generate_id()
	name = player_name
	position = player_position
	nationality = player_nationality
	dominant_foot = player_dominant_foot
	age = 14  # Everyone starts at high school age
	school_year = 1
	background_story = _normalize_background_story(player_background_story)
	career_difficulty = _normalize_career_difficulty(player_career_difficulty)
	personality_traits = player_traits

	# Set starting stats based on position
	_set_starting_stats()
	_apply_background_story_modifiers()

	# Initialize stat XP tracking
	for stat_key in stats:
		stat_xp[stat_key] = 0

	# Apply custom appearance if provided
	if not player_appearance.is_empty():
		for key in player_appearance:
			if key in appearance:
				appearance[key] = player_appearance[key]

	# Update narrative context
	NarrativeEngine.update_context("player_name", name)
	NarrativeEngine.update_context("position", position)


func _generate_id() -> String:
	return "player_%d" % randi()


func _set_starting_stats() -> void:
	# Base stats for a high school player (40-60 range)
	var base = 45
	var variance = 10
	
	var weights = StatSystem.POSITION_WEIGHTS.get(position, StatSystem.POSITION_WEIGHTS["CM"])
	
	for stat_key in stats:
		var weight = weights.get(stat_key, 0.5)
		# Higher weight = slightly higher starting stat
		var weighted_base = base + roundi((weight - 0.5) * 10)
		stats[stat_key] = clampi(weighted_base + randi_range(-variance, variance), 30, 65)


func add_xp(amount: int, source: String = "general") -> void:
	var adjusted_amount = _apply_xp_multiplier(amount, source)
	xp += adjusted_amount
	
	# Check for level up
	var xp_needed = StatSystem.xp_for_level(level)
	while xp >= xp_needed:
		xp -= xp_needed
		_level_up()
		xp_needed = StatSystem.xp_for_level(level)


func _level_up() -> void:
	level += 1
	skill_points += 1
	
	# Small stat boost on level up
	var random_stat = stats.keys()[randi() % stats.size()]
	stats[random_stat] = mini(stats[random_stat] + 1, 99)
	
	print("[PlayerData] Level up! Now level %d" % level)
	StatSystem.level_up.emit(id, level)


func add_stat_xp(stat_key: String, amount: int) -> void:
	if stat_key not in stat_xp:
		return
	
	stat_xp[stat_key] += _apply_stat_xp_multiplier(amount)
	
	# Check for stat increase (every 100 stat XP)
	while stat_xp[stat_key] >= 100:
		stat_xp[stat_key] -= 100
		_increase_stat(stat_key)


func _increase_stat(stat_key: String) -> void:
	if stat_key not in stats:
		return
	
	var old_value = stats[stat_key]
	stats[stat_key] = mini(stats[stat_key] + 1, 99)
	
	if stats[stat_key] != old_value:
		StatSystem.stat_changed.emit(id, stat_key, old_value, stats[stat_key])


func unlock_skill(skill_id: String) -> bool:
	if skill_id in unlocked_skills:
		return false
	
	unlocked_skills.append(skill_id)
	StatSystem.skill_unlocked.emit(id, skill_id)
	return true


func equip_skill(skill_id: String) -> bool:
	if skill_id not in unlocked_skills:
		return false
	
	if equipped_skills.size() >= 4:
		return false
	
	if skill_id in equipped_skills:
		return false
	
	equipped_skills.append(skill_id)
	return true


func unequip_skill(skill_id: String) -> bool:
	var index = equipped_skills.find(skill_id)
	if index >= 0:
		equipped_skills.remove_at(index)
		return true
	return false


func get_overall() -> int:
	return StatSystem.calculate_overall(stats, position)


func get_secondary_stats() -> Dictionary:
	return StatSystem.calculate_all_secondaries(stats)


func get_effective_stat(stat_key: String) -> int:
	if stat_key not in stats:
		return 0
	var effective = StatSystem.apply_form_modifier(stats[stat_key], current_form)
	effective -= _get_injury_penalty_for_stat(stat_key)
	return clampi(effective, 1, 99)


func update_form() -> void:
	# Form changes based on recent performances and morale
	var form_levels = ["terrible", "poor", "average", "good", "excellent"]
	var form_index = 2  # Start at average
	
	# Morale influence
	if morale > 80:
		form_index += 1
	elif morale > 60:
		form_index += 0
	elif morale > 40:
		form_index -= 0
	elif morale > 20:
		form_index -= 1
	else:
		form_index -= 2
	
	# Random variance
	form_index += randi_range(-1, 1)
	
	form_index = clampi(form_index, 0, form_levels.size() - 1)
	current_form = form_levels[form_index]


func rest() -> void:
	# Recover stamina and potentially improve form
	stamina_current = mini(stamina_current + 30, 100)
	morale = mini(morale + 5, 100)


func get_background_profile() -> Dictionary:
	return BACKGROUND_STORIES.get(background_story, BACKGROUND_STORIES["academy_product"])


func get_difficulty_profile() -> Dictionary:
	return CAREER_DIFFICULTIES.get(career_difficulty, CAREER_DIFFICULTIES["normal"])


func get_match_xp_multiplier() -> float:
	return float(get_difficulty_profile().get("match_xp_multiplier", 1.0))


func get_stat_xp_multiplier() -> float:
	return float(get_difficulty_profile().get("stat_xp_multiplier", 1.0)) * float(get_background_profile().get("stat_xp_multiplier", 1.0))


func get_opponent_difficulty_multiplier() -> float:
	return float(get_difficulty_profile().get("opponent_difficulty_multiplier", 1.0))


func get_scout_threshold_multiplier() -> float:
	return float(get_difficulty_profile().get("scout_threshold_multiplier", 1.0))


func get_positive_relationship_multiplier() -> float:
	return float(get_background_profile().get("positive_relationship_multiplier", 1.0))


func get_relationship_loss_multiplier() -> float:
	return float(get_difficulty_profile().get("relationship_loss_multiplier", 1.0))


func get_poor_match_penalty_multiplier() -> float:
	return float(get_background_profile().get("poor_match_penalty_multiplier", 1.0))


func get_match_availability(competition_key: String = "") -> Dictionary:
	var normalized_key = str(competition_key)
	if normalized_key.is_empty():
		normalized_key = "default"

	var suspension_record = _get_competition_record(normalized_key)
	var suspension_matches = int(suspension_record.get("suspension_matches_remaining", 0))
	if suspension_matches > 0:
		return {
			"eligible": false,
			"reason": "suspended",
			"detail": "Suspended for %d more match%s." % [suspension_matches, "es" if suspension_matches != 1 else ""]
		}

	var injury_record = get_injury_record()
	var severity = str(injury_record.get("type", ""))
	var matches_remaining = int(injury_record.get("matches_remaining", 0))
	if severity == "" or matches_remaining <= 0:
		return {"eligible": true, "reason": "", "detail": ""}
	if severity == "minor":
		return {
			"eligible": true,
			"reason": "minor_injury",
			"detail": str(injury_record.get("description", "Playing through a minor injury."))
		}

	return {
		"eligible": false,
		"reason": "injured",
		"detail": str(injury_record.get("description", "Unavailable due to injury."))
	}


func is_match_eligible(competition_key: String = "") -> bool:
	return bool(get_match_availability(competition_key).get("eligible", true))


func get_injury_record() -> Dictionary:
	injury = _normalize_injury_record(injury)
	injury_status = str(injury.get("type", ""))
	return injury


func get_discipline_record(competition_key: String) -> Dictionary:
	discipline = _normalize_discipline_record(discipline)
	var normalized_key = str(competition_key)
	if normalized_key.is_empty():
		normalized_key = "default"
	var competitions: Dictionary = discipline.get("competitions", {})
	var record = competitions.get(normalized_key, {}).duplicate(true)
	record = _normalize_competition_record(record)
	competitions[normalized_key] = record
	discipline["competitions"] = competitions
	return record


func record_competition_card(competition_key: String, card_type: String) -> void:
	var normalized_key = str(competition_key)
	if normalized_key.is_empty():
		normalized_key = "default"
	var record = get_discipline_record(normalized_key)
	var normalized_card = str(card_type).to_lower()

	match normalized_card:
		"yellow":
			record["yellow_count"] = int(record.get("yellow_count", 0)) + 1
			if int(record.get("yellow_count", 0)) >= 3:
				record["yellow_count"] = 0
				record["suspension_matches_remaining"] = int(record.get("suspension_matches_remaining", 0)) + 1
				record["last_dismissal_reason"] = "yellow_accumulation"
		"second_yellow":
			record["yellow_count"] = 0
			record["suspension_matches_remaining"] = int(record.get("suspension_matches_remaining", 0)) + 1
			record["last_dismissal_reason"] = "second_yellow"
		"red":
			record["suspension_matches_remaining"] = int(record.get("suspension_matches_remaining", 0)) + 1
			record["last_dismissal_reason"] = "red"
		_:
			return

	record["last_card"] = normalized_card
	_store_competition_record(normalized_key, record)


func serve_suspension(competition_key: String) -> void:
	var normalized_key = str(competition_key)
	if normalized_key.is_empty():
		normalized_key = "default"
	var record = get_discipline_record(normalized_key)
	var remaining = int(record.get("suspension_matches_remaining", 0))
	if remaining <= 0:
		return
	record["suspension_matches_remaining"] = max(remaining - 1, 0)
	_store_competition_record(normalized_key, record)


func apply_injury_report(report: Dictionary) -> void:
	var matches_out = int(report.get("matches_out", report.get("matches_remaining", 0)))
	if matches_out <= 0:
		clear_injury()
		return

	injury = _normalize_injury_record({
		"type": str(report.get("type", "minor")),
		"injury_type": str(report.get("injury_type", "")),
		"matches_remaining": matches_out,
		"matches_total": int(report.get("matches_total", matches_out)),
		"description": str(report.get("description", "injury"))
	})
	injury_status = str(injury.get("type", ""))


func clear_injury() -> void:
	injury = _normalize_injury_record({})
	injury_status = ""


func process_match_recovery() -> bool:
	var injury_record = get_injury_record()
	var matches_remaining = int(injury_record.get("matches_remaining", 0))
	if matches_remaining <= 0:
		return false

	injury_record["matches_remaining"] = matches_remaining - 1
	if int(injury_record.get("matches_remaining", 0)) <= 0:
		clear_injury()
		return true

	injury = injury_record
	injury_status = str(injury.get("type", ""))
	return false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"position": position,
		"nationality": nationality,
		"dominant_foot": dominant_foot,
		"age": age,
		"school_year": school_year,
		"background_story": background_story,
		"career_difficulty": career_difficulty,
		"stats": stats,
		"level": level,
		"xp": xp,
		"stat_xp": stat_xp,
		"unlocked_skills": unlocked_skills,
		"equipped_skills": equipped_skills,
		"skill_points": skill_points,
		"current_form": current_form,
		"stamina_current": stamina_current,
		"morale": morale,
		"injury_status": injury_status,
		"injury": get_injury_record(),
		"discipline": _normalize_discipline_record(discipline),
		"appearance": appearance,
		"personality_traits": personality_traits,
		"training_records": training_records
	}


func from_dict(data: Dictionary) -> void:
	id = data.get("id", _generate_id())
	name = data.get("name", "Player")
	position = data.get("position", "CM")
	nationality = data.get("nationality", "USA")
	dominant_foot = data.get("dominant_foot", "right")
	age = data.get("age", 14)
	school_year = data.get("school_year", 1)
	background_story = _normalize_background_story(data.get("background_story", "academy_product"))
	career_difficulty = _normalize_career_difficulty(data.get("career_difficulty", "normal"))
	stats = data.get("stats", stats)
	level = data.get("level", 1)
	xp = data.get("xp", 0)
	stat_xp = data.get("stat_xp", {})
	unlocked_skills.assign(data.get("unlocked_skills", []))
	equipped_skills.assign(data.get("equipped_skills", []))
	skill_points = data.get("skill_points", 0)
	current_form = data.get("current_form", "average")
	stamina_current = data.get("stamina_current", 100)
	morale = data.get("morale", 50)
	injury_status = data.get("injury_status", "")
	injury = _normalize_injury_record(data.get("injury", {}))
	if not data.has("injury") and not injury_status.is_empty():
		injury = _normalize_injury_record({"type": injury_status, "description": injury_status})
	injury_status = str(injury.get("type", injury_status))
	discipline = _normalize_discipline_record(data.get("discipline", {}))
	appearance = data.get("appearance", appearance)
	personality_traits.assign(data.get("personality_traits", []))
	training_records = data.get("training_records", {})


func _normalize_background_story(value: String) -> String:
	return value if value in BACKGROUND_STORIES else "academy_product"


func _normalize_career_difficulty(value: String) -> String:
	return value if value in CAREER_DIFFICULTIES else "normal"


func _apply_background_story_modifiers() -> void:
	var profile = get_background_profile()
	var all_stats_delta = int(profile.get("all_stats_delta", 0))
	if all_stats_delta != 0:
		for stat_key in stats:
			stats[stat_key] = clampi(int(stats[stat_key]) + all_stats_delta, 1, 99)

	var stat_bonuses: Dictionary = profile.get("stat_bonuses", {})
	for stat_key in stat_bonuses:
		if stats.has(stat_key):
			stats[stat_key] = clampi(int(stats[stat_key]) + int(stat_bonuses[stat_key]), 1, 99)

	var weighted_bonus = int(profile.get("top_weighted_stat_bonus", 0))
	if weighted_bonus > 0:
		var count = int(profile.get("top_weighted_stat_count", 3))
		var boosted_stats = _get_top_weighted_stats(count)
		for stat_key in boosted_stats:
			stats[stat_key] = clampi(int(stats[stat_key]) + weighted_bonus, 1, 99)


func _get_top_weighted_stats(count: int) -> Array[String]:
	var weights = StatSystem.POSITION_WEIGHTS.get(position, StatSystem.POSITION_WEIGHTS["CM"])
	var weighted_keys: Array[Dictionary] = []
	for stat_key in weights:
		weighted_keys.append({"stat": stat_key, "weight": float(weights[stat_key])})
	weighted_keys.sort_custom(func(a, b): return a.get("weight", 0.0) > b.get("weight", 0.0))

	var top_stats: Array[String] = []
	for i in range(mini(count, weighted_keys.size())):
		top_stats.append(str(weighted_keys[i].get("stat", "")))
	return top_stats


func _apply_xp_multiplier(amount: int, source: String) -> int:
	var adjusted = float(amount)
	if source == "match":
		adjusted *= get_match_xp_multiplier()
	return maxi(0, roundi(adjusted))


func _apply_stat_xp_multiplier(amount: int) -> int:
	return maxi(0, roundi(float(amount) * get_stat_xp_multiplier()))


func _get_injury_penalty_for_stat(stat_key: String) -> int:
	var injury_record = get_injury_record()
	var severity = str(injury_record.get("type", ""))
	var matches_remaining = int(injury_record.get("matches_remaining", 0))
	if severity == "" or matches_remaining <= 0:
		return 0

	var injury_type = str(injury_record.get("injury_type", ""))
	var penalties: Dictionary = MINOR_INJURY_STAT_PENALTIES.get(
		injury_type,
		MINOR_INJURY_STAT_PENALTIES["_default"]
	)
	var penalty = int(penalties.get(stat_key, 0))
	if severity == "moderate":
		penalty = roundi(float(penalty) * MODERATE_INJURY_MULTIPLIER)
	return penalty


func _normalize_injury_record(data: Dictionary) -> Dictionary:
	return {
		"type": str(data.get("type", "")),
		"injury_type": str(data.get("injury_type", "")),
		"matches_remaining": max(int(data.get("matches_remaining", 0)), 0),
		"matches_total": max(int(data.get("matches_total", data.get("matches_remaining", 0))), 0),
		"description": str(data.get("description", ""))
	}


func _normalize_discipline_record(data: Dictionary) -> Dictionary:
	var competitions: Dictionary = {}
	var source: Dictionary = data.get("competitions", {})
	for competition_key in source:
		competitions[str(competition_key)] = _normalize_competition_record(source[competition_key])
	return {"competitions": competitions}


func _normalize_competition_record(data: Dictionary) -> Dictionary:
	return {
		"yellow_count": max(int(data.get("yellow_count", 0)), 0),
		"suspension_matches_remaining": max(int(data.get("suspension_matches_remaining", 0)), 0),
		"last_card": str(data.get("last_card", "")),
		"last_dismissal_reason": str(data.get("last_dismissal_reason", ""))
	}


func _get_competition_record(competition_key: String) -> Dictionary:
	var competitions: Dictionary = _normalize_discipline_record(discipline).get("competitions", {})
	return competitions.get(competition_key, _normalize_competition_record({})).duplicate(true)


func _store_competition_record(competition_key: String, record: Dictionary) -> void:
	discipline = _normalize_discipline_record(discipline)
	var competitions: Dictionary = discipline.get("competitions", {})
	competitions[competition_key] = _normalize_competition_record(record)
	discipline["competitions"] = competitions
