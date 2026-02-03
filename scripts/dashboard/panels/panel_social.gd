extends PanelBase
class_name PanelSocial
## PanelSocial - Social media / FanZone panel

@onready var feed_container: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/ScrollContainer/FeedContainer

var news_articles: Array[Dictionary] = []


func _on_panel_ready() -> void:
	panel_title = "FanZone"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_connect_signals()
	_load_articles()
	_refresh_display()


func _connect_signals() -> void:
	if not NarrativeEngine.news_article_generated.is_connected(_on_news_article):
		NarrativeEngine.news_article_generated.connect(_on_news_article)


func _load_articles() -> void:
	if news_articles.is_empty():
		# Add default welcome post
		news_articles.append({
			"headline": "A New Star Joins the Ranks!",
			"body": "The local football community is buzzing with excitement as a promising young talent begins their career journey. We'll be following their progress closely!",
			"author": "FanZone Staff",
			"date": DesktopManager.get_date_string(),
			"likes": randi_range(50, 200),
			"comments": randi_range(10, 50)
		})


func _refresh_display() -> void:
	if not feed_container:
		return

	for child in feed_container.get_children():
		child.queue_free()

	if news_articles.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No posts yet. Play matches to generate news!"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		feed_container.add_child(empty_label)
		return

	for article in news_articles:
		_add_article_card(article)


func _add_article_card(article: Dictionary) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.18, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.15, 0.25, 0.4)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Headline
	var headline = Label.new()
	headline.text = article.headline
	headline.add_theme_font_size_override("font_size", 18)
	headline.add_theme_color_override("font_color", Color(0.95, 0.97, 1))
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Body
	var body = Label.new()
	body.text = article.body
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Meta row
	var meta_row = HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 16)

	var author_label = Label.new()
	author_label.text = "By %s" % article.author
	author_label.add_theme_font_size_override("font_size", 12)
	author_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

	var date_label = Label.new()
	date_label.text = article.date
	date_label.add_theme_font_size_override("font_size", 12)
	date_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

	meta_row.add_child(author_label)
	meta_row.add_child(date_label)

	# Engagement row
	var engagement_row = HBoxContainer.new()
	engagement_row.add_theme_constant_override("separation", 20)

	var likes_label = Label.new()
	likes_label.text = "%d likes" % article.likes
	likes_label.add_theme_font_size_override("font_size", 13)
	likes_label.add_theme_color_override("font_color", Color(1, 0.4, 0.5))

	var comments_label = Label.new()
	comments_label.text = "%d comments" % article.comments
	comments_label.add_theme_font_size_override("font_size", 13)
	comments_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1))

	engagement_row.add_child(likes_label)
	engagement_row.add_child(comments_label)

	# Spacer for expand
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	engagement_row.add_child(spacer)

	# Like button
	var like_btn = Button.new()
	like_btn.text = "Like"
	like_btn.custom_minimum_size = Vector2(60, 28)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.15, 0.25)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.3, 0.4, 0.6)
	btn_style.set_corner_radius_all(4)
	like_btn.add_theme_stylebox_override("normal", btn_style)
	like_btn.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	like_btn.add_theme_font_size_override("font_size", 12)
	like_btn.pressed.connect(_on_like_pressed.bind(article, likes_label))
	engagement_row.add_child(like_btn)

	vbox.add_child(headline)
	vbox.add_child(body)
	vbox.add_child(meta_row)
	vbox.add_child(engagement_row)

	panel.add_child(vbox)
	feed_container.add_child(panel)


func _on_like_pressed(article: Dictionary, label: Label) -> void:
	AudioManager.play_ui_click()
	article.likes += 1
	label.text = "%d likes" % article.likes


func _on_news_article(article: Dictionary) -> void:
	news_articles.insert(0, {
		"headline": article.get("headline", "News Update"),
		"body": article.get("body", ""),
		"author": article.get("author", "FanZone"),
		"date": DesktopManager.get_date_string(),
		"likes": randi_range(20, 150),
		"comments": randi_range(5, 40)
	})

	# Keep only recent articles
	if news_articles.size() > 20:
		news_articles.resize(20)

	if is_open:
		_refresh_display()
