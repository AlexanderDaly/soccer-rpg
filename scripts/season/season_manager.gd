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
var national_overlay: TournamentData = null
var national_overlay_competition: String = ""
var national_overlay_match_type: String = ""
var national_team: TeamData = null


func _ready() -> void:
	print("[SeasonManager] Initialized")


func initialize_season(prefecture: String, player_team: TeamData) -> void:
	if not player_team:
		push_warning("[SeasonManager] Cannot initialize season without player team")
		return
	var season_year = _get_season_year()
	match GameManager.current_career_phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			_initialize_high_school_season(prefecture, player_team, season_year)
		GameManager.CareerPhase.YOUTH_ACADEMY:
			_initialize_club_season("youth_academy", player_team, season_year, CareerManager.get_team_pool("youth"), player_team.league if not player_team.league.is_empty() else "Youth Elite")
		GameManager.CareerPhase.PRO_CAREER:
			_initialize_club_season("pro_career", player_team, season_year, CareerManager.get_team_pool("pro"), player_team.league if not player_team.league.is_empty() else "Division One")
		_:
			push_warning("[SeasonManager] Unsupported primary phase for season init")
			return

	_refresh_national_overlay()
	season_initialized.emit(current_season)


func _get_season_year() -> int:
	# Use game date year if available
	if DesktopManager and DesktopManager.game_date:
		return DesktopManager.game_date.year
	return 2024


func _process_pre_season_roster_changes(season_year: int, player_team: TeamData) -> void:
	"""Process roster changes at the start of a new season."""
	print("[SeasonManager] Processing pre-season roster changes for year %d" % season_year)

	# 1. Process graduations - 3rd years move on
	var graduated = NpcRegistry.process_graduations(season_year)
	if graduated.size() > 0:
		print("[SeasonManager] %d players graduated" % graduated.size())
		# Show notification about graduating senpai
		if DesktopManager and graduated.size() > 0:
			var senpai_names: Array[String] = []
			for npc in graduated.slice(0, 3):  # Show max 3 names
				senpai_names.append(npc.get("name", "Unknown"))
			if graduated.size() > 3:
				senpai_names.append("and %d more..." % (graduated.size() - 3))
			DesktopManager.show_notification(
				"Graduation Ceremony",
				"Farewell to our senpai: %s" % ", ".join(senpai_names),
				"", ""
			)

	# 2. Promote remaining players to next school year
	NpcRegistry.promote_school_years()

	# 3. Trigger persona evolutions for promotions
	if player_team:
		var team_npcs = NpcRegistry.get_team_npcs(player_team.id)
		PersonaManager.evolve_personas_for_school_year_promotion(team_npcs)

	# 4. Generate new 1st-year players to fill roster gaps
	_generate_new_first_years(player_team)


func _generate_new_first_years(player_team: TeamData) -> void:
	"""Generate new 1st-year players to replace graduated seniors."""
	if not player_team:
		return

	# Count current active players
	var active_npcs = NpcRegistry.get_active_team_npcs(player_team.id)
	var target_squad_size = 10  # Standard squad size
	var new_players_needed = target_squad_size - active_npcs.size()

	if new_players_needed <= 0:
		return

	print("[SeasonManager] Generating %d new first-year players" % new_players_needed)

	# Determine positions needed (basic distribution)
	var positions_pool = ["GK", "CB", "FB", "CDM", "CM", "CAM", "WNG", "ST"]
	var season_year = _get_season_year()

	for i in range(new_players_needed):
		var pos = positions_pool[randi() % positions_pool.size()]
		var pos_index = _get_next_position_index(player_team.id, pos)

		# Create new 1st-year player data
		var npc_data = {
			"name": _generate_japanese_name(),
			"position": pos,
			"stats": StatSystem.generate_npc_stats(pos, 1),
			"school_year": 1,
			"status": "active",
			"graduation_year": season_year + 2,
			"form": ["average", "average", "good"][randi() % 3],
			"personality": ["eager", "hardworker", "shy", "energetic"][randi() % 4],
			"team_name": player_team.name,
			"team_id": player_team.id
		}
		npc_data["overall"] = StatSystem.calculate_overall(npc_data.stats, pos)

		# Register the new player
		var new_npc = NpcRegistry.get_or_create_npc(player_team.id, pos, pos_index, npc_data, false)

		# Add to team's player list
		player_team.players.append(new_npc)

	if DesktopManager and new_players_needed > 0:
		DesktopManager.show_notification(
			"New Recruits",
			"%d first-year students joined the team!" % new_players_needed,
			"", ""
		)


