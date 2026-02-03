extends Control
## FreekickDrill - Free kick training mini-game
## Features 3x3 goal targeting, defensive wall, curve mechanics, power charging, and skill checks

signal drill_completed(results: Dictionary)

# Static function for simulating rewards without playing
static func calculate_simulated_rewards(goals: int, attempts: int = 10) -> Dictionary:
	var total_xp = XP_PER_ATTEMPT * attempts
	total_xp += XP_PER_GOAL * goals

	# Estimate bonus XP based on score
	var top_corner_bonus = roundi(goals * 0.3) * XP_TOP_CORNER_BONUS  # Assume 30% top corners
	var curve_bonus = roundi(goals * 0.5) * XP_CURVE_GOAL_BONUS  # Assume 50% used correct curve
	total_xp += top_corner_bonus + curve_bonus

	if goals >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if goals >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var sho_xp = (STAT_XP_PER_GOAL * goals) + (STAT_XP_PER_MISS * (attempts - goals))
	var tec_xp = TEC_XP_PER_ATTEMPT * attempts

	return {
		"goals": goals,
		"attempts": attempts,
		"total_xp": total_xp,
		"sho_xp": sho_xp,
		"tec_xp": tec_xp,
		"stamina_cost": STAMINA_COST
	}


enum DrillState {
	SETUP,
	SELECTING_ZONE,
	SELECTING_CURVE,
	CHARGING_POWER,
	RESOLVING,
	SHOWING_RESULT,
	DRILL_COMPLETE
}

enum WallPosition {
	LEFT,
	CENTER,
	RIGHT
}

enum CurveDirection {
	LEFT_SWERVE,
	STRAIGHT,
	RIGHT_SWERVE
}

# Difficulty settings
const DIFFICULTY_SETTINGS: Dictionary = {
	"youth": {"name": "20 yards", "distance": 20, "wall_size": 3, "base_mod": 5, "gk_stat": 35, "unlocked": true},
	"pro": {"name": "25 yards", "distance": 25, "wall_size": 4, "base_mod": 0, "gk_stat": 55, "unlocked": false},
	"elite": {"name": "30 yards", "distance": 30, "wall_size": 4, "base_mod": -10, "gk_stat": 75, "unlocked": false}
}

# Zone modifiers (same as penalty)
const ZONE_MODIFIERS: Dictionary = {
	"TOP_LEFT": -20, "TOP_CENTER": -15, "TOP_RIGHT": -20,
	"MID_LEFT": -10, "MID_CENTER": 5, "MID_RIGHT": -10,
	"LOW_LEFT": -10, "LOW_CENTER": -5, "LOW_RIGHT": -10
}

# Wall blocking - which zones are blocked by each wall position
const WALL_BLOCKING: Dictionary = {
	WallPosition.LEFT: {
		"full": ["LOW_LEFT", "MID_LEFT"],
		"partial": ["LOW_CENTER"]
	},
	WallPosition.CENTER: {
		"full": ["LOW_CENTER", "MID_CENTER"],
		"partial": ["LOW_LEFT", "LOW_RIGHT"]
	},
	WallPosition.RIGHT: {
		"full": ["LOW_RIGHT", "MID_RIGHT"],
		"partial": ["LOW_CENTER"]
	}
}

# Zone groupings for curve calculation
const LEFT_ZONES: Array[String] = ["TOP_LEFT", "MID_LEFT", "LOW_LEFT"]
const CENTER_ZONES: Array[String] = ["TOP_CENTER", "MID_CENTER", "LOW_CENTER"]
const RIGHT_ZONES: Array[String] = ["TOP_RIGHT", "MID_RIGHT", "LOW_RIGHT"]
const TOP_CORNER_ZONES: Array[String] = ["TOP_LEFT", "TOP_RIGHT"]

# Power modifiers
const POWER_RANGES: Array[Dictionary] = [
	{"min": 0, "max": 39, "name": "Weak", "modifier": -15},
	{"min": 40, "max": 69, "name": "Good", "modifier": 0},
	{"min": 70, "max": 85, "name": "Optimal", "modifier": 5},
	{"min": 86, "max": 100, "name": "Overpowered", "modifier": -10}
]

# XP rewards
const XP_PER_ATTEMPT: int = 5
const XP_PER_GOAL: int = 10
const XP_TOP_CORNER_BONUS: int = 5
const XP_CURVE_GOAL_BONUS: int = 3
const XP_GOOD_SESSION_BONUS: int = 25  # 7+ goals
const XP_PERFECT_SESSION_BONUS: int = 50  # 10/10
const STAT_XP_PER_GOAL: int = 3
const STAT_XP_PER_MISS: int = 1
const TEC_XP_PER_ATTEMPT: int = 2
const STAMINA_COST: int = 15
const FREEKICKS_PER_SESSION: int = 10
const CHARGE_RATE: float = 66.67  # 100% in 1.5 seconds

