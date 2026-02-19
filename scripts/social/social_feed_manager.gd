extends Node
## SocialFeedManager - Manages the in-game social media feed (FanZone)
##
## Owns feed data, subscribes to game event signals, generates NPC posts
## using persona data, handles player posts/replies, queues NPC auto-replies.

signal post_added(post: Dictionary)
signal reply_added(parent_post_id: String, reply: Dictionary)
signal feed_refreshed()

const MAX_FEED_SIZE := 100
const MAX_REPLIES_PER_POST := 20

# Feed storage - newest first
var feed: Array[Dictionary] = []

# Post ID counter
var _next_post_id: int = 1

# NPC auto-reply queue
var _reply_queue: Array[Dictionary] = []  # [{parent_post_id, npc_id, delay}]
var _reply_timer: Timer

# Post type constants
enum PostType {
	NPC_REACTION,
	NEWS_ARTICLE,
	FAN_REACTION,
	MATCH_SUMMARY,
	MILESTONE,
	PLAYER_POST,
	SEASON_UPDATE,
	INJURY_REPORT
}

const POST_TYPE_NAMES := {
	PostType.NPC_REACTION: "npc_reaction",
	PostType.NEWS_ARTICLE: "news_article",
	PostType.FAN_REACTION: "fan_reaction",
	PostType.MATCH_SUMMARY: "match_summary",
	PostType.MILESTONE: "milestone",
	PostType.PLAYER_POST: "player_post",
	PostType.SEASON_UPDATE: "season_update",
	PostType.INJURY_REPORT: "injury_report"
}

