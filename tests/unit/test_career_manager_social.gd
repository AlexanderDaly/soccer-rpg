extends GutTest
## Unit tests for CareerManager social reputation API

var _original_reputation: int = 0


func before_each() -> void:
	_original_reputation = CareerManager.reputation


func after_each() -> void:
	CareerManager.reputation = _original_reputation


func test_apply_social_reputation_delta_increases_reputation() -> void:
	CareerManager.reputation = 25
	CareerManager.apply_social_reputation_delta(2, "v2_thread_engagement")
	assert_eq(CareerManager.reputation, 27)


func test_apply_social_reputation_delta_zero_no_change() -> void:
	CareerManager.reputation = 25
	CareerManager.apply_social_reputation_delta(0, "noop")
	assert_eq(CareerManager.reputation, 25)
