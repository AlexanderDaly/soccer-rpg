extends PanelBase
class_name PanelPlayerStats
## PanelPlayerStats - Player statistics panel with card and attribute display

# Left column - Player card
@onready var portrait_frame: PanelContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/PortraitSection/PortraitFrame
@onready var overall_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/OverallSection/OverallContainer/OverallLabel
@onready var player_name_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/PlayerNameLabel
@onready var position_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/InfoRow/PositionLabel
@onready var nationality_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/InfoRow/NationalityLabel
@onready var foot_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/InfoRow/FootLabel
@onready var level_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/LevelSection/LevelRow/LevelLabel
@onready var skill_points_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/LevelSection/LevelRow/SkillPointsLabel
@onready var xp_bar: ProgressBar = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/LevelSection/XPBar
@onready var xp_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard/CardContent/LevelSection/XPLabel
@onready var player_card: PanelContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/PlayerCard

# Condition panel
@onready var condition_panel: PanelContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/ConditionPanel
@onready var form_value_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/ConditionPanel/ConditionContent/FormRow/FormValueLabel
@onready var stamina_bar: ProgressBar = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/ConditionPanel/ConditionContent/StaminaRow/StaminaBar
@onready var stamina_value: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/ConditionPanel/ConditionContent/StaminaRow/StaminaValue
@onready var morale_bar: ProgressBar = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/ConditionPanel/ConditionContent/MoraleRow/MoraleBar
@onready var morale_value: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/LeftColumn/ConditionPanel/ConditionContent/MoraleRow/MoraleValue

# Right column - Stats
@onready var stats_container: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/RightColumn/StatsScroll/StatsContainer

# Stat categories for organized display
const STAT_CATEGORIES = {
	"Technical": [
		{"key": "TEC", "name": "Dribbling", "desc": "Ball control and skill moves"},
		{"key": "PAS", "name": "Passing", "desc": "Pass accuracy and vision"},
		{"key": "SHO", "name": "Shooting", "desc": "Shot power and accuracy"}
	],
	"Physical": [
		{"key": "SPD", "name": "Pace", "desc": "Sprint speed and acceleration"},
		{"key": "PHY", "name": "Strength", "desc": "Physical power and aggression"},
		{"key": "STA", "name": "Stamina", "desc": "Endurance and recovery"}
	],
	"Mental": [
		{"key": "DEF", "name": "Defending", "desc": "Tackling and interceptions"},
		{"key": "MEN", "name": "Composure", "desc": "Decision making under pressure"}
	]
}

# Secondary stats (sub-attributes) derived from primaries
const SECONDARY_CATEGORIES = {
	"Attacking": [
		{"key": "finishing", "name": "Finishing", "desc": "Ability to score from close range"},
		{"key": "long_shots", "name": "Long Shots", "desc": "Accuracy from outside the box"},
		{"key": "heading", "name": "Heading", "desc": "Aerial ability and power"}
	],
	"Playmaking": [
		{"key": "vision", "name": "Vision", "desc": "Ability to spot passes and opportunities"},
		{"key": "crossing", "name": "Crossing", "desc": "Delivery from wide positions"},
		{"key": "acceleration", "name": "Acceleration", "desc": "Burst speed and explosiveness"}
	],
	"Defending": [
		{"key": "tackling", "name": "Tackling", "desc": "Ability to win the ball cleanly"},
		{"key": "interception", "name": "Interceptions", "desc": "Reading the game to cut passes"},
		{"key": "positioning", "name": "Positioning", "desc": "Being in the right place"}
	]
}


func _on_panel_ready() -> void:
	panel_title = "Player Stats"
	if title_label:
		title_label.text = panel_title

	_style_panels()


func _on_panel_opened() -> void:
	_connect_signals()
	_refresh_display()


