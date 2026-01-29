extends Control
## AppTeam - Team roster viewer showing teammates and their stats

@onready var team_name_label: Label = $VBoxContainer/HeaderSection/TeamNameLabel
@onready var formation_label: Label = $VBoxContainer/HeaderSection/FormationLabel
@onready var roster_container: VBoxContainer = $VBoxContainer/ScrollContainer/RosterContainer
@onready var player_details: VBoxContainer = $VBoxContainer/PlayerDetails


func _ready() -> void:
	_refresh_display()


func _refresh_display() -> void:
	var team = GameManager.current_team
	if not team:
		team_name_label.text = "No Team"
		return

	team_name_label.text = team.name
	formation_label.text = "Formation: %s" % team.formation

	_build_roster(team)


func _build_roster(team: TeamData) -> void:
	# Clear existing
	for child in roster_container.get_children():
		child.queue_free()

	# Add player character first
	if GameManager.player_data:
		_add_player_row(GameManager.player_data, true)

	# Add separator
	var sep = HSeparator.new()
	roster_container.add_child(sep)

	# Add teammates by position
	var positions_order = ["GK", "CB", "FB", "CDM", "CM", "CAM", "WNG", "ST"]
	var sorted_players = team.players.duplicate()
	sorted_players.sort_custom(func(a, b):
		var pos_a = positions_order.find(a.position)
		var pos_b = positions_order.find(b.position)
		return pos_a < pos_b
	)

	for teammate in sorted_players:
		_add_teammate_row(teammate)


func _add_player_row(player: PlayerData, is_user: bool) -> void:
	var row = _create_roster_row(
		player.name + " (You)" if is_user else player.name,
		player.position,
		player.get_overall(),
		player.current_form,
		is_user
	)
	roster_container.add_child(row)


func _add_teammate_row(teammate: Dictionary) -> void:
	var row = _create_roster_row(
		teammate.get("name", "Unknown"),
		teammate.get("position", "??"),
		teammate.get("overall", 50),
		teammate.get("form", "average"),
		false
	)
	row.gui_input.connect(_on_teammate_clicked.bind(teammate))
	roster_container.add_child(row)


func _create_roster_row(player_name: String, position: String, overall: int, form: String, is_player: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 36)

	if is_player:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.9, 0.7)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()

	# Position badge
	var pos_label = Label.new()
	pos_label.text = position
	pos_label.custom_minimum_size = Vector2(40, 0)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_label.add_theme_color_override("font_color", _get_position_color(position))

	# Name
	var name_label = Label.new()
	name_label.text = player_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Overall
	var ovr_label = Label.new()
	ovr_label.text = str(overall)
	ovr_label.custom_minimum_size = Vector2(30, 0)
	ovr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ovr_label.add_theme_color_override("font_color", _get_stat_color(overall))

	# Form indicator
	var form_label = Label.new()
	form_label.text = _get_form_symbol(form)
	form_label.custom_minimum_size = Vector2(30, 0)
	form_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_label.add_theme_color_override("font_color", _get_form_color(form))

	hbox.add_child(pos_label)
	hbox.add_child(name_label)
	hbox.add_child(ovr_label)
	hbox.add_child(form_label)

	panel.add_child(hbox)
	return panel


func _on_teammate_clicked(event: InputEvent, teammate: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_ui_click()
		_show_teammate_details(teammate)


func _show_teammate_details(teammate: Dictionary) -> void:
	# Clear existing details
	for child in player_details.get_children():
		child.queue_free()

	# Header
	var header = Label.new()
	header.text = teammate.get("name", "Unknown")
	header.add_theme_font_size_override("font_size", 18)
	player_details.add_child(header)

	# Position and overall
	var info = Label.new()
	info.text = "%s | OVR: %d | Form: %s" % [
		_get_position_name(teammate.get("position", "")),
		teammate.get("overall", 50),
		teammate.get("form", "average").capitalize()
	]
	player_details.add_child(info)

	# Stats
	var stats = teammate.get("stats", {})
	for stat_key in stats:
		var stat_name = StatSystem.PRIMARY_STATS.get(stat_key, stat_key)
		var hbox = HBoxContainer.new()

		var name_lbl = Label.new()
		name_lbl.text = stat_name
		name_lbl.custom_minimum_size = Vector2(80, 0)

		var value_lbl = Label.new()
		value_lbl.text = str(stats[stat_key])
		value_lbl.add_theme_color_override("font_color", _get_stat_color(stats[stat_key]))

		hbox.add_child(name_lbl)
		hbox.add_child(value_lbl)
		player_details.add_child(hbox)

	# Personality
	var personality = Label.new()
	personality.text = "Personality: %s" % teammate.get("personality", "unknown").capitalize()
	player_details.add_child(personality)


func _get_position_color(pos: String) -> Color:
	match pos:
		"GK":
			return Color(0.9, 0.7, 0.2)  # Gold
		"CB", "FB":
			return Color(0.2, 0.6, 0.9)  # Blue
		"CDM", "CM":
			return Color(0.2, 0.8, 0.4)  # Green
		"CAM", "WNG":
			return Color(0.9, 0.5, 0.2)  # Orange
		"ST":
			return Color(0.9, 0.2, 0.2)  # Red
		_:
			return Color.WHITE


func _get_position_name(pos: String) -> String:
	var names = {
		"GK": "Goalkeeper",
		"CB": "Center Back",
		"FB": "Full Back",
		"CDM": "Defensive Mid",
		"CM": "Central Mid",
		"CAM": "Attacking Mid",
		"WNG": "Winger",
		"ST": "Striker"
	}
	return names.get(pos, pos)


func _get_stat_color(value: int) -> Color:
	if value >= 75:
		return Color(0.2, 0.9, 0.3)
	elif value >= 60:
		return Color(0.5, 0.8, 0.2)
	elif value >= 45:
		return Color(0.9, 0.8, 0.2)
	else:
		return Color(0.9, 0.4, 0.2)


func _get_form_symbol(form: String) -> String:
	match form:
		"excellent":
			return "^^"
		"good":
			return "^"
		"average":
			return "-"
		"poor":
			return "v"
		"terrible":
			return "vv"
		_:
			return "?"


func _get_form_color(form: String) -> Color:
	match form:
		"excellent":
			return Color(0.2, 0.9, 0.3)
		"good":
			return Color(0.5, 0.8, 0.2)
		"average":
			return Color(0.7, 0.7, 0.7)
		"poor":
			return Color(0.9, 0.5, 0.2)
		"terrible":
			return Color(0.9, 0.2, 0.2)
		_:
			return Color.WHITE
