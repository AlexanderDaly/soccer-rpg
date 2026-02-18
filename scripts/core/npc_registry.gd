extends Node
## NpcRegistry - Persistent storage for all encountered NPCs across seasons
##
## This autoload maintains a registry of NPCs that persists across season transitions,
## enabling narratives, rivalries, and character development that span multiple seasons.

signal npc_registered(npc_id: String)
signal npc_updated(npc_id: String)
signal npc_graduated(npc_id: String, npc_data: Dictionary)
signal npc_injured(npc_id: String, injury: Dictionary)
signal npc_recovered(npc_id: String)

# Registry of all known NPCs: stable_id -> NPC data
var npc_registry: Dictionary = {}

# Team registry for stable team identification: stable_team_id -> team metadata
var team_registry: Dictionary = {}

# Current season for tracking encounter history
var current_season_id: String = ""


func _ready() -> void:
	print("[NpcRegistry] Initialized")


## Generate a stable team ID from team name and prefecture
## This ensures the same school always has the same ID across seasons
static func generate_stable_team_id(team_name: String, prefecture: String = "") -> String:
	var base = team_name.to_lower().strip_edges()
	if prefecture != "":
		base = prefecture.to_lower() + "_" + base
	# Use hash for stable ID generation
	return "team_%s" % str(base.hash()).substr(0, 12)


## Generate a stable NPC ID from team, position, and roster index
## Format: npc_{stable_team_id_prefix}_{position}_{index}
static func generate_stable_npc_id(stable_team_id: String, position: String, roster_index: int) -> String:
	return "npc_%s_%s_%d" % [stable_team_id.substr(5, 8), position, roster_index]


## Set the current season for tracking encounter history
func set_current_season(season_id: String) -> void:
	current_season_id = season_id
	print("[NpcRegistry] Current season set to: %s" % season_id)


## Register a team in the team registry
func register_team(team_name: String, prefecture: String, metadata: Dictionary = {}) -> String:
	var stable_id = generate_stable_team_id(team_name, prefecture)

	if stable_id not in team_registry:
		team_registry[stable_id] = {
			"name": team_name,
			"prefecture": prefecture,
			"first_encountered": current_season_id,
			"metadata": metadata
		}
	else:
		# Update metadata if provided
		if not metadata.is_empty():
			team_registry[stable_id].metadata.merge(metadata, true)

	return stable_id


## Get or create an NPC, returning their full data
## If the NPC exists, returns existing data (with optional stat evolution)
## If not, creates new NPC data and registers it
func get_or_create_npc(stable_team_id: String, position: String, roster_index: int,
		npc_data: Dictionary = {}, apply_evolution: bool = false) -> Dictionary:
	var npc_id = generate_stable_npc_id(stable_team_id, position, roster_index)

	if npc_id in npc_registry:
		var existing = npc_registry[npc_id]

		# Track encounter
		_record_encounter(npc_id)

		# Optionally apply stat evolution for returning NPCs
		if apply_evolution and existing.has("stats"):
			existing = _apply_stat_evolution(existing)
			npc_registry[npc_id] = existing
			npc_updated.emit(npc_id)

		return existing

	# Create new NPC entry
	var new_npc = npc_data.duplicate(true)
	new_npc["id"] = npc_id
	new_npc["stable_team_id"] = stable_team_id
	new_npc["first_encountered_season"] = current_season_id
	new_npc["encounter_history"] = [current_season_id] if current_season_id != "" else []
	new_npc["seasons_played"] = 1

	# Roster status fields
	var season_year = _get_current_season_year()
	new_npc["school_year"] = npc_data.get("school_year", randi_range(1, 3))
	new_npc["status"] = npc_data.get("status", "active")
	new_npc["graduation_year"] = season_year + (3 - new_npc["school_year"])

	# Injury tracking
	new_npc["injury"] = npc_data.get("injury", {
		"type": "",
		"injury_type": "",
		"matches_remaining": 0,
		"matches_total": 0,
		"description": ""
	})

	# Career events for persona evolution
	new_npc["career_events"] = npc_data.get("career_events", [])

	npc_registry[npc_id] = new_npc
	npc_registered.emit(npc_id)

	return new_npc


## Get NPC by their stable ID
func get_npc(npc_id: String) -> Dictionary:
	return npc_registry.get(npc_id, {})


## Check if NPC exists in registry
func has_npc(npc_id: String) -> bool:
	return npc_id in npc_registry


