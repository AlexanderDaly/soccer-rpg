extends PanelSocial
class_name PanelSocialV2
## PanelSocialV2 - FanZone V2 panel with hybrid ranking and ranking reason labels

var current_sort_mode: String = "top"
var sort_bar: HBoxContainer
var sort_buttons: Dictionary = {}

const COLOR_SORT_ACTIVE := Color(0.2, 0.5, 0.9)
const COLOR_SORT_INACTIVE := Color(0.15, 0.2, 0.3)


func _on_panel_ready() -> void:
	panel_title = "FanZone"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_connect_feed_signals()
	SocialFeedManager.ensure_welcome_post_v2()
	_build_filter_bar()
	_build_sort_bar()
	_build_compose_area()
	_build_thread_view()
	_refresh_feed()


func _on_panel_closing() -> void:
	_disconnect_feed_signals()


func _connect_feed_signals() -> void:
	if not SocialFeedManager.post_added_v2.is_connected(_on_post_added):
		SocialFeedManager.post_added_v2.connect(_on_post_added)
	if not SocialFeedManager.reply_added_v2.is_connected(_on_reply_added):
		SocialFeedManager.reply_added_v2.connect(_on_reply_added)
	if not SocialFeedManager.feed_refreshed_v2.is_connected(_on_feed_refreshed):
		SocialFeedManager.feed_refreshed_v2.connect(_on_feed_refreshed)


func _disconnect_feed_signals() -> void:
	if SocialFeedManager.post_added_v2.is_connected(_on_post_added):
		SocialFeedManager.post_added_v2.disconnect(_on_post_added)
	if SocialFeedManager.reply_added_v2.is_connected(_on_reply_added):
		SocialFeedManager.reply_added_v2.disconnect(_on_reply_added)
	if SocialFeedManager.feed_refreshed_v2.is_connected(_on_feed_refreshed):
		SocialFeedManager.feed_refreshed_v2.disconnect(_on_feed_refreshed)


func _build_sort_bar() -> void:
	if sort_bar:
		return

	sort_bar = HBoxContainer.new()
	sort_bar.add_theme_constant_override("separation", 8)

	var sort_label = Label.new()
	sort_label.text = "Sort:"
	sort_label.add_theme_font_size_override("font_size", 12)
	sort_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	sort_bar.add_child(sort_label)

	var sort_options = [
		{"id": "top", "label": "Top"},
		{"id": "latest", "label": "Latest"}
	]

	for opt in sort_options:
		var btn = Button.new()
		btn.text = opt.label
		btn.custom_minimum_size = Vector2(72, 28)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_sort_pressed.bind(opt.id))
		_style_sort_button(btn, opt.id == current_sort_mode)
		sort_buttons[opt.id] = btn
		sort_bar.add_child(btn)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_bar.add_child(spacer)

	var insert_idx = 1 if filter_bar else 0
	main_content.add_child(sort_bar)
	main_content.move_child(sort_bar, insert_idx)


func _style_sort_button(btn: Button, active: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_SORT_ACTIVE if active else COLOR_SORT_INACTIVE
	style.set_border_width_all(1)
	style.border_color = COLOR_ACCENT_BLUE if active else COLOR_BORDER
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)

	var hover = style.duplicate()
	hover.bg_color = hover.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY if active else COLOR_TEXT_DIM)


func _on_sort_pressed(sort_mode: String) -> void:
	if sort_mode == current_sort_mode:
		return
	AudioManager.play_ui_click()
	current_sort_mode = sort_mode
	for key in sort_buttons:
		_style_sort_button(sort_buttons[key], key == current_sort_mode)
	_refresh_feed()


func _on_compose_submit() -> void:
	var text = compose_input.text.strip_edges()
	if text.is_empty():
		return

	AudioManager.play_ui_click()
	SocialFeedManager.create_player_post_v2(text)
	compose_input.text = ""


func _refresh_feed() -> void:
	if not feed_container:
		return

	for child in feed_container.get_children():
		child.queue_free()

	var posts = SocialFeedManager.get_feed_v2(current_filter, current_sort_mode)

	if posts.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No posts yet. Play matches to generate news!"
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		feed_container.add_child(empty_label)
		return

	for i in range(posts.size()):
		var post = posts[i]
		var card = _create_post_card(post)

		if current_sort_mode == "top" and i < 3:
			var wrapper = VBoxContainer.new()
			wrapper.add_theme_constant_override("separation", 4)
			var why = Label.new()
			why.text = "Why this is high: %s" % post.get("ranking_reason", "High relevance")
			why.add_theme_font_size_override("font_size", 11)
			why.add_theme_color_override("font_color", COLOR_TEXT_DIM)
			wrapper.add_child(why)
			wrapper.add_child(card)
			feed_container.add_child(wrapper)
		else:
			feed_container.add_child(card)


func _on_like_pressed(post: Dictionary, btn: Button) -> void:
	AudioManager.play_ui_click()
	SocialFeedManager.toggle_like_v2(post.post_id)
	var updated = SocialFeedManager.get_post_by_id_v2(post.post_id)
	if updated.is_empty():
		return
	var is_liked = updated.get("player_liked", false)
	btn.text = "%d %s" % [updated.get("likes", 0), "Liked" if is_liked else "Like"]
	btn.add_theme_color_override("font_color", COLOR_ACCENT_RED if is_liked else COLOR_TEXT_DIM)


func _on_thread_reply_submit() -> void:
	var text = thread_reply_input.text.strip_edges()
	if text.is_empty() or current_thread_post_id == "":
		return

	AudioManager.play_ui_click()
	SocialFeedManager.add_player_reply_v2(current_thread_post_id, text)
	thread_reply_input.text = ""


func _on_reply_added(parent_post_id: String, _reply: Dictionary) -> void:
	if not is_open:
		return

	if current_view == ViewState.THREAD and current_thread_post_id == parent_post_id:
		var post = SocialFeedManager.get_post_by_id_v2(parent_post_id)
		if not post.is_empty():
			_refresh_thread_replies(post)
