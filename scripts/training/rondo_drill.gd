extends Control
## RondoDrill - Rondo (keep-ball) passing training mini-game
## Features pentagon teammate layout, defender AI, timing mechanics, and skill checks

signal drill_completed(results: Dictionary)

# Static function for simulating rewards without playing
static func calculate_simulated_rewards(successes: int, attempts: int = 10) -> Dictionary:
	var total_xp = XP_PER_ATTEMPT * attempts
	total_xp += XP_PER_SUCCESS * successes

	# Quick pass bonuses (assume 30% were quick in simulation)
	var quick_passes = roundi(successes * 0.3)
	total_xp += XP_QUICK_PASS_BONUS * quick_passes

	if successes >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if successes >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var pas_xp = (STAT_XP_PER_SUCCESS * successes) + (STAT_XP_PER_FAIL * (attempts - successes))
	var tec_xp = TEC_XP_PER_ATTEMPT * attempts

	return {
		"successes": successes,
		"attempts": attempts,
		"total_xp": total_xp,
		"pas_xp": pas_xp,
		"tec_xp": tec_xp,
		"stamina_cost": STAMINA_COST
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
# Position 0 is top, then clockwise: 1=top-right, 2=bottom-right, 3=bottom-left, 4=top-left
const TEAMMATE_ADJACENCY: Dictionary = {
	0: [1, 4],  # Top connects to upper sides
	1: [0, 2],  # Right side
	2: [1, 3],  # Bottom right
	3: [2, 4],  # Bottom left
	4: [3, 0]   # Left side
}

# Pass distances - diagonal passes are "far"
const FAR_PASSES: Array = [
	[0, 2], [0, 3],  # Top to bottom corners
	[1, 3], [1, 4],  # Right side to left corners
	[2, 4]           # Bottom right to top left
]

# Distance modifiers
const DISTANCE_MODIFIERS: Dictionary = {
	"adjacent": 5,   # Near pass: +5%
	"across": 0,     # Not used in pentagon (all are adjacent or far)
	"far": -10       # Diagonal: -10%
}

# Pressure modifiers
const PRESSURE_MODIFIERS: Dictionary = {
	"open": 10,       # No pressure: +10%
	"contested": -5,  # Adjacent to defender target: -5%
	"covered": -25    # Defender's target: -25% (risky pass!)
}

# Timing modifiers
const TIMING_MODIFIERS: Dictionary = {
	"quick": 10,      # >66% time remaining: +10%
	"normal": 0,      # 33-66% time remaining: 0%
	"late": -10       # <33% time remaining: -10%
}

# XP rewards
const XP_PER_ATTEMPT: int = 5
const XP_PER_SUCCESS: int = 8
const XP_QUICK_PASS_BONUS: int = 3
const XP_GOOD_SESSION_BONUS: int = 25   # 7+ successes
const XP_PERFECT_SESSION_BONUS: int = 50  # 10/10
const STAT_XP_PER_SUCCESS: int = 3
const STAT_XP_PER_FAIL: int = 1
const TEC_XP_PER_ATTEMPT: int = 2
const STAMINA_COST: int = 15
const ROUNDS_PER_SESSION: int = 10
const DEFENDER_MOVE_DELAY: float = 0.8  # Time for defender to "move" to target

# Node references
@onready var difficulty_selector: OptionButton = $VBoxContainer/HeaderSection/DifficultyContainer/DifficultySelector
@onready var score_label: Label = $VBoxContainer/HeaderSection/ScoreLabel
@onready var rondo_field: Control = $VBoxContainer/MainContent/FieldSection/RondoField
@onready var timer_bar: ProgressBar = $VBoxContainer/MainContent/FieldSection/TimerSection/TimerBar
@onready var timer_label: Label = $VBoxContainer/MainContent/FieldSection/TimerSection/TimerLabel
@onready var round_label: Label = $VBoxContainer/MainContent/FieldSection/RoundLabel
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
var current_difficulty: String = "youth"
var defender_target: int = -1  # Teammate index being covered
var time_remaining: float = 0.0
var max_time: float = 3.0

# Session tracking
var rounds_played: int = 0
var successful_passes: int = 0
var quick_passes: int = 0
var session_results: Array[Dictionary] = []

# Defender pattern learning (for Pro/Elite)
var player_pass_history: Array[int] = []
var defender_weights: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0]

# Teammate button references
var teammate_buttons: Array[Button] = []

