extends Resource
class_name TeamData
## TeamData - Stores all data for a team (player's team or opponents)

@export var id: String = ""
@export var name: String = ""
@export var short_name: String = ""
@export var league: String = ""
@export var tier: int = 1  # 1=low, 2=medium, 3=high, 4=elite

# Team colors (for UI and generation prompts)
@export var primary_color: Color = Color.BLUE
@export var secondary_color: Color = Color.WHITE

# Formation and tactics
@export var formation: String = "4-4-2"
@export var tactics: Dictionary = {
	"mentality": "balanced",  # defensive, balanced, attacking, all-out-attack
	"pressing": "medium",     # low, medium, high
	"passing": "mixed",       # short, mixed, direct
	"width": "normal"         # narrow, normal, wide
}

# Squad
@export var players: Array[Dictionary] = []  # Array of NPC player data
@export var captain_id: String = ""

# Prefecture for stable ID generation
var _prefecture: String = ""

const MINOR_INJURY_STAT_PENALTIES: Dictionary = {
	"muscle_tightness": {"STA": 6, "SPD": 4, "TEC": 2},
	"light_bruising": {"PHY": 5, "DEF": 2, "MEN": 2},
	"ankle_niggle": {"SPD": 6, "TEC": 4, "PAS": 2},
	"minor_cramp": {"STA": 7, "SPD": 3, "PHY": 2},
	"_default": {"STA": 4, "SPD": 2, "MEN": 1}
}


func _init() -> void:
	# Default to random ID; will be overwritten by set_stable_id() when name/prefecture are known
	id = "team_%d" % randi()


## Set a stable, deterministic ID based on team name and prefecture
## This ensures the same school always has the same ID across seasons
func set_stable_id(team_name: String, prefecture: String = "") -> void:
	name = team_name
	_prefecture = prefecture
	id = NpcRegistry.generate_stable_team_id(team_name, prefecture)


## Get the prefecture this team belongs to
func get_prefecture() -> String:
	if _prefecture != "":
		return _prefecture
	# Try to extract from league if set (e.g., "Kanagawa Prefecture")
	if league.ends_with(" Prefecture"):
		return league.replace(" Prefecture", "")
	return ""


func generate_teammates(count: int, career_phase: GameManager.CareerPhase, use_registry: bool = true) -> void:
	players.clear()

	# Determine quality tier based on career phase
	var quality = _get_quality_for_phase(career_phase)

	# Get positions needed based on formation
	var positions_needed = _get_positions_from_formation()

	# Remove player's position (they fill one slot)
	if GameManager.player_data:
		var player_pos = GameManager.player_data.position
		var pos_index = positions_needed.find(player_pos)
		if pos_index >= 0:
			positions_needed.remove_at(pos_index)

	# Track position counts for stable indexing
	var position_counts: Dictionary = {}

	# Generate remaining players
	for i in range(mini(count, positions_needed.size())):
		var pos = positions_needed[i]

		# Get stable index for this position
		if pos not in position_counts:
			position_counts[pos] = 0
		var pos_index = position_counts[pos]
		position_counts[pos] += 1

		var teammate: Dictionary
		if use_registry and NpcRegistry:
			teammate = _get_or_create_npc_via_registry(pos, quality, career_phase, pos_index)
		else:
			teammate = _generate_npc_player(pos, quality, career_phase, pos_index)

		players.append(teammate)

	# Set captain (highest overall player)
	_assign_captain()


func _get_quality_for_phase(phase: GameManager.CareerPhase) -> int:
	match phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			return 1
		GameManager.CareerPhase.YOUTH_ACADEMY:
			return 2
		GameManager.CareerPhase.U20_QUALIFIERS, GameManager.CareerPhase.U20_WORLD_CUP:
			return 3
		GameManager.CareerPhase.PRO_CAREER:
			return tier  # Use team's actual tier
		_:
			return 1


