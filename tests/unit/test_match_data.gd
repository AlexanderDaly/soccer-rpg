extends GutTest
## Unit tests for position-aware MatchData ratings


func test_calculate_match_rating_striker_favors_scoring() -> void:
	var scoring_match = _make_match("ST", 2, 1)
	scoring_match.player_stats.goals = 1
	scoring_match.player_stats.shots = 4
	scoring_match.player_stats.shots_on_target = 2
	scoring_match.player_stats.passes_attempted = 12
	scoring_match.player_stats.passes_completed = 8
	scoring_match.player_stats.dribbles_attempted = 3
	scoring_match.player_stats.dribbles_completed = 2

	var link_up_match = _make_match("ST", 2, 1)
	link_up_match.player_stats.passes_attempted = 34
	link_up_match.player_stats.passes_completed = 31
	link_up_match.player_stats.tackles_attempted = 4
	link_up_match.player_stats.tackles_won = 3

	assert_gt(
		scoring_match.calculate_match_rating(),
		link_up_match.calculate_match_rating(),
		"Striker rating should reward direct scoring output over safe circulation"
	)


func test_calculate_match_rating_cm_favors_build_up() -> void:
	var playmaker_match = _make_match("CM", 1, 0)
	playmaker_match.player_stats.assists = 1
	playmaker_match.player_stats.passes_attempted = 38
	playmaker_match.player_stats.passes_completed = 33
	playmaker_match.player_stats.tackles_attempted = 5
	playmaker_match.player_stats.tackles_won = 4
	playmaker_match.player_stats.dribbles_attempted = 3
	playmaker_match.player_stats.dribbles_completed = 2

	var poacher_match = _make_match("CM", 1, 0)
	poacher_match.player_stats.goals = 1
	poacher_match.player_stats.shots = 4
	poacher_match.player_stats.shots_on_target = 2
	poacher_match.player_stats.passes_attempted = 12
	poacher_match.player_stats.passes_completed = 7

	assert_gt(
		playmaker_match.calculate_match_rating(),
		poacher_match.calculate_match_rating(),
		"Central midfield rating should prioritize playmaking and ball-winning"
	)


func test_calculate_match_rating_cb_favors_defending_and_clean_sheet() -> void:
	var defensive_match = _make_match("CB", 1, 0)
	defensive_match.player_stats.passes_attempted = 28
	defensive_match.player_stats.passes_completed = 24
	defensive_match.player_stats.tackles_attempted = 7
	defensive_match.player_stats.tackles_won = 5

	var attacking_match = _make_match("CB", 2, 1)
	attacking_match.player_stats.goals = 1
	attacking_match.player_stats.shots = 2
	attacking_match.player_stats.shots_on_target = 1
	attacking_match.player_stats.tackles_attempted = 1
	attacking_match.player_stats.tackles_won = 0

	assert_gt(
		defensive_match.calculate_match_rating(),
		attacking_match.calculate_match_rating(),
		"Center-back rating should value defending and clean sheets over poaching"
	)


func test_calculate_match_rating_goalkeeper_penalizes_conceding() -> void:
	var clean_sheet_match = _make_match("GK", 1, 0)
	clean_sheet_match.player_stats.passes_attempted = 24
	clean_sheet_match.player_stats.passes_completed = 20

	var conceded_match = _make_match("GK", 1, 3)
	conceded_match.player_stats.passes_attempted = 24
	conceded_match.player_stats.passes_completed = 20

	assert_gt(
		clean_sheet_match.calculate_match_rating(),
		conceded_match.calculate_match_rating(),
		"Goalkeeper rating should fall sharply when conceding multiple goals"
	)


func test_generate_result_includes_competition_and_absence_fields() -> void:
	var match = _make_match("CM", 1, 1)
	match.competition_name = "Kanagawa Premier"
	match.competition_key = "league::kanagawa_premier"
	match.did_not_play = true
	match.absence_reason = "suspended"
	match.absence_detail = "Suspended for this fixture."

	var result = match.generate_result()

	assert_eq(result.get("competition_name", ""), "Kanagawa Premier")
	assert_eq(result.get("competition_key", ""), "league::kanagawa_premier")
	assert_true(result.get("did_not_play", false))
	assert_eq(result.get("absence_reason", ""), "suspended")


func _make_match(position: String, home_score: int, away_score: int) -> MatchData:
	var match = MatchData.new()
	match.player_position = position
	match.is_home = true
	match.home_score = home_score
	match.away_score = away_score
	match.home_team = TeamData.new()
	match.home_team.id = "home_team"
	match.home_team.name = "Home FC"
	match.away_team = TeamData.new()
	match.away_team.id = "away_team"
	match.away_team.name = "Away FC"
	return match
