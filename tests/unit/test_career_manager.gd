extends GutTest
## Unit tests for CareerManager reputation system V1

var _snapshot: Dictionary = {}


func before_each() -> void:
	seed(1337)
	_snapshot = {
		"player_data": GameManager.player_data,
		"match_history": CareerManager.match_history.duplicate(true),
		"career_stats": CareerManager.career_stats.duplicate(true),
		"reputation": CareerManager.reputation,
		"scout_attention": CareerManager.scout_attention.duplicate(true),
		"media_coverage": CareerManager.media_coverage,
		"fan_popularity": CareerManager.fan_popularity,
		"current_contract": CareerManager.current_contract.duplicate(true),
		"club_history": CareerManager.club_history.duplicate(true),
		"pending_contract_offers": CareerManager.pending_contract_offers.duplicate(true),
		"relationships": CareerManager.relationships.duplicate(true),
		"coach_trust": CareerManager.coach_trust,
		"scout_relationships": CareerManager.scout_relationships.duplicate(true),
		"queued_contract_offer": CareerManager.queued_contract_offer.duplicate(true),
		"completed_milestones": CareerManager.completed_milestones.duplicate(true),
		"rivals": CareerManager.rivals.duplicate(true),
		"reputation_event_log": CareerManager.reputation_event_log.duplicate(true),
		"last_match_reputation_report": CareerManager.last_match_reputation_report.duplicate(true),
		"social_rep_day_key": CareerManager.social_rep_day_key,
		"social_rep_awarded_today": CareerManager.social_rep_awarded_today,
		"social_rep_actions_today": CareerManager.social_rep_actions_today
	}
	CareerManager.reset_for_new_career()


func after_each() -> void:
	GameManager.player_data = _snapshot.get("player_data", null)
	CareerManager.match_history.assign(_snapshot.get("match_history", []))
	CareerManager.career_stats = _snapshot.get("career_stats", {}).duplicate(true)
	CareerManager.reputation = int(_snapshot.get("reputation", 10))
	CareerManager.scout_attention = _snapshot.get("scout_attention", {}).duplicate(true)
	CareerManager.media_coverage = int(_snapshot.get("media_coverage", 0))
	CareerManager.fan_popularity = int(_snapshot.get("fan_popularity", 0))
	CareerManager.current_contract = _snapshot.get("current_contract", {}).duplicate(true)
	CareerManager.club_history.assign(_snapshot.get("club_history", []))
	CareerManager.pending_contract_offers.assign(_snapshot.get("pending_contract_offers", []))
	CareerManager.relationships = _snapshot.get("relationships", {}).duplicate(true)
	CareerManager.coach_trust = int(_snapshot.get("coach_trust", 50))
	CareerManager.scout_relationships = _snapshot.get("scout_relationships", {}).duplicate(true)
	CareerManager.queued_contract_offer = _snapshot.get("queued_contract_offer", {}).duplicate(true)
	CareerManager.completed_milestones.assign(_snapshot.get("completed_milestones", []))
	CareerManager.rivals.assign(_snapshot.get("rivals", []))
	CareerManager.reputation_event_log.assign(_snapshot.get("reputation_event_log", []))
	CareerManager.last_match_reputation_report = _snapshot.get("last_match_reputation_report", {}).duplicate(true)
	CareerManager.social_rep_day_key = str(_snapshot.get("social_rep_day_key", ""))
	CareerManager.social_rep_awarded_today = int(_snapshot.get("social_rep_awarded_today", 0))
	CareerManager.social_rep_actions_today = int(_snapshot.get("social_rep_actions_today", 0))


func test_reputation_tier_boundaries() -> void:
	assert_eq(CareerManager.get_reputation_tier(0).get("id", ""), "unknown")
	assert_eq(CareerManager.get_reputation_tier(14).get("id", ""), "unknown")
	assert_eq(CareerManager.get_reputation_tier(15).get("id", ""), "prospect")
	assert_eq(CareerManager.get_reputation_tier(30).get("id", ""), "rising_star")
	assert_eq(CareerManager.get_reputation_tier(50).get("id", ""), "noted_talent")
	assert_eq(CareerManager.get_reputation_tier(70).get("id", ""), "national_buzz")
	assert_eq(CareerManager.get_reputation_tier(85).get("id", ""), "wonderkid")


func test_record_match_result_applies_expected_reputation_delta() -> void:
	CareerManager.reputation = 10
	CareerManager.completed_milestones = ["first_goal", "first_assist", "first_motm", "ten_goals"]

	var result = {
		"goals": 2,
		"assists": 1,
		"won": true,
		"lost": false,
		"draw": false,
		"man_of_match": true,
		"clean_sheet": true,
		"yellow_cards": 2,
		"red_card": true,
		"rating": 8.6,
		"importance": 1.5
	}

	CareerManager.record_match_result(result)

	# Raw = +8, scaled by 1.5 => +12
	assert_eq(CareerManager.reputation, 22)
	assert_eq(int(result.get("reputation_delta", 0)), 12)
	assert_eq(int(result.get("reputation_before", 0)), 10)
	assert_eq(int(result.get("reputation_after", 0)), 22)
	assert_true(result.has("reputation_breakdown"))


