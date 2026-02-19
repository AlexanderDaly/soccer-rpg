extends PanelBase
class_name PanelSocial
## PanelSocial - Social media / FanZone panel with feed, compose, threads, and filters

enum ViewState { FEED, THREAD }

@onready var main_content: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent
@onready var feed_container: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/ScrollContainer/FeedContainer
@onready var scroll_container: ScrollContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/ScrollContainer
@onready var thread_view: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/ThreadView

var current_view: ViewState = ViewState.FEED
var current_filter: String = "all"
var current_thread_post_id: String = ""

# UI references built programmatically
var filter_bar: HBoxContainer
var compose_area: VBoxContainer
var compose_input: TextEdit
var compose_button: Button
var thread_scroll: ScrollContainer
var thread_container: VBoxContainer
var thread_reply_input: TextEdit
var thread_reply_button: Button
var thread_original_post: VBoxContainer

# Filter buttons for highlighting
var filter_buttons: Dictionary = {}
var followers_pill: PanelContainer
var followers_label: Label

# Colors
const COLOR_BG_CARD := Color(0.06, 0.1, 0.18, 0.9)
const COLOR_BG_CARD_HOVER := Color(0.08, 0.12, 0.22, 0.9)
const COLOR_BORDER := Color(0.15, 0.25, 0.4)
const COLOR_ACCENT_BLUE := Color(0.3, 0.6, 1)
const COLOR_ACCENT_GREEN := Color(0.3, 0.8, 0.4)
const COLOR_ACCENT_RED := Color(1, 0.4, 0.4)
const COLOR_ACCENT_GOLD := Color(1, 0.85, 0.3)
const COLOR_ACCENT_PURPLE := Color(0.7, 0.4, 1)
const COLOR_TEXT_PRIMARY := Color(0.95, 0.97, 1)
const COLOR_TEXT_SECONDARY := Color(0.75, 0.8, 0.85)
const COLOR_TEXT_DIM := Color(0.5, 0.55, 0.6)
const COLOR_PLAYER_ACCENT := Color(0.3, 0.7, 1)
const COLOR_NEWS_ACCENT := Color(1, 0.6, 0.2)


func _on_panel_ready() -> void:
	panel_title = "FanZone"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_connect_feed_signals()
	_connect_career_signals()
	SocialFeedManager.ensure_welcome_post()
	_build_filter_bar()
	_refresh_followers_display()
	_build_compose_area()
	_build_thread_view()
	_refresh_feed()


func _on_panel_closing() -> void:
	_disconnect_feed_signals()
	_disconnect_career_signals()


func _connect_feed_signals() -> void:
	if not SocialFeedManager.post_added.is_connected(_on_post_added):
		SocialFeedManager.post_added.connect(_on_post_added)
	if not SocialFeedManager.reply_added.is_connected(_on_reply_added):
		SocialFeedManager.reply_added.connect(_on_reply_added)
	if not SocialFeedManager.feed_refreshed.is_connected(_on_feed_refreshed):
		SocialFeedManager.feed_refreshed.connect(_on_feed_refreshed)


func _disconnect_feed_signals() -> void:
	if SocialFeedManager.post_added.is_connected(_on_post_added):
		SocialFeedManager.post_added.disconnect(_on_post_added)
	if SocialFeedManager.reply_added.is_connected(_on_reply_added):
		SocialFeedManager.reply_added.disconnect(_on_reply_added)
	if SocialFeedManager.feed_refreshed.is_connected(_on_feed_refreshed):
		SocialFeedManager.feed_refreshed.disconnect(_on_feed_refreshed)


func _connect_career_signals() -> void:
	if CareerManager and CareerManager.has_signal("fan_popularity_changed"):
		if not CareerManager.fan_popularity_changed.is_connected(_on_fan_popularity_changed):
			CareerManager.fan_popularity_changed.connect(_on_fan_popularity_changed)


func _disconnect_career_signals() -> void:
	if CareerManager and CareerManager.has_signal("fan_popularity_changed"):
		if CareerManager.fan_popularity_changed.is_connected(_on_fan_popularity_changed):
			CareerManager.fan_popularity_changed.disconnect(_on_fan_popularity_changed)


# ─── Input Handling ──────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		if current_view == ViewState.THREAD:
			_show_feed_view()
			get_viewport().set_input_as_handled()
			return

	# Let base class handle close for feed view
	super._input(event)


# ─── Filter Bar ──────────────────────────────────────────────────