func _style_panels() -> void:
	# Style the player card
	if player_card:
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = Color(0.04, 0.08, 0.15, 0.95)
		card_style.border_color = Color(0.15, 0.3, 0.5)
		card_style.set_border_width_all(2)
		card_style.set_corner_radius_all(12)
		card_style.set_content_margin_all(20)
		player_card.add_theme_stylebox_override("panel", card_style)

	# Style the portrait frame
	if portrait_frame:
		var portrait_style = StyleBoxFlat.new()
		portrait_style.bg_color = Color(0.08, 0.12, 0.2)
		portrait_style.border_color = Color(0.2, 0.35, 0.55)
		portrait_style.set_border_width_all(2)
		portrait_style.set_corner_radius_all(8)
		portrait_frame.add_theme_stylebox_override("panel", portrait_style)

	# Style the condition panel
	if condition_panel:
		var cond_style = StyleBoxFlat.new()
		cond_style.bg_color = Color(0.04, 0.08, 0.15, 0.95)
		cond_style.border_color = Color(0.15, 0.25, 0.4)
		cond_style.set_border_width_all(1)
		cond_style.set_corner_radius_all(8)
		cond_style.set_content_margin_all(16)
		condition_panel.add_theme_stylebox_override("panel", cond_style)

	# Style XP bar
	if xp_bar:
		var xp_bg = StyleBoxFlat.new()
		xp_bg.bg_color = Color(0.08, 0.12, 0.2)
		xp_bg.set_corner_radius_all(4)
		xp_bar.add_theme_stylebox_override("background", xp_bg)

		var xp_fill = StyleBoxFlat.new()
		xp_fill.bg_color = Color(0.2, 0.8, 0.4)
		xp_fill.set_corner_radius_all(4)
		xp_bar.add_theme_stylebox_override("fill", xp_fill)

	# Style stamina bar
	if stamina_bar:
		var sta_bg = StyleBoxFlat.new()
		sta_bg.bg_color = Color(0.08, 0.12, 0.2)
		sta_bg.set_corner_radius_all(3)
		stamina_bar.add_theme_stylebox_override("background", sta_bg)

		var sta_fill = StyleBoxFlat.new()
		sta_fill.bg_color = Color(0.3, 0.7, 1.0)
		sta_fill.set_corner_radius_all(3)
		stamina_bar.add_theme_stylebox_override("fill", sta_fill)

	# Style morale bar
	if morale_bar:
		var mor_bg = StyleBoxFlat.new()
		mor_bg.bg_color = Color(0.08, 0.12, 0.2)
		mor_bg.set_corner_radius_all(3)
		morale_bar.add_theme_stylebox_override("background", mor_bg)

		var mor_fill = StyleBoxFlat.new()
		mor_fill.bg_color = Color(1.0, 0.7, 0.3)
		mor_fill.set_corner_radius_all(3)
		morale_bar.add_theme_stylebox_override("fill", mor_fill)


func _connect_signals() -> void:
	if not StatSystem.stat_changed.is_connected(_on_stat_changed):
		StatSystem.stat_changed.connect(_on_stat_changed)
	if not StatSystem.level_up.is_connected(_on_level_up):
		StatSystem.level_up.connect(_on_level_up)


func _on_stat_changed(_player_id: String, _stat_name: String, _old_value: int, _new_value: int) -> void:
	if is_open:
		_refresh_display()


func _on_level_up(_player_id: String, _new_level: int) -> void:
	if is_open:
		_refresh_display()


func _refresh_display() -> void:
	var player = GameManager.player_data
	if not player:
		_show_no_player()
		return

	_update_player_card(player)
	_update_condition(player)
	_build_stats_display(player)


func _show_no_player() -> void:
	if player_name_label:
		player_name_label.text = "No Player"
	if overall_label:
		overall_label.text = "--"


func _update_player_card(player) -> void:
	# Overall rating (big and prominent)
	if overall_label:
		var ovr = player.get_overall()
		overall_label.text = str(ovr)
		overall_label.add_theme_color_override("font_color", _get_overall_color(ovr))

	# Player name
	if player_name_label:
		player_name_label.text = player.name

	# Position
	if position_label:
		position_label.text = player.position
		position_label.add_theme_color_override("font_color", _get_position_color(player.position))

	# Nationality
	if nationality_label:
		nationality_label.text = player.nationality

	# Dominant foot
	if foot_label:
		var foot_text = player.dominant_foot.capitalize() + " Foot"
		if player.dominant_foot == "both":
			foot_text = "Both Feet"
		foot_label.text = foot_text

	# Level and skill points
	if level_label:
		level_label.text = "Level %d" % player.level

	if skill_points_label:
		if player.skill_points > 0:
			skill_points_label.text = " (%d SP)" % player.skill_points
			skill_points_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		else:
			skill_points_label.text = ""

	# XP bar
	var xp_for_next = StatSystem.xp_for_level(player.level)
	if xp_bar:
		xp_bar.max_value = xp_for_next
		xp_bar.value = player.xp

	if xp_label:
		xp_label.text = "%d / %d XP" % [player.xp, xp_for_next]