# Template pools for NPC text generation by {event}_{personality}
const NPC_TEMPLATES := {
	# Match win reactions
	"match_win_passionate": [
		"YESSS!! What a match! That's the kind of fire we need!",
		"We did it!! I'm still buzzing from that game!",
		"THIS is what soccer is all about! Amazing team effort!"
	],
	"match_win_leader": [
		"Great performance from everyone today. We executed the plan perfectly.",
		"The team showed real character out there. Proud of every one of you.",
		"Solid win. But we can't get complacent - next match starts now."
	],
	"match_win_calm": [
		"A well-deserved result. The preparation paid off.",
		"Good game. We controlled the tempo well today.",
		"Steady performance. That's how you build consistency."
	],
	"match_win_hardworker": [
		"All that extra training paid off today!",
		"We earned that win with blood and sweat. Every drill was worth it.",
		"Hard work gets results. Simple as that."
	],
	"match_win_creative": [
		"Beautiful goals, beautiful passing - that was art on the pitch!",
		"The pitch was our canvas today and we painted a masterpiece!",
		"Did you SEE that combination play? Poetry in motion!"
	],
	"match_win_aggressive": [
		"We crushed them! That's how you dominate!",
		"They couldn't handle us. Total domination!",
		"That's what happens when you come at us. Get wrecked!"
	],
	"match_win_reliable": [
		"Another solid win for the team. Consistency is key.",
		"We all did our jobs today. That's how you get results.",
		"A good team performance. Everyone played their part."
	],
	# Match loss reactions
	"match_loss_passionate": [
		"I can't believe we lost... We gave everything out there!",
		"This hurts so much... But we'll come back stronger, I swear it!",
		"Ugh, what a painful result. We can't let this break us!"
	],
	"match_loss_leader": [
		"Tough loss. We need to regroup and learn from our mistakes.",
		"We fell short today. I take responsibility. We'll fix this.",
		"Not our day. But a true team bounces back. We go again."
	],
	"match_loss_calm": [
		"Disappointing result, but there are lessons to take from this.",
		"We lost control of the match in key moments. We'll analyze and adjust.",
		"These things happen. What matters is how we respond."
	],
	"match_loss_hardworker": [
		"We didn't work hard enough. Back to the training ground.",
		"No excuses. We need to train harder and do better.",
		"Losses like this make you stronger. Time to get to work."
	],
	"match_loss_creative": [
		"Nothing clicked today... the rhythm just wasn't there.",
		"We couldn't find our flow. Some days the magic doesn't come.",
		"Frustrating. We had ideas but couldn't execute them."
	],
	"match_loss_aggressive": [
		"This is unacceptable! We need to fight harder!",
		"I'm furious. We let them walk all over us!",
		"No way I'm accepting this. Next time we crush them."
	],
	"match_loss_reliable": [
		"A setback, but not the end. We'll come back.",
		"Tough day. We need to stick to our strengths.",
		"We weren't ourselves today. Back to basics."
	],
	# Match draw reactions
	"match_draw_passionate": [
		"So close! A draw feels like a loss when you want it that badly!",
		"We almost had it! The passion was there, just needed one more goal!"
	],
	"match_draw_leader": [
		"A point gained or two dropped - depends on perspective. We move on.",
		"We showed resilience to not lose. Now let's work on winning."
	],
	"match_draw_calm": [
		"A fair result given how the match played out.",
		"Both teams had chances. A draw was reasonable."
	],
	"match_draw_hardworker": [
		"We fought hard but couldn't get the winner. More work needed.",
		"Close but not enough. We'll get there with more effort."
	],
	"match_draw_creative": [
		"We had some nice moments but couldn't find the finishing touch.",
		"The ideas were there, execution let us down in the final third."
	],
	"match_draw_aggressive": [
		"A draw?! We should've buried them! So frustrating!",
		"Not good enough. We had chances to finish it."
	],
	"match_draw_reliable": [
		"A draw isn't ideal but it's a point. We keep building.",
		"Decent effort from the team. We'll take it and improve."
	],
	# Goal reactions
	"goal_scored_passionate": [
		"GOOOAAAL!! What a strike! I'm screaming!",
		"GET IN!! That's what dreams are made of!"
	],
	"goal_scored_leader": [
		"Clinical finish. That's exactly what we needed.",
		"Great goal. The whole team built up to that moment."
	],
	"goal_scored_calm": [
		"Well taken. Good composure in front of goal.",
		"Nice goal. Kept it simple and effective."
	],
	# Injury reactions
	"injury_teammate_passionate": [
		"No!! Please be okay... We're all behind you!",
		"Get well soon! The team isn't the same without you!"
	],
	"injury_teammate_leader": [
		"Rest up and recover properly. We'll hold the fort.",
		"Take the time you need. The team will cover for you."
	],
	"injury_teammate_calm": [
		"Wishing a speedy recovery. Focus on rehab.",
		"Get well soon. Take it one day at a time."
	],
	"injury_teammate_hardworker": [
		"Stay strong! You'll come back even tougher!",
		"Recovery is just another form of training. You got this!"
	],
	"injury_teammate_reliable": [
		"We'll miss you out there. Get well soon!",
		"Hope it's nothing serious. Take care of yourself."
	],
	# Recovery reactions
	"recovery_passionate": [
		"WELCOME BACK!! We missed you so much!",
		"You're back!! The team is complete again!"
	],
	"recovery_leader": [
		"Good to have you back. Take it easy at first.",
		"Welcome back. We saved your spot."
	],
	"recovery_calm": [
		"Glad to see you recovered. Welcome back.",
		"Good to have you back in the squad."
	],
	# Milestone reactions
	"milestone_passionate": [
		"INCREDIBLE! What an achievement! So proud!",
		"You absolute legend! This is historic!"
	],
	"milestone_leader": [
		"Well deserved. You've earned this through hard work.",
		"Congratulations. A milestone like this inspires the whole team."
	],
	"milestone_calm": [
		"Impressive achievement. Congratulations.",
		"Well earned. Your consistency speaks for itself."
	],
	# Player post reactions (for NPC auto-replies)
	"player_post_passionate": [
		"Love the energy! That's what I'm talking about!",
		"YES! This is the spirit we need!",
		"You always know how to fire up the team!"
	],
	"player_post_leader": [
		"Well said. The team appreciates your words.",
		"Good point. Let's use that motivation.",
		"Couldn't agree more."
	],
	"player_post_calm": [
		"Noted. Good thoughts.",
		"I see your point. Makes sense.",
		"Fair enough. Interesting perspective."
	],
	"player_post_hardworker": [
		"Actions speak louder but I like the sentiment!",
		"Let's back that up with results on the pitch!",
		"Nice post! Now let's go train!"
	],
	"player_post_creative": [
		"Haha, love it! You've got a way with words!",
		"Poetic! Almost as good as a nutmeg!",
		"That's the vibe! Keep it coming!"
	],
	"player_post_aggressive": [
		"Let's GO! That's the attitude!",
		"Now THAT'S what I want to hear!",
		"Talk is cheap but I like your fire!"
	],
	"player_post_reliable": [
		"Good post! The team vibes are strong.",
		"Nice one! Always good to hear from you.",
		"Agreed. We're all in this together."
	]
}

