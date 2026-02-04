extends TrainingDrillBase
## PenaltyDrill - Penalty kick training mini-game
## Features 3x3 goal targeting, power charging, skill checks, and adaptive GK


# Static function for simulating rewards without playing
static func calculate_simulated_rewards(goals: int, attempts: int = 10) -> Dictionary:
	var total_xp = TrainingConstants.XP_PER_ATTEMPT * attempts
	total_xp += XP_PER_GOAL * goals

	if goals >= 7:
		total_xp += TrainingConstants.XP_GOOD_SESSION_BONUS
	if goals >= 10:
		total_xp += TrainingConstants.XP_PERFECT_SESSION_BONUS

	var sho_xp = (TrainingConstants.STAT_XP_PER_SUCCESS * goals) + (TrainingConstants.STAT_XP_PER_FAIL * (attempts - goals))
	var men_xp = MEN_XP_PER_ATTEMPT * attempts

	return {
		"goals": goals,
		"attempts": attempts,
		"total_xp": total_xp,
		"sho_xp": sho_xp,
		"men_xp": men_xp,
		"stamina_cost": TrainingConstants.STAMINA_COST
	}


enum DrillState {
	SETUP,
	SELECTING_ZONE,
	CHARGING_POWER,
	RESOLVING,
	SHOWING_RESULT,
	DRILL_COMPLETE
}

# Difficulty settings
const DIFFICULTY_SETTINGS: Dictionary = {
	"youth": {"name": "Youth GK", "gk_stat": 35, "learning_rate": 0.2, "unlocked": true},
	"pro": {"name": "Pro GK", "gk_stat": 55, "learning_rate": 0.35, "unlocked": false},
	"elite": {"name": "Elite GK", "gk_stat": 75, "learning_rate": 0.5, "unlocked": false}
}

# Zone adjacency for GK saves
const ZONE_ADJACENCY: Dictionary = {
	"TOP_LEFT": ["TOP_CENTER", "MID_LEFT"],
	"TOP_CENTER": ["TOP_LEFT", "TOP_RIGHT", "MID_CENTER"],
	"TOP_RIGHT": ["TOP_CENTER", "MID_RIGHT"],
	"MID_LEFT": ["TOP_LEFT", "LOW_LEFT", "MID_CENTER"],
	"MID_CENTER": ["TOP_CENTER", "LOW_CENTER", "MID_LEFT", "MID_RIGHT"],
	"MID_RIGHT": ["TOP_RIGHT", "LOW_RIGHT", "MID_CENTER"],
	"LOW_LEFT": ["MID_LEFT", "LOW_CENTER"],
	"LOW_CENTER": ["LOW_LEFT", "LOW_RIGHT", "MID_CENTER"],
	"LOW_RIGHT": ["MID_RIGHT", "LOW_CENTER"]
}

# Drill-specific XP rewards
const XP_PER_GOAL: int = 10
const MEN_XP_PER_ATTEMPT: int = 2

# Node references
@onready var difficulty_selector: OptionButton = $VBoxContainer/HeaderSection/DifficultyContainer/DifficultySelector
@onready var score_label: Label = $VBoxContainer/HeaderSection/ScoreLabel
@onready var zone_grid: GridContainer = $VBoxContainer/MainContent/GoalSection/GoalFrame/ZoneGrid
@onready var power_bar: ProgressBar = $VBoxContainer/MainContent/GoalSection/PowerSection/PowerBar
@onready var power_label: Label = $VBoxContainer/MainContent/GoalSection/PowerSection/PowerLabel
@onready var shoot_button: Button = $VBoxContainer/MainContent/GoalSection/ShootButton
@onready var sho_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/SHORow/SHOValue
@onready var men_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/MENRow/MENValue
@onready var base_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/BaseRow/BaseValue
@onready var zone_mod_label: Label = $VBoxContainer/MainContent/InfoSection/ZoneModifiersPanel/ModifiersVBox/ZoneModLabel
@onready var power_mod_label: Label = $VBoxContainer/MainContent/InfoSection/ZoneModifiersPanel/ModifiersVBox/PowerModLabel
@onready var gk_mod_label: Label = $VBoxContainer/MainContent/InfoSection/ZoneModifiersPanel/ModifiersVBox/GKModLabel
@onready var final_chance_label: Label = $VBoxContainer/MainContent/InfoSection/ZoneModifiersPanel/ModifiersVBox/FinalChanceLabel
@onready var skill_check_details: RichTextLabel = $VBoxContainer/MainContent/InfoSection/SkillCheckPanel/SkillCheckVBox/SkillCheckDetails
@onready var narration_label: RichTextLabel = $VBoxContainer/NarrationSection/NarrationLabel
@onready var penalty_counter: Label = $VBoxContainer/FooterSection/PenaltyCounter
@onready var continue_button: Button = $VBoxContainer/FooterSection/ContinueButton
@onready var exit_button: Button = $VBoxContainer/FooterSection/ExitButton
@onready var charge_timer: Timer = $ChargeTimer

