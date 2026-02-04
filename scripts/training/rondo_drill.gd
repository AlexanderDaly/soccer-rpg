extends TrainingDrillBase
## RondoDrill - Rondo (keep-ball) passing training mini-game
## Features pentagon teammate layout, defender AI, timing mechanics, and skill checks


# Static function for simulating rewards without playing
static func calculate_simulated_rewards(successes_count: int, attempts: int = 10) -> Dictionary:
	var total_xp = TrainingConstants.XP_PER_ATTEMPT * attempts
	total_xp += XP_PER_SUCCESS * successes_count

	# Quick pass bonuses (assume 30% were quick in simulation)
	var quick_passes = roundi(successes_count * 0.3)
	total_xp += XP_QUICK_PASS_BONUS * quick_passes

	if successes_count >= 7:
		total_xp += TrainingConstants.XP_GOOD_SESSION_BONUS
	if successes_count >= 10:
		total_xp += TrainingConstants.XP_PERFECT_SESSION_BONUS

	var pas_xp = (TrainingConstants.STAT_XP_PER_SUCCESS * successes_count) + (TrainingConstants.STAT_XP_PER_FAIL * (attempts - successes_count))
	var tec_xp = TEC_XP_PER_ATTEMPT * attempts

	return {
		"successes": successes_count,
		"attempts": attempts,
		"total_xp": total_xp,
		"pas_xp": pas_xp,
		"tec_xp": tec_xp,
		"stamina_cost": TrainingConstants.STAMINA_COST
	}


enum DrillState {
	SETUP,
	DEFENDING,
	PASSING,
	RESOLVING,
	SHOWING_RESULT,
	DRILL_COMPLETE
}

# Difficulty settings
const DIFFICULTY_SETTINGS: Dictionary = {
	"youth": {"name": "Youth", "timer": 3.0, "learning_rate": 0.0, "pressure_radius": 0, "unlocked": true},
	"pro": {"name": "Pro", "timer": 2.5, "learning_rate": 0.3, "pressure_radius": 1, "unlocked": false},
	"elite": {"name": "Elite", "timer": 2.0, "learning_rate": 0.5, "pressure_radius": 2, "unlocked": false}
}

# Teammate adjacency for pentagon layout
const TEAMMATE_ADJACENCY: Dictionary = {
	0: [1, 4],
	1: [0, 2],
	2: [1, 3],
	3: [2, 4],
	4: [3, 0]
}

# Pass distances - diagonal passes are "far"
const FAR_PASSES: Array = [
	[0, 2], [0, 3],
	[1, 3], [1, 4],
	[2, 4]
]

# Distance modifiers
const DISTANCE_MODIFIERS: Dictionary = {
	"adjacent": 5,
	"across": 0,
	"far": -10
}

# Pressure modifiers
const PRESSURE_MODIFIERS: Dictionary = {
	"open": 10,
	"contested": -5,
	"covered": -25
}

# Timing modifiers
const TIMING_MODIFIERS: Dictionary = {
	"quick": 10,
	"normal": 0,
	"late": -10
}

# Drill-specific XP rewards
const XP_PER_SUCCESS: int = 8
const XP_QUICK_PASS_BONUS: int = 3
const TEC_XP_PER_ATTEMPT: int = 2
const DEFENDER_MOVE_DELAY: float = 0.8

