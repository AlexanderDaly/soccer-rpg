extends RefCounted
class_name DiceSystem
## DiceSystem - Hidden tabletop-style dice helpers for tactical resolution

const TARGET_NUMBERS: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
const TWO_D6_SUCCESS_CHANCES: Dictionary = {
	2: 100.0,
	3: 97.222222,
	4: 91.666667,
	5: 83.333333,
	6: 72.222222,
	7: 58.333333,
	8: 41.666667,
	9: 27.777778,
	10: 16.666667,
	11: 8.333333,
	12: 2.777778,
	13: 0.0
}


## Roll 2d6 and return the individual dice plus total.
static func roll_2d6(rng = null) -> Dictionary:
	var die_a = _roll_die(rng)
	var die_b = _roll_die(rng)

	return {
		"dice": [die_a, die_b],
		"total": die_a + die_b
	}


## Convert a percent chance into the nearest 2d6 target number.
static func success_percent_to_target(percent: float) -> int:
	var clamped_percent = clampf(percent, 0.0, 100.0)
	var best_target = TARGET_NUMBERS[0]
	var best_diff = INF

	for target in TARGET_NUMBERS:
		var diff = absf(target_to_success_percent(target) - clamped_percent)
		if diff < best_diff or (is_equal_approx(diff, best_diff) and target > best_target):
			best_diff = diff
			best_target = target

	return best_target


## Scale a raw dice margin into the wider range used by tactical systems.
static func raw_margin_to_scaled_margin(raw_margin: int) -> int:
	return raw_margin * 10


## Return the success percent for a given target number.
static func target_to_success_percent(target_number: int) -> float:
	return float(TWO_D6_SUCCESS_CHANCES.get(target_number, 0.0))


static func _roll_die(rng = null) -> int:
	if rng != null and rng.has_method("randi_range"):
		return int(rng.randi_range(1, 6))
	return randi_range(1, 6)
