extends GutTest
## Unit tests for SocialFeedManager V2 feed behavior

var _original_team: TeamData
var _original_reputation: int = 0
var _original_social_day_key: String = ""
var _original_social_awarded_today: int = 0
var _original_social_actions_today: int = 0


func before_each() -> void:
	_original_team = GameManager.current_team
	_original_reputation = CareerManager.reputation
	_original_social_day_key = CareerManager.social_rep_day_key
	_original_social_awarded_today = CareerManager.social_rep_awarded_today
	_original_social_actions_today = CareerManager.social_rep_actions_today
	CareerManager.social_rep_day_key = ""
	CareerManager.social_rep_awarded_today = 0
	CareerManager.social_rep_actions_today = 0

	var test_team = TeamData.new()
	test_team.name = "Test High"
	test_team.players = [
		{"id": "npc_001", "name": "Takumi"}
	]
	GameManager.current_team = test_team

	SocialFeedManager.feed.clear()
	SocialFeedManager.feed_v2.clear()
	SocialFeedManager._next_post_id = 1
	SocialFeedManager._next_post_id_v2 = 1
	SocialFeedManager._reply_queue.clear()
	SocialFeedManager._reply_queue_v2.clear()
	SocialFeedManager._v2_recent_reply_keys.clear()
	SocialFeedManager._v2_last_reply_npc_by_thread.clear()
	SocialFeedManager._v2_first_npc_reply_awarded.clear()
	SocialFeedManager._v2_thread_engagement_awarded.clear()
	SocialFeedManager._v2_notification_day_by_post.clear()
	SocialFeedManager._v2_social_rep_day_key = SocialFeedManager._get_v2_day_key()
	SocialFeedManager._v2_social_rep_awarded_today = 0


func after_each() -> void:
	GameManager.current_team = _original_team
	CareerManager.reputation = _original_reputation
	CareerManager.social_rep_day_key = _original_social_day_key
	CareerManager.social_rep_awarded_today = _original_social_awarded_today
	CareerManager.social_rep_actions_today = _original_social_actions_today

	SocialFeedManager.feed.clear()
	SocialFeedManager.feed_v2.clear()
	SocialFeedManager._next_post_id = 1
	SocialFeedManager._next_post_id_v2 = 1
	SocialFeedManager._reply_queue.clear()
	SocialFeedManager._reply_queue_v2.clear()
	SocialFeedManager._v2_recent_reply_keys.clear()
	SocialFeedManager._v2_last_reply_npc_by_thread.clear()
	SocialFeedManager._v2_first_npc_reply_awarded.clear()
	SocialFeedManager._v2_thread_engagement_awarded.clear()
	SocialFeedManager._v2_notification_day_by_post.clear()
	SocialFeedManager._v2_social_rep_day_key = ""
	SocialFeedManager._v2_social_rep_awarded_today = 0


func test_normalize_match_result_tactical_schema() -> void:
	var normalized = SocialFeedManager._normalize_match_result_for_feed({
		"player_score": 2,
		"opponent_score": 1,
		"opponent_name": "Rival Academy"
	})

	assert_eq(normalized.player_score, 2)
	assert_eq(normalized.opponent_score, 1)
	assert_eq(normalized.opponent_name, "Rival Academy")
	assert_eq(normalized.result_type, "win")


func test_normalize_match_result_legacy_schema() -> void:
	var normalized = SocialFeedManager._normalize_match_result_for_feed({
		"player_team": "Test High",
		"opponent": "Legacy Opponent",
		"home_score": 0,
		"away_score": 3,
		"is_home": true
	})

	assert_eq(normalized.player_team_name, "Test High")
	assert_eq(normalized.opponent_name, "Legacy Opponent")
	assert_eq(normalized.player_score, 0)
	assert_eq(normalized.opponent_score, 3)
	assert_eq(normalized.result_type, "loss")


