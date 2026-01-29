extends Control
## AppPlayerStats - Displays player stats, level, and progression

@onready var name_label: Label = $VBoxContainer/HeaderSection/NameLabel
@onready var position_label: Label = $VBoxContainer/HeaderSection/PositionLabel
@onready var overall_label: Label = $VBoxContainer/HeaderSection/OverallLabel
@onready var level_label: Label = $VBoxContainer/HeaderSection/LevelLabel
@onready var xp_bar: ProgressBar = $VBoxContainer/HeaderSection/XPBar
@onready var stats_container: VBoxContainer = $VBoxContainer/ScrollContainer/StatsContainer
@onready var form_label: Label = $VBoxContainer/FooterSection/FormLabel
@onready var morale_bar: ProgressBar = $VBoxContainer/FooterSection/MoraleBar


func _ready() -> void:
	_refresh_display()
	StatSystem.stat_changed.connect(_on_stat_changed)
	StatSystem.level_up.connect(_on_level_up)


func _refresh_display() -> void:
	var player = GameManager.player_data
	if not player:
		return

	# Header info
	name_label.text = player.name
	position_label.text = _get_position_name(player.position)
	overall_label.text = "OVR: %d" % player.get_overall()
	level_label.text = "Level %d" % player.level

	# XP progress
	var xp_needed = StatSystem.xp_for_level(player.level)
	xp_bar.max_value = xp_needed
	xp_bar.value = player.xp

	# Build stats display
	_build_stats_display(player)

	# Footer info
	form_label.text = "Form: %s" % player.current_form.capitalize()
	morale_bar.value = player.morale


func _build_stats_display(player: PlayerData) -> void:
	# Clear existing
	for child in stats_container.get_children():
		child.queue_free()

	# Primary stats
	var primary_header = Label.new()
	primary_header.text = "Primary Stats"
	primary_header.add_theme_font_size_override("font_size", 18)
	stats_container.add_child(primary_header)

	for stat_key in StatSystem.PRIMARY_STATS:
		var stat_name = StatSystem.PRIMARY_STATS[stat_key]
		var stat_value = player.stats.get(stat_key, 0)
		_add_stat_row(stat_key, stat_name, stat_value)

	# Separator
	var separator = HSeparator.new()
	stats_container.add_child(separator)

	# Secondary stats
	var secondary_header = Label.new()
	secondary_header.text = "Secondary Stats"
	secondary_header.add_theme_font_size_override("font_size", 18)
	stats_container.add_child(secondary_header)

	var secondaries = player.get_secondary_stats()
	for secondary_name in secondaries:
		var display_name = secondary_name.replace("_", " ").capitalize()
		_add_stat_row(secondary_name, display_name, secondaries[secondary_name])


func _add_stat_row(stat_key: String, stat_name: String, value: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = stat_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.custom_minimum_size = Vector2(120, 0)

	var value_lbl = Label.new()
	value_lbl.text = str(value)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_lbl.custom_minimum_size = Vector2(30, 0)
	value_lbl.add_theme_color_override("font_color", _get_stat_color(value))

	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(100, 16)

	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.3, 0.3, 0.3)
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bar_fill = ColorRect.new()
	bar_fill.color = _get_stat_color(value)
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.anchor_right = value / 100.0

	bar_container.add_child(bar_bg)
	bar_container.add_child(bar_fill)

	hbox.add_child(name_lbl)
	hbox.add_child(value_lbl)
	hbox.add_child(bar_container)

	stats_container.add_child(hbox)


func _get_stat_color(value: int) -> Color:
	if value >= 80:
		return Color(0.2, 0.9, 0.3)  # Green
	elif value >= 60:
		return Color(0.5, 0.8, 0.2)  # Yellow-green
	elif value >= 40:
		return Color(0.9, 0.8, 0.2)  # Yellow
	elif value >= 25:
		return Color(0.9, 0.5, 0.2)  # Orange
	else:
		return Color(0.9, 0.3, 0.2)  # Red


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


func _on_stat_changed(player_id: String, _stat_name: String, _old_value: int, _new_value: int) -> void:
	if GameManager.player_data and player_id == GameManager.player_data.id:
		_refresh_display()


func _on_level_up(player_id: String, _new_level: int) -> void:
	if GameManager.player_data and player_id == GameManager.player_data.id:
		_refresh_display()