# Console Dashboard Colors
const BG_DARK = Color(0.039, 0.086, 0.157)
const PANEL_BG = Color(0.06, 0.1, 0.18, 0.95)
const BORDER_COLOR = Color(0.15, 0.25, 0.4)
const ACCENT_GREEN = Color(0, 1, 0.5)
const TEXT_PRIMARY = Color(0.9, 0.95, 1)
const TEXT_SECONDARY = Color(0.6, 0.65, 0.7)
const TEXT_MUTED = Color(0.5, 0.55, 0.6)

# State Colors
const COLOR_DEFAULT = Color(0.1, 0.15, 0.25)
const COLOR_SELECTED = Color(0, 0.6, 0.3)
const COLOR_SUCCESS = Color(0, 0.8, 0.4)
const COLOR_FAIL = Color(0.8, 0.3, 0.3)
const COLOR_WARNING = Color(0.9, 0.7, 0.2)
const COLOR_BLOCKED = Color(0.6, 0.2, 0.2)
const COLOR_CONTESTED = Color(0.8, 0.5, 0.2)
const COLOR_OPEN = Color(0.2, 0.5, 0.8)

# Node references
@onready var difficulty_selector: OptionButton = $VBoxContainer/HeaderSection/DifficultyContainer/DifficultySelector
@onready var score_label: Label = $VBoxContainer/HeaderSection/ScoreLabel
@onready var zone_grid: GridContainer = $VBoxContainer/MainContent/GoalSection/GoalFrame/ZoneGrid
@onready var wall_indicator: HBoxContainer = $VBoxContainer/MainContent/GoalSection/WallIndicator
@onready var curve_container: HBoxContainer = $VBoxContainer/MainContent/GoalSection/CurveSection/CurveButtons
@onready var curve_hint_label: Label = $VBoxContainer/MainContent/GoalSection/CurveSection/CurveHint
@onready var power_bar: ProgressBar = $VBoxContainer/MainContent/GoalSection/PowerSection/PowerBar
@onready var power_label: Label = $VBoxContainer/MainContent/GoalSection/PowerSection/PowerLabel
@onready var shoot_button: Button = $VBoxContainer/MainContent/GoalSection/ShootButton
@onready var sho_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/SHORow/SHOValue
@onready var tec_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/TECRow/TECValue
@onready var base_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/BaseRow/BaseValue
@onready var zone_mod_label: Label = $VBoxContainer/MainContent/InfoSection/ModifiersPanel/ModifiersVBox/ZoneModLabel
@onready var wall_mod_label: Label = $VBoxContainer/MainContent/InfoSection/ModifiersPanel/ModifiersVBox/WallModLabel
@onready var curve_mod_label: Label = $VBoxContainer/MainContent/InfoSection/ModifiersPanel/ModifiersVBox/CurveModLabel
@onready var power_mod_label: Label = $VBoxContainer/MainContent/InfoSection/ModifiersPanel/ModifiersVBox/PowerModLabel
@onready var final_chance_label: Label = $VBoxContainer/MainContent/InfoSection/ModifiersPanel/ModifiersVBox/FinalChanceLabel
@onready var skill_check_details: RichTextLabel = $VBoxContainer/MainContent/InfoSection/SkillCheckPanel/SkillCheckVBox/SkillCheckDetails
@onready var narration_label: RichTextLabel = $VBoxContainer/NarrationSection/NarrationLabel
@onready var attempt_counter: Label = $VBoxContainer/FooterSection/AttemptCounter
@onready var continue_button: Button = $VBoxContainer/FooterSection/ContinueButton
@onready var exit_button: Button = $VBoxContainer/FooterSection/ExitButton
@onready var charge_timer: Timer = $ChargeTimer

# State
var current_state: DrillState = DrillState.SETUP
var current_difficulty: String = "youth"
var selected_zone: String = ""
var selected_curve: CurveDirection = CurveDirection.STRAIGHT
var current_wall_position: WallPosition = WallPosition.CENTER
var current_power: float = 0.0
var is_charging: bool = false

# Session tracking
var attempts_taken: int = 0
var goals_scored: int = 0
var top_corner_goals: int = 0
var curve_goals: int = 0
var session_results: Array[Dictionary] = []

# Zone button references
var zone_buttons: Dictionary = {}
var curve_buttons: Array[Button] = []
var wall_blocks: Array[Panel] = []


func _ready() -> void:
	_setup_difficulty_selector()
	_setup_zone_buttons()
	_setup_curve_buttons()
	_setup_wall_indicator()
	_setup_signals()
	_style_footer_buttons()
	_update_player_stats_display()
	_generate_new_wall_position()
	_set_state(DrillState.SELECTING_ZONE)
	_show_session_start_narration()


func _setup_difficulty_selector() -> void:
	difficulty_selector.clear()
	var idx = 0
	for diff_id in DIFFICULTY_SETTINGS:
		var diff = DIFFICULTY_SETTINGS[diff_id]
		var text = diff.name
		if not diff.unlocked:
			text += " (Locked)"
		difficulty_selector.add_item(text, idx)
		if not diff.unlocked:
			difficulty_selector.set_item_disabled(idx, true)
		idx += 1
	difficulty_selector.selected = 0
	difficulty_selector.item_selected.connect(_on_difficulty_changed)


