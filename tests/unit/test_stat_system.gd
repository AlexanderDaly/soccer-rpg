extends GutTest
## Unit tests for StatSystem

var stat_system: Node


class FixedDiceRng:
	extends RefCounted

	var die_rolls: Array[int] = []

	func _init(initial_rolls: Array[int] = []) -> void:
		die_rolls = initial_rolls.duplicate()

	func randi_range(min_value: int, max_value: int) -> int:
		if die_rolls.is_empty():
			return min_value
		return clampi(die_rolls.pop_front(), min_value, max_value)


func before_all() -> void:
	# Get reference to the autoloaded StatSystem
	stat_system = get_tree().root.get_node_or_null("StatSystem")


# =============================================================================
# Secondary Stat Calculation Tests
# =============================================================================

func test_calculate_secondary_acceleration() -> void:
	var stats = {"SPD": 80, "PHY": 60}
	var result = StatSystem.calculate_secondary(stats, "acceleration")
	# Expected: 80 * 0.7 + 60 * 0.3 = 56 + 18 = 74
	assert_eq(result, 74, "Acceleration should be weighted 70% SPD, 30% PHY")


func test_calculate_secondary_vision() -> void:
	var stats = {"PAS": 70, "MEN": 90}
	var result = StatSystem.calculate_secondary(stats, "vision")
	# Expected: 70 * 0.5 + 90 * 0.5 = 35 + 45 = 80
	assert_eq(result, 80, "Vision should be 50% PAS, 50% MEN")


func test_calculate_secondary_finishing() -> void:
	var stats = {"SHO": 85, "TEC": 70, "MEN": 60}
	var result = StatSystem.calculate_secondary(stats, "finishing")
	# Expected: 85 * 0.6 + 70 * 0.3 + 60 * 0.1 = 51 + 21 + 6 = 78
	assert_eq(result, 78, "Finishing should be 60% SHO, 30% TEC, 10% MEN")


func test_calculate_secondary_unknown_returns_zero() -> void:
	var stats = {"SPD": 50, "STA": 50}
	var result = StatSystem.calculate_secondary(stats, "unknown_stat")
	assert_eq(result, 0, "Unknown secondary stat should return 0")


func test_calculate_all_secondaries_returns_all() -> void:
	var stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 50, "DEF": 50, "PHY": 50, "MEN": 50}
	var secondaries = StatSystem.calculate_all_secondaries(stats)

	assert_has(secondaries, "acceleration")
	assert_has(secondaries, "vision")
	assert_has(secondaries, "finishing")
	assert_has(secondaries, "long_shots")
	assert_has(secondaries, "crossing")
	assert_has(secondaries, "heading")
	assert_has(secondaries, "tackling")
	assert_has(secondaries, "interception")
	assert_has(secondaries, "positioning")
	assert_has(secondaries, "reflexes")


# =============================================================================
# Overall Rating Tests
# =============================================================================

func test_calculate_overall_returns_valid_range() -> void:
	var stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 50, "DEF": 50, "PHY": 50, "MEN": 50}
	var overall = StatSystem.calculate_overall(stats, "CM")
	assert_between(overall, 1, 99, "Overall should be between 1-99")


func test_calculate_overall_striker_favors_shooting() -> void:
	var shooting_stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 90, "DEF": 30, "PHY": 50, "MEN": 50}
	var defensive_stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 30, "DEF": 90, "PHY": 50, "MEN": 50}

	var striker_with_shooting = StatSystem.calculate_overall(shooting_stats, "ST")
	var striker_with_defense = StatSystem.calculate_overall(defensive_stats, "ST")

	assert_gt(striker_with_shooting, striker_with_defense,
		"Striker overall should favor shooting over defense")


func test_calculate_overall_cb_favors_defense() -> void:
	var shooting_stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 90, "DEF": 30, "PHY": 50, "MEN": 50}
	var defensive_stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 30, "DEF": 90, "PHY": 50, "MEN": 50}

	var cb_with_shooting = StatSystem.calculate_overall(shooting_stats, "CB")
	var cb_with_defense = StatSystem.calculate_overall(defensive_stats, "CB")

	assert_gt(cb_with_defense, cb_with_shooting,
		"CB overall should favor defense over shooting")