# Node references
@onready var difficulty_selector: OptionButton = $VBoxContainer/HeaderSection/DifficultyContainer/DifficultySelector
@onready var score_label: Label = $VBoxContainer/HeaderSection/ScoreLabel
@onready var rondo_field: Control = $VBoxContainer/MainContent/FieldSection/RondoField
@onready var timer_bar: ProgressBar = $VBoxContainer/MainContent/FieldSection/TimerSection/TimerBar
@onready var timer_label: Label = $VBoxContainer/MainContent/FieldSection/TimerSection/TimerLabel
@onready var defender_indicator: Label = $VBoxContainer/MainContent/FieldSection/RondoField/DefenderIndicator
@onready var pas_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/PASRow/PASValue
@onready var tec_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/TECRow/TECValue
@onready var base_value: Label = $VBoxContainer/MainContent/InfoSection/PlayerStatsPanel/StatsVBox/BaseRow/BaseValue
@onready var target_label: Label = $VBoxContainer/MainContent/InfoSection/CurrentRoundPanel/RoundVBox/TargetLabel
@onready var pressure_label: Label = $VBoxContainer/MainContent/InfoSection/CurrentRoundPanel/RoundVBox/PressureLabel
@onready var distance_mod_label: Label = $VBoxContainer/MainContent/InfoSection/CurrentRoundPanel/RoundVBox/DistanceModLabel
@onready var pressure_mod_label: Label = $VBoxContainer/MainContent/InfoSection/CurrentRoundPanel/RoundVBox/PressureModLabel
@onready var timing_mod_label: Label = $VBoxContainer/MainContent/InfoSection/CurrentRoundPanel/RoundVBox/TimingModLabel
@onready var final_chance_label: Label = $VBoxContainer/MainContent/InfoSection/CurrentRoundPanel/RoundVBox/FinalChanceLabel
@onready var skill_check_details: RichTextLabel = $VBoxContainer/MainContent/InfoSection/SkillCheckPanel/SkillCheckVBox/SkillCheckDetails
@onready var narration_label: RichTextLabel = $VBoxContainer/NarrationSection/NarrationLabel
@onready var round_counter: Label = $VBoxContainer/FooterSection/RoundCounter
@onready var continue_button: Button = $VBoxContainer/FooterSection/ContinueButton
@onready var exit_button: Button = $VBoxContainer/FooterSection/ExitButton
@onready var round_timer: Timer = $RoundTimer

# State
var current_state: DrillState = DrillState.SETUP
var defender_target: int = -1
var time_remaining: float = 0.0
var max_time: float = 3.0

# Session tracking (additional to base class)
var quick_passes: int = 0

# Defender pattern learning
var player_pass_history: Array[int] = []
var defender_weights: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]

# Teammate button references
var teammate_buttons: Array[Button] = []


# ===== OVERRIDES =====

func _get_drill_name() -> String:
	return "rondo"


func _get_primary_stat() -> String:
	return "PAS"


func _get_secondary_stat() -> String:
	return "TEC"


func _get_difficulty_settings() -> Dictionary:
	return DIFFICULTY_SETTINGS


func _get_xp_per_success() -> int:
	return XP_PER_SUCCESS


func _get_success_label() -> String:
	return "Successful Passes"


func _is_drill_complete() -> bool:
	return current_state == DrillState.DRILL_COMPLETE


func _get_completion_title() -> String:
	return "Rondo Training Complete"


func _get_completion_message(total_xp: int) -> String:
	return "Passed %d/%d! Earned %d XP" % [successes, attempts_taken, total_xp]


func _calculate_bonus_xp() -> int:
	return XP_QUICK_PASS_BONUS * quick_passes


func _get_bonus_xp_breakdown() -> String:
	if quick_passes > 0:
		return "Quick Bonus: +%d XP (%d × %d)\n" % [XP_QUICK_PASS_BONUS * quick_passes, quick_passes, XP_QUICK_PASS_BONUS]
	return ""


func _calculate_secondary_stat_xp(_xp_per_attempt: int = 2) -> int:
	return TEC_XP_PER_ATTEMPT * attempts_taken


# ===== SETUP =====

func _ready() -> void:
	_setup_difficulty_selector(difficulty_selector)
	_setup_teammate_buttons()
	_setup_signals()
	_style_footer_buttons(continue_button, exit_button)
	_update_player_stats_display()
	_show_session_start_narration(narration_label)
	_set_state(DrillState.DEFENDING)
	_start_new_round()


func _setup_teammate_buttons() -> void:
	teammate_buttons.clear()
	for i in range(5):
		var btn = rondo_field.get_node("Teammate%d" % i) as Button
		if btn:
			teammate_buttons.append(btn)
			btn.pressed.connect(_on_teammate_pressed.bind(i))
			_set_button_style(btn, TrainingConstants.COLOR_DEFAULT)


func _setup_signals() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	round_timer.timeout.connect(_on_timer_tick)


func _update_player_stats_display() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var pas = player.get_effective_stat("PAS")
	var tec = player.get_effective_stat("TEC")
	var base = _calculate_base_chance(pas, tec)

	pas_value.text = str(pas)
	tec_value.text = str(tec)
	base_value.text = "%.1f%%" % base


func _calculate_base_chance(pas: int, tec: int) -> float:
	return (pas * 0.7) + (tec * 0.3)


# ===== STATE MANAGEMENT =====

