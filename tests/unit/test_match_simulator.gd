extends GutTest
## Unit tests for MatchSimulator


func before_each() -> void:
	seed(1234)
	if GameManager:
		GameManager.player_data = null


func test_simulate_league_match_goal_and_card_events() -> void:
	var home = _make_team("team_home", "Home High")
	var away = _make_team("team_away", "Away High")
	var result = MatchSimulator.simulate_league_match(home, away, {"importance": 1.0})

	assert_true(result.has("home_goal_events"))
	assert_true(result.has("away_goal_events"))
	assert_eq(result.home_goal_events.size(), result.home_score)
	assert_eq(result.away_goal_events.size(), result.away_score)

	assert_true(result.has("card_events"))
	for event in result.card_events:
		assert_true(event.minute >= 1 and event.minute <= 90, "Card minute should be within regulation")
		assert_true(event.card_color in ["yellow", "red"], "Card color should be yellow or red")

	assert_true(result.has("home_stats"))
	assert_true(result.has("away_stats"))
	assert_true(result.home_stats.shots >= result.home_score)
	assert_true(result.away_stats.shots >= result.away_score)
	assert_true(result.home_stats.shots_on_target <= result.home_stats.shots)
	assert_true(result.away_stats.shots_on_target <= result.away_stats.shots)
	assert_true(result.home_stats.shots_on_target >= result.home_score)
	assert_true(result.away_stats.shots_on_target >= result.away_score)

	assert_true(result.has("home_fouls"))
	assert_true(result.has("away_fouls"))
	assert_true(result.home_fouls >= 0)
	assert_true(result.away_fouls >= 0)

	assert_true(result.home_stats.passes_attempted >= result.home_stats.passes_completed)
	assert_true(result.away_stats.passes_attempted >= result.away_stats.passes_completed)
	assert_true(result.home_stats.possession >= 0.35 and result.home_stats.possession <= 0.65)


func test_simulate_knockout_match_goal_minutes_range() -> void:
	var home = _make_team("team_home", "Home High")
	var away = _make_team("team_away", "Away High")
	var result = MatchSimulator.simulate_knockout_match(home, away, {"importance": 1.5})

	for event in result.home_goal_events:
		assert_true(event.minute >= 1 and event.minute <= 120, "Goal minute should allow extra time")
	for event in result.away_goal_events:
		assert_true(event.minute >= 1 and event.minute <= 120, "Goal minute should allow extra time")


func _make_team(team_id: String, team_name: String) -> TeamData:
	var team = TeamData.new()
	team.id = team_id
	team.name = team_name
	team.tier = 1
	team.formation = "4-4-2"
	team.players = []

	var positions = ["GK", "CB", "FB", "CDM", "CM", "CAM", "WNG", "ST"]
	for i in range(11):
		var pos = positions[i % positions.size()]
		var stats = StatSystem.generate_npc_stats(pos, 2)
		team.players.append({
			"id": "%s_%d" % [team_id, i],
			"name": "Player %d" % i,
			"position": pos,
			"stats": stats,
			"overall": StatSystem.calculate_overall(stats, pos)
		})

	return team
