extends GutTest
## Unit tests for MatchController goal/assist attribution


var controller: MatchController


func before_each() -> void:
	controller = MatchController.new()
	controller.match_data = MatchData.new()
	controller.match_data.player_position = "CM"
	# Wire up minimal teams so goal events can record team info
	controller.match_data.home_team = _make_team("home_team", "Home FC")
	controller.match_data.away_team = _make_team("away_team", "Away FC")
	controller.match_data.is_home = true
	add_child(controller)


func after_each() -> void:
	controller.queue_free()


# =============================================================================
# Through-ball last_passer tracking (Bug 1)
# =============================================================================

func test_through_ball_sets_last_passer() -> void:
	# Verify _execute_through_ball sets last_passer on success.
	# We can't easily call _execute_through_ball without full ActionResolver
	# wiring, so we test the observable effect: when last_passer is set before
	# a goal, the assist is attributed. This test confirms the plumbing works
	# by simulating the state that _execute_through_ball now produces.
	var passer = _make_unit("passer_1", "Passer", true, true)
	var scorer = _make_unit("scorer_1", "Scorer", false, true)

	controller.last_passer = passer
	controller.last_shooter = scorer
	controller._on_goal_scored(false)  # Home team scores

	assert_eq(controller.home_goal_events.size(), 1, "Should have one home goal event")
	var event = controller.home_goal_events[0]
	assert_eq(event.get("assister_id", ""), "passer_1", "Through-ball passer should get assist")
	assert_eq(event.get("assister_name", ""), "Passer", "Assister name should be recorded")


func test_regular_pass_sets_last_passer() -> void:
	# Baseline: regular pass → assist attribution works the same way
	var passer = _make_unit("passer_2", "Midfielder", true, true)
	var scorer = _make_unit("scorer_2", "Striker", false, true)

	controller.last_passer = passer
	controller.last_shooter = scorer
	controller._on_goal_scored(false)

	var event = controller.home_goal_events[0]
	assert_eq(event.get("assister_id", ""), "passer_2")


# =============================================================================
# Player assist recording in match_data (Bug 2)
# =============================================================================

func test_goal_with_player_assist_records_in_match_data() -> void:
	var passer = _make_unit("passer_3", "Player Passer", true, true)
	var scorer = _make_unit("scorer_3", "Teammate", false, true)

	controller.last_passer = passer
	controller.last_shooter = scorer
	controller._on_goal_scored(false)

	assert_eq(controller.match_data.player_stats.assists, 1,
		"Player assist should be recorded in match_data")


func test_goal_with_npc_assist_does_not_record_player_assist() -> void:
	var npc_passer = _make_unit("npc_1", "NPC Passer", false, true)  # Not player-controlled
	var scorer = _make_unit("scorer_4", "Striker", false, true)

	controller.last_passer = npc_passer
	controller.last_shooter = scorer
	controller._on_goal_scored(false)

	assert_eq(controller.match_data.player_stats.assists, 0,
		"NPC assist should NOT increment player assists in match_data")
	# But the goal event should still have the assist attribution
	var event = controller.home_goal_events[0]
	assert_eq(event.get("assister_id", ""), "npc_1",
		"NPC assister should still appear in goal event for season stats")


func test_goal_without_assist_records_zero_assists() -> void:
	var scorer = _make_unit("scorer_5", "Solo Scorer", true, true)

	controller.last_passer = null
	controller.last_shooter = scorer
	controller._on_goal_scored(false)

	assert_eq(controller.match_data.player_stats.assists, 0,
		"No assist when no last_passer")
	var event = controller.home_goal_events[0]
	assert_false(event.has("assister_id"), "Goal event should have no assister")


func test_player_assist_affects_match_rating() -> void:
	var passer = _make_unit("passer_4", "Playmaker", true, true)
	var scorer = _make_unit("scorer_6", "Striker", false, true)
	var baseline_match = MatchData.new()
	baseline_match.player_position = "CM"
	baseline_match.home_team = _make_team("base_home", "Base Home")
	baseline_match.away_team = _make_team("base_away", "Base Away")
	baseline_match.is_home = true
	baseline_match.home_score = 1
	baseline_match.away_score = 0

	# Record an assist via goal scoring
	controller.last_passer = passer
	controller.last_shooter = scorer
	controller._on_goal_scored(false)

	var baseline_rating = baseline_match.calculate_match_rating()
	var rating = controller.match_data.calculate_match_rating()
	assert_gt(rating, baseline_rating,
		"Rating should improve when the player contributes an assist")


func test_away_goal_records_in_away_events() -> void:
	var scorer = _make_unit("away_scorer", "Away Striker", false, false)  # Away team

	controller.last_passer = null
	controller.last_shooter = scorer
	controller._on_goal_scored(true)  # Ball entered home goal → away scored

	assert_eq(controller.away_goal_events.size(), 1, "Should record in away events")
	assert_eq(controller.home_goal_events.size(), 0, "Should not record in home events")
	var event = controller.away_goal_events[0]
	assert_eq(event.get("team_id", ""), "away_team")


# =============================================================================
# Helpers
# =============================================================================

func _make_unit(id: String, uname: String, is_player: bool, is_home: bool) -> PlayerUnit:
	var unit = PlayerUnit.new()
	unit.unit_id = id
	unit.unit_name = uname
	unit.is_player_controlled = is_player
	unit.is_home_team = is_home
	add_child(unit)
	return unit


func _make_team(id: String, tname: String) -> TeamData:
	var team = TeamData.new()
	team.id = id
	team.name = tname
	return team