func _build_filter_bar() -> void:
	if filter_bar:
		return  # Already built

	filter_bar = HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 8)
	main_content.add_child(filter_bar)
	main_content.move_child(filter_bar, 0)

	var filters = [
		{"id": "all", "label": "All"},
		{"id": "npc", "label": "NPC"},
		{"id": "news", "label": "News"},
		{"id": "my_posts", "label": "My Posts"}
	]

	for f in filters:
		var btn = Button.new()
		btn.text = f.label
		btn.custom_minimum_size = Vector2(80, 32)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_filter_pressed.bind(f.id))
		_style_filter_button(btn, f.id == current_filter)
		filter_bar.add_child(btn)
		filter_buttons[f.id] = btn

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_child(spacer)

	# Followers pill
	followers_pill = PanelContainer.new()
	followers_pill.custom_minimum_size = Vector2(160, 32)
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = Color(0.06, 0.14, 0.22, 0.95)
	pill_style.border_color = COLOR_ACCENT_GREEN.darkened(0.25)
	pill_style.set_border_width_all(1)
	pill_style.set_corner_radius_all(16)
	followers_pill.add_theme_stylebox_override("panel", pill_style)

	var pill_margin = MarginContainer.new()
	pill_margin.add_theme_constant_override("margin_left", 10)
	pill_margin.add_theme_constant_override("margin_right", 10)
	pill_margin.add_theme_constant_override("margin_top", 4)
	pill_margin.add_theme_constant_override("margin_bottom", 4)

	followers_label = Label.new()
	followers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	followers_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	followers_label.add_theme_font_size_override("font_size", 12)
	followers_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	pill_margin.add_child(followers_label)
	followers_pill.add_child(pill_margin)
	filter_bar.add_child(followers_pill)


func _style_filter_button(btn: Button, active: bool) -> void:
	var style = StyleBoxFlat.new()
	if active:
		style.bg_color = COLOR_ACCENT_BLUE.darkened(0.4)
		style.border_color = COLOR_ACCENT_BLUE
		btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	else:
		style.bg_color = Color(0.08, 0.12, 0.2)
		style.border_color = COLOR_BORDER
		btn.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = hover.bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", style)


func _on_filter_pressed(filter_id: String) -> void:
	AudioManager.play_ui_click()
	current_filter = filter_id
	for fid in filter_buttons:
		_style_filter_button(filter_buttons[fid], fid == current_filter)
	_refresh_feed()


func _refresh_followers_display() -> void:
	if not followers_label:
		return
	var followers = CareerManager.fan_popularity if CareerManager else 0
	followers_label.text = "Followers: %s" % _format_followers(followers)


func _format_followers(count: int) -> String:
	if count >= 1000000:
		return "%.1fM" % (float(count) / 1000000.0)
	if count >= 1000:
		return "%.1fK" % (float(count) / 1000.0)
	return str(count)


# ─── Compose Area ────────────────────────────────────────────────

func _build_compose_area() -> void:
	if compose_area:
		return

	var main_content = feed_container.get_parent().get_parent()

	compose_area = VBoxContainer.new()
	compose_area.add_theme_constant_override("separation", 8)

	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.05, 0.08, 0.15, 0.9)
	card_style.set_border_width_all(1)
	card_style.border_color = COLOR_ACCENT_BLUE.darkened(0.3)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)

	var header_label = Label.new()
	header_label.text = "What's on your mind?"
	header_label.add_theme_font_size_override("font_size", 13)
	header_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	inner.add_child(header_label)

	compose_input = TextEdit.new()
	compose_input.placeholder_text = "Share your thoughts with the team..."
	compose_input.custom_minimum_size = Vector2(0, 60)
	compose_input.add_theme_font_size_override("font_size", 14)
	compose_input.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.04, 0.06, 0.12)
	input_style.set_border_width_all(1)
	input_style.border_color = COLOR_BORDER
	input_style.set_corner_radius_all(4)
	input_style.set_content_margin_all(8)
	compose_input.add_theme_stylebox_override("normal", input_style)
	compose_input.add_theme_stylebox_override("focus", input_style)
	inner.add_child(compose_input)

	var btn_row = HBoxContainer.new()
	var btn_spacer = Control.new()
	btn_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(btn_spacer)

	compose_button = Button.new()
	compose_button.text = "Post"
	compose_button.custom_minimum_size = Vector2(80, 32)
	_style_action_button(compose_button, COLOR_ACCENT_BLUE)
	compose_button.pressed.connect(_on_compose_submit)
	btn_row.add_child(compose_button)
	inner.add_child(btn_row)

	card.add_child(inner)
	compose_area.add_child(card)

	# Insert after filter bar
	var insert_idx = 1 if filter_bar else 0
	main_content.add_child(compose_area)
	main_content.move_child(compose_area, insert_idx)


