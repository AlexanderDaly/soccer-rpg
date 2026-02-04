extends TrainingDrillBase
## FreekickDrill - Free kick training mini-game
## Features 3x3 goal targeting, defensive wall, curve mechanics, power charging, and skill checks


# Static function for simulating rewards without playing
static func calculate_simulated_rewards(goals: int, attempts: int = 10) -> Dictionary:
	var total_xp = TrainingConstants.XP_PER_ATTEMPT * attempts
	total_xp += XP_PER_GOAL * goals

	# Estimate bonus XP based on score
	var top_corner_bonus = roundi(goals * 0.3) * XP_TOP_CORNER_BONUS
	var curve_bonus = roundi(goals * 0.5) * XP_CURVE_GOAL_BONUS
	total_xp += top_corner_bonus + curve_bonus

	if goals >= 7:
		total_xp += TrainingConstants.XP_GOOD_SESSION_BONUS
	if goals >= 10:
		total_xp += TrainingConstants.XP_PERFECT_SESSION_BONUS

	var sho_xp = (TrainingConstants.STAT_XP_PER_SUCCESS * goals) + (TrainingConstants.STAT_XP_PER_FAIL * (attempts - goals))
	var tec_xp = TEC_XP_PER_ATTEMPT * attempts

	return {
		"goals": goals,
		"attempts": attempts,
		"total_xp": total_xp,
		"sho_xp": sho_xp,
		"tec_xp": tec_xp,
		"stamina_cost": TrainingConstants.STAMINA_COST
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

enum WallPosition { LEFT, CENTER, RIGHT }
enum CurveDirection { LEFT_SWERVE, STRAIGHT, RIGHT_SWERVE }

# Difficulty settings
const DIFFICULTY_SETTINGS: Dictionary = {
	"youth": {"name": "20 yards", "distance": 20, "wall_size": 3, "base_mod": 5, "gk_stat": 35, "unlocked": true},
	"pro": {"name": "25 yards", "distance": 25, "wall_size": 4, "base_mod": 0, "gk_stat": 55, "unlocked": false},
	"elite": {"name": "30 yards", "distance": 30, "wall_size": 4, "base_mod": -10, "gk_stat": 75, "unlocked": false}
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

# Drill-specific XP rewards
const XP_PER_GOAL: int = 10
const XP_TOP_CORNER_BONUS: int = 5
const XP_CURVE_GOAL_BONUS: int = 3
const TEC_XP_PER_ATTEMPT: int = 2

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
var selected_zone: String = ""
var selected_curve: CurveDirection = CurveDirection.STRAIGHT
var current_wall_position: WallPosition = WallPosition.CENTER
var current_power: float = 0.0
var is_charging: bool = false

# Session tracking (additional to base class)
var top_corner_goals: int = 0
var curve_goals: int = 0

# Zone button references
var zone_buttons: Dictionary = {}
var curve_buttons: Array[Button] = []
var wall_blocks: Array[Panel] = []


# ===== OVERRIDES =====

func _get_drill_name() -> String:
	return "freekick"


func _get_primary_stat() -> String:
	return "SHO"


func _get_secondary_stat() -> String:
	return "TEC"


func _get_difficulty_settings() -> Dictionary:
	return DIFFICULTY_SETTINGS


func _get_xp_per_success() -> int:
	return XP_PER_GOAL


func _get_success_label() -> String:
	return "Goals"


func _is_drill_complete() -> bool:
	return current_state == DrillState.DRILL_COMPLETE


func _get_completion_title() -> String:
	return "Free Kick Practice Complete"


func _calculate_bonus_xp() -> int:
	return (XP_TOP_CORNER_BONUS * top_corner_goals) + (XP_CURVE_GOAL_BONUS * curve_goals)


func _get_bonus_xp_breakdown() -> String:
	var breakdown = ""
	if top_corner_goals > 0:
		breakdown += "Top Corners: +%d XP (%d × %d)\n" % [XP_TOP_CORNER_BONUS * top_corner_goals, top_corner_goals, XP_TOP_CORNER_BONUS]
	if curve_goals > 0:
		breakdown += "Curve Goals: +%d XP (%d × %d)\n" % [XP_CURVE_GOAL_BONUS * curve_goals, curve_goals, XP_CURVE_GOAL_BONUS]
	return breakdown


func _calculate_secondary_stat_xp(_xp_per_attempt: int = 2) -> int:
	return TEC_XP_PER_ATTEMPT * attempts_taken


# ===== SETUP =====

func _ready() -> void:
	_setup_difficulty_selector(difficulty_selector)
	_setup_zone_buttons()
	_setup_curve_buttons()
	_setup_wall_indicator()
	_setup_signals()
	_style_footer_buttons(continue_button, exit_button)
	_style_shoot_button(shoot_button)
	_update_player_stats_display()
	_generate_new_wall_position()
	_set_state(DrillState.SELECTING_ZONE)
	_show_session_start_narration(narration_label)


func _setup_zone_buttons() -> void:
	for i in range(TrainingConstants.ZONE_NAMES.size()):
		var btn = zone_grid.get_node(TrainingConstants.ZONE_BUTTON_NAMES[i])
		zone_buttons[TrainingConstants.ZONE_NAMES[i]] = btn
		btn.pressed.connect(_on_zone_selected.bind(TrainingConstants.ZONE_NAMES[i]))


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
	for i in range(4):
		var block = wall_indicator.get_node("WallBlock%d" % (i + 1))
		wall_blocks.append(block)


func _setup_signals() -> void:
	shoot_button.pressed.connect(_on_shoot_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	charge_timer.timeout.connect(_on_charge_tick)


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


# ===== WALL MECHANICS =====

func _generate_new_wall_position() -> void:
	current_wall_position = randi() % 3 as WallPosition
	_update_wall_display()
	_update_zone_blocking_display()


func _update_wall_display() -> void:
	var diff = DIFFICULTY_SETTINGS[current_difficulty]
	var wall_size = diff.wall_size

	for i in range(wall_blocks.size()):
		wall_blocks[i].visible = i < wall_size

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
		var base_color = TrainingConstants.COLOR_DEFAULT
		var border_color = TrainingConstants.BORDER_COLOR

		if zone in blocking.full:
			border_color = TrainingConstants.COLOR_BLOCKED
		elif zone in blocking.partial:
			border_color = TrainingConstants.COLOR_WARNING
		else:
			border_color = TrainingConstants.COLOR_OPEN

		_set_zone_button_style(zone, base_color, border_color)


func _get_wall_modifier(zone: String) -> int:
	var blocking = WALL_BLOCKING[current_wall_position]

	if zone in blocking.full:
		return -30
	elif zone in blocking.partial:
		return -15
	else:
		return 5


# ===== CURVE MECHANICS =====

func _get_curve_modifier(target_zone: String, curve: CurveDirection, tec: int) -> int:
	var tec_factor = tec / 100.0

	if curve == CurveDirection.STRAIGHT:
		return 0

	var target_side = "center"
	if target_zone in LEFT_ZONES:
		target_side = "left"
	elif target_zone in RIGHT_ZONES:
		target_side = "right"

	var correct_curve = false
	if target_side == "right" and curve == CurveDirection.LEFT_SWERVE:
		correct_curve = true
	elif target_side == "left" and curve == CurveDirection.RIGHT_SWERVE:
		correct_curve = true
	elif target_side == "center":
		correct_curve = false

	if correct_curve:
		return roundi(10.0 * tec_factor)
	else:
		return roundi(-15.0 * tec_factor)


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


func _reset_curve_selection() -> void:
	for i in range(curve_buttons.size()):
		var btn = curve_buttons[i]
		var style = _create_button_style(TrainingConstants.COLOR_DEFAULT, TrainingConstants.BORDER_COLOR)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", TrainingConstants.TEXT_PRIMARY)

	selected_curve = CurveDirection.STRAIGHT
	_highlight_curve_button(1)


func _highlight_curve_button(index: int) -> void:
	for i in range(curve_buttons.size()):
		var btn = curve_buttons[i]
		var style: StyleBoxFlat
		if i == index:
			style = _create_button_style(TrainingConstants.COLOR_SELECTED, TrainingConstants.ACCENT_GREEN)
		else:
			style = _create_button_style(TrainingConstants.COLOR_DEFAULT, TrainingConstants.BORDER_COLOR)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_color_override("font_color", TrainingConstants.TEXT_PRIMARY)


# ===== STATE MANAGEMENT =====

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


# ===== INPUT HANDLING =====

func _input(event: InputEvent) -> void:
	if current_state == DrillState.SELECTING_CURVE or current_state == DrillState.CHARGING_POWER:
		if event.is_action_pressed("ui_select"):
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

	current_power = minf(current_power + TrainingConstants.CHARGE_RATE * charge_timer.wait_time, 100.0)
	power_bar.value = current_power
	_update_power_bar_color(power_bar, current_power)
	_update_modifiers_display()


func _release_shot() -> void:
	is_charging = false
	charge_timer.stop()
	_set_state(DrillState.RESOLVING)
	_resolve_freekick()


# ===== EVENT HANDLERS =====

func _on_zone_selected(zone: String) -> void:
	if current_state != DrillState.SELECTING_ZONE:
		return

	_update_zone_blocking_display()
	selected_zone = zone
	_set_zone_button_style(zone, TrainingConstants.COLOR_SELECTED, TrainingConstants.ACCENT_GREEN)
	_update_modifiers_display()
	AudioManager.play_ui_click()
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


func _on_shoot_pressed() -> void:
	if current_state == DrillState.SELECTING_CURVE:
		_start_charging()


func _on_continue_pressed() -> void:
	if current_state == DrillState.SHOWING_RESULT:
		selected_zone = ""
		selected_curve = CurveDirection.STRAIGHT
		current_power = 0.0
		power_bar.value = 0
		_generate_new_wall_position()
		_update_modifiers_display()
		skill_check_details.text = "Take a free kick to see the skill check math..."
		narration_label.text = "[i]The wall sets itself. Pick your target...[/i]"
		_set_state(DrillState.SELECTING_ZONE)
		AudioManager.play_ui_click()


func _on_exit_pressed() -> void:
	_handle_exit()


# ===== UI HELPERS =====

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
		btn.add_theme_color_override("font_color", TrainingConstants.TEXT_PRIMARY)


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

	var zone_mod = TrainingConstants.ZONE_MODIFIERS.get(selected_zone, 0)
	var wall_mod = _get_wall_modifier(selected_zone)
	var curve_mod = _get_curve_modifier(selected_zone, selected_curve, tec)
	var power_mod = TrainingConstants.get_power_modifier(current_power)
	var power_name = TrainingConstants.get_power_name(current_power)
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


func _update_score() -> void:
	_update_score_display(score_label, attempt_counter, "Attempt")


# ===== RESOLUTION =====

func _resolve_freekick() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var sho = player.get_effective_stat("SHO")
	var tec = player.get_effective_stat("TEC")
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	var base_chance = _calculate_base_chance(sho, tec)
	var zone_mod = TrainingConstants.ZONE_MODIFIERS.get(selected_zone, 0)
	var wall_mod = _get_wall_modifier(selected_zone)
	var curve_mod = _get_curve_modifier(selected_zone, selected_curve, tec)
	var power_mod = TrainingConstants.get_power_modifier(current_power)
	var distance_mod = diff.base_mod

	var success_chance = base_chance + zone_mod + wall_mod + curve_mod + power_mod + distance_mod

	var roll = randf() * 100.0
	var shot_on_target = roll <= success_chance

	var used_correct_curve = _is_correct_curve(selected_zone, selected_curve)
	var is_top_corner = selected_zone in TOP_CORNER_ZONES

	var result: Dictionary = {
		"zone": selected_zone,
		"power": current_power,
		"power_name": TrainingConstants.get_power_name(current_power),
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
		var gk_result = _resolve_gk_save(selected_zone, diff)
		result.gk_save_chance = gk_result.save_chance
		result.gk_roll = gk_result.roll
		result.scored = not gk_result.saved

	attempts_taken += 1
	if result.scored:
		successes += 1
		if is_top_corner:
			top_corner_goals += 1
		if used_correct_curve:
			curve_goals += 1
	session_results.append(result)

	_display_result(result)
	_update_score()

	if attempts_taken >= TrainingConstants.ATTEMPTS_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


func _resolve_gk_save(target_zone: String, diff: Dictionary) -> Dictionary:
	var base_save_chance = diff.gk_stat * 0.4

	if target_zone in TOP_CORNER_ZONES:
		base_save_chance -= 15.0
	elif target_zone in ["MID_LEFT", "MID_CENTER", "MID_RIGHT"]:
		base_save_chance += 10.0
	elif _get_wall_modifier(target_zone) < 0:
		base_save_chance -= 5.0

	base_save_chance = clampf(base_save_chance, 5.0, 85.0)

	var roll = randf() * 100.0
	var saved = roll <= base_save_chance

	return {
		"save_chance": base_save_chance,
		"roll": roll,
		"saved": saved
	}


func _display_result(result: Dictionary) -> void:
	if result.scored:
		_set_zone_button_style(selected_zone, TrainingConstants.COLOR_SUCCESS, Color(0, 0.6, 0.3))
	else:
		_set_zone_button_style(selected_zone, TrainingConstants.COLOR_FAIL, Color(0.6, 0.2, 0.2))

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


func _complete_drill() -> void:
	_set_state(DrillState.DRILL_COMPLETE)
	skill_check_details.text = _build_xp_summary()
	_show_session_end_narration(narration_label)
	_save_best_score()
	drill_completed.emit({
		"attempts_taken": attempts_taken,
		"goals_scored": successes,
		"top_corner_goals": top_corner_goals,
		"curve_goals": curve_goals,
		"accuracy": float(successes) / attempts_taken,
		"total_xp": _calculate_total_xp(),
		"sho_xp": _calculate_primary_stat_xp(),
		"tec_xp": _calculate_secondary_stat_xp(),
		"session_results": session_results
	})
