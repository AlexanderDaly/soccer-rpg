extends RefCounted
class_name InjurySystem
## InjurySystem - Handles injury mechanics for NPC players

const INJURY_CATEGORIES = {
	"minor": {
		"base_weight": 72,
		"types": {
			"muscle_tightness": {
				"descriptions": ["muscle tightness", "minor strain", "mild stiffness"],
				"weight": 30,
				"matches_out": 1
			},
			"light_bruising": {
				"descriptions": ["minor bruise", "light bruising", "soft tissue soreness"],
				"weight": 30,
				"matches_out": 1
			},
			"ankle_niggle": {
				"descriptions": ["ankle niggle", "low-grade ankle soreness", "slight stiffness"],
				"weight": 25,
				"matches_out": 2
			},
			"minor_cramp": {
				"descriptions": ["minor cramp", "hamstring pull", "tight calf"],
				"weight": 15,
				"matches_out": 2
			}
		}
	},
	"moderate": {
		"base_weight": 22,
		"types": {
			"ankle_sprain": {
				"descriptions": ["ankle sprain", "rolled ankle", "ankle ligament stress"],
				"weight": 30,
				"matches_out": 2
			},
			"hamstring_pull": {
				"descriptions": ["hamstring pull", "rear-thigh strain", "high-intensity hamstring pain"],
				"weight": 25,
				"matches_out": 3
			},
			"knee_twist": {
				"descriptions": ["knee twist", "minor meniscus irritation", "knee instability"],
				"weight": 25,
				"matches_out": 3
			},
			"quadriceps_strain": {
				"descriptions": ["quadriceps strain", "strained quad", "front-thigh inflammation"],
				"weight": 20,
				"matches_out": 4
			}
		}
	},
	"severe": {
		"base_weight": 6,
		"types": {
			"acl_tear": {
				"descriptions": ["ACL tear", "major ligament tear", "serious knee injury"],
				"weight": 25,
				"matches_out": 12
			},
			"hamstring_tear": {
				"descriptions": ["hamstring tear", "severe posterior muscle tear", "significant tear"],
				"weight": 25,
				"matches_out": 6
			},
			"ligament_damage": {
				"descriptions": ["ligament damage", "major joint damage", "internal knee disruption"],
				"weight": 25,
				"matches_out": 9
			},
			"fractured_metatarsal": {
				"descriptions": ["fractured metatarsal", "foot fracture", "metatarsal stress fracture"],
				"weight": 25,
				"matches_out": 10
			}
		}
	}
}

## Base injury chance per player per training session
const BASE_TRAINING_INJURY_CHANCE_PER_PLAYER: float = 0.0016

## Hard cap for injury chance per player in a training session
const MAX_TRAINING_INJURY_CHANCE_PER_PLAYER: float = 0.02


## Legacy match injury API kept for call-site compatibility.
## Match-level injury rolls were moved out; this now always returns no injuries.
static func roll_for_injuries(team: TeamData, match_intensity: float = 1.0) -> Array[Dictionary]:
	return []


## Roll for injuries specifically during training sessions.
static func roll_for_training_injuries(team: TeamData, training_context: Dictionary = {}) -> Array[Dictionary]:
	if not team or team.players.is_empty():
		return []

	var injuries: Array[Dictionary] = []
	var context = training_context.duplicate(true)
	context["training_type"] = context.get("training_type", "practice")

	for player in team.players:
		var player_id = player.get("id", "")
		if player_id == "":
			continue

		# Skip already injured players
		if NpcRegistry.has_npc(player_id):
			var npc = NpcRegistry.get_npc(player_id)
			if npc.get("status", "active") != "active":
				continue

		if randf() < _calculate_training_injury_chance(context):
			var injury = generate_injury(player_id, context)
			if not injury.is_empty():
				injuries.append(injury)

	return injuries


## Process a full injury cycle for a training session: roll, apply, and return display events.
static func process_training_injuries(team: TeamData, training_context: Dictionary = {}) -> Array[Dictionary]:
	var injuries = roll_for_training_injuries(team, training_context)
	if injuries.is_empty():
		return []

	apply_injuries(injuries)

	var team_name = ""
	var team_id = ""
	if team:
		team_name = team.name
		team_id = team.id

	var injury_events: Array[Dictionary] = []
	for injury in injuries:
		var npc_id = injury.get("npc_id", "")
		if npc_id == "":
			continue

		var npc = NpcRegistry.get_npc(npc_id)
		var player_name = npc.get("name", "Player")
		var severity = injury.get("type", "minor")
		var specific_injury = injury.get("injury_type", severity)
		var matches_out = injury.get("matches_out", 1)

		if severity == "severe":
			NpcRegistry.record_career_event(npc_id, "severe_injury")

		injury_events.append({
			"team_id": team_id,
			"team_name": team_name,
			"player_name": player_name,
			"description": injury.get("description", "injury"),
			"matches_out": matches_out,
			"type": severity,
			"injury_type": specific_injury
		})

	return injury_events


