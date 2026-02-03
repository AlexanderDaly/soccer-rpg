extends Resource
class_name SeasonPlayerStats
## SeasonPlayerStats - Tracks player statistics across the league season for awards

# player_id -> {team_id, name, position, goals, assists, clean_sheets, matches_played}
@export var player_stats: Dictionary = {}

# Minimum percentage of matches required for award eligibility
const MIN_MATCHES_PERCENT: float = 0.5


func record_appearance(player: Dictionary, team_id: String) -> void:
	var player_id = player.get("id", "")
	if player_id.is_empty():
		return

	if not player_stats.has(player_id):
		player_stats[player_id] = {
			"team_id": team_id,
			"name": player.get("name", "Unknown"),
			"position": player.get("position", ""),
			"goals": 0,
			"assists": 0,
			"clean_sheets": 0,
			"matches_played": 0
		}

	player_stats[player_id].matches_played += 1


func record_goal(player_id: String) -> void:
	if player_stats.has(player_id):
		player_stats[player_id].goals += 1


func record_assist(player_id: String) -> void:
	if player_stats.has(player_id):
		player_stats[player_id].assists += 1


func record_clean_sheet(player_id: String) -> void:
	if player_stats.has(player_id):
		player_stats[player_id].clean_sheets += 1


func get_total_matches_in_league(num_teams: int) -> int:
	# Double round-robin: each team plays (num_teams - 1) * 2 matches
	return (num_teams - 1) * 2


func _is_eligible(stats: Dictionary, total_matches: int) -> bool:
	return stats.matches_played >= int(total_matches * MIN_MATCHES_PERCENT)


func get_golden_boot_winner(total_matches: int = 18) -> Dictionary:
	var eligible_players: Array[Dictionary] = []

	for player_id in player_stats:
		var stats = player_stats[player_id]
		if _is_eligible(stats, total_matches) and stats.goals > 0:
			var entry = stats.duplicate()
			entry["player_id"] = player_id
			eligible_players.append(entry)

	if eligible_players.is_empty():
		return {}

	# Sort by goals (desc), then assists (desc), then fewer matches (asc)
	eligible_players.sort_custom(func(a, b):
		if a.goals != b.goals:
			return a.goals > b.goals
		if a.assists != b.assists:
			return a.assists > b.assists
		return a.matches_played < b.matches_played
	)

	# Defensive check after sort (should never be empty at this point)
	return eligible_players[0] if not eligible_players.is_empty() else {}


func get_top_assister(total_matches: int = 18) -> Dictionary:
	var eligible_players: Array[Dictionary] = []

	for player_id in player_stats:
		var stats = player_stats[player_id]
		if _is_eligible(stats, total_matches) and stats.assists > 0:
			var entry = stats.duplicate()
			entry["player_id"] = player_id
			eligible_players.append(entry)

	if eligible_players.is_empty():
		return {}

	# Sort by assists (desc), then goals (desc), then fewer matches (asc)
	eligible_players.sort_custom(func(a, b):
		if a.assists != b.assists:
			return a.assists > b.assists
		if a.goals != b.goals:
			return a.goals > b.goals
		return a.matches_played < b.matches_played
	)

	# Defensive check after sort (should never be empty at this point)
	return eligible_players[0] if not eligible_players.is_empty() else {}


func get_golden_glove(total_matches: int = 18) -> Dictionary:
	var eligible_gks: Array[Dictionary] = []

	for player_id in player_stats:
		var stats = player_stats[player_id]
		if stats.position == "GK" and _is_eligible(stats, total_matches) and stats.clean_sheets > 0:
			var entry = stats.duplicate()
			entry["player_id"] = player_id
			eligible_gks.append(entry)

	if eligible_gks.is_empty():
		return {}

	# Sort by clean sheets (desc), then fewer matches (asc)
	eligible_gks.sort_custom(func(a, b):
		if a.clean_sheets != b.clean_sheets:
			return a.clean_sheets > b.clean_sheets
		return a.matches_played < b.matches_played
	)

	# Defensive check after sort (should never be empty at this point)
	return eligible_gks[0] if not eligible_gks.is_empty() else {}


func get_all_awards(total_matches: int = 18) -> Dictionary:
	return {
		"golden_boot": get_golden_boot_winner(total_matches),
		"top_assister": get_top_assister(total_matches),
		"golden_glove": get_golden_glove(total_matches)
	}


func get_top_scorers(count: int = 5, total_matches: int = 18) -> Array[Dictionary]:
	var scorers: Array[Dictionary] = []

	for player_id in player_stats:
		var stats = player_stats[player_id]
		if stats.goals > 0:
			var entry = stats.duplicate()
			entry["player_id"] = player_id
			entry["eligible"] = _is_eligible(stats, total_matches)
			scorers.append(entry)

	# Sort by goals (desc), then assists (desc)
	scorers.sort_custom(func(a, b):
		if a.goals != b.goals:
			return a.goals > b.goals
		return a.assists > b.assists
	)

	var result: Array[Dictionary] = []
	for i in range(mini(count, scorers.size())):
		result.append(scorers[i])
	return result


func get_top_assisters(count: int = 5, total_matches: int = 18) -> Array[Dictionary]:
	var assisters: Array[Dictionary] = []

	for player_id in player_stats:
		var stats = player_stats[player_id]
		if stats.assists > 0:
			var entry = stats.duplicate()
			entry["player_id"] = player_id
			entry["eligible"] = _is_eligible(stats, total_matches)
			assisters.append(entry)

	# Sort by assists (desc), then goals (desc)
	assisters.sort_custom(func(a, b):
		if a.assists != b.assists:
			return a.assists > b.assists
		return a.goals > b.goals
	)

	var result: Array[Dictionary] = []
	for i in range(mini(count, assisters.size())):
		result.append(assisters[i])
	return result


func to_dict() -> Dictionary:
	return {
		"player_stats": player_stats
	}


func from_dict(data: Dictionary) -> void:
	player_stats = data.get("player_stats", {})