func _setup_zone_buttons() -> void:
	var zone_names = ["TOP_LEFT", "TOP_CENTER", "TOP_RIGHT",
					  "MID_LEFT", "MID_CENTER", "MID_RIGHT",
					  "LOW_LEFT", "LOW_CENTER", "LOW_RIGHT"]
	var button_names = ["TopLeft", "TopCenter", "TopRight",
						"MidLeft", "MidCenter", "MidRight",
						"LowLeft", "LowCenter", "LowRight"]

	for i in range(zone_names.size()):
		var btn = zone_grid.get_node(button_names[i])
		zone_buttons[zone_names[i]] = btn
		btn.pressed.connect(_on_zone_selected.bind(zone_names[i]))


func _setup_curve_buttons() -> void:
	curve_buttons = [
		curve_container.get_node("LeftSwerve"),
		curve_container.get_node("Straight"),
		curve_container.get_node("RightSwerve")
	]

	curve_buttons[0].pressed.connect(_on_curve_selected.bind(CurveDirection.LEFT_SWERVE))
	curve_buttons[1].pressed.connect(_on_curve_selected.bind(CurveDirection.STRAIGHT))
	curve_buttons[2].pressed.connect(_on_curve_selected.bind(CurveDirection.RIGHT_SWERVE))


func _setup_wall_indicator() -> void:
	# Store references to wall block panels
	for i in range(4):
		var block = wall_indicator.get_node("WallBlock%d" % (i + 1))
		wall_blocks.append(block)