func _update_condition(player) -> void:
	# Form
	if form_value_label:
		form_value_label.text = player.current_form.capitalize()
		form_value_label.add_theme_color_override("font_color", _get_form_color(player.current_form))

	# Stamina
	if stamina_bar:
		stamina_bar.value = player.stamina_current
	if stamina_value:
		stamina_value.text = "%d%%" % player.stamina_current

	# Morale
	if morale_bar:
		morale_bar.value = player.morale
	if morale_value:
		morale_value.text = "%d%%" % player.morale


func _build_stats_display(player) -> void:
	if not stats_container:
		return

	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()

	# Build primary stats categories
	_add_section_header("PRIMARY ATTRIBUTES")
	for category_name in STAT_CATEGORIES:
		_add_category_section(category_name, STAT_CATEGORIES[category_name], player)

	# Add divider
	_add_divider()

	# Build secondary stats (sub-attributes)
	_add_section_header("SUB-ATTRIBUTES")
	var secondaries = player.get_secondary_stats()
	for category_name in SECONDARY_CATEGORIES:
		_add_secondary_category_section(category_name, SECONDARY_CATEGORIES[category_name], secondaries)


func _add_category_section(category_name: String, stats: Array, player) -> void:
	# Category header
	var header = Label.new()
	header.text = category_name.to_upper()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	stats_container.add_child(header)

	# Stats grid (2 columns)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)

	for stat_info in stats:
		var stat_val = player.stats.get(stat_info.key, 50)
		var stat_xp = player.stat_xp.get(stat_info.key, 0)
		var stat_widget = _create_stat_widget(stat_info, stat_val, stat_xp)
		grid.add_child(stat_widget)

	stats_container.add_child(grid)

	# Spacer after category
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	stats_container.add_child(spacer)


func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	stats_container.add_child(header)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	stats_container.add_child(spacer)


func _add_divider() -> void:
	var divider = HSeparator.new()
	divider.add_theme_constant_override("separation", 4)
	divider.add_theme_stylebox_override("separator", _create_divider_style())
	stats_container.add_child(divider)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	stats_container.add_child(spacer)


func _create_divider_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.3, 0.4, 0.5)
	style.set_content_margin_all(1)
	return style


func _add_secondary_category_section(category_name: String, stats: Array, secondaries: Dictionary) -> void:
	# Category header
	var header = Label.new()
	header.text = category_name.to_upper()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	stats_container.add_child(header)

	# Stats grid (3 columns for secondary stats - more compact)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)

	for stat_info in stats:
		var value = secondaries.get(stat_info.key, 50)
		var stat_widget = _create_secondary_stat_widget(stat_info, value)
		grid.add_child(stat_widget)

	stats_container.add_child(grid)

	# Spacer after category
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	stats_container.add_child(spacer)


func _create_secondary_stat_widget(stat_info: Dictionary, value: int) -> Control:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(180, 0)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.9)
	style.border_color = Color(0.1, 0.16, 0.26)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	container.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Top row: name and value
	var top_row = HBoxContainer.new()

	var name_label = Label.new()
	name_label.text = stat_info.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	name_label.tooltip_text = stat_info.desc

	var value_label = Label.new()
	value_label.text = str(value)
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", _get_stat_color(value))

	top_row.add_child(name_label)
	top_row.add_child(value_label)

	# Compact stat bar
	var stat_bar = ProgressBar.new()
	stat_bar.max_value = 99
	stat_bar.value = value
	stat_bar.custom_minimum_size = Vector2(0, 6)
	stat_bar.show_percentage = false

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.1, 0.16)
	bar_bg.set_corner_radius_all(2)
	stat_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = _get_stat_color(value).darkened(0.2)
	bar_fill.set_corner_radius_all(2)
	stat_bar.add_theme_stylebox_override("fill", bar_fill)

	vbox.add_child(top_row)
	vbox.add_child(stat_bar)

	container.add_child(vbox)
	return container


