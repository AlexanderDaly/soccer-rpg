extends GutTest
## Unit tests for SocialFeedManager


func before_each() -> void:
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


func after_each() -> void:
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


# ─── Post Creation ───────────────────────────────────────────────

func test_create_post_adds_to_feed() -> void:
	var post = SocialFeedManager.create_post(
		"npc_reaction", "npc_001", "Takumi", "teammate",
		"Great game today!"
	)

	assert_eq(SocialFeedManager.feed.size(), 1, "Feed should have 1 post")
	assert_eq(post.post_id, "post_1", "First post should have id post_1")
	assert_eq(post.content, "Great game today!")
	assert_eq(post.author_name, "Takumi")
	assert_eq(post.post_type, "npc_reaction")


func test_create_post_increments_id() -> void:
	SocialFeedManager.create_post("npc_reaction", "npc_001", "A", "teammate", "First")
	SocialFeedManager.create_post("npc_reaction", "npc_002", "B", "teammate", "Second")

	assert_eq(SocialFeedManager.feed[0].post_id, "post_2", "Newest should be first")
	assert_eq(SocialFeedManager.feed[1].post_id, "post_1", "Oldest should be second")


func test_feed_ordering_newest_first() -> void:
	SocialFeedManager.create_post("npc_reaction", "a", "A", "teammate", "First")
	SocialFeedManager.create_post("npc_reaction", "b", "B", "teammate", "Second")
	SocialFeedManager.create_post("npc_reaction", "c", "C", "teammate", "Third")

	assert_eq(SocialFeedManager.feed[0].content, "Third")
	assert_eq(SocialFeedManager.feed[1].content, "Second")
	assert_eq(SocialFeedManager.feed[2].content, "First")


func test_feed_cap_at_max_size() -> void:
	for i in range(SocialFeedManager.MAX_FEED_SIZE + 10):
		SocialFeedManager.create_post("npc_reaction", "npc", "NPC", "teammate", "Post %d" % i)

	assert_eq(SocialFeedManager.feed.size(), SocialFeedManager.MAX_FEED_SIZE,
		"Feed should be capped at MAX_FEED_SIZE")


func test_create_npc_post() -> void:
	# Create a post using the NPC helper
	var post = SocialFeedManager.create_npc_post("npc_test", "Hello!", "match_win", "happy")

	assert_eq(post.post_type, "npc_reaction")
	assert_eq(post.content, "Hello!")
	assert_eq(post.event_type, "match_win")
	assert_eq(post.mood, "happy")


func test_create_player_post() -> void:
	var post = SocialFeedManager.create_player_post("We got this team!")

	assert_eq(post.post_type, "player_post")
	assert_eq(post.author_id, "player")
	assert_eq(post.content, "We got this team!")


func test_v2_post_creation_does_not_change_v1_feed() -> void:
	SocialFeedManager.create_player_post("V1 post")
	SocialFeedManager.create_player_post_v2("V2 post")

	assert_eq(SocialFeedManager.feed.size(), 1, "V1 feed should remain unchanged by V2 posts")
	assert_eq(SocialFeedManager.feed_v2.size(), 1, "V2 feed should receive V2 post")


func test_post_default_values() -> void:
	var post = SocialFeedManager.create_post(
		"news_article", "news", "FanZone", "news", "Breaking news"
	)

	assert_eq(post.player_liked, false, "Should not be liked by default")
	assert_eq(post.replies.size(), 0, "Should have no replies by default")
	assert_true(post.has("timestamp"), "Should have timestamp")
	assert_true(post.has("date_string"), "Should have date string")
	assert_true(post.has("author_handle"), "Should have author handle")


# ─── Reply Threading ─────────────────────────────────────────────