# Fan reaction templates
const FAN_TEMPLATES := {
	"match_win": [
		"What a game! These kids are going places!",
		"Incredible match! So proud of our team!",
		"That was exciting! Can't wait for the next one!",
		"Our boys played their hearts out today!"
	],
	"match_loss": [
		"Tough loss but they'll bounce back!",
		"Keep your heads up, team! We believe in you!",
		"Not our day, but the effort was there.",
		"Growing pains. This team has potential."
	],
	"match_draw": [
		"So close! Next time we'll get the win!",
		"A fair result. The team is improving!",
		"Good fight from our boys today!"
	],
	"milestone": [
		"History in the making! What a talent!",
		"Congratulations! The whole school is proud!",
		"A star is born! Remember this moment!"
	],
	"general": [
		"Go team! We're behind you all the way!",
		"Can't wait for the next match!",
		"The future is bright for this squad!"
	]
}

# News headline templates
const NEWS_TEMPLATES := {
	"match_win": [
		{"headline": "%s Claims Victory Over %s!", "body": "In a commanding display, %s defeated %s %s in their latest fixture. The team continues to build momentum as the season progresses."},
		{"headline": "Impressive Win for %s!", "body": "%s put on a strong performance to beat %s %s. The coaching staff will be pleased with the team's execution."}
	],
	"match_loss": [
		{"headline": "%s Fall to %s in Tough Contest", "body": "Despite a spirited effort, %s went down %s to %s. The team will look to bounce back in their next outing."},
		{"headline": "Setback for %s Against %s", "body": "%s suffered a %s defeat to %s. The coaching staff will be working hard to address the issues before the next match."}
	],
	"match_draw": [
		{"headline": "%s and %s Share the Spoils", "body": "An evenly contested match between %s and %s ended %s. Both teams had chances but neither could find a winner."}
	],
	"qualification": [
		{"headline": "HISTORIC! %s Qualifies for Nationals!", "body": "In an incredible achievement, %s has secured their place in the National Championship. The school is buzzing with excitement as the team prepares for the biggest stage."}
	],
	"season_end": [
		{"headline": "%s Season Comes to an End", "body": "The season has concluded for %s. It's been a journey of growth, challenges, and unforgettable moments. The team will regroup during the off-season."}
	]
}


func _ready() -> void:
	print("[SocialFeedManager] Initialized")
	_setup_reply_timer()
	_connect_signals()


func _setup_reply_timer() -> void:
	_reply_timer = Timer.new()
	_reply_timer.one_shot = true
	_reply_timer.timeout.connect(_process_reply_queue)
	add_child(_reply_timer)


func _connect_signals() -> void:
	# Season signals
	if SeasonManager:
		if SeasonManager.has_signal("phase_changed"):
			SeasonManager.phase_changed.connect(_on_phase_changed)
		if SeasonManager.has_signal("league_standings_updated"):
			SeasonManager.league_standings_updated.connect(_on_standings_updated)
		if SeasonManager.has_signal("player_qualified_for_nationals"):
			SeasonManager.player_qualified_for_nationals.connect(_on_qualified_for_nationals)
		if SeasonManager.has_signal("season_completed"):
			SeasonManager.season_completed.connect(_on_season_completed)

	# Career signals
	if CareerManager:
		if CareerManager.has_signal("milestone_reached"):
			CareerManager.milestone_reached.connect(_on_milestone_reached)

	# NPC signals
	if NpcRegistry:
		if NpcRegistry.has_signal("npc_injured"):
			NpcRegistry.npc_injured.connect(_on_npc_injured)
		if NpcRegistry.has_signal("npc_recovered"):
			NpcRegistry.npc_recovered.connect(_on_npc_recovered)

	# Narrative signals
	if NarrativeEngine:
		if NarrativeEngine.has_signal("news_article_generated"):
			NarrativeEngine.news_article_generated.connect(_on_narrative_news_article)


# ─── Post Creation ───────────────────────────────────────────────

