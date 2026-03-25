extends Control
## CareerHub - Standalone progression screen for long-term career state

@onready var header_card: PanelContainer = $MainMargin/RootLayout/TopRow/HeaderCard
@onready var action_card: PanelContainer = $MainMargin/RootLayout/TopRow/ActionCard
@onready var hub_label: Label = $MainMargin/RootLayout/TopRow/HeaderCard/MarginContainer/HeaderContent/HubLabel
@onready var player_name_label: Label = $MainMargin/RootLayout/TopRow/HeaderCard/MarginContainer/HeaderContent/PlayerName
@onready var meta_label: Label = $MainMargin/RootLayout/TopRow/HeaderCard/MarginContainer/HeaderContent/MetaLabel
@onready var status_label: Label = $MainMargin/RootLayout/TopRow/HeaderCard/MarginContainer/HeaderContent/StatusLabel
@onready var primary_action_button: Button = $MainMargin/RootLayout/TopRow/ActionCard/MarginContainer/ActionContent/PrimaryActionButton
@onready var back_button: Button = $MainMargin/RootLayout/TopRow/ActionCard/MarginContainer/ActionContent/BackButton
@onready var action_hint_label: Label = $MainMargin/RootLayout/TopRow/ActionCard/MarginContainer/ActionContent/ActionHint
@onready var scroll_container: ScrollContainer = $MainMargin/RootLayout/ScrollContainer
@onready var progress_panel: PanelContainer = $MainMargin/RootLayout/ScrollContainer/Sections/ProgressPanel
@onready var progress_content: VBoxContainer = $MainMargin/RootLayout/ScrollContainer/Sections/ProgressPanel/MarginContainer/ProgressLayout/ProgressContent
@onready var offers_panel: PanelContainer = $MainMargin/RootLayout/ScrollContainer/Sections/OffersPanel
@onready var offers_content: VBoxContainer = $MainMargin/RootLayout/ScrollContainer/Sections/OffersPanel/MarginContainer/OffersLayout/OffersContent
@onready var journey_panel: PanelContainer = $MainMargin/RootLayout/ScrollContainer/Sections/JourneyPanel
@onready var journey_content: VBoxContainer = $MainMargin/RootLayout/ScrollContainer/Sections/JourneyPanel/MarginContainer/JourneyLayout/JourneyContent
@onready var people_panel: PanelContainer = $MainMargin/RootLayout/ScrollContainer/Sections/PeoplePanel
@onready var people_content: VBoxContainer = $MainMargin/RootLayout/ScrollContainer/Sections/PeoplePanel/MarginContainer/PeopleLayout/PeopleContent

var current_snapshot: Dictionary = {}
var offer_focus_buttons: Array[Button] = []


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.CAREER_HUB)
	_setup_styles()
	_connect_actions()
	_connect_signals()
	_refresh_display()


func _setup_styles() -> void:
	var background := $Background as ColorRect
	if background:
		background.color = Color(0.035, 0.078, 0.145, 1)

	_apply_card_style(header_card, Color(0.18, 0.3, 0.48))
	_apply_card_style(action_card, Color(0.0, 0.65, 0.35))
	_apply_card_style(progress_panel, Color(0.18, 0.3, 0.48))
	_apply_card_style(offers_panel, Color(0.2, 0.42, 0.3))
	_apply_card_style(journey_panel, Color(0.35, 0.28, 0.18))
	_apply_card_style(people_panel, Color(0.28, 0.22, 0.4))

	hub_label.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82))
	hub_label.add_theme_font_size_override("font_size", 14)
	player_name_label.add_theme_color_override("font_color", Color(0.93, 0.96, 1))
	player_name_label.add_theme_font_size_override("font_size", 28)
	meta_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	meta_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	status_label.add_theme_font_size_override("font_size", 14)
	action_hint_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	action_hint_label.add_theme_font_size_override("font_size", 13)

	_apply_button_style(primary_action_button, Color(0.0, 0.62, 0.34), Color(0.0, 0.8, 0.46))
	_apply_button_style(back_button, Color(0.12, 0.18, 0.28), Color(0.28, 0.4, 0.6))
	back_button.text = "Back to Dashboard"


