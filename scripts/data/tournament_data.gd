extends Resource
class_name TournamentData
## TournamentData - Manages knockout bracket generation and tournament progression

enum Stage {
	FIRST_ROUND,
	SECOND_ROUND,
	ROUND_OF_16,
	QUARTER_FINAL,
	SEMI_FINAL,
	FINAL
}

enum TournamentType {
	PREFECTURE_QUALIFIER,  # 16 teams
	NATIONAL_CHAMPIONSHIP  # 48 teams
}

@export var id: String = ""
@export var name: String = ""  # "Kanagawa Prefecture Qualifier" or "National Championship"
@export var tournament_type: TournamentType = TournamentType.PREFECTURE_QUALIFIER

@export var teams: Array[TeamData] = []
@export var player_team_index: int = -1

# Bracket: stage -> [{match_id, team_a_id, team_b_id, winner_id, team_a_score, team_b_score, played, extra_time, penalties}]
@export var bracket: Dictionary = {}

@export var current_stage: Stage = Stage.FIRST_ROUND
@export var player_eliminated: bool = false
@export var champion_team_id: String = ""
@export var is_complete: bool = false


func _init() -> void:
	id = "tournament_%d" % randi()


func initialize(tournament_name: String, tournament_teams: Array[TeamData], player_idx: int, type: TournamentType) -> void:
	name = tournament_name
	teams = tournament_teams
	player_team_index = player_idx
	tournament_type = type
	player_eliminated = false
	champion_team_id = ""
	is_complete = false

	_generate_bracket()


func _generate_bracket() -> void:
	bracket.clear()

	match tournament_type:
		TournamentType.PREFECTURE_QUALIFIER:
			_generate_16_team_bracket()
		TournamentType.NATIONAL_CHAMPIONSHIP:
			_generate_48_team_bracket()


func _generate_16_team_bracket() -> void:
	# 16-team single elimination: R1 (8 matches) -> QF (4) -> SF (2) -> Final (1)
	var shuffled_teams = teams.duplicate()
	shuffled_teams.shuffle()

	# Seed player's team to avoid early elimination vs best teams (optional seeding)
	var player_team: TeamData = null
	if player_team_index >= 0 and player_team_index < teams.size():
		player_team = teams[player_team_index]

	# First round - 8 matches
	var first_round: Array[Dictionary] = []
	for i in range(0, 16, 2):
		first_round.append(_create_match(shuffled_teams[i], shuffled_teams[i + 1], Stage.FIRST_ROUND))

	bracket[Stage.FIRST_ROUND] = first_round

	# Initialize empty slots for later rounds
	bracket[Stage.QUARTER_FINAL] = _create_empty_matches(4, Stage.QUARTER_FINAL)
	bracket[Stage.SEMI_FINAL] = _create_empty_matches(2, Stage.SEMI_FINAL)
	bracket[Stage.FINAL] = _create_empty_matches(1, Stage.FINAL)

	current_stage = Stage.FIRST_ROUND


func _generate_48_team_bracket() -> void:
	# 48-team bracket: 16 teams get byes to R2
	# R1: 32 teams play -> 16 winners
	# R2: 16 winners + 16 seeded = 32 teams -> 16 winners
	# R3 (R16): 16 teams -> 8 winners
	# QF: 8 -> 4
	# SF: 4 -> 2
	# Final: 2 -> 1

	var shuffled_teams = teams.duplicate()
	shuffled_teams.shuffle()

	# Top 16 teams (by index, assuming sorted by strength) get byes
	var seeded_teams = shuffled_teams.slice(0, 16)
	var unseeded_teams = shuffled_teams.slice(16, 48)

	# First round - 16 matches (32 unseeded teams)
	var first_round: Array[Dictionary] = []
	for i in range(0, 32, 2):
		first_round.append(_create_match(unseeded_teams[i], unseeded_teams[i + 1], Stage.FIRST_ROUND))

	bracket[Stage.FIRST_ROUND] = first_round

	# Store seeded teams for second round
	bracket["seeded_teams"] = []
	for team in seeded_teams:
		bracket["seeded_teams"].append(team.id)

	# Initialize empty slots for later rounds
	bracket[Stage.SECOND_ROUND] = _create_empty_matches(16, Stage.SECOND_ROUND)
	bracket[Stage.ROUND_OF_16] = _create_empty_matches(8, Stage.ROUND_OF_16)
	bracket[Stage.QUARTER_FINAL] = _create_empty_matches(4, Stage.QUARTER_FINAL)
	bracket[Stage.SEMI_FINAL] = _create_empty_matches(2, Stage.SEMI_FINAL)
	bracket[Stage.FINAL] = _create_empty_matches(1, Stage.FINAL)

	current_stage = Stage.FIRST_ROUND