## Generate an injury for a specific player from training context.
static func generate_injury(npc_id: String, training_context: Dictionary = {}) -> Dictionary:
	var severity = _roll_injury_severity(training_context)
	var injury_type = _roll_injury_type(severity)
	var type_data = INJURY_CATEGORIES.get(severity, {}).get("types", {}).get(injury_type, {})

	var descriptions = type_data.get("descriptions", ["injury"])
	var description = descriptions[randi() % descriptions.size()]
	var matches_out = int(type_data.get("matches_out", 1))

	return {
		"npc_id": npc_id,
		"type": severity,
		"injury_type": injury_type,
		"matches_out": matches_out,
		"description": description
	}


static func _calculate_training_injury_chance(training_context: Dictionary) -> float:
	var accuracy = clampf(float(training_context.get("accuracy", 1.0)), 0.0, 1.0)
	var attempts = maxi(1, int(training_context.get("attempts", TrainingConstants.ATTEMPTS_PER_SESSION)))
	var intensity = clampf(float(training_context.get("training_intensity", 1.0)), 0.5, 2.0)
	var stamina_before = clampi(int(training_context.get("player_stamina", 100)), 0, 100)
	var stamina_cost = float(training_context.get("stamina_cost", TrainingConstants.STAMINA_COST))

	var fatigue_factor = 1.0 + ((100.0 - float(stamina_before)) / 100.0) * 1.5
	var quality_factor = 1.0 + ((1.0 - accuracy) * 0.75)
	var volume_factor = clampf(float(attempts) / float(TrainingConstants.ATTEMPTS_PER_SESSION), 0.5, 2.0)
	var cost_factor = clampf(0.6 + (stamina_cost / float(TrainingConstants.STAMINA_COST)), 0.6, 2.0)

	var chance = BASE_TRAINING_INJURY_CHANCE_PER_PLAYER
	chance *= intensity
	chance *= fatigue_factor
	chance *= quality_factor
	chance *= volume_factor
	chance *= cost_factor

	return clampf(chance, 0.0, MAX_TRAINING_INJURY_CHANCE_PER_PLAYER)


static func _roll_injury_severity(training_context: Dictionary) -> String:
	var accuracy = clampf(float(training_context.get("accuracy", 1.0)), 0.0, 1.0)
	var stamina_before = clampi(int(training_context.get("player_stamina", 100)), 0, 100)
	var intensity = clampf(float(training_context.get("training_intensity", 1.0)), 0.5, 2.0)

	var fatigue = 1.0 - (float(stamina_before) / 100.0)
	var performance_pressure = 1.0 - accuracy
	var stress = (intensity - 1.0) * 0.8 + fatigue + performance_pressure

	var minor_weight = 72.0 - (stress * 25.0)
	var moderate_weight = 22.0 + (stress * 18.0)
	var severe_weight = 6.0 + (stress * 8.0)

	minor_weight = max(10.0, minor_weight)
	var total_weight = minor_weight + moderate_weight + severe_weight

	var roll = randf() * total_weight
	if roll < minor_weight:
		return "minor"
	elif roll < minor_weight + moderate_weight:
		return "moderate"
	return "severe"


## Roll for injury type based on severity weights
static func _roll_injury_type(injury_severity: String) -> String:
	var severity_data = INJURY_CATEGORIES.get(injury_severity, {})
	var type_data = severity_data.get("types", {})

	var total_weight = 0
	for type_name in type_data:
		var details = type_data[type_name]
		total_weight += int(details.get("weight", 1))

	if total_weight == 0:
		return injury_severity

	var roll = randi() % total_weight
	var cumulative = 0
	for type_name in type_data:
		var type_details = type_data[type_name]
		cumulative += int(type_details.get("weight", 1))
		if roll < cumulative:
			return type_name

	return type_data.keys()[0]


## Get match intensity (legacy helper retained; injuries now come from training events).
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
			injury.get("description", "injury"),
			injury.get("injury_type", "")
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