func create_post(post_type_name: String, author_id: String, author_name: String,
		author_role: String, content: String, extra: Dictionary = {}) -> Dictionary:
	var post = {
		"post_id": "post_%d" % _next_post_id,
		"post_type": post_type_name,
		"author_id": author_id,
		"author_name": author_name,
		"author_role": author_role,
		"author_handle": _generate_handle(author_name),
		"content": content,
		"timestamp": Time.get_unix_time_from_system(),
		"date_string": _get_date_string(),
		"likes": extra.get("likes", 0),
		"player_liked": false,
		"replies": [],
		"event_type": extra.get("event_type", ""),
		"mood": extra.get("mood", "neutral")
	}

	# Merge any extra display data
	for key in ["score", "headline", "body", "source", "milestone_name"]:
		if key in extra:
			post[key] = extra[key]

	_next_post_id += 1
	_add_to_feed(post)
	return post


func create_npc_post(npc_id: String, content: String, event_type: String = "", mood: String = "neutral") -> Dictionary:
	var npc_data = _get_npc_display_data(npc_id)
	return create_post(
		POST_TYPE_NAMES[PostType.NPC_REACTION],
		npc_id, npc_data.name, npc_data.role, content,
		{"event_type": event_type, "mood": mood, "likes": randi_range(5, 50)}
	)


func create_player_post(content: String) -> Dictionary:
	var player_name = "You"
	if GameManager.player_data:
		player_name = GameManager.player_data.name if GameManager.player_data.name != "" else "You"

	var post = create_post(
		POST_TYPE_NAMES[PostType.PLAYER_POST],
		"player", player_name, "player", content,
		{"likes": randi_range(10, 80)}
	)

	# Queue NPC auto-replies
	_queue_npc_replies(post.post_id, "player_post")
	return post


func add_reply(parent_post_id: String, author_id: String, author_name: String,
		author_role: String, content: String) -> Dictionary:
	var reply = {
		"post_id": "reply_%d" % _next_post_id,
		"post_type": "reply",
		"author_id": author_id,
		"author_name": author_name,
		"author_role": author_role,
		"author_handle": _generate_handle(author_name),
		"content": content,
		"timestamp": Time.get_unix_time_from_system(),
		"date_string": _get_date_string(),
		"likes": 0,
		"player_liked": false
	}
	_next_post_id += 1

	# Find parent post and add reply
	for post in feed:
		if post.post_id == parent_post_id:
			if post.replies.size() < MAX_REPLIES_PER_POST:
				post.replies.append(reply)
			reply_added.emit(parent_post_id, reply)
			return reply

	return reply


func add_player_reply(parent_post_id: String, content: String) -> Dictionary:
	var player_name = "You"
	if GameManager.player_data:
		player_name = GameManager.player_data.name if GameManager.player_data.name != "" else "You"

	var reply = add_reply(parent_post_id, "player", player_name, "player", content)

	# Queue NPC auto-replies to the thread
	_queue_npc_replies(parent_post_id, "player_post")
	return reply


# ─── Like System ─────────────────────────────────────────────────

func toggle_like(post_id: String) -> void:
	var post = get_post_by_id(post_id)
	if post.is_empty():
		# Check replies
		for p in feed:
			for r in p.replies:
				if r.post_id == post_id:
					r.player_liked = !r.player_liked
					r.likes += 1 if r.player_liked else -1
					return
		return

	post.player_liked = !post.player_liked
	post.likes += 1 if post.player_liked else -1


# ─── Feed Access ─────────────────────────────────────────────────

func get_feed(filter: String = "all") -> Array[Dictionary]:
	if filter == "all":
		return feed

	var filtered: Array[Dictionary] = []
	for post in feed:
		match filter:
			"npc":
				if post.post_type == "npc_reaction":
					filtered.append(post)
			"news":
				if post.post_type in ["news_article", "match_summary", "season_update", "injury_report"]:
					filtered.append(post)
			"my_posts":
				if post.author_id == "player":
					filtered.append(post)
			"milestones":
				if post.post_type == "milestone":
					filtered.append(post)
	return filtered


func get_post_by_id(post_id: String) -> Dictionary:
	for post in feed:
		if post.post_id == post_id:
			return post
	return {}


# ─── NPC Text Generation ────────────────────────────────────────

