extends Resource
class_name PlayerData
## PlayerData - Stores all data for the player character

@export var id: String = ""
@export var name: String = ""
@export var position: String = ""  # GK, CB, FB, CDM, CM, CAM, WNG, ST
@export var nationality: String = "USA"
@export var dominant_foot: String = "right"  # left, right, both
@export var age: int = 14  # Starting age for high school

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


func initialize(player_name: String, player_position: String, player_nationality: String = "USA", player_appearance: Dictionary = {}, player_dominant_foot: String = "right", player_traits: Array[String] = []) -> void:
	id = _generate_id()
	name = player_name
	position = player_position
	nationality = player_nationality
	dominant_foot = player_dominant_foot
	age = 14  # Everyone starts at high school age
	personality_traits = player_traits

	# Set starting stats based on position
	_set_starting_stats()

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


func add_xp(amount: int) -> void:
	xp += amount
	
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
	
	stat_xp[stat_key] += amount
	
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
	return StatSystem.apply_form_modifier(stats[stat_key], current_form)


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


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"position": position,
		"nationality": nationality,
		"dominant_foot": dominant_foot,
		"age": age,
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
	appearance = data.get("appearance", appearance)
	personality_traits.assign(data.get("personality_traits", []))
	training_records = data.get("training_records", {})
