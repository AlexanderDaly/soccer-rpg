extends Control
## AppSocialMedia - FanZone app for news and social media feed

@onready var feed_container: VBoxContainer = $VBoxContainer/ScrollContainer/FeedContainer
@onready var refresh_button: Button = $VBoxContainer/HeaderSection/RefreshButton

# News articles
var articles: Array[Dictionary] = []


func _ready() -> void:
	_generate_initial_feed()
	_refresh_feed()
	_connect_signals()


func _connect_signals() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	NarrativeEngine.news_article_generated.connect(_on_news_article)


func _generate_initial_feed() -> void:
	# Generate some initial articles based on career state
	var player = GameManager.player_data
	if not player:
		return

	# Career start article
	articles.append({
		"headline": "New Talent Joins %s" % (GameManager.current_team.name if GameManager.current_team else "Local Team"),
		"body": "A promising young %s has joined the squad. %s is expected to make an impact this season with their impressive skills." % [
			_get_position_name(player.position),
			player.name
		],
		"source": "Soccer Weekly",
		"date": DesktopManager.get_date_string(),
		"likes": randi_range(50, 200),
		"comments": randi_range(5, 30)
	})

	# Random soccer news
	var random_headlines = [
		"Season Preview: Teams to Watch",
		"Youth Development Programs on the Rise",
		"International Scouts Flock to High School Tournaments",
		"Technical Skills vs Physical Attributes: The Eternal Debate",
		"Former Pro Shares Advice for Young Players"
	]

	for headline in random_headlines.slice(0, 3):
		articles.append({
			"headline": headline,
			"body": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Soccer fans around the world continue to follow the latest developments in youth football.",
			"source": ["Sports Central", "The Athletic Tribune", "Goal! Magazine"][randi() % 3],
			"date": DesktopManager.get_date_string(),
			"likes": randi_range(100, 1000),
			"comments": randi_range(10, 100)
		})


func _refresh_feed() -> void:
	# Clear existing
	for child in feed_container.get_children():
		child.queue_free()

	# Add articles
	for article in articles:
		_add_article_card(article)


func _add_article_card(article: Dictionary) -> void:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 100)

	var vbox = VBoxContainer.new()

	# Header with source and date
	var header = HBoxContainer.new()

	var source_label = Label.new()
	source_label.text = article.get("source", "Unknown")
	source_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.8))
	source_label.add_theme_font_size_override("font_size", 14)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var date_label = Label.new()
	date_label.text = article.get("date", "")
	date_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	date_label.add_theme_font_size_override("font_size", 14)

	header.add_child(source_label)
	header.add_child(spacer)
	header.add_child(date_label)

	# Headline
	var headline = Label.new()
	headline.text = article.get("headline", "No Headline")
	headline.add_theme_font_size_override("font_size", 18)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Body preview
	var body = Label.new()
	var body_text = article.get("body", "")
	if body_text.length() > 150:
		body_text = body_text.substr(0, 147) + "..."
	body.text = body_text
	body.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	body.add_theme_font_size_override("font_size", 14)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Engagement stats
	var engagement = HBoxContainer.new()

	var likes_label = Label.new()
	likes_label.text = "%d likes" % article.get("likes", 0)
	likes_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	likes_label.add_theme_font_size_override("font_size", 13)

	var comments_label = Label.new()
	comments_label.text = "  |  %d comments" % article.get("comments", 0)
	comments_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	comments_label.add_theme_font_size_override("font_size", 13)

	engagement.add_child(likes_label)
	engagement.add_child(comments_label)

	vbox.add_child(header)
	vbox.add_child(headline)
	vbox.add_child(body)
	vbox.add_child(engagement)

	card.add_child(vbox)
	feed_container.add_child(card)


func _on_refresh_pressed() -> void:
	AudioManager.play_ui_click()
	# Generate a random new article
	_generate_random_article()
	_refresh_feed()


func _generate_random_article() -> void:
	var player = GameManager.player_data
	var player_name = player.name if player else "Local Player"

	var headlines = [
		"Fans React to %s's Recent Performance" % player_name,
		"Scouts Spotted at Recent Match",
		"Youth Soccer Scene Continues to Grow",
		"Training Tips from the Pros",
		"Weekend Match Roundup"
	]

	articles.insert(0, {
		"headline": headlines[randi() % headlines.size()],
		"body": "The latest developments continue to excite fans and analysts alike. Stay tuned for more updates on the youth soccer scene.",
		"source": ["Soccer Weekly", "Sports Central", "The Athletic Tribune", "Goal! Magazine", "Football Daily"][randi() % 5],
		"date": DesktopManager.get_date_string(),
		"likes": randi_range(50, 500),
		"comments": randi_range(5, 50)
	})

	# Keep feed manageable
	if articles.size() > 20:
		articles.pop_back()


func _on_news_article(article: Dictionary) -> void:
	articles.insert(0, {
		"headline": article.get("headline", "Breaking News"),
		"body": article.get("body", ""),
		"source": article.get("source", "Sports Central"),
		"date": article.get("date", DesktopManager.get_date_string()),
		"likes": randi_range(100, 500),
		"comments": randi_range(10, 50)
	})
	_refresh_feed()


func _get_position_name(pos: String) -> String:
	var names = {
		"GK": "goalkeeper",
		"CB": "center back",
		"FB": "full back",
		"CDM": "defensive midfielder",
		"CM": "central midfielder",
		"CAM": "attacking midfielder",
		"WNG": "winger",
		"ST": "striker"
	}
	return names.get(pos, "player")