func test_get_feed_v2_latest_is_strict_chronological() -> void:
	var old_post = SocialFeedManager.create_post_v2(
		"news_article", "news", "FanZone", "news", "Older",
		{"likes": 30, "priority": 95}
	)
	var new_post = SocialFeedManager.create_post_v2(
		"player_post", "player", "You", "player", "Newer",
		{"likes": 1, "priority": 10}
	)

	old_post.timestamp = Time.get_unix_time_from_system() - (10 * 24 * 3600)
	new_post.timestamp = Time.get_unix_time_from_system()

	var latest = SocialFeedManager.get_feed_v2("all", "latest")
	assert_eq(latest[0].post_id, new_post.post_id, "Latest mode should be newest-first")


func test_get_feed_v2_top_uses_hybrid_relevance() -> void:
	var old_high_signal = SocialFeedManager.create_post_v2(
		"news_article", "news", "FanZone", "news", "Historic post",
		{"likes": 0, "priority": 95}
	)
	var new_low_signal = SocialFeedManager.create_post_v2(
		"player_post", "player", "You", "player", "Fresh post",
		{"likes": 1, "priority": 10}
	)

	old_high_signal.timestamp = Time.get_unix_time_from_system() - (10 * 24 * 3600)
	old_high_signal.likes = 30
	new_low_signal.timestamp = Time.get_unix_time_from_system()

	var top = SocialFeedManager.get_feed_v2("all", "top")
	assert_eq(top[0].post_id, old_high_signal.post_id, "Top mode should allow strong engagement/priority to outrank recency")
	assert_true(str(top[0].get("ranking_reason", "")) != "", "Top mode should provide ranking reason metadata")


func test_social_reputation_daily_cap() -> void:
	CareerManager.reputation = 10
	SocialFeedManager._v2_social_rep_day_key = SocialFeedManager._get_v2_day_key()
	SocialFeedManager._v2_social_rep_awarded_today = 0

	assert_true(SocialFeedManager._grant_v2_social_reputation(2, "test_1"))
	assert_true(SocialFeedManager._grant_v2_social_reputation(2, "test_2"))
	assert_true(SocialFeedManager._grant_v2_social_reputation(2, "test_3"))
	assert_false(SocialFeedManager._grant_v2_social_reputation(2, "test_4"))
	assert_eq(SocialFeedManager._v2_social_rep_awarded_today, 4, "Daily cap should stop further social reputation gains")
	assert_eq(CareerManager.reputation, 14, "Social gains should cap at +4/day")


func test_v2_reply_queue_dedupes_same_npc_per_thread_window() -> void:
	var post = SocialFeedManager.create_post_v2(
		"player_post", "player", "You", "player", "Thread starter",
		{"likes": 0}
	)

	SocialFeedManager._reply_queue_v2.clear()
	SocialFeedManager._queue_npc_replies_v2(post.post_id, "player_post")
	var initial_size = SocialFeedManager._reply_queue_v2.size()

	SocialFeedManager._queue_npc_replies_v2(post.post_id, "player_post")
	var deduped_size = SocialFeedManager._reply_queue_v2.size()

	assert_eq(initial_size, 1, "Single NPC candidate should queue exactly one reply")
	assert_eq(deduped_size, 1, "Second queue call within dedupe window should not enqueue duplicate reply")


func test_from_dict_bootstraps_v2_when_absent() -> void:
	SocialFeedManager.create_post("news_article", "news", "FanZone", "news", "Legacy post")
	var legacy_payload = {
		"feed": SocialFeedManager.feed.duplicate(true),
		"next_post_id": SocialFeedManager._next_post_id
	}

	SocialFeedManager.feed.clear()
	SocialFeedManager.feed_v2.clear()
	SocialFeedManager._next_post_id = 1
	SocialFeedManager._next_post_id_v2 = 1

	SocialFeedManager.from_dict(legacy_payload)

	assert_eq(SocialFeedManager.feed.size(), 1)
	assert_eq(SocialFeedManager.feed_v2.size(), 1, "V2 feed should bootstrap from V1 data when V2 payload is missing")
	assert_eq(SocialFeedManager.feed_v2[0].schema_version, SocialFeedManager.V2_SCHEMA_VERSION)