func _setup_signals() -> void:
	shoot_button.pressed.connect(_on_shoot_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	charge_timer.timeout.connect(_on_charge_tick)


func _style_footer_buttons() -> void:
	# Style Continue button with console green accent
	var continue_style = StyleBoxFlat.new()
	continue_style.bg_color = Color(0, 0.6, 0.3)
	continue_style.border_width_left = 2
	continue_style.border_width_top = 2
	continue_style.border_width_right = 2
	continue_style.border_width_bottom = 2
	continue_style.border_color = Color(0, 0.8, 0.4)
	continue_style.set_corner_radius_all(6)
	continue_button.add_theme_stylebox_override("normal", continue_style)
	continue_button.add_theme_color_override("font_color", TEXT_PRIMARY)

	var continue_hover = continue_style.duplicate()
	continue_hover.bg_color = Color(0, 0.7, 0.35)
	continue_button.add_theme_stylebox_override("hover", continue_hover)

	var continue_pressed = continue_style.duplicate()
	continue_pressed.bg_color = Color(0, 0.5, 0.25)
	continue_button.add_theme_stylebox_override("pressed", continue_pressed)

	# Style Exit button with dark panel style
	var exit_style = StyleBoxFlat.new()
	exit_style.bg_color = COLOR_DEFAULT
	exit_style.border_width_left = 2
	exit_style.border_width_top = 2
	exit_style.border_width_right = 2
	exit_style.border_width_bottom = 2
	exit_style.border_color = BORDER_COLOR
	exit_style.set_corner_radius_all(6)
	exit_button.add_theme_stylebox_override("normal", exit_style)
	exit_button.add_theme_color_override("font_color", TEXT_PRIMARY)

	var exit_hover = exit_style.duplicate()
	exit_hover.bg_color = Color(0.15, 0.2, 0.3)
	exit_button.add_theme_stylebox_override("hover", exit_hover)

	var exit_pressed = exit_style.duplicate()
	exit_pressed.bg_color = Color(0.08, 0.12, 0.2)
	exit_button.add_theme_stylebox_override("pressed", exit_pressed)

	# Style Shoot button with console theme
	var shoot_style = StyleBoxFlat.new()
	shoot_style.bg_color = COLOR_DEFAULT
	shoot_style.border_width_left = 2
	shoot_style.border_width_top = 2
	shoot_style.border_width_right = 2
	shoot_style.border_width_bottom = 2
	shoot_style.border_color = ACCENT_GREEN
	shoot_style.set_corner_radius_all(6)
	shoot_button.add_theme_stylebox_override("normal", shoot_style)
	shoot_button.add_theme_color_override("font_color", TEXT_PRIMARY)

	var shoot_hover = shoot_style.duplicate()
	shoot_hover.bg_color = Color(0.15, 0.2, 0.3)
	shoot_button.add_theme_stylebox_override("hover", shoot_hover)

	var shoot_pressed = shoot_style.duplicate()
	shoot_pressed.bg_color = Color(0, 0.5, 0.25)
	shoot_button.add_theme_stylebox_override("pressed", shoot_pressed)

	var shoot_disabled = shoot_style.duplicate()
	shoot_disabled.bg_color = Color(0.08, 0.1, 0.15)
	shoot_disabled.border_color = Color(0.2, 0.25, 0.35)
	shoot_button.add_theme_stylebox_override("disabled", shoot_disabled)
	shoot_button.add_theme_color_override("font_disabled_color", TEXT_MUTED)


func _update_player_stats_display() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var sho = player.get_effective_stat("SHO")
	var tec = player.get_effective_stat("TEC")
	var base = _calculate_base_chance(sho, tec)

	sho_value.text = str(sho)
	tec_value.text = str(tec)
	base_value.text = "%.1f%%" % base


func _calculate_base_chance(sho: int, tec: int) -> float:
	return (sho * 0.6) + (tec * 0.4)


func _generate_new_wall_position() -> void:
	# Randomly choose wall position
	current_wall_position = randi() % 3 as WallPosition
	_update_wall_display()
	_update_zone_blocking_display()


func _update_wall_display() -> void:
	var diff = DIFFICULTY_SETTINGS[current_difficulty]
	var wall_size = diff.wall_size

	# Show/hide wall blocks based on wall size
	for i in range(wall_blocks.size()):
		wall_blocks[i].visible = i < wall_size

	# Position wall blocks based on wall position
	var base_offset = 0
	match current_wall_position:
		WallPosition.LEFT:
			base_offset = 0
		WallPosition.CENTER:
			base_offset = 1
		WallPosition.RIGHT:
			base_offset = 2

	# Update wall indicator alignment
	match current_wall_position:
		WallPosition.LEFT:
			wall_indicator.alignment = BoxContainer.ALIGNMENT_BEGIN
		WallPosition.CENTER:
			wall_indicator.alignment = BoxContainer.ALIGNMENT_CENTER
		WallPosition.RIGHT:
			wall_indicator.alignment = BoxContainer.ALIGNMENT_END


func _update_zone_blocking_display() -> void:
	var blocking = WALL_BLOCKING[current_wall_position]

	for zone in zone_buttons:
		var btn = zone_buttons[zone]
		var base_color = COLOR_DEFAULT
		var border_color = BORDER_COLOR

		if zone in blocking.full:
			border_color = COLOR_BLOCKED  # Red - fully blocked
		elif zone in blocking.partial:
			border_color = COLOR_WARNING  # Amber - partially blocked
		else:
			border_color = COLOR_OPEN  # Blue - clear

		_set_zone_button_style(zone, base_color, border_color)


func _get_wall_modifier(zone: String) -> int:
	var blocking = WALL_BLOCKING[current_wall_position]

	if zone in blocking.full:
		return -30  # Fully blocked
	elif zone in blocking.partial:
		return -15  # Partially blocked
	else:
		return 5  # Clear shot


func _get_curve_modifier(target_zone: String, curve: CurveDirection, tec: int) -> int:
	var tec_factor = tec / 100.0  # Scale by technique

	if curve == CurveDirection.STRAIGHT:
		return 0

	var target_side = "center"
	if target_zone in LEFT_ZONES:
		target_side = "left"
	elif target_zone in RIGHT_ZONES:
		target_side = "right"

	# Curving TOWARD the target side is correct
	# Left swerve curves ball to the RIGHT (from kicker's view)
	# Right swerve curves ball to the LEFT
	var correct_curve = false
	if target_side == "right" and curve == CurveDirection.LEFT_SWERVE:
		correct_curve = true  # Ball curves right
	elif target_side == "left" and curve == CurveDirection.RIGHT_SWERVE:
		correct_curve = true  # Ball curves left
	elif target_side == "center":
		correct_curve = false  # Center targets don't benefit much

	if correct_curve:
		return roundi(10.0 * tec_factor)  # Up to +10%
	else:
		return roundi(-15.0 * tec_factor)  # Up to -15%


func _is_correct_curve(target_zone: String, curve: CurveDirection) -> bool:
	if curve == CurveDirection.STRAIGHT:
		return false

	var target_side = "center"
	if target_zone in LEFT_ZONES:
		target_side = "left"
	elif target_zone in RIGHT_ZONES:
		target_side = "right"

	if target_side == "right" and curve == CurveDirection.LEFT_SWERVE:
		return true
	elif target_side == "left" and curve == CurveDirection.RIGHT_SWERVE:
		return true

	return false


func _set_state(new_state: DrillState) -> void:
	current_state = new_state

	match new_state:
		DrillState.SELECTING_ZONE:
			_enable_zone_selection(true)
			_enable_curve_selection(false)
			shoot_button.disabled = true
			shoot_button.text = "Select a target zone"
			continue_button.visible = false
			power_bar.value = 0
			current_power = 0.0
			selected_zone = ""
			selected_curve = CurveDirection.STRAIGHT
			_reset_curve_selection()

		DrillState.SELECTING_CURVE:
			_enable_zone_selection(false)
			_enable_curve_selection(true)
			shoot_button.disabled = true
			shoot_button.text = "Select curve direction"
			_update_curve_hint()

		DrillState.CHARGING_POWER:
			_enable_zone_selection(false)
			_enable_curve_selection(false)
			shoot_button.text = "Charging... Release to Shoot!"

		DrillState.RESOLVING:
			shoot_button.disabled = true
			shoot_button.text = "Resolving..."

		DrillState.SHOWING_RESULT:
			continue_button.visible = true
			shoot_button.disabled = true

		DrillState.DRILL_COMPLETE:
			_enable_zone_selection(false)
			_enable_curve_selection(false)
			shoot_button.visible = false
			continue_button.visible = false
			exit_button.text = "Finish & Collect XP"


func _enable_zone_selection(enabled: bool) -> void:
	for zone in zone_buttons:
		zone_buttons[zone].disabled = not enabled


func _enable_curve_selection(enabled: bool) -> void:
	for btn in curve_buttons:
		btn.disabled = not enabled


func _reset_curve_selection() -> void:
	for i in range(curve_buttons.size()):
		var btn = curve_buttons[i]
		var style = StyleBoxFlat.new()
		style.bg_color = COLOR_DEFAULT
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = BORDER_COLOR
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)

	# Default select straight
	selected_curve = CurveDirection.STRAIGHT
	_highlight_curve_button(1)