func _get_next_position_index(team_id: String, position: String) -> int:
	"""Get the next available index for a position on a team."""
	var team_npcs = NpcRegistry.get_team_npcs(team_id)
	var max_index = -1

	for npc in team_npcs:
		var npc_id = npc.get("id", "")
		if "_%s_" % position in npc_id:
			# Extract index from ID format: npc_{team}_{pos}_{index}
			var parts = npc_id.split("_")
			if parts.size() >= 4:
				var idx = int(parts[-1])
				if idx > max_index:
					max_index = idx

	return max_index + 1


func _generate_japanese_name() -> String:
	"""Generate a random Japanese name for new students."""
	var first_names = ["Yuki", "Haruto", "Sota", "Ren", "Kaito", "Takumi", "Ryota", "Kenta", "Daiki", "Shota",
		"Hayato", "Riku", "Yuto", "Taiga", "Hinata", "Sora", "Asahi", "Minato", "Yamato", "Itsuki"]
	var last_names = ["Tanaka", "Yamamoto", "Suzuki", "Sato", "Watanabe", "Ito", "Nakamura", "Kobayashi", "Kato", "Yoshida",
		"Takahashi", "Saito", "Matsumoto", "Inoue", "Kimura", "Shimizu", "Yamaguchi", "Hayashi", "Sasaki", "Mori"]

	return "%s %s" % [last_names[randi() % last_names.size()], first_names[randi() % first_names.size()]]


func _initialize_high_school_season(prefecture: String, player_team: TeamData, season_year: int) -> void:
	# Ensure player team has a stable ID before any roster changes or registry usage
	if player_team.id.begins_with("team_") and player_team.id.length() < 15:
		player_team.set_stable_id(player_team.name, prefecture)

	var season_id = "%s_%d" % [prefecture, season_year]
	NpcRegistry.set_current_season(season_id)

	var league_teams = JapaneseSchoolGenerator.generate_league_teams(prefecture, player_team, 10)
	_process_pre_season_roster_changes(season_year, player_team)

	current_season = SeasonData.new()
	current_season.initialize(prefecture, season_year, player_team, league_teams.slice(1), "high_school")

	print("[SeasonManager] Season initialized for %s Prefecture" % prefecture)


func _initialize_club_season(kind: String, player_team: TeamData, season_year: int, team_pool: Array[Dictionary], default_league_name: String) -> void:
	if player_team.players.is_empty():
		player_team.generate_teammates(10, GameManager.current_career_phase, false)

	var other_teams: Array[TeamData] = []
	for team_info in team_pool:
		if team_info.get("id", "") == player_team.id:
			continue
		other_teams.append(CareerManager.create_team_from_catalog(team_info, GameManager.current_career_phase))
		if other_teams.size() >= 9:
			break

	current_season = SeasonData.new()
	current_season.initialize(default_league_name, season_year, player_team, other_teams, kind, default_league_name)
	print("[SeasonManager] Club season initialized for %s" % player_team.name)