# State
var current_state: DrillState = DrillState.SETUP
var selected_zone: String = ""
var current_power: float = 0.0
var is_charging: bool = false

# GK pattern learning
var player_zone_history: Array[String] = []
var gk_zone_weights: Dictionary = {}

# Zone button references
var zone_buttons: Dictionary = {}


# ===== OVERRIDES =====

func _get_drill_name() -> String:
	return "penalty"


func _get_primary_stat() -> String:
	return "SHO"


func _get_secondary_stat() -> String:
	return "MEN"


func _get_difficulty_settings() -> Dictionary:
	return DIFFICULTY_SETTINGS


func _get_xp_per_success() -> int:
	return XP_PER_GOAL


func _get_success_label() -> String:
	return "Goals"


func _is_drill_complete() -> bool:
	return current_state == DrillState.DRILL_COMPLETE


func _get_completion_title() -> String:
	return "Penalty Practice Complete"


func _calculate_secondary_stat_xp(_xp_per_attempt: int = 2) -> int:
	return MEN_XP_PER_ATTEMPT * attempts_taken


# ===== SETUP =====

func _ready() -> void:
	_setup_difficulty_selector(difficulty_selector)
	_setup_zone_buttons()
	_setup_signals()
	_style_footer_buttons(continue_button, exit_button)
	_style_shoot_button(shoot_button)
	_init_gk_weights()
	_update_player_stats_display()
	_set_state(DrillState.SELECTING_ZONE)
	_show_session_start_narration(narration_label)


func _setup_zone_buttons() -> void:
	for i in range(TrainingConstants.ZONE_NAMES.size()):
		var btn = zone_grid.get_node(TrainingConstants.ZONE_BUTTON_NAMES[i])
		zone_buttons[TrainingConstants.ZONE_NAMES[i]] = btn
		btn.pressed.connect(_on_zone_selected.bind(TrainingConstants.ZONE_NAMES[i]))