func test_add_reply_to_post() -> void:
	var post = SocialFeedManager.create_post(
		"player_post", "player", "You", "player", "Let's go!"
	)

	var reply = SocialFeedManager.add_reply(
		post.post_id, "npc_001", "Takumi", "teammate", "Yeah!"
	)

	assert_eq(post.replies.size(), 1, "Post should have 1 reply")
	assert_eq(reply.content, "Yeah!")
	assert_eq(reply.author_name, "Takumi")
	assert_eq(reply.post_type, "reply")


func test_add_multiple_replies() -> void:
	var post = SocialFeedManager.create_post(
		"player_post", "player", "You", "player", "Let's go!"
	)

	SocialFeedManager.add_reply(post.post_id, "npc_001", "A", "teammate", "Reply 1")
	SocialFeedManager.add_reply(post.post_id, "npc_002", "B", "teammate", "Reply 2")
	SocialFeedManager.add_reply(post.post_id, "npc_003", "C", "teammate", "Reply 3")

	assert_eq(post.replies.size(), 3, "Post should have 3 replies")
	assert_eq(post.replies[0].content, "Reply 1")
	assert_eq(post.replies[2].content, "Reply 3")


func test_add_reply_to_nonexistent_post() -> void:
	var reply = SocialFeedManager.add_reply(
		"nonexistent", "npc_001", "A", "teammate", "Hello"
	)

	# Should return reply dict but not crash
	assert_eq(reply.content, "Hello")


func test_add_player_reply() -> void:
	var post = SocialFeedManager.create_post(
		"npc_reaction", "npc_001", "Takumi", "teammate", "Great day!"
	)

	var reply = SocialFeedManager.add_player_reply(post.post_id, "Thanks!")

	assert_eq(post.replies.size(), 1)
	assert_eq(reply.author_id, "player")
	assert_eq(reply.content, "Thanks!")


func test_reply_cap() -> void:
	var post = SocialFeedManager.create_post(
		"player_post", "player", "You", "player", "Test"
	)

	for i in range(SocialFeedManager.MAX_REPLIES_PER_POST + 5):
		SocialFeedManager.add_reply(post.post_id, "npc", "NPC", "teammate", "Reply %d" % i)

	assert_eq(post.replies.size(), SocialFeedManager.MAX_REPLIES_PER_POST,
		"Replies should be capped")


# ─── Like System ─────────────────────────────────────────────────

func test_toggle_like_on() -> void:
	var post = SocialFeedManager.create_post(
		"npc_reaction", "npc_001", "A", "teammate", "Hi",
		{"likes": 10}
	)

	SocialFeedManager.toggle_like(post.post_id)

	assert_eq(post.player_liked, true, "Should be liked after toggle")
	assert_eq(post.likes, 11, "Likes should increment")


func test_toggle_like_off() -> void:
	var post = SocialFeedManager.create_post(
		"npc_reaction", "npc_001", "A", "teammate", "Hi",
		{"likes": 10}
	)

	SocialFeedManager.toggle_like(post.post_id)
	SocialFeedManager.toggle_like(post.post_id)

	assert_eq(post.player_liked, false, "Should be unliked after double toggle")
	assert_eq(post.likes, 10, "Likes should return to original")


func test_toggle_like_nonexistent_post() -> void:
	# Should not crash
	SocialFeedManager.toggle_like("nonexistent")
	assert_true(true, "Should not crash on nonexistent post")


# ─── Feed Filtering ──────────────────────────────────────────────

func test_filter_all() -> void:
	SocialFeedManager.create_post("npc_reaction", "npc", "A", "teammate", "NPC post")
	SocialFeedManager.create_post("news_article", "news", "News", "news", "News post")
	SocialFeedManager.create_post("player_post", "player", "You", "player", "My post")

	var all_posts = SocialFeedManager.get_feed("all")
	assert_eq(all_posts.size(), 3, "All filter should return everything")