func _refresh_national_overlay() -> void:
	if national_overlay and not national_overlay.is_complete and not national_overlay.player_eliminated:
		if GameManager.current_national_phase == GameManager.NationalPhase.U20_QUALIFIERS and national_overlay_match_type == "qualifier":
			return
		if GameManager.current_national_phase == GameManager.NationalPhase.U20_WORLD_CUP and national_overlay_match_type == "world_cup":
			return

	national_overlay = null
	national_overlay_competition = ""
	national_overlay_match_type = ""
	national_team = null

	if not GameManager.player_data:
		return
	if GameManager.current_national_phase == GameManager.NationalPhase.NONE:
		return
	if GameManager.player_data.age > 20 or CareerManager.reputation < 40:
		GameManager.set_national_phase(GameManager.NationalPhase.NONE)
		return

	var pool_id = "u20_qualifiers"
	var tournament_name = "U20 Continental Qualifiers"
	var tournament_type = TournamentData.TournamentType.PREFECTURE_QUALIFIER
	var match_type = "qualifier"

	if GameManager.current_national_phase == GameManager.NationalPhase.U20_WORLD_CUP:
		pool_id = "u20_world_cup"
		tournament_name = "U20 World Cup"
		tournament_type = TournamentData.TournamentType.NATIONAL_CHAMPIONSHIP
		match_type = "world_cup"

	var player_national_team = TeamData.new()
	player_national_team.id = "u20_%s_player" % GameManager.player_data.nationality.to_lower()
	player_national_team.name = "%s U20" % GameManager.player_data.nationality
	player_national_team.short_name = GameManager.player_data.nationality
	player_national_team.league = tournament_name
	player_national_team.tier = 3
	player_national_team.formation = "4-3-3"
	player_national_team.generate_teammates(10, GameManager.CareerPhase.PRO_CAREER, false)
	national_team = player_national_team

	var teams: Array[TeamData] = [player_national_team]
	for team_info in CareerManager.get_team_pool(pool_id):
		if team_info.get("name", "") == player_national_team.name:
			continue
		teams.append(CareerManager.create_team_from_catalog(team_info, GameManager.CareerPhase.PRO_CAREER))

	national_overlay = TournamentData.new()
	national_overlay.initialize(tournament_name, teams, 0, tournament_type)
	national_overlay_competition = tournament_name
	national_overlay_match_type = match_type


func get_current_phase() -> SeasonData.Phase:
	if current_season:
		return current_season.current_phase
	return SeasonData.Phase.PRE_SEASON


func get_current_competition_name() -> String:
	var next_fixture = get_next_fixture()
	if not next_fixture.is_empty():
		return str(next_fixture.get("competition", ""))
	return current_season.get_current_competition_name() if current_season else national_overlay_competition


func get_next_player_match() -> Dictionary:
	return get_next_fixture()


func get_match_type() -> String:
	var next_fixture = get_next_fixture()
	return str(next_fixture.get("type", "friendly"))


func get_match_importance() -> float:
	var match_type = get_match_type()
	match match_type:
		"league":
			return 1.0
		"cup", "prefecture_qualifier":
			return 1.5
		"national_championship":
			return 1.8
		"qualifier":
			return 1.8
		"world_cup":
			return 2.5
		"world_cup_final", "national_final":
			return 3.0
		_:
			return current_season.get_match_importance_for_phase() if current_season else 1.0


func get_upcoming_fixtures(limit: int = -1, include_played: bool = true) -> Array[Dictionary]:
	var fixtures: Array[Dictionary] = []

	if current_season and current_season.league:
		for fixture in current_season.league.get_all_player_fixtures():
			if not include_played and fixture.get("played", false):
				continue
			fixtures.append(_build_league_fixture_display(fixture, current_season.league, "league"))

	if current_season and current_season.current_phase in [SeasonData.Phase.QUALIFIERS, SeasonData.Phase.NATIONALS]:
		var tournament = current_season.prefecture_qualifier if current_season.current_phase == SeasonData.Phase.QUALIFIERS else current_season.national_championship
		var competition = current_season.get_current_competition_name()
		var match_type = current_season.get_match_type_for_phase()
		var tournament_fixture = _build_tournament_fixture_display(tournament, competition, match_type, current_season.league.get_player_team() if current_season.league else GameManager.current_team)
		if not tournament_fixture.is_empty():
			fixtures.append(tournament_fixture)

	if national_overlay:
		var overlay_fixture = _build_tournament_fixture_display(national_overlay, national_overlay_competition, national_overlay_match_type, national_team)
		if not overlay_fixture.is_empty():
			fixtures.append(overlay_fixture)

	fixtures.sort_custom(_sort_fixture_display)

	if limit > 0 and fixtures.size() > limit:
		return fixtures.slice(0, limit)
	return fixtures


func get_next_fixture() -> Dictionary:
	var fixtures = get_upcoming_fixtures(-1, false)
	for fixture in fixtures:
		if not fixture.get("played", false):
			return fixture
	return {}


