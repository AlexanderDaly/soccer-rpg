extends GutTest
## Unit tests for ActionResolver dice-driven tactical resolution


class StubRng:
	extends RefCounted

	var die_rolls: Array[int] = []
	var float_rolls: Array[float] = []

	func _init(initial_die_rolls: Array[int] = [], initial_float_rolls: Array[float] = []) -> void:
		die_rolls = initial_die_rolls.duplicate()
		float_rolls = initial_float_rolls.duplicate()

	func randi_range(min_value: int, max_value: int) -> int:
		if die_rolls.is_empty():
			return min_value
		return clampi(die_rolls.pop_front(), min_value, max_value)

	func randf() -> float:
		if float_rolls.is_empty():
			return 0.0
		return float_rolls.pop_front()


func test_execute_pass_larger_failed_margin_misses_farther() -> void:
	var target_hex = Vector2i(14, 7)
	var receiver = _make_unit("receiver", {"PAS": 45}, target_hex)

	var slight_miss = ActionResolver.execute_pass(
		_make_unit("passer_slight", {"PAS": 50}, Vector2i(10, 7), true),
		target_hex,
		receiver,
		[],
		MatchData.new(),
		StubRng.new([4, 4], [0.9])
	)
	var heavy_miss = ActionResolver.execute_pass(
		_make_unit("passer_heavy", {"PAS": 50}, Vector2i(10, 7), true),
		target_hex,
		receiver,
		[],
		MatchData.new(),
		StubRng.new([2, 3], [0.9])
	)

	assert_false(slight_miss.success)
	assert_false(heavy_miss.success)
	assert_eq(slight_miss.reason, "inaccurate")
	assert_eq(heavy_miss.reason, "inaccurate")
	assert_eq(slight_miss.roll.margin, -10)
	assert_eq(heavy_miss.roll.margin, -40)
	assert_gt(
		HexUtils.hex_distance(target_hex, heavy_miss.miss_hex),
		HexUtils.hex_distance(target_hex, slight_miss.miss_hex),
		"Bigger negative margins should push the missed pass farther away"
	)


func test_execute_shot_margin_changes_goalkeeper_roll_window() -> void:
	var goal_hex = HexUtils.AWAY_GOAL_HEX
	var marginal_result = ActionResolver.execute_shot(
		_make_unit("shooter_marginal", {"SHO": 80}, Vector2i(18, 7), true),
		goal_hex,
		_make_goalkeeper("keeper_marginal", Vector2i(20, 7)),
		[],
		MatchData.new(),
		StubRng.new([4, 4, 4, 5])
	)
	var strong_result = ActionResolver.execute_shot(
		_make_unit("shooter_strong", {"SHO": 80}, Vector2i(18, 7), true),
		goal_hex,
		_make_goalkeeper("keeper_strong", Vector2i(20, 7)),
		[],
		MatchData.new(),
		StubRng.new([6, 6, 4, 5])
	)

	assert_false(marginal_result.success)
	assert_false(strong_result.success)
	assert_eq(marginal_result.reason, "saved")
	assert_eq(strong_result.reason, "saved")
	assert_gt(strong_result.shot_roll.margin, marginal_result.shot_roll.margin)
	assert_ne(marginal_result.save_roll.target_number, strong_result.save_roll.target_number)
	assert_ne(marginal_result.save_roll.chance_percent, strong_result.save_roll.chance_percent)


func test_execute_dribble_success_keeps_expected_result_shape() -> void:
	var dribbler = _make_unit("dribbler", {"TEC": 80}, Vector2i(10, 7), true)
	var defender = _make_unit("defender", {"DEF": 40, "PHY": 40}, Vector2i(11, 7))

	var result = ActionResolver.execute_dribble(
		dribbler,
		Vector2i(11, 6),
		defender,
		MatchData.new(),
		"basic",
		StubRng.new([3, 4])
	)

	assert_true(result.success)
	assert_has(result, "target_hex")
	assert_has(result, "roll")
	assert_has(result, "beat_defender")
	assert_has(result, "move_id")
	assert_has(result, "move_name")
	assert_has(result, "ap_spent")
	assert_has(result, "stamina_spent")
	assert_eq(result.roll.dice_total, 7)


func test_execute_pass_applies_strong_side_foot_bonus() -> void:
	var target_hex = Vector2i(14, 4)
	var receiver = _make_unit("receiver", {"PAS": 45}, target_hex)
	var passer = _make_unit("passer", {"PAS": 50}, Vector2i(10, 4), true)
	passer.is_player_controlled = true
	passer.dominant_foot = "left"

	var result = ActionResolver.execute_pass(
		passer,
		target_hex,
		receiver,
		[],
		MatchData.new(),
		StubRng.new([5, 6], [0.9])
	)

	assert_true(result.success)
	assert_gt(result.roll.chance_percent, 30.0)


func test_execute_pass_applies_weak_side_foot_penalty() -> void:
	var target_hex = Vector2i(14, 10)
	var receiver = _make_unit("receiver", {"PAS": 45}, target_hex)
	var passer = _make_unit("passer", {"PAS": 50}, Vector2i(10, 10), true)
	passer.is_player_controlled = true
	passer.dominant_foot = "left"

	var result = ActionResolver.execute_pass(
		passer,
		target_hex,
		receiver,
		[],
		MatchData.new(),
		StubRng.new([5, 6], [0.9])
	)

	assert_lt(result.roll.chance_percent, 30.0)


func _make_unit(id: String, stats: Dictionary, hex_pos: Vector2i, has_ball: bool = false) -> PlayerUnit:
	var unit = PlayerUnit.new()
	unit.unit_id = id
	unit.unit_name = id.capitalize()
	unit.position_role = "CM"
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
	unit.stats.merge(stats, true)
	unit.action_points = 3
	unit.max_action_points = 3
	unit.stamina = 100
	unit.max_stamina = 100
	unit.hex_position = hex_pos
	unit.has_ball = has_ball
	return unit


func _make_goalkeeper(id: String, hex_pos: Vector2i) -> PlayerUnit:
	var keeper = _make_unit(id, {"DEF": 80, "MEN": 80}, hex_pos)
	keeper.position_role = "GK"
	return keeper