func _generate_npc_text(npc_id: String, event_key: String) -> String:
	var persona = PersonaManager.get_persona(npc_id) if PersonaManager else null
	var personality = "reliable"  # fallback

	if persona and not persona.personality_traits.is_empty():
		# Map persona traits to our template personality categories
		personality = _map_traits_to_personality(persona.personality_traits)

	# Try specific template
	var template_key = "%s_%s" % [event_key, personality]
	if template_key in NPC_TEMPLATES:
		var templates = NPC_TEMPLATES[template_key]
		return templates[randi() % templates.size()]

	# Fallback: try event with "reliable" personality
	var fallback_key = "%s_reliable" % event_key
	if fallback_key in NPC_TEMPLATES:
		var templates = NPC_TEMPLATES[fallback_key]
		return templates[randi() % templates.size()]

	# Final fallback - use catchphrase if available
	if persona and not persona.catchphrases.is_empty():
		return persona.catchphrases[randi() % persona.catchphrases.size()]

	return "Great effort from the team today!"


func _map_traits_to_personality(traits: Array[String]) -> String:
	# Map persona traits to template personality categories
	var trait_map = {
		"commanding": "leader", "protective": "leader", "responsible": "leader",
		"diligent": "hardworker", "humble": "hardworker", "persistent": "hardworker", "disciplined": "hardworker",
		"imaginative": "creative", "unpredictable": "creative", "expressive": "creative", "intuitive": "creative",
		"intense": "aggressive", "competitive": "aggressive", "fearless": "aggressive",
		"composed": "calm", "analytical": "calm", "patient": "calm", "steady": "calm",
		"emotional": "passionate", "inspiring": "passionate", "dramatic": "passionate", "wholehearted": "passionate",
		"consistent": "reliable", "trustworthy": "reliable", "supportive": "reliable", "dependable": "reliable"
	}

	for trait in traits:
		var lower_trait = trait.to_lower()
		if lower_trait in trait_map:
			return trait_map[lower_trait]

	return "reliable"


func _get_npc_display_data(npc_id: String) -> Dictionary:
	var data = {"name": "Unknown", "role": "teammate", "position": ""}

	# Try NPC registry first
	if NpcRegistry and NpcRegistry.has_npc(npc_id):
		var npc = NpcRegistry.get_npc(npc_id)
		data.name = npc.get("name", "Unknown")
		data.position = npc.get("position", "")

	# Try persona for role
	if PersonaManager and PersonaManager.has_persona(npc_id):
		var persona = PersonaManager.get_persona(npc_id)
		if persona:
			data.role = persona.role
			if data.name == "Unknown":
				data.name = persona.name

	# Determine if teammate or rival
	if GameManager.current_team:
		var player = GameManager.current_team.get_player_by_id(npc_id)
		if not player.is_empty():
			data.role = "teammate"
			data.name = player.get("name", data.name)
			data.position = player.get("position", data.position)
		else:
			if data.role == "teammate":
				data.role = "rival"  # Not on our team

	return data


# ─── NPC Auto-Reply Queue ───────────────────────────────────────

func _queue_npc_replies(parent_post_id: String, event_key: String) -> void:
	var npcs = _select_replying_npcs()

	for i in range(npcs.size()):
		_reply_queue.append({
			"parent_post_id": parent_post_id,
			"npc_id": npcs[i],
			"event_key": event_key,
			"delay": 2.0 if i == 0 else randf_range(1.5, 3.0)
		})

	if not _reply_queue.is_empty() and _reply_timer.is_stopped():
		_reply_timer.start(_reply_queue[0].delay)


func _select_replying_npcs() -> Array[String]:
	var candidates: Array[String] = []

	# Get teammates from current team
	if GameManager.current_team:
		for player in GameManager.current_team.players:
			var pid = player.get("id", "")
			if pid != "" and pid != "player":
				candidates.append(pid)

	if candidates.is_empty():
		return []

	# Shuffle and select 1-3 NPCs, preferring passionate/leader types
	candidates.shuffle()
	var count = mini(randi_range(1, 3), candidates.size())
	var selected: Array[String] = []

	# Priority pass: pick passionate/leader personalities first
	for npc_id in candidates:
		if selected.size() >= count:
			break
		var persona = PersonaManager.get_persona(npc_id) if PersonaManager else null
		if persona:
			var personality = _map_traits_to_personality(persona.personality_traits)
			if personality in ["passionate", "leader", "aggressive"]:
				selected.append(npc_id)

	# Fill remaining slots randomly
	for npc_id in candidates:
		if selected.size() >= count:
			break
		if npc_id not in selected:
			selected.append(npc_id)

	return selected