func test_filter_npc() -> void:
	SocialFeedManager.create_post("npc_reaction", "npc", "A", "teammate", "NPC post")
	SocialFeedManager.create_post("news_article", "news", "News", "news", "News post")
	SocialFeedManager.create_post("player_post", "player", "You", "player", "My post")

	var npc_posts = SocialFeedManager.get_feed("npc")
	assert_eq(npc_posts.size(), 1, "NPC filter should return 1 post")
	assert_eq(npc_posts[0].post_type, "npc_reaction")


func test_filter_news() -> void:
	SocialFeedManager.create_post("npc_reaction", "npc", "A", "teammate", "NPC post")
	SocialFeedManager.create_post("news_article", "news", "News", "news", "News post")
	SocialFeedManager.create_post("match_summary", "sys", "Match", "system", "Match")
	SocialFeedManager.create_post("season_update", "sys", "Season", "system", "Season")
	SocialFeedManager.create_post("injury_report", "sys", "Injury", "system", "Injury")

	var news_posts = SocialFeedManager.get_feed("news")
	assert_eq(news_posts.size(), 4, "News filter should include news, match, season, injury")


func test_filter_my_posts() -> void:
	SocialFeedManager.create_post("npc_reaction", "npc", "A", "teammate", "NPC post")
	SocialFeedManager.create_post("player_post", "player", "You", "player", "My post 1")
	SocialFeedManager.create_post("player_post", "player", "You", "player", "My post 2")

	var my_posts = SocialFeedManager.get_feed("my_posts")
	assert_eq(my_posts.size(), 2, "My posts filter should return 2 posts")


# ─── Post Lookup ─────────────────────────────────────────────────

func test_get_post_by_id() -> void:
	var post = SocialFeedManager.create_post(
		"npc_reaction", "npc", "A", "teammate", "Find me"
	)

	var found = SocialFeedManager.get_post_by_id(post.post_id)
	assert_eq(found.content, "Find me")


func test_get_post_by_id_not_found() -> void:
	var found = SocialFeedManager.get_post_by_id("nonexistent")
	assert_true(found.is_empty(), "Should return empty dict for missing post")


# ─── Handle Generation ───────────────────────────────────────────

func test_handle_generation_two_names() -> void:
	var post = SocialFeedManager.create_post(
		"npc_reaction", "npc", "Takumi Yamada", "teammate", "Test"
	)
	assert_eq(post.author_handle, "@t_yamada")


func test_handle_generation_player() -> void:
	var post = SocialFeedManager.create_post(
		"player_post", "player", "You", "player", "Test"
	)
	assert_eq(post.author_handle, "@you")


func test_handle_generation_news() -> void:
	var post = SocialFeedManager.create_post(
		"news_article", "news", "FanZone News", "news", "Test"
	)
	assert_eq(post.author_handle, "@fanzone")


# ─── NPC Text Generation ────────────────────────────────────────

func test_generate_npc_text_returns_string() -> void:
	var text = SocialFeedManager._generate_npc_text("nonexistent_npc", "match_win")
	assert_true(text is String, "Should return a string")
	assert_true(text.length() > 0, "Should not be empty")


func test_map_traits_to_personality() -> void:
	var traits_passionate: Array[String] = ["emotional", "inspiring"]
	assert_eq(SocialFeedManager._map_traits_to_personality(traits_passionate), "passionate")

	var traits_leader: Array[String] = ["commanding", "protective"]
	assert_eq(SocialFeedManager._map_traits_to_personality(traits_leader), "leader")

	var traits_calm: Array[String] = ["composed", "analytical"]
	assert_eq(SocialFeedManager._map_traits_to_personality(traits_calm), "calm")

	var traits_unknown: Array[String] = ["mysterious", "enigmatic"]
	assert_eq(SocialFeedManager._map_traits_to_personality(traits_unknown), "reliable",
		"Unknown traits should fallback to reliable")


# ─── Welcome Post ────────────────────────────────────────────────