func _connect_actions() -> void:
	primary_action_button.pressed.connect(_on_primary_action_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _connect_signals() -> void:
	_connect_signal_once(CareerManager.reputation_changed, _on_reputation_changed)
	_connect_signal_once(CareerManager.milestone_reached, _on_milestone_reached)
	_connect_signal_once(CareerManager.contract_offer_received, _on_contract_offer_received)
	_connect_signal_once(CareerManager.contract_offer_resolved, _on_contract_offer_resolved)
	_connect_signal_once(SeasonManager.season_initialized, _on_season_initialized)
	_connect_signal_once(SeasonManager.phase_changed, _on_season_phase_changed)
	_connect_signal_once(SeasonManager.season_completed, _on_season_completed)
	_connect_signal_once(GameManager.career_phase_changed, _on_career_phase_changed)
	_connect_signal_once(GameManager.national_phase_changed, _on_national_phase_changed)


func _connect_signal_once(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)


func _refresh_display() -> void:
	current_snapshot = CareerManager.get_career_hub_snapshot()
	_refresh_header()
	_refresh_primary_action()
	_build_progress_section()
	_build_offers_section()
	_build_journey_section()
	_build_people_section()


func _refresh_header() -> void:
	var overview = current_snapshot.get("player_overview", {})
	var national_phase = str(overview.get("national_phase_name", ""))
	var national_text = ""
	if national_phase != "None" and not national_phase.is_empty():
		national_text = " • %s" % national_phase

	hub_label.text = "CAREER HUB"
	player_name_label.text = str(overview.get("name", "No Player"))
	meta_label.text = "%s • %s • OVR %d • %s%s" % [
		str(overview.get("team_name", "No Team")),
		str(overview.get("position", "--")),
		int(overview.get("overall", 0)),
		str(overview.get("phase_name", "Career")),
		national_text
	]
	status_label.text = "REP %d (%s) • Coach Trust %d • Fans %d • %s" % [
		int(overview.get("reputation_score", 0)),
		str(overview.get("reputation_tier", "Unknown")),
		int(overview.get("coach_trust", 0)),
		int(overview.get("fan_popularity", 0)),
		str(overview.get("active_contract", {}).get("summary", "No active contract"))
	]


func _refresh_primary_action() -> void:
	var action = current_snapshot.get("primary_action", {})
	primary_action_button.text = str(action.get("label", "Return to Dashboard"))
	action_hint_label.text = str(action.get("description", "Review your career status."))


func _build_progress_section() -> void:
	_clear_container(progress_content)
	var objective = current_snapshot.get("current_objective", {})
	var journey = current_snapshot.get("journey_status", {})
	var next_fixture = journey.get("next_fixture", {})

	progress_content.add_child(_create_feature_title(str(objective.get("title", "Current Objective")), Color(0.93, 0.96, 1), 22))
	progress_content.add_child(_create_body_label(str(objective.get("detail", "No objective available yet."))))
	progress_content.add_child(_create_divider())
	progress_content.add_child(_create_key_value_row("Competition", str(journey.get("current_competition", "No active competition"))))
	progress_content.add_child(_create_key_value_row("Season Phase", str(journey.get("season_phase", "Offseason"))))

	if bool(journey.get("active_season", false)):
		var league_position = int(journey.get("league_position", -1))
		if league_position > 0:
			progress_content.add_child(_create_key_value_row("League Position", _format_ordinal(league_position)))
	else:
		progress_content.add_child(_create_body_label("No active season. Use this screen to review your trajectory and next step.", Color(0.65, 0.72, 0.8)))

	progress_content.add_child(_create_divider())
	progress_content.add_child(_create_feature_title("Next Match", Color(0.78, 0.86, 0.96), 16))
	if bool(next_fixture.get("available", false)):
		progress_content.add_child(_create_body_label("%s\n%s" % [
			str(next_fixture.get("label", "")),
			str(next_fixture.get("detail", ""))
		]))
	else:
		progress_content.add_child(_create_muted_label("No upcoming fixture right now."))


func _build_offers_section() -> void:
	_clear_container(offers_content)
	offer_focus_buttons.clear()

	var offers = current_snapshot.get("offers", {})
	var queued_contract = offers.get("queued_contract", {})
	if bool(queued_contract.get("available", false)):
		offers_content.add_child(_create_feature_title("Queued Move", Color(0.88, 0.94, 1), 18))
		offers_content.add_child(_create_body_label("%s\n%s" % [
			str(queued_contract.get("summary", "")),
			str(queued_contract.get("detail", ""))
		]))
		offers_content.add_child(_create_divider())

	var pending_offers = offers.get("pending", [])
	if pending_offers.is_empty():
		offers_content.add_child(_create_muted_label("No live contract offers right now."))
		return

	for offer in pending_offers:
		offers_content.add_child(_create_offer_card(offer))


func _build_journey_section() -> void:
	_clear_container(journey_content)
	var milestones = current_snapshot.get("milestones", {})
	var journey = current_snapshot.get("journey_status", {})

	journey_content.add_child(_create_body_label("Season %d • %d/%d milestones unlocked" % [
		int(milestones.get("current_season", 1)),
		int(milestones.get("completed_count", 0)),
		int(milestones.get("total_count", 0))
	], Color(0.82, 0.88, 0.95)))

	_add_list_section(
		journey_content,
		"Recent Milestones",
		_build_named_summary_lines(milestones.get("recent_completed", []), "No milestones unlocked yet.", "description")
	)
	_add_list_section(
		journey_content,
		"Recent Awards",
		_extract_summary_lines(milestones.get("awards", []), "summary", "No awards yet.")
	)
	_add_list_section(
		journey_content,
		"Trophies",
		_extract_string_lines(milestones.get("trophies", []), "No trophies yet.")
	)
	_add_list_section(
		journey_content,
		"Club History",
		_extract_string_lines(journey.get("club_history", {}).get("recent_entries", []), str(journey.get("club_history", {}).get("summary", "No previous clubs yet.")))
	)


func _build_people_section() -> void:
	_clear_container(people_content)
	var relationships = current_snapshot.get("relationships", {})
	var rivals = current_snapshot.get("rivals", {})

	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	people_content.add_child(columns)

	var relationships_column = VBoxContainer.new()
	relationships_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relationships_column.add_theme_constant_override("separation", 8)
	columns.add_child(relationships_column)

	var rivals_column = VBoxContainer.new()
	rivals_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rivals_column.add_theme_constant_override("separation", 8)
	columns.add_child(rivals_column)

	relationships_column.add_child(_create_feature_title("Relationships", Color(0.88, 0.94, 1), 18))
	var meaningful_relationships = int(relationships.get("total_meaningful", 0))
	if meaningful_relationships == 0:
		relationships_column.add_child(_create_muted_label("No meaningful relationship data yet."))
	else:
		_add_list_section(
			relationships_column,
			"Best Connections",
			_build_named_summary_lines(relationships.get("positive", []), "No standout positive relationships yet.")
		)
		_add_list_section(
			relationships_column,
			"Friction Points",
			_build_named_summary_lines(relationships.get("friction", []), "No active friction points.")
		)

	rivals_column.add_child(_create_feature_title("Rivals", Color(0.88, 0.94, 1), 18))
	if int(rivals.get("count", 0)) == 0:
		rivals_column.add_child(_create_muted_label("No rivals yet."))
	else:
		_add_list_section(
			rivals_column,
			"Known Threats",
			_build_named_summary_lines(rivals.get("items", []), "No rivals yet.")
		)


func _create_offer_card(offer: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.1, 0.16, 0.96)
	style.border_color = Color(0.18, 0.42, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	card.add_child(layout)

	layout.add_child(_create_feature_title(str(offer.get("team_name", "Club")), Color(0.93, 0.96, 1), 18))
	layout.add_child(_create_body_label("%s\n%s" % [
		str(offer.get("summary", "")),
		str(offer.get("detail", ""))
	], Color(0.77, 0.84, 0.93)))

	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	layout.add_child(button_row)

	var accept_button = Button.new()
	accept_button.text = "Accept"
	accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_style(accept_button, Color(0.0, 0.62, 0.34), Color(0.0, 0.8, 0.46))
	accept_button.pressed.connect(_on_accept_offer.bind(offer.get("offer_data", {})))
	button_row.add_child(accept_button)
	offer_focus_buttons.append(accept_button)

	var decline_button = Button.new()
	decline_button.text = "Decline"
	decline_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_style(decline_button, Color(0.45, 0.18, 0.18), Color(0.7, 0.28, 0.28))
	decline_button.pressed.connect(_on_decline_offer.bind(offer.get("offer_data", {})))
	button_row.add_child(decline_button)

	return card


func _add_list_section(container: VBoxContainer, title: String, lines: Array[String]) -> void:
	container.add_child(_create_feature_title(title, Color(0.78, 0.86, 0.96), 15))
	for line in lines:
		container.add_child(_create_body_label(line, Color(0.8, 0.86, 0.94)))


func _create_key_value_row(key: String, value: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var key_label = _create_feature_title("%s:" % key, Color(0.55, 0.68, 0.82), 14)
	key_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(key_label)

	var value_label = _create_body_label(value, Color(0.9, 0.94, 0.98))
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	return row


func _create_feature_title(text: String, color: Color, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _create_body_label(text: String, color: Color = Color(0.82, 0.88, 0.95)) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _create_muted_label(text: String) -> Label:
	return _create_body_label(text, Color(0.6, 0.68, 0.78))


func _create_divider() -> HSeparator:
	var divider = HSeparator.new()
	divider.modulate = Color(0.18, 0.28, 0.42)
	return divider


func _build_named_summary_lines(items: Array, empty_text: String, detail_key: String = "summary") -> Array[String]:
	var lines: Array[String] = []
	for item in items:
		lines.append("%s\n%s" % [
			str(item.get("name", "Unknown")),
			str(item.get(detail_key, item.get("summary", "")))
		])
	if lines.is_empty():
		lines.append(empty_text)
	return lines


func _extract_summary_lines(items: Array, summary_key: String, empty_text: String) -> Array[String]:
	var lines: Array[String] = []
	for item in items:
		lines.append(str(item.get(summary_key, "")))
	if lines.is_empty():
		lines.append(empty_text)
	return lines


func _extract_string_lines(items: Array, empty_text: String) -> Array[String]:
	var lines: Array[String] = []
	for item in items:
		lines.append(str(item))
	if lines.is_empty():
		lines.append(empty_text)
	return lines


func _apply_card_style(card: PanelContainer, border_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.086, 0.15, 0.96)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(0)
	card.add_theme_stylebox_override("panel", style)


func _apply_button_style(button: Button, background_color: Color, border_color: Color) -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = background_color
	normal_style.border_color = border_color
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(12)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = background_color.lightened(0.12)
	hover_style.border_color = border_color.lightened(0.15)
	hover_style.set_border_width_all(2)
	hover_style.set_corner_radius_all(8)
	hover_style.set_content_margin_all(12)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", normal_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_font_size_override("font_size", 15)


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _format_ordinal(value: int) -> String:
	if value <= 0:
		return "Unplaced"

	var remainder_100 = value % 100
	var suffix = "th"
	if remainder_100 < 11 or remainder_100 > 13:
		match value % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s" % [value, suffix]


func _on_primary_action_pressed() -> void:
	var action = current_snapshot.get("primary_action", {})
	match str(action.get("id", "")):
		"play_match":
			_launch_next_match()
		"review_offers":
			_focus_offers_section()
		_:
			_on_back_pressed()


func _focus_offers_section() -> void:
	AudioManager.play_ui_click()
	scroll_container.ensure_control_visible(offers_panel)
	if not offer_focus_buttons.is_empty():
		offer_focus_buttons[0].grab_focus()


func _launch_next_match() -> void:
	var match_info = SeasonManager.get_next_fixture()
	if match_info.is_empty():
		return

	var opponent = match_info.get("opponent", {})
	var opponent_team = opponent.get("team_data", null)
	if not opponent_team:
		return

	AudioManager.play_ui_confirm()
	GameManager.start_match(
		opponent_team,
		str(match_info.get("type", "friendly")),
		bool(match_info.get("is_home", true)),
		match_info.get("player_team", null)
	)
	get_tree().change_scene_to_file("res://scenes/match/pre_match.tscn")


func _on_accept_offer(offer: Dictionary) -> void:
	if offer.is_empty():
		return

	AudioManager.play_ui_confirm()
	CareerManager.accept_contract(offer)
	var team_name = str(offer.get("team_name", "the club"))
	var message = "Move to %s confirmed for the next window." % team_name if bool(offer.get("starts_next_window", false)) and SeasonManager.has_active_season() else "You accepted the offer from %s." % team_name
	DesktopManager.show_notification("Contract Accepted", message, "", "email")


func _on_decline_offer(offer: Dictionary) -> void:
	if offer.is_empty():
		return

	AudioManager.play_ui_click()
	CareerManager.decline_contract(offer)
	DesktopManager.show_notification("Offer Declined", "You declined the offer from %s." % str(offer.get("team_name", "the club")), "", "email")


func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")


func _on_reputation_changed(_new_reputation: int) -> void:
	_refresh_display()


func _on_milestone_reached(_milestone: String) -> void:
	_refresh_display()


func _on_contract_offer_received(_offer: Dictionary) -> void:
	_refresh_display()


func _on_contract_offer_resolved(_offer: Dictionary, _resolution: String) -> void:
	_refresh_display()


func _on_season_initialized(_season: SeasonData) -> void:
	_refresh_display()


func _on_season_phase_changed(_phase: int) -> void:
	_refresh_display()


func _on_season_completed(_summary: Dictionary) -> void:
	_refresh_display()


func _on_career_phase_changed(_phase: int) -> void:
	_refresh_display()


func _on_national_phase_changed(_phase: int) -> void:
	_refresh_display()
