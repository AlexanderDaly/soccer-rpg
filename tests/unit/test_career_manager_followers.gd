extends GutTest
## Unit tests for CareerManager follower scaling

var _snapshot: Dictionary = {}


func before_each() -> void:
	seed(1234)
	_snapshot = {
		"match_history": CareerManager.match_history.duplicate(true),
		"career_stats": CareerManager.career_stats.duplicate(true),
		"reputation": CareerManager.reputation,
		"fan_popularity": CareerManager.fan_popularity,
		"media_coverage": CareerManager.media_coverage,
		"scout_attention": CareerManager.scout_attention.duplicate(true),
		"completed_milestones": CareerManager.completed_milestones.duplicate(true),
		"rivals": CareerManager.rivals.duplicate(true),
		"reputation_event_log": CareerManager.reputation_event_log.duplicate(true),
		"last_match_reputation_report": CareerManager.last_match_reputation_report.duplicate(true),
		"social_rep_day_key": CareerManager.social_rep_day_key,
		"social_rep_awarded_today": CareerManager.social_rep_awarded_today,
		"social_rep_actions_today": CareerManager.social_rep_actions_today
	}
	_reset_career_state()


func after_each() -> void:
	CareerManager.match_history.assign(_snapshot.get("match_history", []))
	CareerManager.career_stats = _snapshot.get("career_stats", {}).duplicate(true)
	CareerManager.reputation = int(_snapshot.get("reputation", 10))
	CareerManager.fan_popularity = int(_snapshot.get("fan_popularity", 0))
	CareerManager.media_coverage = int(_snapshot.get("media_coverage", 0))
	CareerManager.scout_attention = _snapshot.get("scout_attention", {}).duplicate(true)
	CareerManager.completed_milestones.assign(_snapshot.get("completed_milestones", []))
	CareerManager.rivals.assign(_snapshot.get("rivals", []))
	CareerManager.reputation_event_log.assign(_snapshot.get("reputation_event_log", []))
	CareerManager.last_match_reputation_report = _snapshot.get("last_match_reputation_report", {}).duplicate(true)
	CareerManager.social_rep_day_key = str(_snapshot.get("social_rep_day_key", ""))
	CareerManager.social_rep_awarded_today = int(_snapshot.get("social_rep_awarded_today", 0))
	CareerManager.social_rep_actions_today = int(_snapshot.get("social_rep_actions_today", 0))


func test_low_rep_win_adds_followers_and_emits_delta() -> void:
	CareerManager.reputation = 10
	CareerManager.fan_popularity = 0

	var payload = {"called": false, "new_total": 0, "delta": 0, "outcome": ""}
	var callback := func(new_total: int, delta: int, outcome: String) -> void:
		payload["called"] = true
		payload["new_total"] = new_total
		payload["delta"] = delta
		payload["outcome"] = outcome
	CareerManager.fan_popularity_changed.connect(callback, CONNECT_ONE_SHOT)

	var result = _make_result(true, false, false, 1.0, 2, 1)
	CareerManager.record_match_result(result)

	assert_eq(CareerManager.fan_popularity, 6, "Win at low rep should add 6 followers")
	assert_true(payload.get("called", false), "Follower signal should be emitted")
	assert_eq(payload.get("delta", 0), 6, "Signal delta should be +6")
	assert_eq(payload.get("new_total", 0), 6, "Signal total should be 6")
	assert_eq(payload.get("outcome", ""), "win", "Signal should mark outcome as win")


func test_high_rep_high_importance_win_scales_to_thirty_three() -> void:
	CareerManager.reputation = 65
	CareerManager.fan_popularity = 0

	var result = _make_result(true, false, false, 1.5, 3, 0)
	CareerManager.record_match_result(result)

	assert_eq(CareerManager.fan_popularity, 33, "Win at rep 65 with 1.5x importance should add 33")
	assert_eq(result.get("followers_delta", 0), 33)
	assert_eq(result.get("followers_total", 0), 33)


func test_draw_does_not_change_followers() -> void:
	CareerManager.reputation = 50
	CareerManager.fan_popularity = 12

	var result = _make_result(false, false, true, 2.0, 1, 1)
	CareerManager.record_match_result(result)

	assert_eq(CareerManager.fan_popularity, 12, "Draw should not change followers")
	assert_eq(result.get("followers_delta", 999), 0)
	assert_eq(result.get("followers_total", 0), 12)


func test_loss_applies_penalty_at_mid_reputation() -> void:
	CareerManager.reputation = 45
	CareerManager.fan_popularity = 20

	var result = _make_result(false, true, false, 1.0, 0, 1)
	CareerManager.record_match_result(result)

	assert_eq(CareerManager.fan_popularity, 17, "Loss at rep 45 should subtract 3 followers")
	assert_eq(result.get("followers_delta", 0), -3)
	assert_eq(result.get("followers_total", 0), 17)


func test_loss_at_zero_followers_is_floored() -> void:
	CareerManager.reputation = 45
	CareerManager.fan_popularity = 0

	var result = _make_result(false, true, false, 1.0, 0, 2)
	CareerManager.record_match_result(result)

	assert_eq(CareerManager.fan_popularity, 0, "Followers should not drop below zero")
	assert_eq(result.get("followers_delta", 999), 0, "Applied delta should be zero after floor")
	assert_eq(result.get("followers_total", -1), 0)


func test_match_result_contains_follower_metadata_keys() -> void:
	CareerManager.reputation = 10
	CareerManager.fan_popularity = 0

	var result = _make_result(true, false, false, 1.0, 1, 0)
	CareerManager.record_match_result(result)

	assert_true(result.has("followers_delta"), "Result should include followers_delta")
	assert_true(result.has("followers_total"), "Result should include followers_total")


func _make_result(won: bool, lost: bool, draw: bool, importance: float, player_score: int, opponent_score: int) -> Dictionary:
	return {
		"won": won,
		"lost": lost,
		"draw": draw,
		"importance": importance,
		"player_score": player_score,
		"opponent_score": opponent_score,
		"goals": 0,
		"assists": 0,
		"man_of_match": false
	}


func _reset_career_state() -> void:
	CareerManager.match_history.clear()
	CareerManager.career_stats = {
		"matches_played": 0,
		"goals": 0,
		"assists": 0,
		"clean_sheets": 0,
		"man_of_match_awards": 0,
		"trophies": [],
		"current_season": 1
	}
	CareerManager.reputation = 10
	CareerManager.fan_popularity = 0
	CareerManager.media_coverage = 0
	CareerManager.scout_attention = {}
	CareerManager.completed_milestones.clear()
	CareerManager.rivals.clear()
	CareerManager.reputation_event_log.clear()
	CareerManager.last_match_reputation_report = {}
	CareerManager.social_rep_day_key = ""
	CareerManager.social_rep_awarded_today = 0
	CareerManager.social_rep_actions_today = 0
