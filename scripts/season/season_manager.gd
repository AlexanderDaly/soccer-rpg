extends Node
## SeasonManager - Autoload singleton for coordinating season phases
## Handles initialization, phase transitions, and CPU match simulation

signal season_initialized(season: SeasonData)
signal phase_changed(new_phase: SeasonData.Phase)
signal league_standings_updated(standings: Array[Dictionary])
signal tournament_bracket_updated(tournament: TournamentData)
signal cpu_matches_simulated(results: Array[Dictionary])
signal player_qualified_for_nationals()
signal player_eliminated(competition: String)
signal season_completed(summary: Dictionary)

var current_season: SeasonData = null


func _ready() -> void:
	print("[SeasonManager] Initialized")


func initialize_season(prefecture: String, player_team: TeamData) -> void:
	if GameManager.current_career_phase != GameManager.CareerPhase.HIGH_SCHOOL:
		push_warning("[SeasonManager] Season system only available in HIGH_SCHOOL phase")
		return

	# Generate league teams using Japanese school generator
	var league_teams = JapaneseSchoolGenerator.generate_league_teams(prefecture, player_team, 10)

	# Find player team index in the generated list
	var player_idx = 0
	for i in range(league_teams.size()):
		if league_teams[i].id == player_team.id:
			player_idx = i
			break

	# Initialize season
	current_season = SeasonData.new()
	current_season.initialize(prefecture, _get_season_year(), player_team, league_teams.slice(1))

	print("[SeasonManager] Season initialized for %s Prefecture" % prefecture)
	season_initialized.emit(current_season)


func _get_season_year() -> int:
	# Use game date year if available
	if DesktopManager and DesktopManager.game_date:
		return DesktopManager.game_date.year
	return 2024


func get_current_phase() -> SeasonData.Phase:
	if current_season:
		return current_season.current_phase
	return SeasonData.Phase.PRE_SEASON


func get_current_competition_name() -> String:
	if current_season:
		return current_season.get_current_competition_name()
	return ""


func get_next_player_match() -> Dictionary:
	if current_season:
		return current_season.get_next_player_match()
	return {}


func get_match_type() -> String:
	if current_season:
		return current_season.get_match_type_for_phase()
	return "friendly"


func get_match_importance() -> float:
	if current_season:
		return current_season.get_match_importance_for_phase()
	return 1.0


func record_player_match_result(opponent_id: String, player_score: int, opponent_score: int, is_home: bool = true, extra_time: bool = false, penalties: bool = false, pen_player: int = 0, pen_opponent: int = 0) -> void:
	if not current_season:
		return

	var home_id: String
	var away_id: String
	var home_score: int
	var away_score: int

	if is_home:
		home_id = current_season.league.get_player_team_id() if current_season.league else ""
		away_id = opponent_id
		home_score = player_score
		away_score = opponent_score
	else:
		home_id = opponent_id
		away_id = current_season.league.get_player_team_id() if current_season.league else ""
		home_score = opponent_score
		away_score = player_score

	match current_season.current_phase:
		SeasonData.Phase.LEAGUE:
			_record_league_result(home_id, away_id, home_score, away_score)
		SeasonData.Phase.QUALIFIERS:
			_record_qualifier_result(home_id, away_id, home_score, away_score, extra_time, penalties, pen_player, pen_opponent, is_home)
		SeasonData.Phase.NATIONALS:
			_record_nationals_result(home_id, away_id, home_score, away_score, extra_time, penalties, pen_player, pen_opponent, is_home)

	# Check for phase transitions
	_check_phase_transition()


func _record_league_result(home_id: String, away_id: String, home_score: int, away_score: int) -> void:
	if current_season.league:
		current_season.league.record_result(home_id, away_id, home_score, away_score)
		league_standings_updated.emit(current_season.league.get_sorted_standings())


func _record_qualifier_result(home_id: String, away_id: String, home_score: int, away_score: int, extra_time: bool, penalties: bool, pen_player: int, pen_opponent: int, is_home: bool) -> void:
	if current_season.prefecture_qualifier:
		var pen_a = pen_player if is_home else pen_opponent
		var pen_b = pen_opponent if is_home else pen_player
		current_season.prefecture_qualifier.record_result(home_id, away_id, home_score, away_score, extra_time, penalties, pen_a, pen_b)
		tournament_bracket_updated.emit(current_season.prefecture_qualifier)