func _create_match(team_a: TeamData, team_b: TeamData, stage: Stage) -> Dictionary:
	return {
		"match_id": "tmatch_%d_%d" % [id.hash(), randi()],
		"team_a_id": team_a.id if team_a else "",
		"team_b_id": team_b.id if team_b else "",
		"team_a_name": team_a.name if team_a else "TBD",
		"team_b_name": team_b.name if team_b else "TBD",
		"winner_id": "",
		"team_a_score": 0,
		"team_b_score": 0,
		"played": false,
		"extra_time": false,
		"penalties": false,
		"penalty_score_a": 0,
		"penalty_score_b": 0,
		"stage": stage
	}


func _create_empty_matches(count: int, stage: Stage) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for i in range(count):
		matches.append({
			"match_id": "tmatch_%d_%d" % [id.hash(), randi()],
			"team_a_id": "",
			"team_b_id": "",
			"team_a_name": "TBD",
			"team_b_name": "TBD",
			"winner_id": "",
			"team_a_score": 0,
			"team_b_score": 0,
			"played": false,
			"extra_time": false,
			"penalties": false,
			"penalty_score_a": 0,
			"penalty_score_b": 0,
			"stage": stage
		})
	return matches


func record_result(team_a_id: String, team_b_id: String, team_a_score: int, team_b_score: int, extra_time: bool = false, penalties: bool = false, pen_a: int = 0, pen_b: int = 0) -> void:
	# Find the match in current stage
	var stage_matches = bracket.get(current_stage, [])

	for i in range(stage_matches.size()):
		var match_data = stage_matches[i]
		if (match_data.team_a_id == team_a_id and match_data.team_b_id == team_b_id) or \
		   (match_data.team_a_id == team_b_id and match_data.team_b_id == team_a_id):

			# Handle if teams are swapped
			if match_data.team_a_id == team_b_id:
				var temp_score = team_a_score
				team_a_score = team_b_score
				team_b_score = temp_score
				var temp_pen = pen_a
				pen_a = pen_b
				pen_b = temp_pen

			stage_matches[i].played = true
			stage_matches[i].team_a_score = team_a_score
			stage_matches[i].team_b_score = team_b_score
			stage_matches[i].extra_time = extra_time
			stage_matches[i].penalties = penalties
			stage_matches[i].penalty_score_a = pen_a
			stage_matches[i].penalty_score_b = pen_b

			# Determine winner
			var winner_id: String
			if penalties:
				winner_id = team_a_id if pen_a > pen_b else team_b_id
			else:
				winner_id = team_a_id if team_a_score > team_b_score else team_b_id

			stage_matches[i].winner_id = winner_id

			# Check if player was eliminated
			var player_id = get_player_team_id()
			if player_id and (team_a_id == player_id or team_b_id == player_id):
				if winner_id != player_id:
					player_eliminated = true

			bracket[current_stage] = stage_matches

			# Check if stage is complete and advance
			_check_stage_complete()
			break


func _check_stage_complete() -> void:
	var stage_matches = bracket.get(current_stage, [])
	var all_played = true

	for match_data in stage_matches:
		if match_data.team_a_id != "" and match_data.team_b_id != "" and not match_data.played:
			all_played = false
			break

	if all_played:
		_advance_to_next_stage()


func _advance_to_next_stage() -> void:
	var winners: Array[String] = []
	var stage_matches = bracket.get(current_stage, [])

	for match_data in stage_matches:
		if match_data.winner_id != "":
			winners.append(match_data.winner_id)

	# Determine next stage
	var next_stage: Stage
	match current_stage:
		Stage.FIRST_ROUND:
			if tournament_type == TournamentType.NATIONAL_CHAMPIONSHIP:
				next_stage = Stage.SECOND_ROUND
				# Add seeded teams to winners for second round
				var seeded = bracket.get("seeded_teams", [])
				winners.append_array(seeded)
			else:
				next_stage = Stage.QUARTER_FINAL
		Stage.SECOND_ROUND:
			next_stage = Stage.ROUND_OF_16
		Stage.ROUND_OF_16:
			next_stage = Stage.QUARTER_FINAL
		Stage.QUARTER_FINAL:
			next_stage = Stage.SEMI_FINAL
		Stage.SEMI_FINAL:
			next_stage = Stage.FINAL
		Stage.FINAL:
			# Tournament complete
			if winners.size() > 0:
				champion_team_id = winners[0]
			is_complete = true
			return

	# Populate next stage matches with winners
	_populate_next_stage(next_stage, winners)
	current_stage = next_stage