func _create_stat_widget(stat_info: Dictionary, value: int, current_xp: int) -> Control:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(280, 0)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.16, 0.9)
	style.border_color = Color(0.12, 0.2, 0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	container.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Top row: name and value
	var top_row = HBoxContainer.new()

	var name_label = Label.new()
	name_label.text = stat_info.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	name_label.tooltip_text = stat_info.desc

	var value_label = Label.new()
	value_label.text = str(value)
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.add_theme_color_override("font_color", _get_stat_color(value))

	top_row.add_child(name_label)
	top_row.add_child(value_label)

	# Stat bar
	var stat_bar = ProgressBar.new()
	stat_bar.max_value = 99
	stat_bar.value = value
	stat_bar.custom_minimum_size = Vector2(0, 10)
	stat_bar.show_percentage = false

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.12, 0.2)
	bar_bg.set_corner_radius_all(3)
	stat_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = _get_stat_color(value)
	bar_fill.set_corner_radius_all(3)
	stat_bar.add_theme_stylebox_override("fill", bar_fill)

	# XP progress row
	var xp_row = HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 6)

	var xp_progress = ProgressBar.new()
	xp_progress.max_value = 100
	xp_progress.value = current_xp
	xp_progress.custom_minimum_size = Vector2(0, 6)
	xp_progress.show_percentage = false
	xp_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var xp_bg = StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.06, 0.1, 0.16)
	xp_bg.set_corner_radius_all(2)
	xp_progress.add_theme_stylebox_override("background", xp_bg)

	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.3, 0.5, 0.8, 0.8)
	xp_fill.set_corner_radius_all(2)
	xp_progress.add_theme_stylebox_override("fill", xp_fill)

	var xp_text = Label.new()
	xp_text.text = "%d/100" % current_xp
	xp_text.add_theme_font_size_override("font_size", 10)
	xp_text.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))

	xp_row.add_child(xp_progress)
	xp_row.add_child(xp_text)

	vbox.add_child(top_row)
	vbox.add_child(stat_bar)
	vbox.add_child(xp_row)

	container.add_child(vbox)
	return container


func _get_position_color(pos: String) -> Color:
	match pos:
		"GK":
			return Color(1.0, 0.8, 0.2)
		"CB", "LB", "RB", "LWB", "RWB":
			return Color(0.3, 0.6, 1.0)
		"CDM", "CM", "CAM", "LM", "RM":
			return Color(0.2, 0.9, 0.4)
		"LW", "RW", "CF", "ST":
			return Color(1.0, 0.4, 0.4)
		_:
			return Color(0.8, 0.8, 0.8)


func _get_overall_color(ovr: int) -> Color:
	if ovr >= 85:
		return Color(1.0, 0.84, 0.0)  # Gold
	elif ovr >= 75:
		return Color(0.0, 0.9, 0.4)  # Green
	elif ovr >= 65:
		return Color(0.9, 0.9, 0.9)  # White
	elif ovr >= 55:
		return Color(0.8, 0.6, 0.3)  # Bronze
	else:
		return Color(0.6, 0.6, 0.6)  # Gray


func _get_stat_color(val: int) -> Color:
	if val >= 80:
		return Color(0.2, 1.0, 0.5)  # Bright green
	elif val >= 70:
		return Color(0.5, 0.9, 0.4)  # Green
	elif val >= 60:
		return Color(0.9, 0.95, 1.0)  # White
	elif val >= 50:
		return Color(1.0, 0.8, 0.3)  # Yellow
	elif val >= 40:
		return Color(1.0, 0.5, 0.2)  # Orange
	else:
		return Color(1.0, 0.3, 0.3)  # Red


func _get_form_color(form: String) -> Color:
	match form:
		"excellent":
			return Color(0.2, 1.0, 0.5)
		"good":
			return Color(0.5, 0.9, 0.4)
		"average":
			return Color(0.9, 0.9, 0.2)
		"poor":
			return Color(1.0, 0.5, 0.2)
		"terrible":
			return Color(1.0, 0.3, 0.3)
		_:
			return Color(0.7, 0.75, 0.8)