func test_ensure_welcome_post_on_empty_feed() -> void:
	SocialFeedManager.ensure_welcome_post()

	assert_eq(SocialFeedManager.feed.size(), 1, "Should add welcome post")
	assert_eq(SocialFeedManager.feed[0].post_type, "news_article")
	assert_true(SocialFeedManager.feed[0].content.contains("New Star"))


func test_ensure_welcome_post_not_duplicated() -> void:
	SocialFeedManager.ensure_welcome_post()
	SocialFeedManager.ensure_welcome_post()

	assert_eq(SocialFeedManager.feed.size(), 1, "Should not duplicate welcome post")


# ─── Serialization ───────────────────────────────────────────────

func test_serialization_round_trip() -> void:
	# Create some posts
	SocialFeedManager.create_post("npc_reaction", "npc_001", "Takumi", "teammate", "Hello!")
	var post = SocialFeedManager.create_post("player_post", "player", "You", "player", "Testing")
	SocialFeedManager.add_reply(post.post_id, "npc_002", "Ren", "teammate", "Nice post!")
	SocialFeedManager.toggle_like(post.post_id)

	# Serialize
	var data = SocialFeedManager.to_dict()

	# Clear and restore
	SocialFeedManager.feed.clear()
	SocialFeedManager._next_post_id = 1
	assert_eq(SocialFeedManager.feed.size(), 0)

	SocialFeedManager.from_dict(data)

	# Verify restoration
	assert_eq(SocialFeedManager.feed.size(), 2, "Should restore 2 posts")
	assert_eq(SocialFeedManager._next_post_id, data.next_post_id, "Should restore post ID counter")

	# Check post content preserved
	var restored_post = SocialFeedManager.get_post_by_id(post.post_id)
	assert_eq(restored_post.content, "Testing")
	assert_eq(restored_post.player_liked, true, "Like state should be preserved")
	assert_eq(restored_post.replies.size(), 1, "Replies should be preserved")
	assert_eq(restored_post.replies[0].content, "Nice post!")


func test_serialization_empty_feed() -> void:
	var data = SocialFeedManager.to_dict()
	assert_eq(data.feed.size(), 0)
	assert_eq(data.next_post_id, 1)

	SocialFeedManager.from_dict(data)
	assert_eq(SocialFeedManager.feed.size(), 0)


# ─── Match Event ─────────────────────────────────────────────────

func test_on_match_ended_creates_posts() -> void:
	var result = {
		"player_team": "Test High",
		"opponent": "Rival Academy",
		"home_score": 3,
		"away_score": 1,
		"is_home": true
	}

	SocialFeedManager.on_match_ended(result)

	# Should create at least a match summary and a news article
	var has_summary = false
	var has_news = false
	for post in SocialFeedManager.feed:
		if post.post_type == "match_summary":
			has_summary = true
			assert_true(post.content.contains("3-1"), "Score should be in summary")
		if post.post_type == "news_article":
			has_news = true

	assert_true(has_summary, "Should create match summary post")
	assert_true(has_news, "Should create news article")


func test_on_match_ended_loss() -> void:
	var result = {
		"player_team": "Test High",
		"opponent": "Strong School",
		"home_score": 0,
		"away_score": 2,
		"is_home": true
	}

	SocialFeedManager.on_match_ended(result)

	var summary = null
	for post in SocialFeedManager.feed:
		if post.post_type == "match_summary":
			summary = post
			break

	assert_not_null(summary, "Should have match summary")
	assert_eq(summary.mood, "sad", "Loss should have sad mood")


func test_on_match_ended_draw() -> void:
	var result = {
		"player_team": "Test High",
		"opponent": "Equal FC",
		"home_score": 1,
		"away_score": 1,
		"is_home": true
	}

	SocialFeedManager.on_match_ended(result)

	var summary = null
	for post in SocialFeedManager.feed:
		if post.post_type == "match_summary":
			summary = post
			break

	assert_not_null(summary, "Should have match summary")
	assert_eq(summary.mood, "neutral", "Draw should have neutral mood")