# Colors
const COLOR_DEFAULT = Color(0.3, 0.5, 0.8)      # Blue
const COLOR_COVERED = Color(0.9, 0.2, 0.2)      # Red (pulsing)
const COLOR_CONTESTED = Color(0.9, 0.6, 0.2)   # Orange
const COLOR_SELECTED = Color(0.9, 0.9, 0.3)    # Yellow
const COLOR_SUCCESS = Color(0.2, 0.8, 0.3)     # Green
const COLOR_FAIL = Color(0.5, 0.5, 0.5)        # Gray


func _ready() -> void:
	_setup_difficulty_selector()
	_setup_teammate_buttons()
	_setup_signals()
	_update_player_stats_display()
	_show_session_start_narration()
	_set_state(DrillState.DEFENDING)
	_start_new_round()


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


func _setup_teammate_buttons() -> void:
	teammate_buttons.clear()
	for i in range(5):
		var btn = rondo_field.get_node("Teammate%d" % i) as Button
		if btn:
			teammate_buttons.append(btn)
			btn.pressed.connect(_on_teammate_pressed.bind(i))
			_set_button_color(btn, COLOR_DEFAULT)


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


func _start_new_round() -> void:
	# Reset button colors
	for i in range(teammate_buttons.size()):
		_set_button_color(teammate_buttons[i], COLOR_DEFAULT)

	# Pick defender target
	_select_defender_target()

	# Update UI to show defender moving
	defender_indicator.text = "[DEF]"
	target_label.text = "Defender moving..."
	pressure_label.text = "..."
	_clear_modifiers_display()

	# Move to defending state with delay
	_set_state(DrillState.DEFENDING)

	# After delay, start the passing phase
	await get_tree().create_timer(DEFENDER_MOVE_DELAY).timeout

	if current_state != DrillState.DEFENDING:
		return  # State changed (e.g., exited)

	_position_defender()
	_update_teammate_colors()
	_start_passing_phase()


func _select_defender_target() -> void:
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	if diff.learning_rate <= 0.0 or player_pass_history.is_empty():
		# Random target for Youth difficulty or first round
		defender_target = randi() % 5
	else:
		# Weighted selection based on player patterns
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
	# Move defender indicator near the target teammate button
	var target_btn = teammate_buttons[defender_target]
	var btn_pos = target_btn.position
	var btn_size = target_btn.size

	# Position defender indicator near the target (offset slightly toward center)
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
				_set_button_color(btn, COLOR_COVERED)
			"contested":
				_set_button_color(btn, COLOR_CONTESTED)
			_:
				_set_button_color(btn, COLOR_DEFAULT)

	# Update info panel
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

	# Get adjacent teammates to defender target
	var adjacent = TEAMMATE_ADJACENCY.get(defender_target, [])
	for adj in adjacent:
		contested.append(adj)

		# Elite difficulty: also pressure teammates adjacent to adjacent
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
	_update_timer_bar_color()

	_set_state(DrillState.PASSING)
	round_timer.start()


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
	_update_timer_bar_color()

	# Update timing modifier display
	_update_timing_display()


func _update_timer_bar_color() -> void:
	var pct = time_remaining / max_time
	var color: Color

	if pct > 0.66:
		color = Color(0.2, 0.8, 0.3)  # Green
	elif pct > 0.33:
		color = Color(0.9, 0.8, 0.2)  # Yellow
	else:
		color = Color(0.9, 0.3, 0.2)  # Red

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3)
	timer_bar.add_theme_stylebox_override("fill", style)


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

	rounds_played += 1
	session_results.append(result)

	_display_timeout_result()
	_update_score_display()

	if rounds_played >= ROUNDS_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


func _on_teammate_pressed(teammate_idx: int) -> void:
	if current_state != DrillState.PASSING:
		return

	AudioManager.play_ui_click()
	_set_state(DrillState.RESOLVING)
	round_timer.stop()

	_resolve_pass(teammate_idx)