func test_calculate_overall_unknown_position_defaults_to_cm() -> void:
	var stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 50, "DEF": 50, "PHY": 50, "MEN": 50}
	var unknown_overall = StatSystem.calculate_overall(stats, "UNKNOWN")
	var cm_overall = StatSystem.calculate_overall(stats, "CM")

	assert_eq(unknown_overall, cm_overall, "Unknown position should default to CM")


func test_calculate_overall_empty_stats_returns_default() -> void:
	var empty_stats = {}
	var overall = StatSystem.calculate_overall(empty_stats, "CM")
	assert_eq(overall, 50, "Empty stats should return default overall of 50")


# =============================================================================
# XP Curve Tests
# =============================================================================

func test_xp_for_level_one() -> void:
	var xp = StatSystem.xp_for_level(1)
	assert_eq(xp, 100, "Level 1 should require base XP of 100")


func test_xp_for_level_increases() -> void:
	var xp_1 = StatSystem.xp_for_level(1)
	var xp_2 = StatSystem.xp_for_level(2)
	var xp_3 = StatSystem.xp_for_level(3)

	assert_gt(xp_2, xp_1, "XP requirement should increase from level 1 to 2")
	assert_gt(xp_3, xp_2, "XP requirement should increase from level 2 to 3")


func test_xp_for_level_follows_exponential_growth() -> void:
	var xp_1 = StatSystem.xp_for_level(1)
	var xp_2 = StatSystem.xp_for_level(2)

	# Growth rate is 1.15, so level 2 should be ~115
	var expected_xp_2 = roundi(100 * 1.15)
	assert_eq(xp_2, expected_xp_2, "Level 2 XP should follow exponential growth rate")


func test_total_xp_for_level_accumulates() -> void:
	var total_1 = StatSystem.total_xp_for_level(1)
	var total_2 = StatSystem.total_xp_for_level(2)
	var total_3 = StatSystem.total_xp_for_level(3)

	assert_eq(total_1, 0, "Total XP to reach level 1 should be 0")
	assert_eq(total_2, StatSystem.xp_for_level(1), "Total XP to reach level 2 should be level 1 XP")
	assert_eq(total_3, StatSystem.xp_for_level(1) + StatSystem.xp_for_level(2),
		"Total XP to reach level 3 should be sum of levels 1 and 2")


# =============================================================================
# Form Modifier Tests
# =============================================================================

func test_apply_form_modifier_average_no_change() -> void:
	var result = StatSystem.apply_form_modifier(50, "average")
	assert_eq(result, 50, "Average form should not modify stat")


func test_apply_form_modifier_excellent_adds_ten() -> void:
	var result = StatSystem.apply_form_modifier(50, "excellent")
	assert_eq(result, 60, "Excellent form should add 10 to stat")


func test_apply_form_modifier_terrible_subtracts_ten() -> void:
	var result = StatSystem.apply_form_modifier(50, "terrible")
	assert_eq(result, 40, "Terrible form should subtract 10 from stat")


func test_apply_form_modifier_clamped_to_max() -> void:
	var result = StatSystem.apply_form_modifier(95, "excellent")
	assert_eq(result, 99, "Form modifier should not exceed 99")


func test_apply_form_modifier_clamped_to_min() -> void:
	var result = StatSystem.apply_form_modifier(5, "terrible")
	assert_eq(result, 1, "Form modifier should not go below 1")


func test_apply_form_modifier_unknown_form_no_change() -> void:
	var result = StatSystem.apply_form_modifier(50, "unknown")
	assert_eq(result, 50, "Unknown form should not modify stat")


# =============================================================================
# NPC Stat Generation Tests
# =============================================================================

func test_generate_npc_stats_returns_all_primary_stats() -> void:
	var stats = StatSystem.generate_npc_stats("CM", 2)

	for stat_key in StatSystem.PRIMARY_STATS:
		assert_has(stats, stat_key, "Generated stats should include %s" % stat_key)


func test_generate_npc_stats_within_valid_range() -> void:
	for _i in range(10):
		var stats = StatSystem.generate_npc_stats("CM", 2)

		for stat_key in stats:
			assert_between(stats[stat_key], 1, 99,
				"%s should be between 1 and 99" % stat_key)


