extends GutTest
## Unit tests for CareerManager social reputation compatibility API

var _snapshot: Dictionary = {}


func before_each() -> void:
	_snapshot = {
		"reputation": CareerManager.reputation,
		"social_rep_day_key": CareerManager.social_rep_day_key,
		"social_rep_awarded_today": CareerManager.social_rep_awarded_today,
		"social_rep_actions_today": CareerManager.social_rep_actions_today
	}
	CareerManager.reputation = 25
	CareerManager.social_rep_day_key = ""
	CareerManager.social_rep_awarded_today = 0
	CareerManager.social_rep_actions_today = 0


func after_each() -> void:
	CareerManager.reputation = int(_snapshot.get("reputation", 10))
	CareerManager.social_rep_day_key = str(_snapshot.get("social_rep_day_key", ""))
	CareerManager.social_rep_awarded_today = int(_snapshot.get("social_rep_awarded_today", 0))
	CareerManager.social_rep_actions_today = int(_snapshot.get("social_rep_actions_today", 0))


func test_apply_social_reputation_delta_increases_reputation() -> void:
	CareerManager.apply_social_reputation_delta(2, "legacy_test")
	assert_eq(CareerManager.reputation, 27)


func test_apply_social_reputation_like_uses_new_api() -> void:
	var result = CareerManager.apply_social_reputation("like", {"post_type": "news_article", "liked": true})
	assert_eq(int(result.get("applied_delta", 0)), 1)
	assert_eq(CareerManager.reputation, 26)
