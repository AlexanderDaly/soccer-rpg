extends RefCounted
class_name DribbleMoves
## DribbleMoves - Defines dribble move data and helper lookups.

const MOVES: Dictionary = {
	"basic": {
		"name": "Basic Touch",
		"desc": "Keep it simple and retain control.",
		"dribble_bonus": 0,
		"defender_bonus": 0,
		"stamina_cost": 0,
		"ap_cost": 1,
		"range_bonus": 0,
		"unlock_tec": 0,
		"unlock_skill": "",
		"unlock_skill_name": "",
		"sort": 0
	},
	"body_feint": {
		"name": "Body Feint",
		"desc": "Sell the fake for a safer beat.",
		"dribble_bonus": 6,
		"defender_bonus": 0,
		"stamina_cost": 4,
		"ap_cost": 1,
		"range_bonus": 0,
		"unlock_tec": 45,
		"unlock_skill": "",
		"unlock_skill_name": "",
		"sort": 1
	},
	"stepover": {
		"name": "Stepover",
		"desc": "Classic move to shift the defender.",
		"dribble_bonus": 8,
		"defender_bonus": 0,
		"stamina_cost": 6,
		"ap_cost": 1,
		"range_bonus": 0,
		"unlock_tec": 55,
		"unlock_skill": "skill_stepover",
		"unlock_skill_name": "Stepover Mastery",
		"sort": 2
	},
	"roulette": {
		"name": "Roulette",
		"desc": "Flashy spin with a big payoff.",
		"dribble_bonus": 12,
		"defender_bonus": 0,
		"stamina_cost": 10,
		"ap_cost": 1,
		"range_bonus": 0,
		"unlock_tec": 70,
		"unlock_skill": "skill_roulette",
		"unlock_skill_name": "Roulette Mastery",
		"sort": 3
	}
}


## Get move data by id, falling back to the basic touch.
static func get_move(move_id: String) -> Dictionary:
	if move_id in MOVES:
		return MOVES[move_id]
	return MOVES["basic"]


## Return available moves for a unit (unlock rules can be expanded later).
static func get_available_moves(unit: PlayerUnit) -> Array[Dictionary]:
	var available: Array[Dictionary] = []

	for move_id in MOVES:
		var move = MOVES[move_id]
		var status = get_move_status(unit, move_id)
		if not status.locked:
			var entry: Dictionary = move.duplicate(true)
			entry["id"] = move_id
			entry["locked"] = false
			entry["lock_reasons"] = []
			available.append(entry)

	available.sort_custom(Callable(DribbleMoves, "_sort_by_order"))
	return available


## Return all moves with lock status and reasons for UI presentation.
static func get_move_entries(unit: PlayerUnit) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	for move_id in MOVES:
		var move = MOVES[move_id]
		var status = get_move_status(unit, move_id)
		var entry: Dictionary = move.duplicate(true)
		entry["id"] = move_id
		entry["locked"] = status.locked
		entry["lock_reasons"] = status.reasons
		entries.append(entry)

	entries.sort_custom(Callable(DribbleMoves, "_sort_by_order"))
	return entries


## Check if a move is unlocked for the unit.
static func is_move_unlocked(unit: PlayerUnit, move_id: String) -> bool:
	return not get_move_status(unit, move_id).locked


## Return move lock status and reasons.
static func get_move_status(unit: PlayerUnit, move_id: String) -> Dictionary:
	var move = get_move(move_id)
	var reasons: Array[String] = []

	if unit:
		var tec_required = int(move.get("unlock_tec", 0))
		if unit.get_stat("TEC") < tec_required:
			reasons.append("TEC %d" % tec_required)

		var skill_id = move.get("unlock_skill", "")
		if skill_id != "" and unit.is_player_controlled:
			var unlocked_skills: Array[String] = []
			if GameManager.player_data:
				unlocked_skills = GameManager.player_data.unlocked_skills
			if skill_id not in unlocked_skills:
				var skill_name = move.get("unlock_skill_name", skill_id)
				reasons.append("Skill %s" % skill_name)

	return {
		"locked": reasons.size() > 0,
		"reasons": reasons
	}


## Sort moves by their display order.
static func _sort_by_order(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("sort", 0)) < int(b.get("sort", 0))