## Get all NPCs for a specific team
func get_team_npcs(stable_team_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var prefix = "npc_%s_" % stable_team_id.substr(5, 8)

	for npc_id in npc_registry:
		if npc_id.begins_with(prefix):
			result.append(npc_registry[npc_id])

	return result


## Update NPC data in the registry
func update_npc(npc_id: String, updates: Dictionary) -> void:
	if npc_id in npc_registry:
		npc_registry[npc_id].merge(updates, true)
		npc_updated.emit(npc_id)


## Record an encounter with an NPC in the current season
func _record_encounter(npc_id: String) -> void:
	if npc_id not in npc_registry or current_season_id == "":
		return

	var npc = npc_registry[npc_id]
	if not npc.has("encounter_history"):
		npc["encounter_history"] = []

	if current_season_id not in npc.encounter_history:
		npc.encounter_history.append(current_season_id)
		npc["seasons_played"] = npc.encounter_history.size()


## Apply stat evolution for NPCs returning in a new season
## Young players improve, older players may decline
func _apply_stat_evolution(npc_data: Dictionary) -> Dictionary:
	var evolved = npc_data.duplicate(true)

	if not evolved.has("stats"):
		return evolved

	var seasons_played = evolved.get("seasons_played", 1)
	var stats = evolved.stats.duplicate()

	# Evolution factors based on career stage
	# High school players tend to improve as they gain experience
	var growth_rate: float
	if seasons_played <= 2:
		growth_rate = randf_range(0.02, 0.08)  # Significant growth early
	elif seasons_played <= 3:
		growth_rate = randf_range(0.0, 0.04)   # Slower growth
	else:
		growth_rate = randf_range(-0.02, 0.02) # Peak/slight decline

	# Apply evolution to each stat with some variance
	for stat_key in stats:
		if stats[stat_key] is int or stats[stat_key] is float:
			var change = stats[stat_key] * growth_rate * randf_range(0.5, 1.5)
			stats[stat_key] = clampi(roundi(stats[stat_key] + change), 20, 99)

	evolved.stats = stats

	# Recalculate overall if we have position info
	if evolved.has("position"):
		evolved["overall"] = StatSystem.calculate_overall(stats, evolved.position)

	# Update form with some randomness
	var forms = ["poor", "average", "average", "good", "excellent"]
	evolved["form"] = forms[randi() % forms.size()]

	return evolved


## Get NPCs that the player has encountered as rivals (on other teams)
func get_known_rivals() -> Array[Dictionary]:
	var rivals: Array[Dictionary] = []
	var player_team_prefix = ""

	if GameManager.current_team:
		var player_stable_id = generate_stable_team_id(
			GameManager.current_team.name,
			GameManager.current_prefecture
		)
		player_team_prefix = "npc_%s_" % player_stable_id.substr(5, 8)

	for npc_id in npc_registry:
		var npc = npc_registry[npc_id]
		# Not on player's team and encountered more than once
		if not npc_id.begins_with(player_team_prefix):
			if npc.get("seasons_played", 1) > 1:
				rivals.append(npc)

	return rivals


## Get active (non-injured, non-graduated) NPCs for a team
func get_active_team_npcs(stable_team_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var all_npcs = get_team_npcs(stable_team_id)

	for npc in all_npcs:
		var status = npc.get("status", "active")
		if status == "active":
			result.append(npc)

	return result


## Apply an injury to an NPC
func apply_injury(npc_id: String, injury_type: String, matches_out: int, description: String = "", specific_injury_type: String = "") -> void:
	if npc_id not in npc_registry:
		return

	var injury = {
		"type": injury_type,
		"injury_type": specific_injury_type,
		"matches_remaining": matches_out,
		"matches_total": matches_out,
		"description": description
	}

	npc_registry[npc_id]["injury"] = injury
	npc_registry[npc_id]["status"] = "injured"

	npc_injured.emit(npc_id, injury)
	npc_updated.emit(npc_id)
	print("[NpcRegistry] %s injured: %s (%d matches)" % [npc_id, description, matches_out])


## Recover an NPC from injury
func recover_from_injury(npc_id: String) -> void:
	if npc_id not in npc_registry:
		return

	var npc = npc_registry[npc_id]
	if npc.get("status", "") != "injured":
		return

	npc["injury"] = {
		"type": "",
		"injury_type": "",
		"matches_remaining": 0,
		"matches_total": 0,
		"description": ""
	}
	npc["status"] = "active"

	npc_recovered.emit(npc_id)
	npc_updated.emit(npc_id)
	print("[NpcRegistry] %s recovered from injury" % npc_id)


## Process injury recovery after a match - decrements match counters
func process_injury_recovery() -> Array[String]:
	var recovered: Array[String] = []

	for npc_id in npc_registry:
		var npc = npc_registry[npc_id]
		if npc.get("status", "") != "injured":
			continue

		var injury = npc.get("injury", {})
		var matches_remaining = injury.get("matches_remaining", 0)

		if matches_remaining > 0:
			matches_remaining -= 1
			npc["injury"]["matches_remaining"] = matches_remaining

			if matches_remaining <= 0:
				recover_from_injury(npc_id)
				recovered.append(npc_id)

	return recovered


## Graduate an NPC (mark as graduated)
func graduate_npc(npc_id: String) -> void:
	if npc_id not in npc_registry:
		return

	npc_registry[npc_id]["status"] = "graduated"
	var npc_data = npc_registry[npc_id]

	npc_graduated.emit(npc_id, npc_data)
	npc_updated.emit(npc_id)
	print("[NpcRegistry] %s graduated" % npc_data.get("name", npc_id))


## Process graduations for all 3rd-year students at end of season
## Returns array of graduated NPC data
func process_graduations(season_year: int) -> Array[Dictionary]:
	var graduated: Array[Dictionary] = []

	for npc_id in npc_registry:
		var npc = npc_registry[npc_id]
		if npc.get("status", "") == "graduated":
			continue

		var school_year = npc.get("school_year", 0)
		var graduation_year = npc.get("graduation_year", 0)

		# Graduate 3rd-years or anyone past their graduation year
		if school_year >= 3 or (graduation_year > 0 and season_year >= graduation_year):
			graduate_npc(npc_id)
			graduated.append(npc)

	print("[NpcRegistry] Processed graduations: %d players graduated" % graduated.size())
	return graduated


## Promote all active NPCs to next school year (1→2, 2→3)
func promote_school_years() -> void:
	var promoted_count = 0

	for npc_id in npc_registry:
		var npc = npc_registry[npc_id]
		var status = npc.get("status", "active")
		if status == "graduated":
			continue

		var school_year = npc.get("school_year", 0)
		if school_year > 0 and school_year < 3:
			npc["school_year"] = school_year + 1
			promoted_count += 1
			npc_updated.emit(npc_id)

	print("[NpcRegistry] Promoted %d players to next school year" % promoted_count)


## Record a career event for persona evolution
func record_career_event(npc_id: String, event: String) -> void:
	if npc_id not in npc_registry:
		return

	var npc = npc_registry[npc_id]
	if not npc.has("career_events"):
		npc["career_events"] = []

	# Add event with timestamp
	var season_year = _get_current_season_year()
	var event_entry = "%s_%d" % [event, season_year]

	if event_entry not in npc.career_events:
		npc.career_events.append(event_entry)
		npc_updated.emit(npc_id)
		print("[NpcRegistry] Recorded career event for %s: %s" % [npc_id, event_entry])


## Check if an NPC is available (active and not injured)
func is_npc_available(npc_id: String) -> bool:
	if npc_id not in npc_registry:
		return true  # Unknown NPCs are assumed available

	var npc = npc_registry[npc_id]
	return npc.get("status", "active") == "active"


## Check if an NPC can be selected for match play.
## Minor injuries are playable; all other injuries are unavailable.
func is_npc_match_eligible(npc_id: String) -> bool:
	if npc_id not in npc_registry:
		return true  # Unknown NPCs are assumed available

	var npc = npc_registry[npc_id]
	var status = npc.get("status", "active")
	if status == "active":
		return true
	if status != "injured":
		return false

	var injury = npc.get("injury", {})
	var severity = injury.get("type", "")
	var matches_remaining = int(injury.get("matches_remaining", 0))
	return severity == "minor" and matches_remaining > 0


## Get the current season year from the season ID
func _get_current_season_year() -> int:
	if current_season_id == "":
		return 2024  # Default year

	# Season ID format: "prefecture_year" e.g., "Kanagawa_2024"
	var parts = current_season_id.split("_")
	if parts.size() >= 2:
		return int(parts[-1])

	return 2024


## Clear the registry (for new game)
func clear() -> void:
	npc_registry.clear()
	team_registry.clear()
	current_season_id = ""
	print("[NpcRegistry] Registry cleared")


## Serialize for saving
func to_dict() -> Dictionary:
	return {
		"npc_registry": npc_registry,
		"team_registry": team_registry,
		"current_season_id": current_season_id
	}


## Deserialize from save data
func from_dict(data: Dictionary) -> void:
	npc_registry = data.get("npc_registry", {})
	team_registry = data.get("team_registry", {})
	current_season_id = data.get("current_season_id", "")
	print("[NpcRegistry] Loaded %d NPCs, %d teams from save" % [npc_registry.size(), team_registry.size()])