func _get_positions_from_formation() -> Array[String]:
	# Parse formation string and return positions
	var positions: Array[String] = ["GK"]  # Always need a keeper
	
	match formation:
		"4-4-2":
			positions.append_array(["FB", "CB", "CB", "FB", "WNG", "CM", "CM", "WNG", "ST", "ST"])
		"4-3-3":
			positions.append_array(["FB", "CB", "CB", "FB", "CDM", "CM", "CM", "WNG", "ST", "WNG"])
		"3-5-2":
			positions.append_array(["CB", "CB", "CB", "FB", "CM", "CDM", "CM", "FB", "ST", "ST"])
		"4-2-3-1":
			positions.append_array(["FB", "CB", "CB", "FB", "CDM", "CDM", "WNG", "CAM", "WNG", "ST"])
		_:
			# Default 4-4-2
			positions.append_array(["FB", "CB", "CB", "FB", "WNG", "CM", "CM", "WNG", "ST", "ST"])
	
	return positions


func _generate_npc_player(pos: String, quality: int, phase: GameManager.CareerPhase, player_index: int = 0) -> Dictionary:
	# Create deterministic ID based on team ID, position, and index
	var npc_id = "npc_%s_%s_%d" % [id.substr(0, 8), pos, player_index]

	# Generate appropriate name based on phase/setting
	var npc_name = _generate_name(phase)

	# Add some variance to quality within the team
	var quality_variance = randi_range(-1, 1)
	var adjusted_quality = clampi(quality + quality_variance, 1, 4)

	# Generate stats using the adjusted quality
	var npc_stats = StatSystem.generate_npc_stats(pos, adjusted_quality)

	return {
		"id": npc_id,
		"name": npc_name,
		"position": pos,
		"stats": npc_stats,
		"overall": StatSystem.calculate_overall(npc_stats, pos),
		"form": ["poor", "average", "average", "good", "excellent"][randi() % 5],
		"personality": _random_personality()
	}


func _get_or_create_npc_via_registry(pos: String, quality: int, phase: GameManager.CareerPhase, pos_index: int) -> Dictionary:
	"""Get existing NPC from registry or create new one if not found."""
	var npc_id = NpcRegistry.generate_stable_npc_id(id, pos, pos_index)
	var exists = NpcRegistry.has_npc(npc_id)
	var existing: Dictionary = {}

	if exists:
		existing = NpcRegistry.get_npc(npc_id)
		if existing.has("name") and existing.has("stats") and existing.has("overall"):
			# NPC exists - return with potential stat evolution already applied
			return NpcRegistry.get_or_create_npc(id, pos, pos_index, {}, true)

	# Create new NPC data (or heal missing data)
	var npc_name = _generate_name(phase)

	# Add some variance to quality within the team
	var quality_variance = randi_range(-1, 1)
	var adjusted_quality = clampi(quality + quality_variance, 1, 4)

	# Generate stats using the adjusted quality
	var npc_stats = StatSystem.generate_npc_stats(pos, adjusted_quality)

	var npc_data = {
		"name": npc_name,
		"position": pos,
		"stats": npc_stats,
		"overall": StatSystem.calculate_overall(npc_stats, pos),
		"form": ["poor", "average", "average", "good", "excellent"][randi() % 5],
		"personality": _random_personality(),
		"team_name": name,
		"team_id": id
	}

	if exists:
		var updates: Dictionary = {}
		for key in npc_data:
			if not existing.has(key) or existing[key] == null or (existing[key] is String and existing[key] == ""):
				updates[key] = npc_data[key]
		if not updates.is_empty():
			NpcRegistry.update_npc(npc_id, updates)
		return NpcRegistry.get_or_create_npc(id, pos, pos_index, {}, true)

	# Register the new NPC and return
	return NpcRegistry.get_or_create_npc(id, pos, pos_index, npc_data, false)


func _generate_name(phase: GameManager.CareerPhase) -> String:
	# Japanese names for high school/domestic phases
	var first_names = ["Yuki", "Haruto", "Sota", "Ren", "Kaito", "Takumi", "Ryota", "Kenta", "Daiki", "Shota"]
	var last_names = ["Tanaka", "Yamamoto", "Suzuki", "Sato", "Watanabe", "Ito", "Nakamura", "Kobayashi", "Kato", "Yoshida"]
	
	# Add international names for world cup phase
	if phase == GameManager.CareerPhase.U20_WORLD_CUP:
		first_names.append_array(["Lucas", "Marco", "Diego", "Pierre", "James", "Mohammed"])
		last_names.append_array(["Silva", "Mueller", "Rodriguez", "Dupont", "Smith", "Ahmed"])
	
	return "%s %s" % [last_names[randi() % last_names.size()], first_names[randi() % first_names.size()]]