func _highlight_curve_button(index: int) -> void:
	for i in range(curve_buttons.size()):
		var btn = curve_buttons[i]
		var style = StyleBoxFlat.new()
		if i == index:
			style.bg_color = COLOR_SELECTED  # Green highlight
			style.border_color = ACCENT_GREEN
		else:
			style.bg_color = COLOR_DEFAULT
			style.border_color = BORDER_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)


func _update_curve_hint() -> void:
	if selected_zone.is_empty():
		curve_hint_label.text = "Select a zone first"
		return

	var target_side = "center"
	if selected_zone in LEFT_ZONES:
		target_side = "left"
	elif selected_zone in RIGHT_ZONES:
		target_side = "right"

	match target_side:
		"left":
			curve_hint_label.text = "Right swerve curves toward left targets"
		"right":
			curve_hint_label.text = "Left swerve curves toward right targets"
		"center":
			curve_hint_label.text = "Center targets: curve less effective"


func _input(event: InputEvent) -> void:
	if current_state == DrillState.SELECTING_CURVE or current_state == DrillState.CHARGING_POWER:
		if event.is_action_pressed("ui_select"):  # SPACE
			if current_state == DrillState.SELECTING_CURVE:
				_start_charging()
		elif event.is_action_released("ui_select"):
			if is_charging:
				_release_shot()


func _start_charging() -> void:
	if current_state != DrillState.SELECTING_CURVE:
		return

	is_charging = true
	current_power = 0.0
	_set_state(DrillState.CHARGING_POWER)
	charge_timer.start()
	AudioManager.play_ui_click()


func _on_charge_tick() -> void:
	if not is_charging:
		charge_timer.stop()
		return

	current_power = minf(current_power + CHARGE_RATE * charge_timer.wait_time, 100.0)
	power_bar.value = current_power
	_update_power_bar_color()
	_update_modifiers_display()


func _update_power_bar_color() -> void:
	var color: Color
	if current_power < 40:
		color = COLOR_FAIL  # Darker red - weak
	elif current_power < 70:
		color = COLOR_WARNING  # Amber - good
	elif current_power <= 85:
		color = COLOR_SUCCESS  # Console green - optimal
	else:
		color = COLOR_CONTESTED  # Orange - overpowered

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(4)
	power_bar.add_theme_stylebox_override("fill", fill_style)

	# Set dark background for power bar
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = COLOR_DEFAULT
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = BORDER_COLOR
	bg_style.set_corner_radius_all(4)
	power_bar.add_theme_stylebox_override("background", bg_style)


func _release_shot() -> void:
	is_charging = false
	charge_timer.stop()
	_set_state(DrillState.RESOLVING)
	_resolve_freekick()


func _on_zone_selected(zone: String) -> void:
	if current_state != DrillState.SELECTING_ZONE:
		return

	# Reset zone colors to blocking display
	_update_zone_blocking_display()

	# Highlight new selection with green
	selected_zone = zone
	_set_zone_button_style(zone, COLOR_SELECTED, ACCENT_GREEN)

	_update_modifiers_display()
	AudioManager.play_ui_click()

	# Move to curve selection
	_set_state(DrillState.SELECTING_CURVE)


func _on_curve_selected(curve: CurveDirection) -> void:
	if current_state != DrillState.SELECTING_CURVE:
		return

	selected_curve = curve
	_highlight_curve_button(curve as int)

	shoot_button.disabled = false
	shoot_button.text = "Hold SPACE to Charge Power"

	_update_modifiers_display()
	AudioManager.play_ui_click()


func _set_zone_button_style(zone: String, bg_color: Color, border_color: Color) -> void:
	var btn = zone_buttons.get(zone)
	if btn:
		var style = StyleBoxFlat.new()
		style.bg_color = bg_color
		style.border_width_left = 3
		style.border_width_top = 3
		style.border_width_right = 3
		style.border_width_bottom = 3
		style.border_color = border_color
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", TEXT_PRIMARY)