func _record_nationals_result(home_id: String, away_id: String, home_score: int, away_score: int, extra_time: bool, penalties: bool, pen_player: int, pen_opponent: int, is_home: bool) -> void:
	if current_season.national_championship:
		var pen_a = pen_player if is_home else pen_opponent
		var pen_b = pen_opponent if is_home else pen_player
		current_season.national_championship.record_result(home_id, away_id, home_score, away_score, extra_time, penalties, pen_a, pen_b)
		tournament_bracket_updated.emit(current_season.national_championship)


func simulate_cpu_matches_for_current_matchday() -> void:
	if not current_season:
		return

	var results: Array[Dictionary] = []

	match current_season.current_phase:
		SeasonData.Phase.LEAGUE:
			results = _simulate_league_cpu_matches()
		SeasonData.Phase.QUALIFIERS:
			results = _simulate_qualifier_cpu_matches()
		SeasonData.Phase.NATIONALS:
			results = _simulate_nationals_cpu_matches()

	if results.size() > 0:
		cpu_matches_simulated.emit(results)

	# Check for phase transitions after simulation
	_check_phase_transition()


func _simulate_league_cpu_matches() -> Array[Dictionary]:
	if not current_season.league:
		return []

	var cpu_fixtures = current_season.league.get_unplayed_cpu_fixtures_for_matchday(current_season.league.current_matchday)
	if cpu_fixtures.is_empty():
		return []

	# Build team lookup
	var teams_by_id: Dictionary = {}
	for team in current_season.league.teams:
		teams_by_id[team.id] = team

	var results = MatchSimulator.simulate_batch_league_matches(cpu_fixtures, teams_by_id)

	# Record results with goal events for stats tracking
	for result in results:
		current_season.league.record_result(
			result.home_team_id, result.away_team_id,
			result.home_score, result.away_score,
			result.get("home_goal_events", []),
			result.get("away_goal_events", [])
		)

	league_standings_updated.emit(current_season.league.get_sorted_standings())
	return results


func _simulate_qualifier_cpu_matches() -> Array[Dictionary]:
	if not current_season.prefecture_qualifier:
		return []

	var cpu_matches = current_season.prefecture_qualifier.get_unplayed_cpu_matches()
	if cpu_matches.is_empty():
		return []

	var teams_by_id: Dictionary = {}
	for team in current_season.prefecture_qualifier.teams:
		teams_by_id[team.id] = team

	var results = MatchSimulator.simulate_batch_knockout_matches(cpu_matches, teams_by_id)

	for result in results:
		current_season.prefecture_qualifier.record_result(
			result.home_team_id, result.away_team_id,
			result.home_score, result.away_score,
			result.extra_time, result.penalties,
			result.penalty_score_home, result.penalty_score_away
		)

	tournament_bracket_updated.emit(current_season.prefecture_qualifier)
	return results


func _simulate_nationals_cpu_matches() -> Array[Dictionary]:
	if not current_season.national_championship:
		return []

	var cpu_matches = current_season.national_championship.get_unplayed_cpu_matches()
	if cpu_matches.is_empty():
		return []

	var teams_by_id: Dictionary = {}
	for team in current_season.national_championship.teams:
		teams_by_id[team.id] = team

	var results = MatchSimulator.simulate_batch_knockout_matches(cpu_matches, teams_by_id)

	for result in results:
		current_season.national_championship.record_result(
			result.home_team_id, result.away_team_id,
			result.home_score, result.away_score,
			result.extra_time, result.penalties,
			result.penalty_score_home, result.penalty_score_away
		)

	tournament_bracket_updated.emit(current_season.national_championship)
	return results


func _check_phase_transition() -> void:
	if not current_season:
		return

	match current_season.current_phase:
		SeasonData.Phase.LEAGUE:
			if current_season.is_league_complete():
				_transition_to_qualifiers()
		SeasonData.Phase.QUALIFIERS:
			if current_season.is_qualifiers_complete():
				_handle_qualifier_completion()
		SeasonData.Phase.NATIONALS:
			if current_season.is_nationals_complete():
				_handle_nationals_completion()