func record_fixture_result(opponent_id: String, player_score: int, opponent_score: int, is_home: bool = true, extra_time: bool = false, penalties: bool = false, pen_player: int = 0, pen_opponent: int = 0, player_goal_events: Array = [], opponent_goal_events: Array = [], home_fouls: int = 0, away_fouls: int = 0) -> void:
	record_player_match_result(opponent_id, player_score, opponent_score, is_home, extra_time, penalties, pen_player, pen_opponent, player_goal_events, opponent_goal_events, home_fouls, away_fouls)


func record_player_match_result(opponent_id: String, player_score: int, opponent_score: int, is_home: bool = true, extra_time: bool = false, penalties: bool = false, pen_player: int = 0, pen_opponent: int = 0, player_goal_events: Array = [], opponent_goal_events: Array = [], home_fouls: int = 0, away_fouls: int = 0) -> void:
	if not current_season and not national_overlay:
		return

	if _is_current_match_national_overlay():
		_record_overlay_result(opponent_id, player_score, opponent_score, extra_time, penalties, pen_player, pen_opponent)
		_process_post_match_injury_recovery()
		_check_national_overlay_transition()
		return

	var home_id: String
	var away_id: String
	var home_score: int
	var away_score: int
	var home_events: Array
	var away_events: Array

	if is_home:
		home_id = current_season.league.get_player_team_id() if current_season.league else ""
		away_id = opponent_id
		home_score = player_score
		away_score = opponent_score
		home_events = player_goal_events
		away_events = opponent_goal_events
	else:
		home_id = opponent_id
		away_id = current_season.league.get_player_team_id() if current_season.league else ""
		home_score = opponent_score
		away_score = player_score
		home_events = opponent_goal_events
		away_events = player_goal_events

	match current_season.current_phase:
		SeasonData.Phase.LEAGUE:
			_record_league_result(home_id, away_id, home_score, away_score, home_events, away_events, home_fouls, away_fouls)
		SeasonData.Phase.QUALIFIERS:
			_record_qualifier_result(home_id, away_id, home_score, away_score, extra_time, penalties, pen_player, pen_opponent, is_home)
		SeasonData.Phase.NATIONALS:
			_record_nationals_result(home_id, away_id, home_score, away_score, extra_time, penalties, pen_player, pen_opponent, is_home)

	# Process injury recovery after each match
	_process_post_match_injury_recovery()

	# Check for phase transitions
	_check_phase_transition()


func _process_post_match_injury_recovery() -> void:
	"""Process injury recovery after a match."""
	var recovered = NpcRegistry.process_injury_recovery()
	var player_recovered = false
	if GameManager.player_data:
		player_recovered = GameManager.player_data.process_match_recovery()

	if recovered.size() > 0:
		print("[SeasonManager] %d players recovered from injury" % recovered.size())

		# Notify about recovered players (for player's team)
		var player_team_id = ""
		if GameManager.current_team:
			player_team_id = GameManager.current_team.id

		for npc_id in recovered:
			var npc = NpcRegistry.get_npc(npc_id)
			if npc.get("stable_team_id", "") == player_team_id or npc.get("team_id", "") == player_team_id:
				var npc_name = npc.get("name", "A player")
				if DesktopManager:
					DesktopManager.show_notification(
						"Player Recovered",
						"%s is back from injury!" % npc_name,
						"", ""
					)

				# Check if this was a severe injury for persona evolution
				# The injury data would have been cleared, so we track it via career events
				var career_events = npc.get("career_events", [])
				var had_severe_injury = false
				for event in career_events:
					if event.begins_with("severe_injury_"):
						had_severe_injury = true
						break

				if had_severe_injury:
					PersonaManager.evolve_persona_for_event(npc_id, "survived_major_injury")

	if player_recovered and DesktopManager and GameManager.player_data:
		DesktopManager.show_notification(
			"Player Recovered",
			"%s is fit again." % GameManager.player_data.name,
			"", ""
		)