func _set_state(new_state: DrillState) -> void:
	current_state = new_state

	match new_state:
		DrillState.DEFENDING:
			_enable_teammate_buttons(false)
			continue_button.visible = false

		DrillState.PASSING:
			_enable_teammate_buttons(true)
			continue_button.visible = false

		DrillState.RESOLVING:
			_enable_teammate_buttons(false)
			round_timer.stop()

		DrillState.SHOWING_RESULT:
			_enable_teammate_buttons(false)
			continue_button.visible = true

		DrillState.DRILL_COMPLETE:
			_enable_teammate_buttons(false)
			round_timer.stop()
			continue_button.visible = false
			exit_button.text = "Finish & Collect XP"


func _enable_teammate_buttons(enabled: bool) -> void:
	for btn in teammate_buttons:
		btn.disabled = not enabled


# ===== ROUND MANAGEMENT =====

func _start_new_round() -> void:
	for i in range(teammate_buttons.size()):
		_set_button_style(teammate_buttons[i], TrainingConstants.COLOR_DEFAULT)

	_select_defender_target()

	defender_indicator.text = "[DEF]"
	target_label.text = "Defender moving..."
	pressure_label.text = "..."
	_clear_modifiers_display()

	_set_state(DrillState.DEFENDING)

	await get_tree().create_timer(DEFENDER_MOVE_DELAY).timeout

	if current_state != DrillState.DEFENDING:
		return

	_position_defender()
	_update_teammate_colors()
	_start_passing_phase()


func _select_defender_target() -> void:
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	if diff.learning_rate <= 0.0 or player_pass_history.is_empty():
		defender_target = randi() % 5
	else:
		var total_weight = 0.0
		for w in defender_weights:
			total_weight += w

		var roll = randf() * total_weight
		var cumulative = 0.0

		for i in range(defender_weights.size()):
			cumulative += defender_weights[i]
			if roll <= cumulative:
				defender_target = i
				break


func _position_defender() -> void:
	var target_btn = teammate_buttons[defender_target]
	var btn_pos = target_btn.position
	var btn_size = target_btn.size

	var center = Vector2(160, 140)
	var direction_to_center = (center - (btn_pos + btn_size / 2)).normalized()
	var defender_pos = btn_pos + btn_size / 2 + direction_to_center * 30 - Vector2(30, 15)

	defender_indicator.position = defender_pos
	defender_indicator.text = "[DEF]"


func _update_teammate_colors() -> void:
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	for i in range(teammate_buttons.size()):
		var pressure = _get_pressure_level(i, diff)
		var btn = teammate_buttons[i]

		match pressure:
			"covered":
				_set_button_style(btn, TrainingConstants.COLOR_BLOCKED)
			"contested":
				_set_button_style(btn, TrainingConstants.COLOR_CONTESTED)
			_:
				_set_button_style(btn, TrainingConstants.COLOR_DEFAULT)

	target_label.text = "Defender on: T%d" % (defender_target + 1)
	var contested_list = _get_contested_teammates(diff)
	if contested_list.is_empty():
		pressure_label.text = "Only T%d covered" % (defender_target + 1)
	else:
		var contested_str = ", ".join(contested_list.map(func(x): return "T%d" % (x + 1)))
		pressure_label.text = "Contested: %s" % contested_str


func _get_contested_teammates(diff: Dictionary) -> Array:
	var contested: Array = []
	var radius = diff.pressure_radius

	if radius <= 0:
		return contested

	var adjacent = TEAMMATE_ADJACENCY.get(defender_target, [])
	for adj in adjacent:
		contested.append(adj)

		if radius >= 2:
			var second_level = TEAMMATE_ADJACENCY.get(adj, [])
			for sl in second_level:
				if sl != defender_target and sl not in contested:
					contested.append(sl)

	return contested


func _get_pressure_level(teammate_idx: int, diff: Dictionary) -> String:
	if teammate_idx == defender_target:
		return "covered"

	var contested = _get_contested_teammates(diff)
	if teammate_idx in contested:
		return "contested"

	return "open"


func _start_passing_phase() -> void:
	var diff = DIFFICULTY_SETTINGS[current_difficulty]
	max_time = diff.timer
	time_remaining = max_time

	timer_label.text = "Time: %.1fs" % time_remaining
	timer_bar.value = 100.0
	_update_timer_bar_color(timer_bar, time_remaining, max_time)

	_set_state(DrillState.PASSING)
	round_timer.start()