func _update_modifiers_display() -> void:
	if selected_zone.is_empty():
		zone_mod_label.text = "Zone: --"
		wall_mod_label.text = "Wall: --"
		curve_mod_label.text = "Curve: --"
		power_mod_label.text = "Power: --"
		final_chance_label.text = "Final: --%"
		return

	var player = GameManager.player_data
	if not player:
		return

	var tec = player.get_effective_stat("TEC")

	var zone_mod = ZONE_MODIFIERS.get(selected_zone, 0)
	var wall_mod = _get_wall_modifier(selected_zone)
	var curve_mod = _get_curve_modifier(selected_zone, selected_curve, tec)
	var power_mod = _get_power_modifier(current_power)
	var power_name = _get_power_name(current_power)
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	zone_mod_label.text = "Zone: %+d%%" % zone_mod

	var wall_status = "Clear" if wall_mod > 0 else ("Partial" if wall_mod == -15 else "Blocked")
	wall_mod_label.text = "Wall (%s): %+d%%" % [wall_status, wall_mod]

	var curve_name = ["Left Swerve", "Straight", "Right Swerve"][selected_curve as int]
	curve_mod_label.text = "Curve (%s): %+d%%" % [curve_name, curve_mod]

	power_mod_label.text = "Power (%s): %+d%%" % [power_name, power_mod]

	var sho = player.get_effective_stat("SHO")
	var base = _calculate_base_chance(sho, tec)
	var final = base + zone_mod + wall_mod + curve_mod + power_mod + diff.base_mod
	final_chance_label.text = "Final: %.1f%%" % final


func _get_power_modifier(power: float) -> int:
	for range_data in POWER_RANGES:
		if power >= range_data.min and power <= range_data.max:
			return range_data.modifier
	return 0


func _get_power_name(power: float) -> String:
	for range_data in POWER_RANGES:
		if power >= range_data.min and power <= range_data.max:
			return range_data.name
	return "Unknown"


func _resolve_freekick() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var sho = player.get_effective_stat("SHO")
	var tec = player.get_effective_stat("TEC")
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	# Calculate success chance
	var base_chance = _calculate_base_chance(sho, tec)
	var zone_mod = ZONE_MODIFIERS.get(selected_zone, 0)
	var wall_mod = _get_wall_modifier(selected_zone)
	var curve_mod = _get_curve_modifier(selected_zone, selected_curve, tec)
	var power_mod = _get_power_modifier(current_power)
	var distance_mod = diff.base_mod

	var success_chance = base_chance + zone_mod + wall_mod + curve_mod + power_mod + distance_mod

	# Roll for shot on target
	var roll = randf() * 100.0
	var shot_on_target = roll <= success_chance

	var used_correct_curve = _is_correct_curve(selected_zone, selected_curve)
	var is_top_corner = selected_zone in TOP_CORNER_ZONES

	var result: Dictionary = {
		"zone": selected_zone,
		"power": current_power,
		"power_name": _get_power_name(current_power),
		"curve": selected_curve,
		"curve_name": ["Left Swerve", "Straight", "Right Swerve"][selected_curve as int],
		"wall_position": current_wall_position,
		"base_chance": base_chance,
		"zone_mod": zone_mod,
		"wall_mod": wall_mod,
		"curve_mod": curve_mod,
		"power_mod": power_mod,
		"distance_mod": distance_mod,
		"success_chance": success_chance,
		"roll": roll,
		"shot_on_target": shot_on_target,
		"scored": false,
		"gk_save_chance": 0.0,
		"gk_roll": 0.0,
		"used_correct_curve": used_correct_curve,
		"is_top_corner": is_top_corner
	}

	if shot_on_target:
		# GK attempts save
		var gk_result = _resolve_gk_save(selected_zone, diff)
		result.gk_save_chance = gk_result.save_chance
		result.gk_roll = gk_result.roll
		result.scored = not gk_result.saved

	# Track result
	attempts_taken += 1
	if result.scored:
		goals_scored += 1
		if is_top_corner:
			top_corner_goals += 1
		if used_correct_curve:
			curve_goals += 1
	session_results.append(result)

	# Show result
	_display_result(result)
	_update_score_display()

	# Check for drill completion
	if attempts_taken >= FREEKICKS_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


func _resolve_gk_save(target_zone: String, diff: Dictionary) -> Dictionary:
	# GK save chance based on difficulty and zone
	var base_save_chance = diff.gk_stat * 0.4

	# Top corners are harder to save
	if target_zone in TOP_CORNER_ZONES:
		base_save_chance -= 15.0
	# Mid zones are easier
	elif target_zone in ["MID_LEFT", "MID_CENTER", "MID_RIGHT"]:
		base_save_chance += 10.0
	# Low zones blocked by wall are rarely reached
	elif _get_wall_modifier(target_zone) < 0:
		base_save_chance -= 5.0  # Ball had to bend around wall

	base_save_chance = clampf(base_save_chance, 5.0, 85.0)

	var roll = randf() * 100.0
	var saved = roll <= base_save_chance

	return {
		"save_chance": base_save_chance,
		"roll": roll,
		"saved": saved
	}


