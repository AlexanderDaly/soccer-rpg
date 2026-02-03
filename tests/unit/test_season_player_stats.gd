extends GutTest
## Unit tests for SeasonPlayerStats and season awards


var stats: SeasonPlayerStats


func before_each() -> void:
	stats = SeasonPlayerStats.new()


# =============================================================================
# Stat Recording Tests
# =============================================================================

func test_record_appearance_creates_player_entry() -> void:
	var player = {"id": "player_1", "name": "Test Player", "position": "ST"}
	stats.record_appearance(player, "team_1")

	assert_true(stats.player_stats.has("player_1"), "Player should be added to stats")
	assert_eq(stats.player_stats["player_1"].matches_played, 1)


func test_record_appearance_increments_matches() -> void:
	var player = {"id": "player_1", "name": "Test Player", "position": "ST"}
	stats.record_appearance(player, "team_1")
	stats.record_appearance(player, "team_1")
	stats.record_appearance(player, "team_1")

	assert_eq(stats.player_stats["player_1"].matches_played, 3)


func test_record_goal_increments_count() -> void:
	var player = {"id": "player_1", "name": "Test Player", "position": "ST"}
	stats.record_appearance(player, "team_1")
	stats.record_goal("player_1")
	stats.record_goal("player_1")

	assert_eq(stats.player_stats["player_1"].goals, 2)


func test_record_assist_increments_count() -> void:
	var player = {"id": "player_1", "name": "Test Player", "position": "CM"}
	stats.record_appearance(player, "team_1")
	stats.record_assist("player_1")

	assert_eq(stats.player_stats["player_1"].assists, 1)


func test_record_clean_sheet_increments_count() -> void:
	var player = {"id": "gk_1", "name": "Goalkeeper", "position": "GK"}
	stats.record_appearance(player, "team_1")
	stats.record_clean_sheet("gk_1")

	assert_eq(stats.player_stats["gk_1"].clean_sheets, 1)


func test_record_goal_ignores_unknown_player() -> void:
	# Should not crash when recording goal for non-existent player
	stats.record_goal("unknown_player")
	assert_false(stats.player_stats.has("unknown_player"))


# =============================================================================
# Eligibility Tests
# =============================================================================

func test_eligibility_requires_50_percent_matches() -> void:
	var player = {"id": "player_1", "name": "Test Player", "position": "ST"}

	# 18 total matches, need 9 to be eligible
	for i in range(8):
		stats.record_appearance(player, "team_1")
	stats.record_goal("player_1")

	var winner = stats.get_golden_boot_winner(18)
	assert_true(winner.is_empty(), "Player with 8/18 matches should not be eligible")

	# Play one more match to reach eligibility
	stats.record_appearance(player, "team_1")
	winner = stats.get_golden_boot_winner(18)
	assert_false(winner.is_empty(), "Player with 9/18 matches should be eligible")


# =============================================================================
# Golden Boot Tests
# =============================================================================

func test_golden_boot_returns_top_scorer() -> void:
	_create_player("scorer_1", "ST", 10, 15, 2, 0)
	_create_player("scorer_2", "ST", 10, 10, 3, 0)

	var winner = stats.get_golden_boot_winner(18)
	assert_eq(winner.player_id, "scorer_1", "Higher goal scorer should win")


func test_golden_boot_tiebreak_by_assists() -> void:
	_create_player("scorer_1", "ST", 10, 15, 2, 0)
	_create_player("scorer_2", "ST", 10, 15, 5, 0)  # Same goals, more assists

	var winner = stats.get_golden_boot_winner(18)
	assert_eq(winner.player_id, "scorer_2", "Player with more assists should win tie")


func test_golden_boot_tiebreak_by_fewer_matches() -> void:
	_create_player("scorer_1", "ST", 18, 15, 5, 0)  # More matches
	_create_player("scorer_2", "ST", 10, 15, 5, 0)  # Fewer matches, same stats

	var winner = stats.get_golden_boot_winner(18)
	assert_eq(winner.player_id, "scorer_2", "Player with fewer matches should win tie")


func test_golden_boot_requires_goals() -> void:
	_create_player("player_1", "ST", 10, 0, 5, 0)  # No goals

	var winner = stats.get_golden_boot_winner(18)
	assert_true(winner.is_empty(), "Player with 0 goals should not win golden boot")


# =============================================================================
# Top Assister Tests
# =============================================================================

func test_top_assister_returns_most_assists() -> void:
	_create_player("passer_1", "CM", 10, 5, 12, 0)
	_create_player("passer_2", "CM", 10, 3, 8, 0)

	var winner = stats.get_top_assister(18)
	assert_eq(winner.player_id, "passer_1", "Higher assist count should win")


func test_top_assister_tiebreak_by_goals() -> void:
	_create_player("passer_1", "CM", 10, 5, 10, 0)
	_create_player("passer_2", "CM", 10, 8, 10, 0)  # Same assists, more goals

	var winner = stats.get_top_assister(18)
	assert_eq(winner.player_id, "passer_2", "Player with more goals should win tie")


# =============================================================================
# Golden Glove Tests
# =============================================================================

func test_golden_glove_returns_top_gk() -> void:
	_create_player("gk_1", "GK", 10, 0, 0, 8)
	_create_player("gk_2", "GK", 10, 0, 0, 5)

	var winner = stats.get_golden_glove(18)
	assert_eq(winner.player_id, "gk_1", "GK with more clean sheets should win")


func test_golden_glove_only_gk_eligible() -> void:
	_create_player("cb_1", "CB", 10, 0, 0, 10)  # Non-GK with clean sheets
	_create_player("gk_1", "GK", 10, 0, 0, 5)

	var winner = stats.get_golden_glove(18)
	assert_eq(winner.player_id, "gk_1", "Only GK should be eligible for golden glove")


func test_golden_glove_requires_clean_sheets() -> void:
	_create_player("gk_1", "GK", 10, 0, 0, 0)  # No clean sheets

	var winner = stats.get_golden_glove(18)
	assert_true(winner.is_empty(), "GK with 0 clean sheets should not win")


# =============================================================================
# All Awards Tests
# =============================================================================

func test_get_all_awards_returns_all_three() -> void:
	_create_player("scorer", "ST", 10, 20, 5, 0)
	_create_player("passer", "CM", 10, 3, 15, 0)
	_create_player("keeper", "GK", 10, 0, 0, 10)

	var awards = stats.get_all_awards(18)

	assert_has(awards, "golden_boot")
	assert_has(awards, "top_assister")
	assert_has(awards, "golden_glove")
	assert_eq(awards.golden_boot.player_id, "scorer")
	assert_eq(awards.top_assister.player_id, "passer")
	assert_eq(awards.golden_glove.player_id, "keeper")


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict_preserves_data() -> void:
	_create_player("player_1", "ST", 10, 15, 5, 0)

	var data = stats.to_dict()
	var new_stats = SeasonPlayerStats.new()
	new_stats.from_dict(data)

	assert_true(new_stats.player_stats.has("player_1"))
	assert_eq(new_stats.player_stats["player_1"].goals, 15)
	assert_eq(new_stats.player_stats["player_1"].assists, 5)


# =============================================================================
# Helper Functions
# =============================================================================

func _create_player(id: String, position: String, matches: int, goals: int, assists: int, clean_sheets: int) -> void:
	var player = {"id": id, "name": "Player " + id, "position": position}

	for i in range(matches):
		stats.record_appearance(player, "team_1")

	for i in range(goals):
		stats.record_goal(id)

	for i in range(assists):
		stats.record_assist(id)

	for i in range(clean_sheets):
		stats.record_clean_sheet(id)
