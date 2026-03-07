extends GutTest
## Unit tests for DiceSystem

const DICE_SYSTEM = preload("res://scripts/core/dice_system.gd")


class StubRng:
	extends RefCounted

	var die_rolls: Array[int] = []

	func _init(initial_rolls: Array[int] = []) -> void:
		die_rolls = initial_rolls.duplicate()

	func randi_range(min_value: int, max_value: int) -> int:
		if die_rolls.is_empty():
			return min_value
		return clampi(die_rolls.pop_front(), min_value, max_value)


func test_success_percent_to_target_maps_extremes() -> void:
	assert_eq(DICE_SYSTEM.success_percent_to_target(100.0), 2)
	assert_eq(DICE_SYSTEM.success_percent_to_target(0.0), 13)


func test_success_percent_to_target_maps_common_bands() -> void:
	assert_eq(DICE_SYSTEM.success_percent_to_target(90.0), 4)
	assert_eq(DICE_SYSTEM.success_percent_to_target(58.0), 7)
	assert_eq(DICE_SYSTEM.success_percent_to_target(15.0), 10)


func test_success_percent_to_target_breaks_ties_toward_harder_roll() -> void:
	var midpoint = (DICE_SYSTEM.target_to_success_percent(5) + DICE_SYSTEM.target_to_success_percent(6)) / 2.0
	assert_eq(DICE_SYSTEM.success_percent_to_target(midpoint), 6)


func test_roll_2d6_returns_dice_and_total() -> void:
	var result = DICE_SYSTEM.roll_2d6(StubRng.new([2, 5]))

	assert_eq(result.dice, [2, 5])
	assert_eq(result.total, 7)


func test_raw_margin_to_scaled_margin_expands_dice_gap() -> void:
	assert_eq(DICE_SYSTEM.raw_margin_to_scaled_margin(-3), -30)
	assert_eq(DICE_SYSTEM.raw_margin_to_scaled_margin(4), 40)