func _process_reply_queue() -> void:
	if _reply_queue.is_empty():
		return

	var item = _reply_queue.pop_front()
	var npc_data = _get_npc_display_data(item.npc_id)
	var text = _generate_npc_text(item.npc_id, item.event_key)

	add_reply(item.parent_post_id, item.npc_id, npc_data.name, npc_data.role, text)

	# Schedule next reply if queue has more
	if not _reply_queue.is_empty():
		_reply_timer.start(_reply_queue[0].delay)


# ─── Event Handlers ──────────────────────────────────────────────

func on_match_ended(result: Dictionary) -> void:
	var player_team_name = result.get("player_team", "Our Team")
	var opponent_name = result.get("opponent", "Opponent")
	var home_score = result.get("home_score", 0)
	var away_score = result.get("away_score", 0)
	var is_home = result.get("is_home", true)

	var player_score = home_score if is_home else away_score
	var opponent_score = away_score if is_home else home_score
	var score_str = "%d-%d" % [player_score, opponent_score]

	# Determine result type
	var result_type = "draw"
	var mood = "neutral"
	if player_score > opponent_score:
		result_type = "win"
		mood = "happy"
	elif player_score < opponent_score:
		result_type = "loss"
		mood = "sad"

	# Match summary post
	var summary_content = "%s %s %s" % [player_team_name, score_str, opponent_name]
	if result_type == "win":
		summary_content += " - Victory!"
	elif result_type == "loss":
		summary_content += " - Defeat"
	else:
		summary_content += " - Draw"

	create_post(
		POST_TYPE_NAMES[PostType.MATCH_SUMMARY],
		"system", "Match Report", "system", summary_content,
		{"event_type": "match_" + result_type, "mood": mood,
		 "score": score_str, "likes": randi_range(30, 150)}
	)

	# NPC reactions (2-4 from teammates)
	var event_key = "match_" + result_type
	_generate_npc_event_posts(event_key, mood, randi_range(2, 4))

	# Fan reactions (0-2)
	var fan_count = randi_range(0, 2)
	for i in range(fan_count):
		var fan_templates = FAN_TEMPLATES.get("match_" + result_type, FAN_TEMPLATES["general"])
		var fan_text = fan_templates[randi() % fan_templates.size()]
		create_post(
			POST_TYPE_NAMES[PostType.FAN_REACTION],
			"fan_%d" % randi(), "Soccer Fan", "fan", fan_text,
			{"event_type": event_key, "mood": mood, "likes": randi_range(2, 20)}
		)

	# News article
	var news_list = NEWS_TEMPLATES.get("match_" + result_type, [])
	if not news_list.is_empty():
		var template = news_list[randi() % news_list.size()]
		var headline = ""
		var body = ""
		match result_type:
			"win":
				headline = template.headline % [player_team_name, opponent_name]
				body = template.body % [player_team_name, opponent_name, score_str]
			"loss":
				headline = template.headline % [player_team_name, opponent_name]
				body = template.body % [player_team_name, score_str, opponent_name]
			"draw":
				headline = template.headline % [player_team_name, opponent_name]
				body = template.body % [player_team_name, opponent_name, score_str]

		create_post(
			POST_TYPE_NAMES[PostType.NEWS_ARTICLE],
			"news", "FanZone News", "news", headline,
			{"headline": headline, "body": body, "source": "FanZone Sports Desk",
			 "event_type": event_key, "likes": randi_range(20, 100)}
		)


func _on_phase_changed(new_phase: int) -> void:
	var phase_names = {
		0: "Pre-Season",
		1: "League Stage",
		2: "Qualifiers",
		3: "Nationals",
		4: "Post-Season"
	}
	var phase_name = phase_names.get(new_phase, "New Phase")

	create_post(
		POST_TYPE_NAMES[PostType.SEASON_UPDATE],
		"system", "Season Update", "system",
		"The %s has begun! A new chapter of our journey starts now." % phase_name,
		{"event_type": "phase_changed", "mood": "excited", "likes": randi_range(15, 60)}
	)


