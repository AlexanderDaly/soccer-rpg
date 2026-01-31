extends RefCounted
class_name InjurySystem
## InjurySystem - Handles injury mechanics for NPC players

const INJURY_TYPES = {
	"minor": {
		"matches_out": [1, 2],
		"descriptions": ["slight knock", "minor fatigue", "muscle tightness", "light bruising"]
	},
	"moderate": {
		"matches_out": [2, 4],
		"descriptions": ["ankle sprain", "muscle strain", "knee twist", "hamstring pull"]
	},
	"severe": {
		"matches_out": [4, 8],
		"descriptions": ["hamstring tear", "ligament damage", "fractured metatarsal", "ACL sprain"]
	}
}

# Base injury probability per player per match (2%)
const BASE_INJURY_CHANCE: float = 0.02

# Injury type weights (higher = more common)
const INJURY_TYPE_WEIGHTS = {
	"minor": 60,
	"moderate": 30,
	"severe": 10
}


## Roll for injuries after a match
## Returns array of injury dictionaries for affected players
static func roll_for_injuries(team: TeamData, match_intensity: float = 1.0) -> Array[Dictionary]:
	var injuries: Array[Dictionary] = []

	if not team or team.players.is_empty():
		return injuries

	# Adjust injury chance based on match intensity
	var injury_chance = BASE_INJURY_CHANCE * match_intensity

	for player in team.players:
		var player_id = player.get("id", "")
		if player_id == "":
			continue

		# Skip already injured players
		if NpcRegistry.has_npc(player_id):
			var npc = NpcRegistry.get_npc(player_id)
			if npc.get("status", "active") != "active":
				continue

		# Roll for injury
		if randf() < injury_chance:
			var injury = generate_injury(player_id)
			if not injury.is_empty():
				injuries.append(injury)

	return injuries


## Generate an injury for a specific player
static func generate_injury(npc_id: String) -> Dictionary:
	var injury_type = _roll_injury_type()
	var type_data = INJURY_TYPES.get(injury_type, INJURY_TYPES["minor"])

	var matches_range = type_data.get("matches_out", [1, 2])
	var matches_out = randi_range(matches_range[0], matches_range[1])

	var descriptions = type_data.get("descriptions", ["injury"])
	var description = descriptions[randi() % descriptions.size()]

	return {
		"npc_id": npc_id,
		"type": injury_type,
		"matches_out": matches_out,
		"description": description
	}


## Roll for injury type based on weights
static func _roll_injury_type() -> String:
	var total_weight = 0
	for type_name in INJURY_TYPE_WEIGHTS:
		total_weight += INJURY_TYPE_WEIGHTS[type_name]

	var roll = randi() % total_weight
	var cumulative = 0

	for type_name in INJURY_TYPE_WEIGHTS:
		cumulative += INJURY_TYPE_WEIGHTS[type_name]
		if roll < cumulative:
			return type_name

	return "minor"


## Get match intensity based on match type and competition stage
static func get_match_intensity(match_type: String, competition_stage: String = "") -> float:
	var base_intensity = 1.0

	match match_type:
		"friendly":
			base_intensity = 0.5
		"league":
			base_intensity = 1.0
		"knockout":
			base_intensity = 1.3
		"final":
			base_intensity = 1.5

	# Further increase for later tournament stages
	match competition_stage:
		"quarter_final":
			base_intensity *= 1.1
		"semi_final":
			base_intensity *= 1.2
		"final":
			base_intensity *= 1.3

	return base_intensity


## Apply injuries from array to NpcRegistry
static func apply_injuries(injuries: Array[Dictionary]) -> void:
	for injury in injuries:
		var npc_id = injury.get("npc_id", "")
		if npc_id == "":
			continue

		NpcRegistry.apply_injury(
			npc_id,
			injury.get("type", "minor"),
			injury.get("matches_out", 1),
			injury.get("description", "injury")
		)


## Get injury severity description for UI display
static func get_severity_text(injury_type: String) -> String:
	match injury_type:
		"minor":
			return "Minor"
		"moderate":
			return "Moderate"
		"severe":
			return "Severe"
		_:
			return "Unknown"


## Get color for injury severity display
static func get_severity_color(injury_type: String) -> Color:
	match injury_type:
		"minor":
			return Color(0.9, 0.9, 0.2)  # Yellow
		"moderate":
			return Color(0.9, 0.6, 0.2)  # Orange
		"severe":
			return Color(0.9, 0.2, 0.2)  # Red
		_:
			return Color.WHITE
