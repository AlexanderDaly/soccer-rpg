extends GutTest
## Unit tests for shared tactical match rules


func test_build_competition_key_uses_match_type_and_competition_name() -> void:
	var match_data = MatchData.new()
	match_data.match_type = "league"
	match_data.competition_name = "Kanagawa Premier"

	var key = TacticalMatchRules.build_competition_key(match_data)

	assert_eq(key, "league::kanagawa_premier")


func test_is_receiver_offside_requires_second_last_defender() -> void:
	var passer = _make_unit("passer", Vector2i(10, 7))
	var receiver = _make_unit("receiver", Vector2i(16, 7))
	var defender_a = _make_unit("def_a", Vector2i(14, 6))
	var defender_b = _make_unit("def_b", Vector2i(13, 8))

	assert_true(TacticalMatchRules.is_receiver_offside(receiver, passer, [defender_a, defender_b], true))

	receiver.hex_position = Vector2i(12, 7)
	assert_false(TacticalMatchRules.is_receiver_offside(receiver, passer, [defender_a, defender_b], true))


func test_classify_ball_exit_distinguishes_throw_in_corner_and_goal_kick() -> void:
	var throw_in = TacticalMatchRules.classify_ball_exit(Vector2i(8, -1), true)
	assert_eq(throw_in.get("restart_type", ""), TacticalMatchRules.RESTART_THROW_IN)

	var corner = TacticalMatchRules.classify_ball_exit(Vector2i(HexUtils.GRID_WIDTH, 4), false)
	assert_eq(corner.get("restart_type", ""), TacticalMatchRules.RESTART_CORNER)

	var goal_kick = TacticalMatchRules.classify_ball_exit(Vector2i(HexUtils.GRID_WIDTH, 4), true)
	assert_eq(goal_kick.get("restart_type", ""), TacticalMatchRules.RESTART_GOAL_KICK)


func _make_unit(id: String, hex_pos: Vector2i) -> PlayerUnit:
	var unit = PlayerUnit.new()
	unit.unit_id = id
	unit.unit_name = id
	unit.position_role = "CM"
	unit.hex_position = hex_pos
	unit.stats = {
		"SPD": 50,
		"STA": 50,
		"TEC": 50,
		"PAS": 50,
		"SHO": 50,
		"DEF": 50,
		"PHY": 50,
		"MEN": 50
	}
	return unit