func _random_personality() -> String:
	var personalities = ["leader", "hardworker", "creative", "aggressive", "calm", "passionate", "reliable"]
	return personalities[randi() % personalities.size()]


func _assign_captain() -> void:
	if players.is_empty():
		return
	
	var highest_overall = 0
	var captain_index = 0
	
	for i in range(players.size()):
		if players[i].overall > highest_overall:
			highest_overall = players[i].overall
			captain_index = i
	
	captain_id = players[captain_index].id


func get_player_by_id(player_id: String) -> Dictionary:
	for player in players:
		if player.id == player_id:
			return player
	return {}


func get_player_by_position(pos: String) -> Dictionary:
	for player in players:
		if player.position == pos:
			return player
	return {}


func get_starting_eleven(competition_key: String = "") -> Array[Dictionary]:
	# Returns the best 11 match-eligible players (including user's player)
	# Minor injuries can play through with stat penalties.
	var eleven: Array[Dictionary] = []
	var resolved_competition_key = _resolve_competition_key(competition_key)

	var player_record = _build_player_character_record(resolved_competition_key)
	if not player_record.is_empty():
		eleven.append(player_record)

	# Filter to only available players (not injured or graduated)
	var available_players: Array[Dictionary] = []
	for player in players:
		if is_player_available_for_match(player, resolved_competition_key):
			available_players.append(get_match_ready_player_record(player))

	# Sort by overall rating
	available_players.sort_custom(func(a, b): return a.overall > b.overall)

	for player in available_players:
		if eleven.size() >= 11:
			break
		eleven.append(player)

	return eleven


func is_player_available_for_match(player: Dictionary, competition_key: String = "") -> bool:
	var player_id = player.get("id", "")
	if player_id == "":
		return true

	if GameManager.player_data and player_id == GameManager.player_data.id:
		return GameManager.player_data.is_match_eligible(competition_key)

	if not NpcRegistry.has_npc(player_id):
		return true  # Unknown NPCs are assumed available

	return NpcRegistry.get_npc_match_availability(player_id, competition_key).get("eligible", true)


func get_match_ready_player_record(player: Dictionary) -> Dictionary:
	var player_id = player.get("id", "")
	if player_id == "":
		return player
	if GameManager.player_data and player_id == GameManager.player_data.id:
		return _build_player_character_record(_resolve_competition_key(""))
	if not NpcRegistry.has_npc(player_id):
		return player

	var npc = NpcRegistry.get_npc(player_id)
	var status = npc.get("status", "active")
	if status != "injured":
		return player

	var injury = npc.get("injury", {})
	var severity = injury.get("type", "")
	var matches_remaining = int(injury.get("matches_remaining", 0))
	if severity == "minor" and matches_remaining > 0:
		return _apply_minor_injury_penalty(player, injury)

	return player


func _apply_minor_injury_penalty(player: Dictionary, injury: Dictionary) -> Dictionary:
	var adjusted = player.duplicate(true)
	adjusted["base_stats"] = adjusted.get("stats", {}).duplicate(true)
	adjusted["base_overall"] = int(adjusted.get("overall", 50))
	var injury_type = str(injury.get("injury_type", ""))
	var penalties: Dictionary = MINOR_INJURY_STAT_PENALTIES.get(
		injury_type,
		MINOR_INJURY_STAT_PENALTIES["_default"]
	)
	var penalty_scale = _minor_injury_penalty_scale(injury)

	var stats: Dictionary = adjusted.get("stats", {}).duplicate(true)
	if stats.is_empty():
		var overall_penalty = maxi(1, roundi(4.0 * penalty_scale))
		adjusted["overall"] = maxi(int(adjusted.get("overall", 50)) - overall_penalty, 1)
	else:
		for stat_key in penalties:
			if stats.has(stat_key):
				var base_penalty = int(penalties[stat_key])
				var scaled_penalty = maxi(1, roundi(float(base_penalty) * penalty_scale))
				stats[stat_key] = clampi(int(stats[stat_key]) - scaled_penalty, 1, 99)

		adjusted["stats"] = stats
		adjusted["overall"] = StatSystem.calculate_overall(stats, adjusted.get("position", "CM"))

	adjusted["playing_through_injury"] = true
	adjusted["injury_severity"] = "minor"
	adjusted["injury_type"] = injury_type
	adjusted["injury_matches_remaining"] = int(injury.get("matches_remaining", 0))
	adjusted["injury_penalty_scale"] = penalty_scale
	adjusted["injury"] = injury.duplicate(true)
	return adjusted