func _on_standings_updated(_standings: Array[Dictionary]) -> void:
	pass  # Could add periodic standings update posts


func _on_qualified_for_nationals() -> void:
	var team_name = "Our Team"
	if GameManager.current_team:
		team_name = GameManager.current_team.name

	# Milestone post
	create_post(
		POST_TYPE_NAMES[PostType.MILESTONE],
		"system", "Achievement", "system",
		"QUALIFIED FOR NATIONALS! %s is heading to the National Championship!" % team_name,
		{"event_type": "qualification", "mood": "ecstatic",
		 "milestone_name": "National Qualification", "likes": randi_range(100, 300)}
	)

	# NPC celebrations (3-5)
	_generate_npc_event_posts("milestone", "ecstatic", randi_range(3, 5))

	# Fan reactions (2-3)
	var fan_templates = FAN_TEMPLATES["milestone"]
	for i in range(randi_range(2, 3)):
		create_post(
			POST_TYPE_NAMES[PostType.FAN_REACTION],
			"fan_%d" % randi(), "Excited Fan", "fan",
			fan_templates[randi() % fan_templates.size()],
			{"event_type": "qualification", "mood": "ecstatic", "likes": randi_range(10, 50)}
		)

	# News article
	var news_list = NEWS_TEMPLATES["qualification"]
	if not news_list.is_empty():
		var template = news_list[randi() % news_list.size()]
		create_post(
			POST_TYPE_NAMES[PostType.NEWS_ARTICLE],
			"news", "FanZone News", "news",
			template.headline % team_name,
			{"headline": template.headline % team_name, "body": template.body % team_name,
			 "source": "FanZone Sports Desk", "event_type": "qualification",
			 "likes": randi_range(50, 200)}
		)


func _on_season_completed(summary: Dictionary) -> void:
	var team_name = "Our Team"
	if GameManager.current_team:
		team_name = GameManager.current_team.name

	create_post(
		POST_TYPE_NAMES[PostType.SEASON_UPDATE],
		"system", "Season Update", "system",
		"The season has come to an end for %s. What a journey it's been!" % team_name,
		{"event_type": "season_end", "mood": "reflective", "likes": randi_range(30, 100)}
	)

	# News article
	var news_list = NEWS_TEMPLATES["season_end"]
	if not news_list.is_empty():
		var template = news_list[randi() % news_list.size()]
		create_post(
			POST_TYPE_NAMES[PostType.NEWS_ARTICLE],
			"news", "FanZone News", "news",
			template.headline % team_name,
			{"headline": template.headline % team_name, "body": template.body % team_name,
			 "source": "FanZone Sports Desk", "event_type": "season_end",
			 "likes": randi_range(30, 120)}
		)


func _on_milestone_reached(milestone: String) -> void:
	var player_name = "Our Star"
	if GameManager.player_data:
		player_name = GameManager.player_data.name if GameManager.player_data.name != "" else "Our Star"

	create_post(
		POST_TYPE_NAMES[PostType.MILESTONE],
		"system", "Achievement", "system",
		"%s reached a new milestone: %s!" % [player_name, milestone.replace("_", " ").capitalize()],
		{"event_type": "milestone", "mood": "proud",
		 "milestone_name": milestone, "likes": randi_range(40, 150)}
	)

	# NPC congratulations (1-2)
	_generate_npc_event_posts("milestone", "proud", randi_range(1, 2))


func _on_npc_injured(npc_id: String, injury: Dictionary) -> void:
	var npc_data = _get_npc_display_data(npc_id)
	var matches_out = injury.get("matches_remaining", 0)
	var description = injury.get("description", "injury")

	create_post(
		POST_TYPE_NAMES[PostType.INJURY_REPORT],
		"system", "Medical Update", "system",
		"%s has suffered a %s and will miss %d match%s." % [
			npc_data.name, description, matches_out,
			"es" if matches_out != 1 else ""
		],
		{"event_type": "injury", "mood": "concerned", "likes": randi_range(10, 40)}
	)

	# Get-well NPC posts (1-2)
	_generate_npc_injury_posts(npc_id, randi_range(1, 2))