func _setup_signals() -> void:
	shoot_button.pressed.connect(_on_shoot_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	charge_timer.timeout.connect(_on_charge_tick)


func _init_gk_weights() -> void:
	for zone in TrainingConstants.ZONE_MODIFIERS:
		gk_zone_weights[zone] = 1.0


func _update_player_stats_display() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var sho = player.get_effective_stat("SHO")
	var men = player.get_effective_stat("MEN")
	var base = _calculate_base_chance(sho, men)

	sho_value.text = str(sho)
	men_value.text = str(men)
	base_value.text = "%.1f%%" % base


func _calculate_base_chance(sho: int, men: int) -> float:
	return (sho * 0.7) + (men * 0.3)


# ===== STATE MANAGEMENT =====

func _set_state(new_state: DrillState) -> void:
	current_state = new_state

	match new_state:
		DrillState.SELECTING_ZONE:
			_enable_zone_selection(true)
			shoot_button.disabled = selected_zone.is_empty()
			shoot_button.text = "Select a zone first" if selected_zone.is_empty() else "Hold SPACE to Charge Power"
			continue_button.visible = false
			power_bar.value = 0
			current_power = 0.0

		DrillState.CHARGING_POWER:
			_enable_zone_selection(false)
			shoot_button.text = "Charging... Release to Shoot!"

		DrillState.RESOLVING:
			shoot_button.disabled = true
			shoot_button.text = "Resolving..."

		DrillState.SHOWING_RESULT:
			continue_button.visible = true
			shoot_button.disabled = true

		DrillState.DRILL_COMPLETE:
			_enable_zone_selection(false)
			shoot_button.visible = false
			continue_button.visible = false
			exit_button.text = "Finish & Collect XP"


func _enable_zone_selection(enabled: bool) -> void:
	for zone in zone_buttons:
		zone_buttons[zone].disabled = not enabled


# ===== INPUT HANDLING =====

func _input(event: InputEvent) -> void:
	if current_state == DrillState.SELECTING_ZONE or current_state == DrillState.CHARGING_POWER:
		if event.is_action_pressed("ui_select"):
			if selected_zone.is_empty():
				return
			_start_charging()
		elif event.is_action_released("ui_select"):
			if is_charging:
				_release_shot()


func _start_charging() -> void:
	if current_state != DrillState.SELECTING_ZONE:
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
	_resolve_penalty()


# ===== EVENT HANDLERS =====

func _on_zone_selected(zone: String) -> void:
	if current_state != DrillState.SELECTING_ZONE:
		return

	# Clear previous selection
	for z in zone_buttons:
		_set_zone_button_color(z, TrainingConstants.COLOR_DEFAULT, TrainingConstants.BORDER_COLOR)

	# Highlight new selection
	selected_zone = zone
	_set_zone_button_color(zone, TrainingConstants.COLOR_SELECTED, TrainingConstants.ACCENT_GREEN)

	shoot_button.disabled = false
	shoot_button.text = "Hold SPACE to Charge Power"

	_update_modifiers_display()
	AudioManager.play_ui_click()


func _set_zone_button_color(zone: String, bg_color: Color, border_color: Color = TrainingConstants.BORDER_COLOR) -> void:
	var btn = zone_buttons.get(zone)
	if btn:
		_set_button_style(btn, bg_color, border_color)


func _on_shoot_pressed() -> void:
	if current_state == DrillState.SELECTING_ZONE and not selected_zone.is_empty():
		_start_charging()


func _on_continue_pressed() -> void:
	if current_state == DrillState.SHOWING_RESULT:
		selected_zone = ""
		current_power = 0.0
		power_bar.value = 0

		for zone in zone_buttons:
			_set_zone_button_color(zone, TrainingConstants.COLOR_DEFAULT, TrainingConstants.BORDER_COLOR)

		_update_modifiers_display()
		skill_check_details.text = "Take a shot to see the skill check math..."
		narration_label.text = "[i]Step up to the spot again. The goalkeeper sets himself...[/i]"

		_set_state(DrillState.SELECTING_ZONE)
		AudioManager.play_ui_click()


func _on_exit_pressed() -> void:
	_handle_exit()


# ===== UI HELPERS =====

func _update_modifiers_display() -> void:
	if selected_zone.is_empty():
		zone_mod_label.text = "Zone: --"
		power_mod_label.text = "Power: --"
		gk_mod_label.text = "GK Prediction: --"
		final_chance_label.text = "Final: --%"
		return

	var zone_mod = TrainingConstants.ZONE_MODIFIERS.get(selected_zone, 0)
	var power_mod = TrainingConstants.get_power_modifier(current_power)
	var power_name = TrainingConstants.get_power_name(current_power)

	zone_mod_label.text = "Zone: %+d%%" % zone_mod
	power_mod_label.text = "Power: %s (%+d%%)" % [power_name, power_mod]
	gk_mod_label.text = "GK Prediction: ?"

	var player = GameManager.player_data
	if player:
		var base = _calculate_base_chance(player.get_effective_stat("SHO"), player.get_effective_stat("MEN"))
		var final = base + zone_mod + power_mod
		final_chance_label.text = "Final: %.1f%%" % final


func _update_score() -> void:
	_update_score_display(score_label, penalty_counter, "Penalty")


# ===== RESOLUTION =====

func _resolve_penalty() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var sho = player.get_effective_stat("SHO")
	var men = player.get_effective_stat("MEN")
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	var base_chance = _calculate_base_chance(sho, men)
	var zone_mod = TrainingConstants.ZONE_MODIFIERS.get(selected_zone, 0)
	var power_mod = TrainingConstants.get_power_modifier(current_power)
	var success_chance = base_chance + zone_mod + power_mod

	var roll = randf() * 100.0
	var shot_on_target = roll <= success_chance

	var result: Dictionary = {
		"zone": selected_zone,
		"power": current_power,
		"power_name": TrainingConstants.get_power_name(current_power),
		"base_chance": base_chance,
		"zone_mod": zone_mod,
		"power_mod": power_mod,
		"success_chance": success_chance,
		"roll": roll,
		"shot_on_target": shot_on_target,
		"scored": false,
		"gk_dived": "",
		"gk_save_chance": 0.0,
		"gk_roll": 0.0
	}

	if shot_on_target:
		var gk_result = _resolve_gk_save(selected_zone, diff)
		result.gk_dived = gk_result.dive_zone
		result.gk_save_chance = gk_result.save_chance
		result.gk_roll = gk_result.roll
		result.scored = not gk_result.saved

	# Update GK learning
	player_zone_history.append(selected_zone)
	_update_gk_weights(diff.learning_rate)

	attempts_taken += 1
	if result.scored:
		successes += 1
	session_results.append(result)

	_display_result(result)
	_update_score()

	if attempts_taken >= TrainingConstants.ATTEMPTS_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


func _resolve_gk_save(target_zone: String, diff: Dictionary) -> Dictionary:
	var dive_zone = _select_gk_dive_zone()
	var base_save_chance = diff.gk_stat * 0.5

	if dive_zone == target_zone:
		base_save_chance += 40.0
	elif dive_zone in ZONE_ADJACENCY.get(target_zone, []):
		base_save_chance += 15.0
	else:
		base_save_chance -= 20.0

	base_save_chance = clampf(base_save_chance, 5.0, 95.0)

	var roll = randf() * 100.0
	var saved = roll <= base_save_chance

	return {
		"dive_zone": dive_zone,
		"save_chance": base_save_chance,
		"roll": roll,
		"saved": saved
	}


func _select_gk_dive_zone() -> String:
	var total_weight = 0.0
	for zone in gk_zone_weights:
		total_weight += gk_zone_weights[zone]

	var roll = randf() * total_weight
	var cumulative = 0.0

	for zone in gk_zone_weights:
		cumulative += gk_zone_weights[zone]
		if roll <= cumulative:
			return zone

	return "MID_CENTER"


func _update_gk_weights(learning_rate: float) -> void:
	if player_zone_history.is_empty():
		return

	var zone_counts: Dictionary = {}
	for zone in TrainingConstants.ZONE_MODIFIERS:
		zone_counts[zone] = 0

	for zone in player_zone_history:
		zone_counts[zone] += 1

	var total = player_zone_history.size()

	for zone in gk_zone_weights:
		var frequency = float(zone_counts[zone]) / total
		var target_weight = 1.0 + (frequency * 3.0)
		gk_zone_weights[zone] = lerpf(gk_zone_weights[zone], target_weight, learning_rate)


func _display_result(result: Dictionary) -> void:
	if result.scored:
		_set_zone_button_color(selected_zone, TrainingConstants.COLOR_SUCCESS, Color(0, 0.6, 0.3))
	else:
		_set_zone_button_color(selected_zone, TrainingConstants.COLOR_FAIL, Color(0.6, 0.2, 0.2))

	var breakdown = ""
	breakdown += "[b]Shot Calculation:[/b]\n"
	breakdown += "Base: (SHO × 0.7) + (MEN × 0.3) = %.1f%%\n" % result.base_chance
	breakdown += "Zone (%s): %+d%%\n" % [selected_zone, result.zone_mod]
	breakdown += "Power (%s): %+d%%\n" % [result.power_name, result.power_mod]
	breakdown += "[b]Final: %.1f%%[/b]\n\n" % result.success_chance
	breakdown += "Roll: %.1f vs %.1f\n" % [result.roll, result.success_chance]

	if result.shot_on_target:
		breakdown += "[color=green]Shot on target![/color]\n\n"
		breakdown += "[b]GK Save Attempt:[/b]\n"
		breakdown += "GK dived: %s\n" % result.gk_dived
		var prediction = "Correct!" if result.gk_dived == selected_zone else ("Adjacent" if result.gk_dived in ZONE_ADJACENCY.get(selected_zone, []) else "Wrong side")
		breakdown += "Prediction: %s\n" % prediction
		breakdown += "Save chance: %.1f%%\n" % result.gk_save_chance
		breakdown += "Roll: %.1f vs %.1f\n" % [result.gk_roll, result.gk_save_chance]

		if result.scored:
			breakdown += "\n[color=green][b]GOAL![/b][/color]"
		else:
			breakdown += "\n[color=red][b]SAVED![/b][/color]"
	else:
		breakdown += "[color=red]Shot off target! MISSED![/color]"

	skill_check_details.text = breakdown
	_show_result_narration(result)


func _show_result_narration(result: Dictionary) -> void:
	var narrative: Dictionary
	var context = {
		"zone": selected_zone.replace("_", " ").to_lower(),
		"power": result.power_name.to_lower()
	}

	if result.scored:
		narrative = NarrativeEngine.generate_dialogue("penalty", "goal", context)
	elif result.shot_on_target:
		narrative = NarrativeEngine.generate_dialogue("penalty", "saved", context)
	else:
		narrative = NarrativeEngine.generate_dialogue("penalty", "missed", context)

	narration_label.text = "[i]%s[/i]" % narrative.text


func _complete_drill() -> void:
	_set_state(DrillState.DRILL_COMPLETE)
	skill_check_details.text = _build_xp_summary()
	_show_session_end_narration(narration_label)
	_save_best_score()
	drill_completed.emit({
		"penalties_taken": attempts_taken,
		"goals_scored": successes,
		"accuracy": float(successes) / attempts_taken,
		"total_xp": _calculate_total_xp(),
		"sho_xp": _calculate_primary_stat_xp(),
		"men_xp": _calculate_secondary_stat_xp(),
		"session_results": session_results
	})