func _record_league_result(home_id: String, away_id: String, home_score: int, away_score: int, home_events: Array = [], away_events: Array = [], home_fouls: int = 0, away_fouls: int = 0) -> void:
	if current_season.league:
		current_season.league.record_result(home_id, away_id, home_score, away_score, home_events, away_events, home_fouls, away_fouls)
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
	if _is_current_match_national_overlay():
		var overlay_results = _simulate_overlay_cpu_matches()
		if overlay_results.size() > 0:
			cpu_matches_simulated.emit(overlay_results)
		_check_national_overlay_transition()
		return

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


func _simulate_overlay_cpu_matches() -> Array[Dictionary]:
	if not national_overlay:
		return []

	var cpu_matches = national_overlay.get_unplayed_cpu_matches()
	if cpu_matches.is_empty():
		return []

	var teams_by_id: Dictionary = {}
	for team in national_overlay.teams:
		teams_by_id[team.id] = team

	var importance = 2.0 if national_overlay_match_type == "world_cup" else 1.8
	var results = MatchSimulator.simulate_batch_knockout_matches(cpu_matches, teams_by_id, importance)
	for result in results:
		national_overlay.record_result(
			result.home_team_id, result.away_team_id,
			result.home_score, result.away_score,
			result.extra_time, result.penalties,
			result.penalty_score_home, result.penalty_score_away
		)

	tournament_bracket_updated.emit(national_overlay)
	return results


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

	var importance = get_match_importance()
	var results = MatchSimulator.simulate_batch_league_matches(cpu_fixtures, teams_by_id, current_season.league, importance)

	# Record results with goal events for stats tracking
	for result in results:
		current_season.league.record_result(
			result.home_team_id, result.away_team_id,
			result.home_score, result.away_score,
			result.get("home_goal_events", []),
			result.get("away_goal_events", []),
			result.get("home_fouls", 0),
			result.get("away_fouls", 0)
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

	var importance = get_match_importance()
	var results = MatchSimulator.simulate_batch_knockout_matches(cpu_matches, teams_by_id, importance)

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

	var importance = get_match_importance()
	var results = MatchSimulator.simulate_batch_knockout_matches(cpu_matches, teams_by_id, importance)

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

		# Notify about award winners
		_notify_award_winners(awards)

	# Check for league champion milestone
	if current_season.player_won_league():
		CareerManager.award_milestone("prefecture_league_champion", {"source": "season_progress"})
		print("[SeasonManager] Player won the prefecture league!")

	var player_team = current_season.league.get_player_team()
	var qualifier_teams: Array[TeamData] = []
	var tournament_name = "%s Prefecture Qualifier" % current_season.prefecture

	if current_season.season_kind == "high_school":
		var league_teams = current_season.league.teams.duplicate()
		qualifier_teams = JapaneseSchoolGenerator.generate_qualifier_teams(current_season.prefecture, league_teams, 16)
	else:
		tournament_name = "Youth Cup" if current_season.season_kind == "youth_academy" else "Domestic Cup"
		qualifier_teams = current_season.league.teams.duplicate()
		while qualifier_teams.size() < 16:
			var pool_id = "youth" if current_season.season_kind == "youth_academy" else "pro"
			for team_info in CareerManager.get_team_pool(pool_id):
				if qualifier_teams.size() >= 16:
					break
				if team_info.get("id", "") == player_team.id:
					continue
				qualifier_teams.append(CareerManager.create_team_from_catalog(team_info, GameManager.current_career_phase))

	# Find player team index
	var player_idx = -1
	for i in range(qualifier_teams.size()):
		if qualifier_teams[i].id == player_team.id:
			player_idx = i
			break

	# Validate player team was found in qualifier teams
	if player_idx == -1:
		push_error("[SeasonManager] Player team not found in qualifier teams!")
		# Add player team to qualifiers if missing
		qualifier_teams.append(player_team)
		player_idx = qualifier_teams.size() - 1

	current_season.start_qualifiers(qualifier_teams, player_idx, tournament_name)
	phase_changed.emit(current_season.current_phase)


func _handle_qualifier_completion() -> void:
	if current_season.season_kind != "high_school":
		if current_season.prefecture_qualifier and current_season.prefecture_qualifier.player_won_tournament():
			var trophies = CareerManager.career_stats.get("trophies", []).duplicate()
			trophies.append(current_season.prefecture_qualifier.name)
			CareerManager.career_stats["trophies"] = trophies
		_end_season()
		return

	if current_season.player_won_qualifiers():
		print("[SeasonManager] Player won qualifiers, advancing to nationals")
		CareerManager.award_milestone("prefecture_qualifier_winner", {"source": "season_progress"})
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
	CareerManager.award_milestone("national_participant", {"source": "season_progress"})

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
		CareerManager.award_milestone("national_champion", {"source": "season_progress"})
	else:
		print("[SeasonManager] Player eliminated from nationals")
		player_eliminated.emit("National Championship")

		# Record progress milestones
		_record_nationals_progress_milestones()

	_end_season()


func _record_nationals_progress_milestones() -> void:
	if not current_season.national_championship:
		return

	# current_stage is the stage where the player lost
	# Award milestones for all stages reached (if you made the final, you also made semis and quarters)
	var stage = current_season.national_championship.current_stage
	match stage:
		TournamentData.Stage.QUARTER_FINAL:
			# Lost in quarter finals = made quarter finals
			CareerManager.award_milestone("national_quarter_finalist", {"source": "season_progress"})
		TournamentData.Stage.SEMI_FINAL:
			# Lost in semi finals = made quarters and semis
			CareerManager.award_milestone("national_quarter_finalist", {"source": "season_progress"})
			CareerManager.award_milestone("national_semi_finalist", {"source": "season_progress"})
		TournamentData.Stage.FINAL:
			# Lost in final = made quarters, semis, and final
			CareerManager.award_milestone("national_quarter_finalist", {"source": "season_progress"})
			CareerManager.award_milestone("national_semi_finalist", {"source": "season_progress"})
			CareerManager.award_milestone("national_finalist", {"source": "season_progress"})


func _end_season() -> void:
	print("[SeasonManager] Season complete")
	if current_season:
		current_season.advance_to_post_season()

	var summary = current_season.get_season_summary() if current_season else {}
	summary["competition_name"] = current_season.get_current_competition_name() if current_season else ""
	summary["season_kind"] = current_season.season_kind if current_season else ""
	season_completed.emit(summary)


func _is_current_match_national_overlay() -> bool:
	if not national_overlay or not GameManager.current_match:
		return false
	return GameManager.current_match.get_player_team().id == national_team.id if national_team else false


func _record_overlay_result(opponent_id: String, player_score: int, opponent_score: int, extra_time: bool, penalties: bool, pen_player: int, pen_opponent: int) -> void:
	if not national_overlay or not national_team:
		return

	national_overlay.record_result(
		national_team.id,
		opponent_id,
		player_score,
		opponent_score,
		extra_time,
		penalties,
		pen_player,
		pen_opponent
	)
	tournament_bracket_updated.emit(national_overlay)
	if "u20_debut" not in CareerManager.completed_milestones:
		CareerManager.award_milestone("u20_debut", {"source": "overlay_match"})


func _check_national_overlay_transition() -> void:
	if not national_overlay or not national_overlay.is_complete:
		return

	if GameManager.current_national_phase == GameManager.NationalPhase.U20_QUALIFIERS and national_overlay.player_won_tournament():
		GameManager.set_national_phase(GameManager.NationalPhase.U20_WORLD_CUP)
		_refresh_national_overlay()
	elif GameManager.current_national_phase == GameManager.NationalPhase.U20_WORLD_CUP:
		GameManager.set_national_phase(GameManager.NationalPhase.NONE)
		national_overlay = null
		national_overlay_competition = ""
		national_overlay_match_type = ""
		national_team = null
	else:
		GameManager.set_national_phase(GameManager.NationalPhase.NONE)
		national_overlay = null
		national_overlay_competition = ""
		national_overlay_match_type = ""
		national_team = null


func _build_league_fixture_display(fixture: Dictionary, league: LeagueData, match_type: String) -> Dictionary:
	var player_id = league.get_player_team_id()
	var opponent_id = fixture.get("away_id", "") if fixture.get("home_id", "") == player_id else fixture.get("home_id", "")
	var opponent_team = league.get_team_by_id(opponent_id)
	var opponent_name = fixture.get("away_team_name", "") if fixture.get("home_id", "") == player_id else fixture.get("home_team_name", "")
	return {
		"fixture_id": fixture.get("match_id", ""),
		"matchday": fixture.get("matchday", 0),
		"match_date": fixture.get("match_date", {}),
		"opponent": {"name": opponent_name, "team_data": opponent_team},
		"player_team": league.get_player_team(),
		"is_home": fixture.get("home_id", "") == player_id,
		"type": match_type,
		"competition": league.name,
		"played": fixture.get("played", false),
		"result": _get_fixture_result(fixture, player_id) if fixture.get("played", false) else "",
		"from_season": true
	}


func _build_tournament_fixture_display(tournament: TournamentData, competition: String, match_type: String, player_team: TeamData) -> Dictionary:
	if not tournament or not player_team:
		return {}
	var next_match = tournament.get_next_player_match()
	if next_match.is_empty():
		return {}

	var player_id = player_team.id
	var opponent_id = next_match.get("team_b_id", "") if next_match.get("team_a_id", "") == player_id else next_match.get("team_a_id", "")
	var opponent_team = tournament.get_team_by_id(opponent_id)
	var opponent_name = next_match.get("team_b_name", "") if next_match.get("team_a_id", "") == player_id else next_match.get("team_a_name", "")
	var is_home = next_match.get("team_a_id", "") == player_id

	return {
		"fixture_id": next_match.get("match_id", ""),
		"matchday": 0,
		"match_date": _date_in_days(3),
		"opponent": {"name": opponent_name, "team_data": opponent_team},
		"player_team": player_team,
		"is_home": is_home,
		"type": match_type,
		"competition": competition,
		"played": false,
		"result": "",
		"stage": tournament.get_current_stage_name(),
		"from_season": true
	}


func _sort_fixture_display(a: Dictionary, b: Dictionary) -> bool:
	return _fixture_sort_value(a.get("match_date", {})) < _fixture_sort_value(b.get("match_date", {}))


func _fixture_sort_value(date: Dictionary) -> int:
	return int(date.get("year", 0)) * 10000 + int(date.get("month", 0)) * 100 + int(date.get("day", 0))


func _date_in_days(days: int) -> Dictionary:
	var date = DesktopManager.game_date.duplicate(true) if DesktopManager and DesktopManager.game_date else {"year": 2024, "month": 4, "day": 1}
	date["day"] = int(date.get("day", 1)) + days
	while int(date.get("day", 1)) > 30:
		date["day"] = int(date.get("day", 1)) - 30
		date["month"] = int(date.get("month", 1)) + 1
	while int(date.get("month", 1)) > 12:
		date["month"] = int(date.get("month", 1)) - 12
		date["year"] = int(date.get("year", 2024)) + 1
	return date


func _get_fixture_result(fixture: Dictionary, player_id: String) -> String:
	var player_score: int
	var opponent_score: int

	if fixture.get("home_id", "") == player_id:
		player_score = int(fixture.get("home_score", 0))
		opponent_score = int(fixture.get("away_score", 0))
	else:
		player_score = int(fixture.get("away_score", 0))
		opponent_score = int(fixture.get("home_score", 0))

	if player_score > opponent_score:
		return "W %d-%d" % [player_score, opponent_score]
	if player_score < opponent_score:
		return "L %d-%d" % [player_score, opponent_score]
	return "D %d-%d" % [player_score, opponent_score]


func _is_valid_award_winner(award: Variant) -> bool:
	# Validate award winner dictionary has required fields
	if not award is Dictionary:
		return false
	if award.is_empty():
		return false
	# Must have at least a name to display
	var name = award.get("name", "")
	return not name.is_empty() if name is String else false


func _notify_award_winners(awards: Dictionary) -> void:
	var player_id = ""
	if GameManager.player_data:
		player_id = GameManager.player_data.id

	# Golden Boot
	var golden_boot = awards.get("golden_boot", {})
	if _is_valid_award_winner(golden_boot):
		var is_player = golden_boot.get("player_id", "") == player_id
		var winner_id = golden_boot.get("player_id", "")
		var winner_name = str(golden_boot.get("name", "Unknown"))
		var goals = int(golden_boot.get("goals", 0))
		var title = "Golden Boot Winner!" if is_player else "Golden Boot: %s" % winner_name
		var msg = "%d goals" % goals
		if is_player:
			msg = "Congratulations! You won with " + msg
			CareerManager.record_season_award("golden_boot", goals)
		else:
			# Evolve NPC persona for winning award
			PersonaManager.evolve_persona_for_event(winner_id, "won_golden_boot")
		DesktopManager.show_notification(title, msg, "", "")

	# Top Assister
	var top_assister = awards.get("top_assister", {})
	if _is_valid_award_winner(top_assister):
		var is_player = top_assister.get("player_id", "") == player_id
		var winner_id = top_assister.get("player_id", "")
		var winner_name = str(top_assister.get("name", "Unknown"))
		var assists = int(top_assister.get("assists", 0))
		var title = "Playmaker Award!" if is_player else "Playmaker: %s" % winner_name
		var msg = "%d assists" % assists
		if is_player:
			msg = "Congratulations! You won with " + msg
			CareerManager.record_season_award("playmaker_award", assists)
		else:
			# Evolve NPC persona for winning award
			PersonaManager.evolve_persona_for_event(winner_id, "won_playmaker_award")
		DesktopManager.show_notification(title, msg, "", "")

	# Golden Glove
	var golden_glove = awards.get("golden_glove", {})
	if _is_valid_award_winner(golden_glove):
		var is_player = golden_glove.get("player_id", "") == player_id
		var winner_id = golden_glove.get("player_id", "")
		var winner_name = str(golden_glove.get("name", "Unknown"))
		var clean_sheets = int(golden_glove.get("clean_sheets", 0))
		var title = "Golden Glove Winner!" if is_player else "Golden Glove: %s" % winner_name
		var msg = "%d clean sheets" % clean_sheets
		if is_player:
			msg = "Congratulations! You won with " + msg
			CareerManager.record_season_award("golden_glove", clean_sheets)
		else:
			# Evolve NPC persona for winning award
			PersonaManager.evolve_persona_for_event(winner_id, "won_golden_glove")
		DesktopManager.show_notification(title, msg, "", "")


func get_league_standings() -> Array[Dictionary]:
	if current_season and current_season.league:
		return current_season.league.get_sorted_standings()
	return []


func get_player_league_position() -> int:
	if current_season and current_season.league:
		return current_season.league.get_team_position(current_season.league.get_player_team_id())
	return -1


func get_current_tournament() -> TournamentData:
	if _is_current_match_national_overlay():
		return national_overlay
	if not current_season:
		return national_overlay

	match current_season.current_phase:
		SeasonData.Phase.QUALIFIERS:
			return current_season.prefecture_qualifier
		SeasonData.Phase.NATIONALS:
			return current_season.national_championship
		_:
			return null


func has_active_season() -> bool:
	var primary_active = current_season != null and current_season.current_phase != SeasonData.Phase.POST_SEASON
	var overlay_active = national_overlay != null and not national_overlay.is_complete and not national_overlay.player_eliminated
	return primary_active or overlay_active


func to_dict() -> Dictionary:
	return {
		"current_season": current_season.to_dict() if current_season else {},
		"national_overlay": national_overlay.to_dict() if national_overlay else {},
		"national_overlay_competition": national_overlay_competition,
		"national_overlay_match_type": national_overlay_match_type,
		"national_team": national_team.to_dict() if national_team else {}
	}


func from_dict(data: Dictionary) -> void:
	var season_data = data.get("current_season", {})
	if not season_data.is_empty():
		current_season = SeasonData.new()
		current_season.from_dict(season_data)
	else:
		current_season = null

	var overlay_data = data.get("national_overlay", {})
	if not overlay_data.is_empty():
		national_overlay = TournamentData.new()
		national_overlay.from_dict(overlay_data)
	else:
		national_overlay = null

	national_overlay_competition = data.get("national_overlay_competition", "")
	national_overlay_match_type = data.get("national_overlay_match_type", "")
	var national_team_data = data.get("national_team", {})
	if not national_team_data.is_empty():
		national_team = TeamData.new()
		national_team.from_dict(national_team_data)
	else:
		national_team = null
