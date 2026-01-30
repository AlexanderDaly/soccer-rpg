extends PanelBase
class_name PanelTeam
## PanelTeam - Team roster panel

@onready var team_name_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/TeamHeader/TeamNameLabel
@onready var formation_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/TeamHeader/FormationLabel
@onready var roster_list: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/ScrollContainer/RosterList
@onready var player_detail: PanelContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/PlayerDetailPanel


func _on_panel_ready() -> void:
	panel_title = "Team Roster"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_refresh_display()


func _refresh_display() -> void:
	var team = GameManager.current_team
	if not team:
		_show_no_team()
		return

	if team_name_label:
		team_name_label.text = team.name
		team_name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		team_name_label.add_theme_font_size_override("font_size", 20)

	if formation_label:
		formation_label.text = "Formation: %s" % team.formation
		formation_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))

	_build_roster_list(team)


func _show_no_team() -> void:
	if team_name_label:
		team_name_label.text = "No Team"
	if formation_label:
		formation_label.text = ""
	if roster_list:
		for child in roster_list.get_children():
			child.queue_free()
		var label = Label.new()
		label.text = "You are not currently on a team."
		label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		roster_list.add_child(label)


func _build_roster_list(team: TeamData) -> void:
	if not roster_list:
		return

	for child in roster_list.get_children():
		child.queue_free()

	# Group players by position
	var positions = {
		"GK": [],
		"DEF": [],
		"MID": [],
		"FWD": []
	}

	# Add the player
	var player = GameManager.player_data
	if player:
		var pos_group = _get_position_group(player.position)
		positions[pos_group].append({"data": player, "is_player": true})

	# Add teammates
	for teammate in team.teammates:
		var pos_group = _get_position_group(teammate.position)
		positions[pos_group].append({"data": teammate, "is_player": false})

	# Build UI for each group
	for group_name in ["GK", "DEF", "MID", "FWD"]:
		if positions[group_name].is_empty():
			continue

		var header = Label.new()
		header.text = _get_group_display_name(group_name)
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color(0, 0.8, 0.4))
		roster_list.add_child(header)

		for player_info in positions[group_name]:
			_add_player_row(player_info.data, player_info.is_player)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		roster_list.add_child(spacer)


func _get_position_group(position: String) -> String:
	match position:
		"GK":
			return "GK"
		"CB", "LB", "RB", "LWB", "RWB":
			return "DEF"
		"CDM", "CM", "CAM", "LM", "RM":
			return "MID"
		"LW", "RW", "CF", "ST":
			return "FWD"
		_:
			return "MID"


func _get_group_display_name(group: String) -> String:
	match group:
		"GK":
			return "Goalkeepers"
		"DEF":
			return "Defenders"
		"MID":
			return "Midfielders"
		"FWD":
			return "Forwards"
		_:
			return group


func _add_player_row(player_data, is_main_player: bool) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)

	if is_main_player:
		style.bg_color = Color(0.1, 0.2, 0.15)
		style.border_color = Color(0, 0.6, 0.3)
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.06, 0.1, 0.18, 0.9)
		style.border_color = Color(0.15, 0.25, 0.4)
		style.set_border_width_all(1)

	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# Position
	var pos_label = Label.new()
	pos_label.text = player_data.position
	pos_label.custom_minimum_size = Vector2(50, 0)
	pos_label.add_theme_color_override("font_color", _get_position_color(player_data.position))
	pos_label.add_theme_font_size_override("font_size", 14)

	# Name
	var name_label = Label.new()
	if is_main_player:
		name_label.text = player_data.name + " (You)"
	else:
		name_label.text = player_data.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))

	# Overall
	var ovr = player_data.get_overall() if player_data.has_method("get_overall") else player_data.overall
	var ovr_label = Label.new()
	ovr_label.text = str(ovr)
	ovr_label.custom_minimum_size = Vector2(40, 0)
	ovr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ovr_label.add_theme_color_override("font_color", _get_overall_color(ovr))
	ovr_label.add_theme_font_size_override("font_size", 16)

	hbox.add_child(pos_label)
	hbox.add_child(name_label)
	hbox.add_child(ovr_label)

	panel.add_child(hbox)

	# Make clickable for details
	panel.gui_input.connect(_on_player_clicked.bind(player_data))
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	roster_list.add_child(panel)


func _on_player_clicked(event: InputEvent, player_data) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_player_detail(player_data)


func _show_player_detail(player_data) -> void:
	if not player_detail:
		return

	player_detail.visible = true

	# Clear existing content
	for child in player_detail.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# Name
	var name_label = Label.new()
	name_label.text = player_data.name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	vbox.add_child(name_label)

	# Position and Overall
	var pos_ovr = Label.new()
	var ovr = player_data.get_overall() if player_data.has_method("get_overall") else player_data.overall
	pos_ovr.text = "%s - OVR %d" % [player_data.position, ovr]
	pos_ovr.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	vbox.add_child(pos_ovr)

	# Stats
	var stats = ["SHO", "PAS", "DEF", "SPD", "STA", "TEC", "MEN"]
	for stat in stats:
		var stat_val = player_data.stats.get(stat, 50) if "stats" in player_data else 50
		var stat_row = HBoxContainer.new()

		var stat_name = Label.new()
		stat_name.text = stat
		stat_name.custom_minimum_size = Vector2(50, 0)
		stat_name.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))

		var stat_bar = ProgressBar.new()
		stat_bar.max_value = 99
		stat_bar.value = stat_val
		stat_bar.custom_minimum_size = Vector2(100, 16)
		stat_bar.show_percentage = false

		var stat_value = Label.new()
		stat_value.text = str(stat_val)
		stat_value.custom_minimum_size = Vector2(30, 0)
		stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_value.add_theme_color_override("font_color", _get_stat_color(stat_val))

		stat_row.add_child(stat_name)
		stat_row.add_child(stat_bar)
		stat_row.add_child(stat_value)
		vbox.add_child(stat_row)

	player_detail.add_child(vbox)


func _get_position_color(pos: String) -> Color:
	match pos:
		"GK":
			return Color(1.0, 0.8, 0.2)
		"CB", "LB", "RB", "LWB", "RWB":
			return Color(0.2, 0.6, 1.0)
		"CDM", "CM", "CAM", "LM", "RM":
			return Color(0.2, 0.9, 0.4)
		"LW", "RW", "CF", "ST":
			return Color(1.0, 0.4, 0.4)
		_:
			return Color(0.8, 0.8, 0.8)


func _get_overall_color(ovr: int) -> Color:
	if ovr >= 85:
		return Color(1.0, 0.84, 0.0)
	elif ovr >= 75:
		return Color(0.0, 0.9, 0.4)
	elif ovr >= 65:
		return Color(0.9, 0.9, 0.9)
	elif ovr >= 55:
		return Color(0.8, 0.5, 0.2)
	else:
		return Color(0.6, 0.6, 0.6)


func _get_stat_color(val: int) -> Color:
	if val >= 80:
		return Color(0, 1, 0.5)
	elif val >= 60:
		return Color(0.9, 0.95, 1)
	elif val >= 40:
		return Color(1, 0.8, 0.3)
	else:
		return Color(1, 0.4, 0.4)