func _on_compose_submit() -> void:
	var text = compose_input.text.strip_edges()
	if text.is_empty():
		return

	AudioManager.play_ui_click()
	SocialFeedManager.create_player_post(text)
	compose_input.text = ""


# ─── Feed Display ────────────────────────────────────────────────

func _refresh_feed() -> void:
	if not feed_container:
		return

	for child in feed_container.get_children():
		child.queue_free()

	var posts = SocialFeedManager.get_feed(current_filter)

	if posts.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No posts yet. Play matches to generate news!"
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		feed_container.add_child(empty_label)
		return

	for post in posts:
		var card = _create_post_card(post)
		feed_container.add_child(card)


func _create_post_card(post: Dictionary) -> PanelContainer:
	var post_type = post.get("post_type", "")

	match post_type:
		"match_summary":
			return _create_match_summary_card(post)
		"news_article":
			return _create_news_card(post)
		"milestone":
			return _create_milestone_card(post)
		"fan_reaction":
			return _create_fan_card(post)
		"player_post":
			return _create_player_card(post)
		"injury_report":
			return _create_injury_card(post)
		"season_update":
			return _create_season_update_card(post)
		_:
			return _create_npc_card(post)


func _create_base_card(border_color: Color = COLOR_BORDER) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_CARD
	style.set_border_width_all(1)
	style.border_color = border_color
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_npc_card(post: Dictionary) -> PanelContainer:
	var role = post.get("author_role", "teammate")
	var border_color = COLOR_ACCENT_GREEN if role == "teammate" else COLOR_ACCENT_RED
	if role == "coach":
		border_color = COLOR_ACCENT_BLUE

	var panel = _create_base_card(border_color)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Author row
	var author_row = _create_author_row(post, border_color)
	vbox.add_child(author_row)

	# Content
	var content_label = _create_content_label(post.get("content", ""))
	vbox.add_child(content_label)

	# Engagement row
	var engagement = _create_engagement_row(post)
	vbox.add_child(engagement)

	panel.add_child(vbox)
	return panel


func _create_match_summary_card(post: Dictionary) -> PanelContainer:
	var mood = post.get("mood", "neutral")
	var border_color = COLOR_ACCENT_GREEN if mood == "happy" else COLOR_ACCENT_RED if mood == "sad" else COLOR_TEXT_DIM

	var panel = _create_base_card(border_color)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Match badge
	var badge_row = HBoxContainer.new()
	var badge = _create_badge("MATCH", border_color)
	badge_row.add_child(badge)
	var date_label = Label.new()
	date_label.text = "  " + post.get("date_string", "")
	date_label.add_theme_font_size_override("font_size", 11)
	date_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	badge_row.add_child(date_label)
	vbox.add_child(badge_row)

	# Score display
	var score_label = Label.new()
	score_label.text = post.get("content", "")
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(score_label)

	# Engagement row
	var engagement = _create_engagement_row(post)
	vbox.add_child(engagement)

	panel.add_child(vbox)
	return panel


func _create_news_card(post: Dictionary) -> PanelContainer:
	var panel = _create_base_card(COLOR_NEWS_ACCENT.darkened(0.3))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# News badge
	var badge_row = HBoxContainer.new()
	var badge = _create_badge("NEWS", COLOR_NEWS_ACCENT)
	badge_row.add_child(badge)
	var source = Label.new()
	source.text = "  " + post.get("source", post.get("author_name", "FanZone"))
	source.add_theme_font_size_override("font_size", 11)
	source.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	badge_row.add_child(source)
	vbox.add_child(badge_row)

	# Headline
	var headline = Label.new()
	headline.text = post.get("headline", post.get("content", ""))
	headline.add_theme_font_size_override("font_size", 17)
	headline.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(headline)

	# Body preview
	var body_text = post.get("body", "")
	if body_text != "":
		var body = Label.new()
		body.text = body_text
		body.add_theme_font_size_override("font_size", 13)
		body.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.max_lines_visible = 3
		vbox.add_child(body)

	# Engagement row
	var engagement = _create_engagement_row(post)
	vbox.add_child(engagement)

	panel.add_child(vbox)
	return panel