# ===== TIMER =====

func _on_timer_tick() -> void:
	if current_state != DrillState.PASSING:
		return

	time_remaining -= round_timer.wait_time

	if time_remaining <= 0:
		time_remaining = 0
		_handle_timeout()
		return

	timer_label.text = "Time: %.1fs" % time_remaining
	var pct = (time_remaining / max_time) * 100.0
	timer_bar.value = pct
	_update_timer_bar_color(timer_bar, time_remaining, max_time)
	_update_timing_display()


func _get_timing_level() -> String:
	var pct = time_remaining / max_time
	if pct > 0.66:
		return "quick"
	elif pct > 0.33:
		return "normal"
	else:
		return "late"


func _update_timing_display() -> void:
	var timing = _get_timing_level()
	var mod = TIMING_MODIFIERS.get(timing, 0)
	timing_mod_label.text = "Timing: %s (%+d%%)" % [timing.capitalize(), mod]


func _handle_timeout() -> void:
	round_timer.stop()
	_set_state(DrillState.RESOLVING)

	var result: Dictionary = {
		"target_teammate": -1,
		"defender_target": defender_target,
		"timeout": true,
		"success": false,
		"timing": "timeout",
		"base_chance": 0,
		"distance_mod": 0,
		"pressure_mod": 0,
		"timing_mod": 0,
		"final_chance": 0,
		"roll": 0
	}

	attempts_taken += 1
	session_results.append(result)

	_display_timeout_result()
	_update_score()

	if attempts_taken >= TrainingConstants.ATTEMPTS_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


# ===== EVENT HANDLERS =====

func _on_teammate_pressed(teammate_idx: int) -> void:
	if current_state != DrillState.PASSING:
		return

	AudioManager.play_ui_click()
	_set_state(DrillState.RESOLVING)
	round_timer.stop()

	_resolve_pass(teammate_idx)


func _on_continue_pressed() -> void:
	if current_state == DrillState.SHOWING_RESULT:
		AudioManager.play_ui_click()
		skill_check_details.text = "Click a teammate to pass..."
		_clear_modifiers_display()
		_start_new_round()


func _on_exit_pressed() -> void:
	_handle_exit()


# ===== UI HELPERS =====

func _clear_modifiers_display() -> void:
	distance_mod_label.text = "Distance: --"
	pressure_mod_label.text = "Pressure: --"
	timing_mod_label.text = "Timing: --"
	final_chance_label.text = "Final: --%"


func _update_score() -> void:
	_update_score_display(score_label, round_counter, "Round")


# ===== RESOLUTION =====

func _resolve_pass(teammate_idx: int) -> void:
	var player = GameManager.player_data
	if not player:
		return

	var diff = DIFFICULTY_SETTINGS[current_difficulty]
	var pas = player.get_effective_stat("PAS")
	var tec = player.get_effective_stat("TEC")

	var base_chance = _calculate_base_chance(pas, tec)
	var distance_mod = _get_distance_modifier(teammate_idx)
	var pressure = _get_pressure_level(teammate_idx, diff)
	var pressure_mod = PRESSURE_MODIFIERS.get(pressure, 0)
	var timing = _get_timing_level()
	var timing_mod = TIMING_MODIFIERS.get(timing, 0)

	var final_chance = base_chance + distance_mod + pressure_mod + timing_mod
	final_chance = clampf(final_chance, 5.0, 95.0)

	var roll = randf() * 100.0
	var success = roll <= final_chance

	var result: Dictionary = {
		"target_teammate": teammate_idx,
		"defender_target": defender_target,
		"timeout": false,
		"success": success,
		"timing": timing,
		"pressure": pressure,
		"distance": _get_distance_type(teammate_idx),
		"base_chance": base_chance,
		"distance_mod": distance_mod,
		"pressure_mod": pressure_mod,
		"timing_mod": timing_mod,
		"final_chance": final_chance,
		"roll": roll,
		"risky_pass": pressure == "covered"
	}

	player_pass_history.append(teammate_idx)
	_update_defender_weights(diff.learning_rate)

	attempts_taken += 1
	if success:
		successes += 1
		if timing == "quick":
			quick_passes += 1
	session_results.append(result)

	_display_pass_result(result, teammate_idx)
	_update_score()

	if attempts_taken >= TrainingConstants.ATTEMPTS_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