func _display_result(result: Dictionary) -> void:
	# Update zone button color
	if result.scored:
		_set_zone_button_style(selected_zone, COLOR_SUCCESS, Color(0, 0.6, 0.3))  # Green - goal
	else:
		_set_zone_button_style(selected_zone, COLOR_FAIL, Color(0.6, 0.2, 0.2))  # Red - miss/save

	# Build skill check breakdown
	var breakdown = ""
	breakdown += "[b]Free Kick Calculation:[/b]\n"
	breakdown += "Base: (SHO × 0.6) + (TEC × 0.4) = %.1f%%\n" % result.base_chance
	breakdown += "Zone (%s): %+d%%\n" % [selected_zone, result.zone_mod]

	var wall_status = "Clear" if result.wall_mod > 0 else ("Partial" if result.wall_mod == -15 else "Blocked")
	breakdown += "Wall (%s): %+d%%\n" % [wall_status, result.wall_mod]
	breakdown += "Curve (%s): %+d%%\n" % [result.curve_name, result.curve_mod]
	breakdown += "Power (%s): %+d%%\n" % [result.power_name, result.power_mod]

	if result.distance_mod != 0:
		breakdown += "Distance: %+d%%\n" % result.distance_mod

	breakdown += "[b]Final: %.1f%%[/b]\n\n" % result.success_chance
	breakdown += "Roll: %.1f vs %.1f\n" % [result.roll, result.success_chance]

	if result.shot_on_target:
		breakdown += "[color=green]Shot on target![/color]\n\n"
		breakdown += "[b]GK Save Attempt:[/b]\n"
		breakdown += "Save chance: %.1f%%\n" % result.gk_save_chance
		breakdown += "Roll: %.1f vs %.1f\n" % [result.gk_roll, result.gk_save_chance]

		if result.scored:
			breakdown += "\n[color=green][b]GOAL![/b][/color]"
			if result.is_top_corner:
				breakdown += " [color=yellow](Top Corner Bonus!)[/color]"
			if result.used_correct_curve:
				breakdown += " [color=cyan](Curve Bonus!)[/color]"
		else:
			breakdown += "\n[color=red][b]SAVED![/b][/color]"
	else:
		if result.wall_mod == -30:
			breakdown += "[color=red]Blocked by the wall![/color]"
		else:
			breakdown += "[color=red]Shot off target! MISSED![/color]"

	skill_check_details.text = breakdown

	# Show narration
	_show_result_narration(result)


func _show_result_narration(result: Dictionary) -> void:
	var narrative: Dictionary
	var context = {
		"zone": selected_zone.replace("_", " ").to_lower(),
		"power": result.power_name.to_lower(),
		"curve": result.curve_name.to_lower()
	}

	if result.scored:
		if result.is_top_corner:
			narrative = NarrativeEngine.generate_dialogue("freekick", "goal_top_corner", context)
		else:
			narrative = NarrativeEngine.generate_dialogue("freekick", "goal", context)
	elif result.shot_on_target:
		narrative = NarrativeEngine.generate_dialogue("freekick", "saved", context)
	elif result.wall_mod == -30:
		narrative = NarrativeEngine.generate_dialogue("freekick", "wall_block", context)
	else:
		narrative = NarrativeEngine.generate_dialogue("freekick", "missed", context)

	narration_label.text = "[i]%s[/i]" % narrative.text


func _show_session_start_narration() -> void:
	var narrative = NarrativeEngine.generate_dialogue("freekick", "session_start", {})
	narration_label.text = "[i]%s[/i]" % narrative.text


func _update_score_display() -> void:
	score_label.text = "%d / %d" % [goals_scored, FREEKICKS_PER_SESSION]
	attempt_counter.text = "Attempt %d of %d" % [mini(attempts_taken + 1, FREEKICKS_PER_SESSION), FREEKICKS_PER_SESSION]