func _create_milestone_card(post: Dictionary) -> PanelContainer:
	var panel = _create_base_card(COLOR_ACCENT_GOLD.darkened(0.2))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Achievement badge
	var badge_row = HBoxContainer.new()
	var badge = _create_badge("ACHIEVEMENT", COLOR_ACCENT_GOLD)
	badge_row.add_child(badge)
	vbox.add_child(badge_row)

	# Content
	var content_label = Label.new()
	content_label.text = post.get("content", "")
	content_label.add_theme_font_size_override("font_size", 16)
	content_label.add_theme_color_override("font_color", COLOR_ACCENT_GOLD)
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(content_label)

	# Engagement row
	var engagement = _create_engagement_row(post)
	vbox.add_child(engagement)

	panel.add_child(vbox)
	return panel


func _create_fan_card(post: Dictionary) -> PanelContainer:
	var panel = _create_base_card(COLOR_BORDER)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Minimal author
	var author_label = Label.new()
	author_label.text = post.get("author_name", "Fan")
	author_label.add_theme_font_size_override("font_size", 12)
	author_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(author_label)

	# Content
	var content_label = _create_content_label(post.get("content", ""))
	content_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(content_label)

	# Minimal engagement
	var likes_label = Label.new()
	likes_label.text = "%d likes" % post.get("likes", 0)
	likes_label.add_theme_font_size_override("font_size", 11)
	likes_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(likes_label)

	panel.add_child(vbox)
	return panel


func _create_player_card(post: Dictionary) -> PanelContainer:
	var panel = _create_base_card(COLOR_PLAYER_ACCENT)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# "You" label
	var author_row = HBoxContainer.new()
	author_row.add_theme_constant_override("separation", 8)
	var you_badge = _create_badge("YOU", COLOR_PLAYER_ACCENT)
	author_row.add_child(you_badge)
	var handle = Label.new()
	handle.text = post.get("author_handle", "@you")
	handle.add_theme_font_size_override("font_size", 12)
	handle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	author_row.add_child(handle)
	var date_lbl = Label.new()
	date_lbl.text = post.get("date_string", "")
	date_lbl.add_theme_font_size_override("font_size", 11)
	date_lbl.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	date_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	author_row.add_child(date_lbl)
	vbox.add_child(author_row)

	# Content
	var content_label = _create_content_label(post.get("content", ""))
	vbox.add_child(content_label)

	# Engagement row
	var engagement = _create_engagement_row(post)
	vbox.add_child(engagement)

	panel.add_child(vbox)
	return panel


func _create_injury_card(post: Dictionary) -> PanelContainer:
	var panel = _create_base_card(COLOR_ACCENT_RED.darkened(0.3))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Injury badge
	var badge_row = HBoxContainer.new()
	var badge = _create_badge("INJURY", COLOR_ACCENT_RED)
	badge_row.add_child(badge)
	vbox.add_child(badge_row)

	# Content
	var content_label = _create_content_label(post.get("content", ""))
	vbox.add_child(content_label)

	# Engagement
	var engagement = _create_engagement_row(post)
	vbox.add_child(engagement)

	panel.add_child(vbox)
	return panel


func _create_season_update_card(post: Dictionary) -> PanelContainer:
	var panel = _create_base_card(COLOR_ACCENT_PURPLE.darkened(0.3))
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Season badge
	var badge_row = HBoxContainer.new()
	var badge = _create_badge("SEASON", COLOR_ACCENT_PURPLE)
	badge_row.add_child(badge)
	vbox.add_child(badge_row)

	# Content
	var content_label = _create_content_label(post.get("content", ""))
	content_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(content_label)

	# Engagement
	var engagement = _create_engagement_row(post)
	vbox.add_child(engagement)

	panel.add_child(vbox)
	return panel


# ─── Shared Card Components ─────────────────────────────────────

func _create_badge(text: String, color: Color) -> PanelContainer:
	var badge_panel = PanelContainer.new()
	var badge_style = StyleBoxFlat.new()
	badge_style.bg_color = color.darkened(0.6)
	badge_style.set_border_width_all(1)
	badge_style.border_color = color.darkened(0.2)
	badge_style.set_corner_radius_all(3)
	badge_style.content_margin_left = 6
	badge_style.content_margin_right = 6
	badge_style.content_margin_top = 2
	badge_style.content_margin_bottom = 2
	badge_panel.add_theme_stylebox_override("panel", badge_style)

	var badge_label = Label.new()
	badge_label.text = text
	badge_label.add_theme_font_size_override("font_size", 10)
	badge_label.add_theme_color_override("font_color", color)
	badge_panel.add_child(badge_label)

	return badge_panel