func _on_npc_recovered(npc_id: String) -> void:
	var npc_data = _get_npc_display_data(npc_id)

	create_post(
		POST_TYPE_NAMES[PostType.NPC_REACTION],
		npc_id, npc_data.name, npc_data.role,
		"I'm back! Feeling good and ready to play again!",
		{"event_type": "recovery", "mood": "happy", "likes": randi_range(15, 60)}
	)

	# Welcome-back posts (1-2)
	_generate_npc_recovery_posts(npc_id, randi_range(1, 2))


func _on_narrative_news_article(article: Dictionary) -> void:
	create_post(
		POST_TYPE_NAMES[PostType.NEWS_ARTICLE],
		"news", article.get("author", "FanZone"), "news",
		article.get("headline", "News Update"),
		{"headline": article.get("headline", "News Update"),
		 "body": article.get("body", ""),
		 "source": article.get("author", "FanZone"),
		 "likes": randi_range(20, 100)}
	)


# ─── NPC Post Generation Helpers ────────────────────────────────

func _generate_npc_event_posts(event_key: String, mood: String, count: int) -> void:
	var npcs = _get_available_teammate_npcs()
	npcs.shuffle()
	var actual_count = mini(count, npcs.size())

	for i in range(actual_count):
		var npc_id = npcs[i]
		var text = _generate_npc_text(npc_id, event_key)
		create_npc_post(npc_id, text, event_key, mood)


func _generate_npc_injury_posts(injured_npc_id: String, count: int) -> void:
	var npcs = _get_available_teammate_npcs()
	npcs.erase(injured_npc_id)
	npcs.shuffle()
	var actual_count = mini(count, npcs.size())

	for i in range(actual_count):
		var text = _generate_npc_text(npcs[i], "injury_teammate")
		create_npc_post(npcs[i], text, "injury", "concerned")


func _generate_npc_recovery_posts(recovered_npc_id: String, count: int) -> void:
	var npcs = _get_available_teammate_npcs()
	npcs.erase(recovered_npc_id)
	npcs.shuffle()
	var actual_count = mini(count, npcs.size())

	for i in range(actual_count):
		var text = _generate_npc_text(npcs[i], "recovery")
		create_npc_post(npcs[i], text, "recovery", "happy")


func _get_available_teammate_npcs() -> Array[String]:
	var npcs: Array[String] = []
	if GameManager.current_team:
		for player in GameManager.current_team.players:
			var pid = player.get("id", "")
			if pid != "" and pid != "player":
				npcs.append(pid)
	return npcs


# ─── Internal Helpers ────────────────────────────────────────────

func _add_to_feed(post: Dictionary) -> void:
	feed.insert(0, post)
	if feed.size() > MAX_FEED_SIZE:
		feed.resize(MAX_FEED_SIZE)
	post_added.emit(post)


func _generate_handle(author_name: String) -> String:
	if author_name == "You" or author_name == "player":
		return "@you"
	if author_name in ["FanZone News", "Match Report", "Medical Update", "Season Update", "Achievement"]:
		return "@fanzone"
	# Generate handle from name: "Takumi Yamada" -> "@t_yamada"
	var parts = author_name.split(" ")
	if parts.size() >= 2:
		return "@%s_%s" % [parts[0][0].to_lower(), parts[-1].to_lower()]
	return "@%s" % author_name.to_lower().replace(" ", "_")


func _get_date_string() -> String:
	if DesktopManager:
		return DesktopManager.get_date_string()
	return Time.get_date_string_from_system()


# ─── Welcome Post ────────────────────────────────────────────────

func ensure_welcome_post() -> void:
	if feed.is_empty():
		create_post(
			POST_TYPE_NAMES[PostType.NEWS_ARTICLE],
			"news", "FanZone Staff", "news",
			"A New Star Joins the Ranks!",
			{"headline": "A New Star Joins the Ranks!",
			 "body": "The local football community is buzzing with excitement as a promising young talent begins their career journey. We'll be following their progress closely!",
			 "source": "FanZone Staff", "likes": randi_range(50, 200)}
		)


# ─── Serialization ───────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"feed": feed,
		"next_post_id": _next_post_id
	}


func from_dict(data: Dictionary) -> void:
	feed.assign(data.get("feed", []))
	_next_post_id = data.get("next_post_id", feed.size() + 1)
	feed_refreshed.emit()
	print("[SocialFeedManager] Loaded %d posts from save" % feed.size())