func _complete_drill() -> void:
	_set_state(DrillState.DRILL_COMPLETE)

	# Calculate rewards
	var total_xp = XP_PER_ATTEMPT * attempts_taken
	total_xp += XP_PER_GOAL * goals_scored
	total_xp += XP_TOP_CORNER_BONUS * top_corner_goals
	total_xp += XP_CURVE_GOAL_BONUS * curve_goals

	if goals_scored >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if goals_scored >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var sho_xp = (STAT_XP_PER_GOAL * goals_scored) + (STAT_XP_PER_MISS * (attempts_taken - goals_scored))
	var tec_xp = TEC_XP_PER_ATTEMPT * attempts_taken

	# Build summary
	var summary = "[b]Drill Complete![/b]\n\n"
	summary += "Goals: %d / %d (%.0f%%)\n\n" % [goals_scored, attempts_taken, (float(goals_scored) / attempts_taken) * 100]
	summary += "[b]XP Earned:[/b]\n"
	summary += "Base: %d XP (%d attempts × %d)\n" % [XP_PER_ATTEMPT * attempts_taken, attempts_taken, XP_PER_ATTEMPT]
	summary += "Goals: +%d XP (%d goals × %d)\n" % [XP_PER_GOAL * goals_scored, goals_scored, XP_PER_GOAL]

	if top_corner_goals > 0:
		summary += "Top Corners: +%d XP (%d × %d)\n" % [XP_TOP_CORNER_BONUS * top_corner_goals, top_corner_goals, XP_TOP_CORNER_BONUS]
	if curve_goals > 0:
		summary += "Curve Goals: +%d XP (%d × %d)\n" % [XP_CURVE_GOAL_BONUS * curve_goals, curve_goals, XP_CURVE_GOAL_BONUS]

	if goals_scored >= 10:
		summary += "Perfect Session: +%d XP\n" % XP_PERFECT_SESSION_BONUS
	elif goals_scored >= 7:
		summary += "Good Session: +%d XP\n" % XP_GOOD_SESSION_BONUS

	summary += "[b]Total: %d XP[/b]\n\n" % total_xp
	summary += "[b]Stat XP:[/b]\n"
	summary += "SHO: +%d\n" % sho_xp
	summary += "TEC: +%d\n" % tec_xp

	skill_check_details.text = summary

	# Show session end narration
	var context = {"goals": str(goals_scored), "total": str(attempts_taken)}
	var narrative = NarrativeEngine.generate_dialogue("freekick", "session_end", context)
	narration_label.text = "[i]%s[/i]" % narrative.text

	# Store results for when drill is exited
	var results = {
		"attempts_taken": attempts_taken,
		"goals_scored": goals_scored,
		"top_corner_goals": top_corner_goals,
		"curve_goals": curve_goals,
		"accuracy": float(goals_scored) / attempts_taken,
		"total_xp": total_xp,
		"sho_xp": sho_xp,
		"tec_xp": tec_xp,
		"session_results": session_results
	}

	# Save best score for simulation feature
	_save_best_score()

	drill_completed.emit(results)


func _save_best_score() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var current_record = player.training_records.get("freekick_drill", {})
	var previous_best = current_record.get("best_score", 0)

	if goals_scored > previous_best:
		player.training_records["freekick_drill"] = {
			"best_score": goals_scored,
			"attempts": FREEKICKS_PER_SESSION,
			"best_accuracy": float(goals_scored) / FREEKICKS_PER_SESSION
		}


func _on_difficulty_changed(index: int) -> void:
	var keys = DIFFICULTY_SETTINGS.keys()
	if index < keys.size():
		current_difficulty = keys[index]
		_update_wall_display()
	AudioManager.play_ui_click()


func _on_shoot_pressed() -> void:
	if current_state == DrillState.SELECTING_CURVE:
		_start_charging()


func _on_continue_pressed() -> void:
	if current_state == DrillState.SHOWING_RESULT:
		# Reset for next attempt
		selected_zone = ""
		selected_curve = CurveDirection.STRAIGHT
		current_power = 0.0
		power_bar.value = 0

		# Generate new wall position
		_generate_new_wall_position()

		_update_modifiers_display()
		skill_check_details.text = "Take a free kick to see the skill check math..."
		narration_label.text = "[i]The wall sets itself. Pick your target...[/i]"

		_set_state(DrillState.SELECTING_ZONE)
		AudioManager.play_ui_click()


func _on_exit_pressed() -> void:
	AudioManager.play_ui_click()

	# Apply rewards if drill was completed
	if current_state == DrillState.DRILL_COMPLETE:
		_apply_rewards()

	# Return to console dashboard
	get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")


func _apply_rewards() -> void:
	var player = GameManager.player_data
	if not player:
		return

	# Calculate rewards
	var total_xp = XP_PER_ATTEMPT * attempts_taken
	total_xp += XP_PER_GOAL * goals_scored
	total_xp += XP_TOP_CORNER_BONUS * top_corner_goals
	total_xp += XP_CURVE_GOAL_BONUS * curve_goals

	if goals_scored >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if goals_scored >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var sho_xp = (STAT_XP_PER_GOAL * goals_scored) + (STAT_XP_PER_MISS * (attempts_taken - goals_scored))
	var tec_xp = TEC_XP_PER_ATTEMPT * attempts_taken

	# Apply to player
	player.stamina_current = maxi(player.stamina_current - STAMINA_COST, 0)
	player.add_xp(total_xp)
	player.add_stat_xp("SHO", sho_xp)
	player.add_stat_xp("TEC", tec_xp)

	# Advance time
	DesktopManager.advance_time(1)

	# Show notification
	DesktopManager.show_notification(
		"Free Kick Practice Complete",
		"Scored %d/%d! Earned %d XP" % [goals_scored, attempts_taken, total_xp],
		"",
		"training"
	)