func _create_author_row(post: Dictionary, accent_color: Color) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Role indicator dot
	var dot = Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 10)
	dot.add_theme_color_override("font_color", accent_color)
	row.add_child(dot)

	# Author name
	var name_label = Label.new()
	name_label.text = post.get("author_name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	row.add_child(name_label)

	# Handle
	var handle_label = Label.new()
	handle_label.text = post.get("author_handle", "")
	handle_label.add_theme_font_size_override("font_size", 12)
	handle_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	row.add_child(handle_label)

	# Spacer + date
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var date_label = Label.new()
	date_label.text = post.get("date_string", "")
	date_label.add_theme_font_size_override("font_size", 11)
	date_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	row.add_child(date_label)

	return row


func _create_content_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _create_engagement_row(post: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	# Likes
	var likes_btn = Button.new()
	var is_liked = post.get("player_liked", false)
	likes_btn.text = "%d %s" % [post.get("likes", 0), "Liked" if is_liked else "Like"]
	likes_btn.add_theme_font_size_override("font_size", 12)
	likes_btn.add_theme_color_override("font_color", COLOR_ACCENT_RED if is_liked else COLOR_TEXT_DIM)
	_style_flat_button(likes_btn)
	likes_btn.pressed.connect(_on_like_pressed.bind(post, likes_btn))
	row.add_child(likes_btn)

	# Reply count + button
	var replies = post.get("replies", [])
	var reply_btn = Button.new()
	reply_btn.text = "%d Repl%s" % [replies.size(), "ies" if replies.size() != 1 else "y"]
	reply_btn.add_theme_font_size_override("font_size", 12)
	reply_btn.add_theme_color_override("font_color", COLOR_ACCENT_BLUE)
	_style_flat_button(reply_btn)
	reply_btn.pressed.connect(_on_reply_pressed.bind(post))
	row.add_child(reply_btn)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	return row


func _style_flat_button(btn: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.2, 0.5)
	style.set_border_width_all(1)
	style.border_color = Color(0.15, 0.2, 0.3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)

	var hover = style.duplicate()
	hover.bg_color = Color(0.12, 0.16, 0.25, 0.7)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", style)


func _style_action_button(btn: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.4)
	style.set_border_width_all(1)
	style.border_color = color.darkened(0.1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	btn.add_theme_font_size_override("font_size", 13)

	var hover = style.duplicate()
	hover.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", style)


# ─── Interactions ────────────────────────────────────────────────

func _on_like_pressed(post: Dictionary, btn: Button) -> void:
	AudioManager.play_ui_click()
	SocialFeedManager.toggle_like(post.post_id)
	var is_liked = post.get("player_liked", false)
	btn.text = "%d %s" % [post.get("likes", 0), "Liked" if is_liked else "Like"]
	btn.add_theme_color_override("font_color", COLOR_ACCENT_RED if is_liked else COLOR_TEXT_DIM)


func _on_reply_pressed(post: Dictionary) -> void:
	AudioManager.play_ui_click()
	_show_thread_view(post)


# ─── Thread View ─────────────────────────────────────────────────

func _build_thread_view() -> void:
	if not thread_view:
		return
	if thread_scroll:
		return  # Already built

	thread_view.visible = false

	# Clear any placeholder children
	for child in thread_view.get_children():
		child.queue_free()

	# Original post container
	thread_original_post = VBoxContainer.new()
	thread_view.add_child(thread_original_post)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_BORDER)
	thread_view.add_child(sep)

	# Replies label
	var replies_header = Label.new()
	replies_header.text = "Replies"
	replies_header.add_theme_font_size_override("font_size", 14)
	replies_header.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	thread_view.add_child(replies_header)

	# Scroll for replies
	thread_scroll = ScrollContainer.new()
	thread_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thread_container = VBoxContainer.new()
	thread_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thread_container.add_theme_constant_override("separation", 8)
	thread_scroll.add_child(thread_container)
	thread_view.add_child(thread_scroll)

	# Reply input area
	var reply_area = HBoxContainer.new()
	reply_area.add_theme_constant_override("separation", 8)

	thread_reply_input = TextEdit.new()
	thread_reply_input.placeholder_text = "Write a reply..."
	thread_reply_input.custom_minimum_size = Vector2(0, 50)
	thread_reply_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thread_reply_input.add_theme_font_size_override("font_size", 13)
	thread_reply_input.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.04, 0.06, 0.12)
	input_style.set_border_width_all(1)
	input_style.border_color = COLOR_BORDER
	input_style.set_corner_radius_all(4)
	input_style.set_content_margin_all(8)
	thread_reply_input.add_theme_stylebox_override("normal", input_style)
	thread_reply_input.add_theme_stylebox_override("focus", input_style)
	reply_area.add_child(thread_reply_input)

	thread_reply_button = Button.new()
	thread_reply_button.text = "Reply"
	thread_reply_button.custom_minimum_size = Vector2(70, 50)
	_style_action_button(thread_reply_button, COLOR_ACCENT_BLUE)
	thread_reply_button.pressed.connect(_on_thread_reply_submit)
	reply_area.add_child(thread_reply_button)

	thread_view.add_child(reply_area)


func _show_thread_view(post: Dictionary) -> void:
	current_view = ViewState.THREAD
	current_thread_post_id = post.post_id

	# Hide feed elements
	if filter_bar:
		filter_bar.visible = false
	if compose_area:
		compose_area.visible = false
	scroll_container.visible = false

	# Show thread view
	thread_view.visible = true

	# Build original post display
	for child in thread_original_post.get_children():
		child.queue_free()
	var original_card = _create_post_card(post)
	thread_original_post.add_child(original_card)

	# Build replies
	_refresh_thread_replies(post)


func _refresh_thread_replies(post: Dictionary) -> void:
	for child in thread_container.get_children():
		child.queue_free()

	var replies = post.get("replies", [])
	if replies.is_empty():
		var empty = Label.new()
		empty.text = "No replies yet. Be the first!"
		empty.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		empty.add_theme_font_size_override("font_size", 13)
		thread_container.add_child(empty)
		return

	for reply in replies:
		var card = _create_reply_card(reply)
		thread_container.add_child(card)


func _create_reply_card(reply: Dictionary) -> PanelContainer:
	var is_player = reply.get("author_id", "") == "player"
	var accent = COLOR_PLAYER_ACCENT if is_player else COLOR_ACCENT_GREEN

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 0.8)
	style.set_border_width_all(1)
	style.border_color = accent.darkened(0.4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Author
	var author_row = HBoxContainer.new()
	author_row.add_theme_constant_override("separation", 6)
	var name_label = Label.new()
	name_label.text = reply.get("author_name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", accent if is_player else COLOR_TEXT_PRIMARY)
	author_row.add_child(name_label)
	var handle = Label.new()
	handle.text = reply.get("author_handle", "")
	handle.add_theme_font_size_override("font_size", 11)
	handle.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	author_row.add_child(handle)
	vbox.add_child(author_row)

	# Content
	var content = Label.new()
	content.text = reply.get("content", "")
	content.add_theme_font_size_override("font_size", 13)
	content.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(content)

	panel.add_child(vbox)
	return panel


func _on_thread_reply_submit() -> void:
	var text = thread_reply_input.text.strip_edges()
	if text.is_empty() or current_thread_post_id == "":
		return

	AudioManager.play_ui_click()
	SocialFeedManager.add_player_reply(current_thread_post_id, text)
	thread_reply_input.text = ""


func _show_feed_view() -> void:
	current_view = ViewState.FEED
	current_thread_post_id = ""

	# Show feed elements
	if filter_bar:
		filter_bar.visible = true
	if compose_area:
		compose_area.visible = true
	scroll_container.visible = true

	# Hide thread
	thread_view.visible = false

	_refresh_feed()


# ─── Signal Handlers ─────────────────────────────────────────────

func _on_post_added(_post: Dictionary) -> void:
	if not is_open:
		return

	if current_view == ViewState.FEED:
		_refresh_feed()


func _on_reply_added(parent_post_id: String, _reply: Dictionary) -> void:
	if not is_open:
		return

	if current_view == ViewState.THREAD and current_thread_post_id == parent_post_id:
		var post = SocialFeedManager.get_post_by_id(parent_post_id)
		if not post.is_empty():
			_refresh_thread_replies(post)


func _on_feed_refreshed() -> void:
	if is_open and current_view == ViewState.FEED:
		_refresh_feed()


func _on_fan_popularity_changed(_new_total: int, _delta: int, _outcome: String) -> void:
	_refresh_followers_display()