func _get_distance_type(teammate_idx: int) -> String:
	for pair in FAR_PASSES:
		if teammate_idx in [pair[0], pair[1]]:
			var other = pair[0] if pair[1] == teammate_idx else pair[1]
			if other not in TEAMMATE_ADJACENCY.get(teammate_idx, []):
				return "far"

	return "adjacent"


func _get_distance_modifier(teammate_idx: int) -> int:
	var distance_type = _get_distance_type(teammate_idx)
	return DISTANCE_MODIFIERS.get(distance_type, 0)


func _update_defender_weights(learning_rate: float) -> void:
	if learning_rate <= 0.0 or player_pass_history.is_empty():
		return

	var counts: Array[int] = [0, 0, 0, 0, 0]
	for target in player_pass_history:
		if target >= 0 and target < 5:
			counts[target] += 1

	var total = player_pass_history.size()

	for i in range(5):
		var frequency = float(counts[i]) / total
		var target_weight = 1.0 + (frequency * 3.0)
		defender_weights[i] = lerpf(defender_weights[i], target_weight, learning_rate)


func _display_pass_result(result: Dictionary, teammate_idx: int) -> void:
	var btn = teammate_buttons[teammate_idx]

	if result.success:
		_set_button_style(btn, TrainingConstants.COLOR_SUCCESS)
	else:
		_set_button_style(btn, Color(0.3, 0.3, 0.35))

	var breakdown = ""
	breakdown += "[b]Pass Calculation:[/b]\n"
	breakdown += "Base: (PAS x 0.7) + (TEC x 0.3) = %.1f%%\n" % result.base_chance
	breakdown += "Distance (%s): %+d%%\n" % [result.distance, result.distance_mod]
	breakdown += "Pressure (%s): %+d%%\n" % [result.pressure, result.pressure_mod]
	breakdown += "Timing (%s): %+d%%\n" % [result.timing, result.timing_mod]
	breakdown += "[b]Final: %.1f%%[/b]\n\n" % result.final_chance
	breakdown += "Roll: %.1f vs %.1f\n" % [result.roll, result.final_chance]

	if result.risky_pass:
		breakdown += "[color=orange]Risky pass to covered teammate![/color]\n"

	if result.success:
		breakdown += "\n[color=green][b]SUCCESS![/b][/color]"
	else:
		breakdown += "\n[color=red][b]INTERCEPTED![/b][/color]"

	skill_check_details.text = breakdown
	_show_pass_narration(result)


func _display_timeout_result() -> void:
	for btn in teammate_buttons:
		_set_button_style(btn, Color(0.3, 0.3, 0.35))

	var breakdown = "[b]TIMEOUT![/b]\n\n"
	breakdown += "You held onto the ball too long.\n"
	breakdown += "The defender closed you down.\n\n"
	breakdown += "[color=red][b]TURNOVER[/b][/color]"

	skill_check_details.text = breakdown

	var narrative = NarrativeEngine.generate_dialogue("rondo", "timeout", {})
	narration_label.text = "[i]%s[/i]" % narrative.text


func _show_pass_narration(result: Dictionary) -> void:
	var narrative_type: String

	if result.success:
		if result.risky_pass:
			narrative_type = "risky_success"
		else:
			narrative_type = "success"
	else:
		narrative_type = "intercepted"

	var context = {
		"teammate": "T%d" % (result.target_teammate + 1),
		"timing": result.timing
	}

	var narrative = NarrativeEngine.generate_dialogue("rondo", narrative_type, context)
	narration_label.text = "[i]%s[/i]" % narrative.text


func _complete_drill() -> void:
	_set_state(DrillState.DRILL_COMPLETE)

	var summary = _build_xp_summary()
	summary = summary.replace("Successful Passes: %d / %d" % [successes, attempts_taken],
		"Successful Passes: %d / %d (%.0f%%)\nQuick Passes: %d" % [
			successes, attempts_taken,
			(float(successes) / attempts_taken) * 100,
			quick_passes
		])

	skill_check_details.text = summary
	_show_session_end_narration(narration_label)
	_save_best_score()
	drill_completed.emit({
		"rounds_played": attempts_taken,
		"successful_passes": successes,
		"quick_passes": quick_passes,
		"accuracy": float(successes) / attempts_taken,
		"total_xp": _calculate_total_xp(),
		"pas_xp": _calculate_primary_stat_xp(),
		"tec_xp": _calculate_secondary_stat_xp(),
		"session_results": session_results
	})