func _transition_to_qualifiers() -> void:
	print("[SeasonManager] League complete, transitioning to qualifiers")

	# Compute and store league awards
	if current_season.league and current_season.league.player_stats:
		var total_matches = current_season.league.player_stats.get_total_matches_in_league(current_season.league.teams.size())
		var awards = current_season.league.player_stats.get_all_awards(total_matches)
		current_season.league.league_awards = awards
		print("[SeasonManager] League awards computed")

	# Check for league champion milestone
	if current_season.player_won_league():
		CareerManager._complete_milestone("prefecture_league_champion")
		print("[SeasonManager] Player won the prefecture league!")

	# Generate qualifier teams (all league teams plus additional)
	var player_team = current_season.league.get_player_team()
	var league_teams = current_season.league.teams.duplicate()
	var qualifier_teams = JapaneseSchoolGenerator.generate_qualifier_teams(current_season.prefecture, league_teams, 16)

	# Find player team index
	var player_idx = -1
	for i in range(qualifier_teams.size()):
		if qualifier_teams[i].id == player_team.id:
			player_idx = i
			break

	current_season.start_qualifiers(qualifier_teams, player_idx)
	phase_changed.emit(current_season.current_phase)


func _handle_qualifier_completion() -> void:
	if current_season.player_won_qualifiers():
		print("[SeasonManager] Player won qualifiers, advancing to nationals")
		CareerManager._complete_milestone("prefecture_qualifier_winner")
		_transition_to_nationals()
	else:
		print("[SeasonManager] Player eliminated from qualifiers")
		current_season.eliminated_from_qualifiers = true
		player_eliminated.emit("Prefecture Qualifier")

		# Season ends for player, but check if they still qualified via league
		if current_season.player_qualified_through_league():
			print("[SeasonManager] Player still qualified via league position")
			_transition_to_nationals()
		else:
			_end_season()


func _transition_to_nationals() -> void:
	print("[SeasonManager] Transitioning to National Championship")

	# Milestone for making it to nationals
	CareerManager._complete_milestone("national_participant")

	var player_team = current_season.league.get_player_team()
	var national_teams = JapaneseSchoolGenerator.generate_national_teams(player_team, 48)

	# Find player team index
	var player_idx = 0
	for i in range(national_teams.size()):
		if national_teams[i].id == player_team.id:
			player_idx = i
			break

	current_season.start_nationals(national_teams, player_idx)
	player_qualified_for_nationals.emit()
	phase_changed.emit(current_season.current_phase)


func _handle_nationals_completion() -> void:
	if current_season.player_won_nationals():
		print("[SeasonManager] Player won the National Championship!")
		# Record milestone
		CareerManager._complete_milestone("national_champion")
	else:
		print("[SeasonManager] Player eliminated from nationals")
		player_eliminated.emit("National Championship")

		# Record progress milestones
		_record_nationals_progress_milestones()

	_end_season()


func _record_nationals_progress_milestones() -> void:
	if not current_season.national_championship:
		return

	var stage = current_season.national_championship.current_stage
	match stage:
		TournamentData.Stage.QUARTER_FINAL, TournamentData.Stage.SEMI_FINAL:
			CareerManager._complete_milestone("national_quarter_finalist")
		TournamentData.Stage.FINAL:
			CareerManager._complete_milestone("national_semi_finalist")
			CareerManager._complete_milestone("national_finalist")


func _end_season() -> void:
	print("[SeasonManager] Season complete")
	current_season.advance_to_post_season()

	var summary = current_season.get_season_summary()
	season_completed.emit(summary)


func get_league_standings() -> Array[Dictionary]:
	if current_season and current_season.league:
		return current_season.league.get_sorted_standings()
	return []


func get_player_league_position() -> int:
	if current_season and current_season.league:
		return current_season.league.get_team_position(current_season.league.get_player_team_id())
	return -1


func get_current_tournament() -> TournamentData:
	if not current_season:
		return null

	match current_season.current_phase:
		SeasonData.Phase.QUALIFIERS:
			return current_season.prefecture_qualifier
		SeasonData.Phase.NATIONALS:
			return current_season.national_championship
		_:
			return null


func has_active_season() -> bool:
	return current_season != null and current_season.current_phase != SeasonData.Phase.POST_SEASON


func to_dict() -> Dictionary:
	return {
		"current_season": current_season.to_dict() if current_season else {}
	}


func from_dict(data: Dictionary) -> void:
	var season_data = data.get("current_season", {})
	if not season_data.is_empty():
		current_season = SeasonData.new()
		current_season.from_dict(season_data)
