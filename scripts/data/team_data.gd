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


func _init() -> void:
	id = "team_%d" % randi()


func generate_teammates(count: int, career_phase: GameManager.CareerPhase) -> void:
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
	
	# Generate remaining players
	for i in range(mini(count, positions_needed.size())):
		var pos = positions_needed[i]
		var teammate = _generate_npc_player(pos, quality, career_phase)
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


func _generate_npc_player(pos: String, quality: int, phase: GameManager.CareerPhase) -> Dictionary:
	var npc_id = "npc_%d" % randi()
	
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


func get_starting_eleven() -> Array[Dictionary]:
	# Returns the best 11 players (including user's player)
	var eleven: Array[Dictionary] = []
	
	# Add user's player
	if GameManager.player_data:
		eleven.append({
			"id": GameManager.player_data.id,
			"name": GameManager.player_data.name,
			"position": GameManager.player_data.position,
			"stats": GameManager.player_data.stats,
			"overall": GameManager.player_data.get_overall(),
			"is_player": true
		})
	
	# Add teammates
	var sorted_players = players.duplicate()
	sorted_players.sort_custom(func(a, b): return a.overall > b.overall)
	
	for player in sorted_players:
		if eleven.size() >= 11:
			break
		eleven.append(player)
	
	return eleven


func get_average_overall() -> int:
	if players.is_empty():
		return 50
	
	var total = 0
	for player in players:
		total += player.overall
	
	return roundi(float(total) / players.size())


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
		"captain_id": captain_id
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