func _populate_next_stage(stage: Stage, team_ids: Array[String]) -> void:
	var next_matches = bracket.get(stage, [])

	# Shuffle for random matchups
	team_ids.shuffle()

	var match_idx = 0
	for i in range(0, team_ids.size(), 2):
		if match_idx < next_matches.size():
			var team_a = get_team_by_id(team_ids[i])
			var team_b = get_team_by_id(team_ids[i + 1]) if i + 1 < team_ids.size() else null

			next_matches[match_idx].team_a_id = team_a.id if team_a else ""
			next_matches[match_idx].team_a_name = team_a.name if team_a else "TBD"
			next_matches[match_idx].team_b_id = team_b.id if team_b else ""
			next_matches[match_idx].team_b_name = team_b.name if team_b else "TBD"
			match_idx += 1

	bracket[stage] = next_matches


func get_player_team() -> TeamData:
	if player_team_index >= 0 and player_team_index < teams.size():
		return teams[player_team_index]
	return null


func get_player_team_id() -> String:
	var team = get_player_team()
	return team.id if team else ""


func get_team_by_id(team_id: String) -> TeamData:
	for team in teams:
		if team.id == team_id:
			return team
	return null


func get_next_player_match() -> Dictionary:
	if player_eliminated or is_complete:
		return {}

	var player_id = get_player_team_id()
	var stage_matches = bracket.get(current_stage, [])

	for match_data in stage_matches:
		if not match_data.played and (match_data.team_a_id == player_id or match_data.team_b_id == player_id):
			return match_data

	return {}


func get_unplayed_cpu_matches() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player_id = get_player_team_id()
	var stage_matches = bracket.get(current_stage, [])

	for match_data in stage_matches:
		if not match_data.played and match_data.team_a_id != "" and match_data.team_b_id != "":
			if match_data.team_a_id != player_id and match_data.team_b_id != player_id:
				result.append(match_data)

	return result


func get_matches_for_stage(stage: Stage) -> Array[Dictionary]:
	return bracket.get(stage, [])


func get_stage_name(stage: Stage) -> String:
	match stage:
		Stage.FIRST_ROUND:
			return "First Round"
		Stage.SECOND_ROUND:
			return "Second Round"
		Stage.ROUND_OF_16:
			return "Round of 16"
		Stage.QUARTER_FINAL:
			return "Quarter Final"
		Stage.SEMI_FINAL:
			return "Semi Final"
		Stage.FINAL:
			return "Final"
		_:
			return "Unknown"


func get_current_stage_name() -> String:
	return get_stage_name(current_stage)


func player_won_tournament() -> bool:
	return is_complete and champion_team_id == get_player_team_id()


func to_dict() -> Dictionary:
	var teams_data: Array[Dictionary] = []
	for team in teams:
		teams_data.append(team.to_dict())

	# Convert bracket with enum keys to string keys for serialization
	var bracket_data: Dictionary = {}
	for key in bracket:
		if key is Stage:
			bracket_data[str(key)] = bracket[key]
		else:
			bracket_data[key] = bracket[key]

	return {
		"id": id,
		"name": name,
		"tournament_type": tournament_type,
		"teams": teams_data,
		"player_team_index": player_team_index,
		"bracket": bracket_data,
		"current_stage": current_stage,
		"player_eliminated": player_eliminated,
		"champion_team_id": champion_team_id,
		"is_complete": is_complete
	}


func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	name = data.get("name", "")
	tournament_type = data.get("tournament_type", TournamentType.PREFECTURE_QUALIFIER)
	player_team_index = data.get("player_team_index", -1)
	current_stage = data.get("current_stage", Stage.FIRST_ROUND)
	player_eliminated = data.get("player_eliminated", false)
	champion_team_id = data.get("champion_team_id", "")
	is_complete = data.get("is_complete", false)

	# Restore teams
	teams.clear()
	var teams_data = data.get("teams", [])
	for team_data in teams_data:
		var team = TeamData.new()
		team.from_dict(team_data)
		teams.append(team)

	# Restore bracket with proper enum keys
	bracket.clear()
	var bracket_data = data.get("bracket", {})
	for key in bracket_data:
		if key == "seeded_teams":
			bracket[key] = bracket_data[key]
		else:
			var stage_key = int(key) as Stage
			bracket[stage_key] = bracket_data[key]