func _resolve_pass(teammate_idx: int) -> void:
	var player = GameManager.player_data
	if not player:
		return

	var diff = DIFFICULTY_SETTINGS[current_difficulty]
	var pas = player.get_effective_stat("PAS")
	var tec = player.get_effective_stat("TEC")

	# Calculate success chance
	var base_chance = _calculate_base_chance(pas, tec)
	var distance_mod = _get_distance_modifier(teammate_idx)
	var pressure = _get_pressure_level(teammate_idx, diff)
	var pressure_mod = PRESSURE_MODIFIERS.get(pressure, 0)
	var timing = _get_timing_level()
	var timing_mod = TIMING_MODIFIERS.get(timing, 0)

	var final_chance = base_chance + distance_mod + pressure_mod + timing_mod
	final_chance = clampf(final_chance, 5.0, 95.0)

	# Roll for success
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

	# Update learning for Pro/Elite difficulty
	player_pass_history.append(teammate_idx)
	_update_defender_weights(diff.learning_rate)

	# Track results
	rounds_played += 1
	if success:
		successful_passes += 1
		if timing == "quick":
			quick_passes += 1
	session_results.append(result)

	# Show result
	_display_pass_result(result, teammate_idx)
	_update_score_display()

	if rounds_played >= ROUNDS_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


func _get_distance_type(teammate_idx: int) -> String:
	# Check if it's a far (diagonal) pass
	for pair in FAR_PASSES:
		if (pair[0] == 0 and pair[1] == teammate_idx) or (pair[1] == 0 and pair[0] == teammate_idx):
			# This simplified check assumes player is at center, all passes originate from center
			pass
		# Actually check if target is far from any starting position
		# In rondo, we consider diagonal across pentagon as "far"
		if teammate_idx in [pair[0], pair[1]]:
			# Check if this is a diagonal relationship
			var other = pair[0] if pair[1] == teammate_idx else pair[1]
			# Far passes are non-adjacent in the pentagon
			if other not in TEAMMATE_ADJACENCY.get(teammate_idx, []):
				return "far"

	# If not far, check adjacency (all positions are "adjacent" to the center player)
	return "adjacent"


func _get_distance_modifier(teammate_idx: int) -> int:
	var distance_type = _get_distance_type(teammate_idx)
	return DISTANCE_MODIFIERS.get(distance_type, 0)


func _update_defender_weights(learning_rate: float) -> void:
	if learning_rate <= 0.0 or player_pass_history.is_empty():
		return

	# Count pass frequencies
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for target in player_pass_history:
		if target >= 0 and target < 5:
			counts[target] += 1

	var total = player_pass_history.size()

	# Update weights based on frequency
	for i in range(5):
		var frequency = float(counts[i]) / total
		var target_weight = 1.0 + (frequency * 3.0)
		defender_weights[i] = lerpf(defender_weights[i], target_weight, learning_rate)


func _display_pass_result(result: Dictionary, teammate_idx: int) -> void:
	var btn = teammate_buttons[teammate_idx]

	if result.success:
		_set_button_color(btn, COLOR_SUCCESS)
	else:
		_set_button_color(btn, COLOR_FAIL)

	# Build skill check breakdown
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

	# Show narration
	_show_pass_narration(result)


func _display_timeout_result() -> void:
	# Gray out all buttons
	for btn in teammate_buttons:
		_set_button_color(btn, COLOR_FAIL)

	var breakdown = "[b]TIMEOUT![/b]\n\n"
	breakdown += "You held onto the ball too long.\n"
	breakdown += "The defender closed you down.\n\n"
	breakdown += "[color=red][b]TURNOVER[/b][/color]"

	skill_check_details.text = breakdown

	# Show timeout narration
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


func _clear_modifiers_display() -> void:
	distance_mod_label.text = "Distance: --"
	pressure_mod_label.text = "Pressure: --"
	timing_mod_label.text = "Timing: --"
	final_chance_label.text = "Final: --%"


func _update_score_display() -> void:
	score_label.text = "%d / %d" % [successful_passes, ROUNDS_PER_SESSION]
	round_counter.text = "Round %d of %d" % [mini(rounds_played + 1, ROUNDS_PER_SESSION), ROUNDS_PER_SESSION]
	round_label.text = round_counter.text