func _minor_injury_penalty_scale(injury: Dictionary) -> float:
	var matches_remaining = maxi(int(injury.get("matches_remaining", 0)), 0)
	if matches_remaining <= 0:
		return 0.0

	var matches_total = maxi(int(injury.get("matches_total", matches_remaining)), 1)
	if matches_total <= 1:
		return 1.0

	var numerator = float(matches_remaining - 1)
	var denominator = float(maxi(matches_total - 1, 1))
	var progress = clampf(numerator / denominator, 0.0, 1.0)
	return lerpf(0.55, 1.0, progress)


func get_injured_players() -> Array[Dictionary]:
	"""Get list of currently injured players on the team."""
	var injured: Array[Dictionary] = []

	for player in players:
		var player_id = player.get("id", "")
		if player_id == "" or not NpcRegistry.has_npc(player_id):
			continue

		var npc = NpcRegistry.get_npc(player_id)
		if npc.get("status", "active") == "injured":
			var injury = npc.get("injury", {})
			injured.append({
				"player": player,
				"injury_type": injury.get("injury_type", injury.get("type", "")),
				"injury_severity": injury.get("type", ""),
				"matches_remaining": injury.get("matches_remaining", 0),
				"description": injury.get("description", "")
			})

	return injured


func get_average_overall() -> int:
	if players.is_empty():
		return 50
	
	var total = 0
	for player in players:
		total += player.overall
	
	return roundi(float(total) / players.size())


func _build_player_character_record(competition_key: String) -> Dictionary:
	if not _should_include_player_character():
		return {}
	if not GameManager.player_data:
		return {}
	if not GameManager.player_data.is_match_eligible(competition_key):
		return {}

	var record = {
		"id": GameManager.player_data.id,
		"name": GameManager.player_data.name,
		"position": GameManager.player_data.position,
		"stats": GameManager.player_data.stats.duplicate(true),
		"overall": GameManager.player_data.get_overall(),
		"is_player": true,
		"dominant_foot": GameManager.player_data.dominant_foot,
		"stamina_current": GameManager.player_data.stamina_current,
		"injury": GameManager.player_data.get_injury_record()
	}

	var injury_record = GameManager.player_data.get_injury_record()
	if str(injury_record.get("type", "")) == "minor" and int(injury_record.get("matches_remaining", 0)) > 0:
		return _apply_minor_injury_penalty(record, injury_record)

	return record


func _should_include_player_character() -> bool:
	if not GameManager.player_data:
		return false
	if GameManager.current_match:
		var player_team = GameManager.current_match.get_player_team()
		return player_team != null and player_team.id == id
	return GameManager.current_team != null and GameManager.current_team.id == id


func _resolve_competition_key(competition_key: String) -> String:
	if not str(competition_key).is_empty():
		return str(competition_key)
	if GameManager.current_match:
		return str(GameManager.current_match.competition_key)
	return ""


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"short_name": short_name,
		"league": league,
		"tier": tier,
		"formation": formation,
		"tactics": tactics,
		"players": players,
		"captain_id": captain_id,
		"prefecture": _prefecture
	}


func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	name = data.get("name", "Unknown Team")
	short_name = data.get("short_name", "UNK")
	league = data.get("league", "")
	tier = data.get("tier", 1)
	formation = data.get("formation", "4-4-2")
	tactics = data.get("tactics", tactics)
	players.assign(data.get("players", []))
	captain_id = data.get("captain_id", "")
	_prefecture = data.get("prefecture", "")