func test_record_match_result_applies_milestone_bonus() -> void:
	CareerManager.reputation = 10

	var result = {
		"goals": 1,
		"assists": 0,
		"won": false,
		"lost": false,
		"draw": true,
		"man_of_match": false,
		"clean_sheet": false,
		"yellow_cards": 0,
		"red_card": false,
		"rating": 6.0,
		"importance": 1.0
	}

	CareerManager.record_match_result(result)

	# +2 for goal and +5 for first_goal milestone.
	assert_eq(CareerManager.reputation, 17)
	assert_true("first_goal" in CareerManager.completed_milestones)
	assert_eq(int(result.get("reputation_delta", 0)), 7)


func test_social_reputation_diminishing_and_daily_cap() -> void:
	CareerManager.reputation = 10

	var r1 = CareerManager.apply_social_reputation("player_post")
	var r2 = CareerManager.apply_social_reputation("player_post")
	var r3 = CareerManager.apply_social_reputation("player_post")
	var r4 = CareerManager.apply_social_reputation("player_reply")

	assert_eq(int(r1.get("applied_delta", 0)), 2)
	assert_eq(int(r2.get("applied_delta", 0)), 1)
	assert_eq(int(r3.get("applied_delta", 0)), 1)
	assert_eq(int(r4.get("applied_delta", 0)), 0)
	assert_eq(CareerManager.reputation, 14)

	var summary = CareerManager.get_reputation_summary()
	assert_eq(int(summary.get("daily_social_awarded", 0)), 4)
	assert_eq(int(summary.get("daily_social_cap", 0)), 4)


func test_social_like_only_counts_for_eligible_post_types() -> void:
	CareerManager.reputation = 10

	var denied = CareerManager.apply_social_reputation("like", {"post_type": "npc_reaction", "liked": true})
	assert_eq(int(denied.get("applied_delta", 0)), 0)
	assert_eq(CareerManager.reputation, 10)

	var allowed = CareerManager.apply_social_reputation("like", {"post_type": "news_article", "liked": true})
	assert_eq(int(allowed.get("applied_delta", 0)), 1)
	assert_eq(CareerManager.reputation, 11)


func test_reputation_tier_changed_signal_emits_on_boundary_cross() -> void:
	CareerManager.reputation = 14
	CareerManager.social_rep_day_key = ""
	CareerManager.social_rep_awarded_today = 0
	CareerManager.social_rep_actions_today = 0

	var captured := {"called": false, "old": "", "new": ""}
	var callback := func(old_tier: String, new_tier: String) -> void:
		captured["called"] = true
		captured["old"] = old_tier
		captured["new"] = new_tier
	CareerManager.reputation_tier_changed.connect(callback, CONNECT_ONE_SHOT)

	CareerManager.apply_social_reputation("player_post")

	assert_true(captured.get("called", false))
	assert_eq(captured.get("old", ""), "unknown")
	assert_eq(captured.get("new", ""), "prospect")


func test_get_last_match_reputation_report_returns_payload() -> void:
	var result = {
		"goals": 0,
		"assists": 0,
		"won": true,
		"lost": false,
		"draw": false,
		"man_of_match": false,
		"clean_sheet": false,
		"yellow_cards": 0,
		"red_card": false,
		"rating": 7.0,
		"importance": 1.0
	}

	CareerManager.record_match_result(result)
	var report = CareerManager.get_last_match_reputation_report()

	assert_true(report.has("reputation_before"))
	assert_true(report.has("reputation_after"))
	assert_true(report.has("reputation_delta"))
	assert_true(report.has("reputation_breakdown"))


func test_generate_progression_offers_creates_fallback_offer_after_third_year() -> void:
	GameManager.player_data = PlayerData.new()
	GameManager.player_data.school_year = 3
	GameManager.player_data.career_difficulty = "normal"
	CareerManager.reputation = 10

	var offers = CareerManager.generate_progression_offers({})

	assert_false(offers.is_empty(), "Year 3 graduation should always produce at least one offer")
	assert_eq(str(offers[0].get("target_phase", -1)), str(GameManager.CareerPhase.YOUTH_ACADEMY))


func test_update_relationship_clamps_and_applies_positive_multiplier() -> void:
	GameManager.player_data = PlayerData.new()
	GameManager.player_data.background_story = "late_bloomer"

	var rel = CareerManager.update_relationship("npc_teammate", 10, 5, "teammate", "Teammate")

	assert_eq(int(rel.get("affinity", 0)), 11)
	assert_eq(int(rel.get("trust", 0)), 56)