func _complete_drill() -> void:
	_set_state(DrillState.DRILL_COMPLETE)

	# Calculate rewards
	var total_xp = XP_PER_ATTEMPT * rounds_played
	total_xp += XP_PER_SUCCESS * successful_passes
	total_xp += XP_QUICK_PASS_BONUS * quick_passes

	if successful_passes >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if successful_passes >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var pas_xp = (STAT_XP_PER_SUCCESS * successful_passes) + (STAT_XP_PER_FAIL * (rounds_played - successful_passes))
	var tec_xp = TEC_XP_PER_ATTEMPT * rounds_played

	# Build summary
	var summary = "[b]Drill Complete![/b]\n\n"
	summary += "Successful Passes: %d / %d (%.0f%%)\n" % [successful_passes, rounds_played, (float(successful_passes) / rounds_played) * 100]
	summary += "Quick Passes: %d\n\n" % quick_passes
	summary += "[b]XP Earned:[/b]\n"
	summary += "Base: %d XP (%d attempts x %d)\n" % [XP_PER_ATTEMPT * rounds_played, rounds_played, XP_PER_ATTEMPT]
	summary += "Successes: +%d XP (%d x %d)\n" % [XP_PER_SUCCESS * successful_passes, successful_passes, XP_PER_SUCCESS]
	summary += "Quick Bonus: +%d XP (%d x %d)\n" % [XP_QUICK_PASS_BONUS * quick_passes, quick_passes, XP_QUICK_PASS_BONUS]

	if successful_passes >= 10:
		summary += "Perfect Session: +%d XP\n" % XP_PERFECT_SESSION_BONUS
	elif successful_passes >= 7:
		summary += "Good Session: +%d XP\n" % XP_GOOD_SESSION_BONUS

	summary += "[b]Total: %d XP[/b]\n\n" % total_xp
	summary += "[b]Stat XP:[/b]\n"
	summary += "PAS: +%d\n" % pas_xp
	summary += "TEC: +%d\n" % tec_xp

	skill_check_details.text = summary

	# Show session end narration
	var context = {"successes": str(successful_passes), "total": str(rounds_played)}
	var narrative = NarrativeEngine.generate_dialogue("rondo", "session_end", context)
	narration_label.text = "[i]%s[/i]" % narrative.text

	# Store results
	var results = {
		"rounds_played": rounds_played,
		"successful_passes": successful_passes,
		"quick_passes": quick_passes,
		"accuracy": float(successful_passes) / rounds_played,
		"total_xp": total_xp,
		"pas_xp": pas_xp,
		"tec_xp": tec_xp,
		"session_results": session_results
	}

	# Save best score
	_save_best_score()

	drill_completed.emit(results)


func _save_best_score() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var current_record = player.training_records.get("rondo_drill", {})
	var previous_best = current_record.get("best_score", 0)

	if successful_passes > previous_best:
		player.training_records["rondo_drill"] = {
			"best_score": successful_passes,
			"attempts": ROUNDS_PER_SESSION,
			"best_accuracy": float(successful_passes) / ROUNDS_PER_SESSION
		}


func _show_session_start_narration() -> void:
	var narrative = NarrativeEngine.generate_dialogue("rondo", "session_start", {})
	narration_label.text = "[i]%s[/i]" % narrative.text


func _set_button_color(btn: Button, color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.2, 0.2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)


func _on_difficulty_changed(index: int) -> void:
	var keys = DIFFICULTY_SETTINGS.keys()
	if index < keys.size():
		current_difficulty = keys[index]
	AudioManager.play_ui_click()


func _on_continue_pressed() -> void:
	if current_state == DrillState.SHOWING_RESULT:
		AudioManager.play_ui_click()
		skill_check_details.text = "Click a teammate to pass..."
		_clear_modifiers_display()
		_start_new_round()


func _on_exit_pressed() -> void:
	AudioManager.play_ui_click()

	# Apply rewards if drill was completed
	if current_state == DrillState.DRILL_COMPLETE:
		_apply_rewards()

	queue_free()


func _apply_rewards() -> void:
	var player = GameManager.player_data
	if not player:
		return

	# Calculate rewards
	var total_xp = XP_PER_ATTEMPT * rounds_played
	total_xp += XP_PER_SUCCESS * successful_passes
	total_xp += XP_QUICK_PASS_BONUS * quick_passes

	if successful_passes >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if successful_passes >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var pas_xp = (STAT_XP_PER_SUCCESS * successful_passes) + (STAT_XP_PER_FAIL * (rounds_played - successful_passes))
	var tec_xp = TEC_XP_PER_ATTEMPT * rounds_played

	# Apply to player
	player.stamina_current = maxi(player.stamina_current - STAMINA_COST, 0)
	player.add_xp(total_xp)
	player.add_stat_xp("PAS", pas_xp)
	player.add_stat_xp("TEC", tec_xp)

	# Advance time
	DesktopManager.advance_time(1)

	# Show notification
	DesktopManager.show_notification(
		"Rondo Training Complete",
		"Passed %d/%d! Earned %d XP" % [successful_passes, rounds_played, total_xp],
		"",
		"training"
	)