func test_generate_npc_stats_higher_tier_better_stats() -> void:
	var low_tier_totals: Array[int] = []
	var high_tier_totals: Array[int] = []

	# Generate multiple samples to account for randomness
	for _i in range(20):
		var low_stats = StatSystem.generate_npc_stats("CM", 1)
		var high_stats = StatSystem.generate_npc_stats("CM", 4)

		var low_total = 0
		var high_total = 0
		for key in low_stats:
			low_total += low_stats[key]
			high_total += high_stats[key]

		low_tier_totals.append(low_total)
		high_tier_totals.append(high_total)

	var avg_low = _array_average(low_tier_totals)
	var avg_high = _array_average(high_tier_totals)

	assert_gt(avg_high, avg_low, "Higher tier NPCs should have better average stats")


func _array_average(arr: Array[int]) -> float:
	var sum = 0
	for val in arr:
		sum += val
	return float(sum) / arr.size()


# =============================================================================
# Action Success Roll Tests
# =============================================================================

func test_roll_action_success_returns_required_keys() -> void:
	var result = StatSystem.roll_action_success(50)

	assert_has(result, "success")
	assert_has(result, "critical")
	assert_has(result, "margin")
	assert_has(result, "chance_percent")
	assert_has(result, "target_number")
	assert_has(result, "dice_total")
	assert_has(result, "dice")


func test_roll_action_success_high_stat_usually_succeeds() -> void:
	var successes = 0
	var trials = 100
	var rng = RandomNumberGenerator.new()
	rng.seed = 1337

	for _i in range(trials):
		var result = StatSystem.roll_action_success(99, 0, 0.1, rng)  # Very easy
		if result.success:
			successes += 1

	assert_gt(successes, 80, "High stat with low difficulty should succeed most of the time")


func test_roll_action_success_low_stat_usually_fails() -> void:
	var failures = 0
	var trials = 100
	var rng = RandomNumberGenerator.new()
	rng.seed = 2026

	for _i in range(trials):
		var result = StatSystem.roll_action_success(10, 0, 0.9, rng)  # Very hard
		if not result.success:
			failures += 1

	assert_gt(failures, 80, "Low stat with high difficulty should fail most of the time")


func test_roll_action_contested_favors_higher_stat() -> void:
	var actor_wins = 0
	var trials = 100
	var rng = RandomNumberGenerator.new()
	rng.seed = 9001

	for _i in range(trials):
		var result = StatSystem.roll_action_success(80, 20, 0.5, rng)  # Big advantage
		if result.success:
			actor_wins += 1

	assert_gt(actor_wins, 60, "Higher stat should win contested rolls more often")


func test_roll_action_success_reports_expected_dice_metadata() -> void:
	var result = StatSystem.roll_action_success(80, 0, 0.4, FixedDiceRng.new([6, 6]))

	assert_almost_eq(result.chance_percent, 48.0, 0.01)
	assert_eq(result.target_number, 8)
	assert_eq(result.dice_total, 12)
	assert_eq(result.dice, [6, 6])
	assert_eq(result.margin, 40)
	assert_true(result.critical, "A natural 12 should count as a critical success")


func test_roll_action_success_scales_failure_margin_from_dice_gap() -> void:
	var result = StatSystem.roll_action_success(50, 0, 0.42, FixedDiceRng.new([4, 4]))

	assert_false(result.success)
	assert_eq(result.target_number, 9)
	assert_eq(result.dice_total, 8)
	assert_eq(result.margin, -10)


# =============================================================================
# Constants Validation Tests
# =============================================================================

func test_primary_stats_has_eight_entries() -> void:
	assert_eq(StatSystem.PRIMARY_STATS.size(), 8, "Should have 8 primary stats")


func test_position_weights_has_all_positions() -> void:
	var positions = ["GK", "CB", "FB", "CDM", "CM", "CAM", "WNG", "ST"]

	for pos in positions:
		assert_has(StatSystem.POSITION_WEIGHTS, pos, "Position weights should include %s" % pos)


func test_form_modifiers_has_all_levels() -> void:
	var forms = ["terrible", "poor", "average", "good", "excellent"]

	for form in forms:
		assert_has(StatSystem.FORM_MODIFIERS, form, "Form modifiers should include %s" % form)
