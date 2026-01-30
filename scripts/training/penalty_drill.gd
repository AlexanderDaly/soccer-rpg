extends Control
## PenaltyDrill - Penalty kick training mini-game
## Features 3x3 goal targeting, power charging, skill checks, and adaptive GK

signal drill_completed(results: Dictionary)

# Static function for simulating rewards without playing
static func calculate_simulated_rewards(goals: int, attempts: int = 10) -> Dictionary:
	var total_xp = XP_PER_ATTEMPT * attempts
	total_xp += XP_PER_GOAL * goals

	if goals >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if goals >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var sho_xp = (STAT_XP_PER_GOAL * goals) + (STAT_XP_PER_MISS * (attempts - goals))
	var men_xp = MEN_XP_PER_ATTEMPT * attempts

	return {
		"goals": goals,
		"attempts": attempts,
		"total_xp": total_xp,
		"sho_xp": sho_xp,
		"men_xp": men_xp,
		"stamina_cost": STAMINA_COST
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

# Zone modifiers
const ZONE_MODIFIERS: Dictionary = {
	"TOP_LEFT": -20, "TOP_CENTER": -15, "TOP_RIGHT": -20,
	"MID_LEFT": -10, "MID_CENTER": 5, "MID_RIGHT": -10,
	"LOW_LEFT": -10, "LOW_CENTER": -5, "LOW_RIGHT": -10
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
const XP_GOOD_SESSION_BONUS: int = 25  # 7+ goals
const XP_PERFECT_SESSION_BONUS: int = 50  # 10/10
const STAT_XP_PER_GOAL: int = 3
const STAT_XP_PER_MISS: int = 1
const MEN_XP_PER_ATTEMPT: int = 2
const STAMINA_COST: int = 15
const PENALTIES_PER_SESSION: int = 10
const CHARGE_RATE: float = 66.67  # 100% in 1.5 seconds

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
var current_difficulty: String = "youth"
var selected_zone: String = ""
var current_power: float = 0.0
var is_charging: bool = false

# Session tracking
var penalties_taken: int = 0
var goals_scored: int = 0
var session_results: Array[Dictionary] = []

# GK pattern learning
var player_zone_history: Array[String] = []
var gk_zone_weights: Dictionary = {}

# Zone button references
var zone_buttons: Dictionary = {}


func _ready() -> void:
	_setup_difficulty_selector()
	_setup_zone_buttons()
	_setup_signals()
	_init_gk_weights()
	_update_player_stats_display()
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


func _setup_signals() -> void:
	shoot_button.pressed.connect(_on_shoot_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	charge_timer.timeout.connect(_on_charge_tick)


func _init_gk_weights() -> void:
	for zone in ZONE_MODIFIERS:
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


func _input(event: InputEvent) -> void:
	if current_state == DrillState.SELECTING_ZONE or current_state == DrillState.CHARGING_POWER:
		if event.is_action_pressed("ui_select"):  # SPACE
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

	current_power = minf(current_power + CHARGE_RATE * charge_timer.wait_time, 100.0)
	power_bar.value = current_power
	_update_power_bar_color()
	_update_modifiers_display()


func _update_power_bar_color() -> void:
	var color: Color
	if current_power < 40:
		color = Color(0.9, 0.3, 0.2)  # Red - weak
	elif current_power < 70:
		color = Color(0.9, 0.8, 0.2)  # Yellow - good
	elif current_power <= 85:
		color = Color(0.2, 0.9, 0.3)  # Green - optimal
	else:
		color = Color(0.9, 0.5, 0.2)  # Orange - overpowered

	# Apply color via stylebox override
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3)
	power_bar.add_theme_stylebox_override("fill", style)


func _release_shot() -> void:
	is_charging = false
	charge_timer.stop()
	_set_state(DrillState.RESOLVING)
	_resolve_penalty()


func _on_zone_selected(zone: String) -> void:
	if current_state != DrillState.SELECTING_ZONE:
		return

	# Clear previous selection
	for z in zone_buttons:
		_set_zone_button_color(z, Color(0.75, 0.75, 0.75))

	# Highlight new selection
	selected_zone = zone
	_set_zone_button_color(zone, Color(0.9, 0.9, 0.4))  # Yellow highlight

	shoot_button.disabled = false
	shoot_button.text = "Hold SPACE to Charge Power"

	_update_modifiers_display()
	AudioManager.play_ui_click()


func _set_zone_button_color(zone: String, color: Color) -> void:
	var btn = zone_buttons.get(zone)
	if btn:
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.4, 0.4)
		btn.add_theme_stylebox_override("normal", style)


func _update_modifiers_display() -> void:
	if selected_zone.is_empty():
		zone_mod_label.text = "Zone: --"
		power_mod_label.text = "Power: --"
		gk_mod_label.text = "GK Prediction: --"
		final_chance_label.text = "Final: --%"
		return

	var zone_mod = ZONE_MODIFIERS.get(selected_zone, 0)
	var power_mod = _get_power_modifier(current_power)
	var power_name = _get_power_name(current_power)

	zone_mod_label.text = "Zone: %+d%%" % zone_mod
	power_mod_label.text = "Power: %s (%+d%%)" % [power_name, power_mod]
	gk_mod_label.text = "GK Prediction: ?"

	var player = GameManager.player_data
	if player:
		var base = _calculate_base_chance(player.get_effective_stat("SHO"), player.get_effective_stat("MEN"))
		var final = base + zone_mod + power_mod
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


func _resolve_penalty() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var sho = player.get_effective_stat("SHO")
	var men = player.get_effective_stat("MEN")
	var diff = DIFFICULTY_SETTINGS[current_difficulty]

	# Calculate success chance
	var base_chance = _calculate_base_chance(sho, men)
	var zone_mod = ZONE_MODIFIERS.get(selected_zone, 0)
	var power_mod = _get_power_modifier(current_power)
	var success_chance = base_chance + zone_mod + power_mod

	# Roll for shot on target
	var roll = randf() * 100.0
	var shot_on_target = roll <= success_chance

	var result: Dictionary = {
		"zone": selected_zone,
		"power": current_power,
		"power_name": _get_power_name(current_power),
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
		# GK attempts save
		var gk_result = _resolve_gk_save(selected_zone, diff)
		result.gk_dived = gk_result.dive_zone
		result.gk_save_chance = gk_result.save_chance
		result.gk_roll = gk_result.roll
		result.scored = not gk_result.saved

	# Update GK learning
	player_zone_history.append(selected_zone)
	_update_gk_weights(diff.learning_rate)

	# Track result
	penalties_taken += 1
	if result.scored:
		goals_scored += 1
	session_results.append(result)

	# Show result
	_display_result(result)
	_update_score_display()

	# Check for drill completion
	if penalties_taken >= PENALTIES_PER_SESSION:
		_complete_drill()
	else:
		_set_state(DrillState.SHOWING_RESULT)


func _resolve_gk_save(target_zone: String, diff: Dictionary) -> Dictionary:
	# Select GK dive zone based on learned weights
	var dive_zone = _select_gk_dive_zone()

	# Calculate save chance based on dive accuracy
	var base_save_chance = diff.gk_stat * 0.5  # Base from GK stat

	if dive_zone == target_zone:
		# Correct guess - high save chance
		base_save_chance += 40.0
	elif dive_zone in ZONE_ADJACENCY.get(target_zone, []):
		# Adjacent zone - moderate save chance
		base_save_chance += 15.0
	else:
		# Wrong side - low save chance
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
	# Weighted random selection based on player patterns
	var total_weight = 0.0
	for zone in gk_zone_weights:
		total_weight += gk_zone_weights[zone]

	var roll = randf() * total_weight
	var cumulative = 0.0

	for zone in gk_zone_weights:
		cumulative += gk_zone_weights[zone]
		if roll <= cumulative:
			return zone

	return "MID_CENTER"  # Fallback


func _update_gk_weights(learning_rate: float) -> void:
	if player_zone_history.is_empty():
		return

	# Count zone frequencies
	var zone_counts: Dictionary = {}
	for zone in ZONE_MODIFIERS:
		zone_counts[zone] = 0

	for zone in player_zone_history:
		zone_counts[zone] += 1

	var total = player_zone_history.size()

	# Update weights based on frequency
	for zone in gk_zone_weights:
		var frequency = float(zone_counts[zone]) / total
		var target_weight = 1.0 + (frequency * 3.0)  # More frequent = higher weight
		gk_zone_weights[zone] = lerpf(gk_zone_weights[zone], target_weight, learning_rate)


func _display_result(result: Dictionary) -> void:
	# Update zone button colors
	if result.scored:
		_set_zone_button_color(selected_zone, Color(0.2, 0.9, 0.3))  # Green - goal
	else:
		_set_zone_button_color(selected_zone, Color(0.9, 0.3, 0.2))  # Red - miss/save

	# Build skill check breakdown
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

	# Show narration
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


func _show_session_start_narration() -> void:
	var narrative = NarrativeEngine.generate_dialogue("penalty", "session_start", {})
	narration_label.text = "[i]%s[/i]" % narrative.text


func _update_score_display() -> void:
	score_label.text = "%d / %d" % [goals_scored, PENALTIES_PER_SESSION]
	penalty_counter.text = "Penalty %d of %d" % [mini(penalties_taken + 1, PENALTIES_PER_SESSION), PENALTIES_PER_SESSION]


func _complete_drill() -> void:
	_set_state(DrillState.DRILL_COMPLETE)

	# Calculate rewards
	var total_xp = XP_PER_ATTEMPT * penalties_taken
	total_xp += XP_PER_GOAL * goals_scored

	if goals_scored >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if goals_scored >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var sho_xp = (STAT_XP_PER_GOAL * goals_scored) + (STAT_XP_PER_MISS * (penalties_taken - goals_scored))
	var men_xp = MEN_XP_PER_ATTEMPT * penalties_taken

	# Build summary
	var summary = "[b]Drill Complete![/b]\n\n"
	summary += "Goals: %d / %d (%.0f%%)\n\n" % [goals_scored, penalties_taken, (float(goals_scored) / penalties_taken) * 100]
	summary += "[b]XP Earned:[/b]\n"
	summary += "Base: %d XP (%d attempts × %d)\n" % [XP_PER_ATTEMPT * penalties_taken, penalties_taken, XP_PER_ATTEMPT]
	summary += "Goals: +%d XP (%d goals × %d)\n" % [XP_PER_GOAL * goals_scored, goals_scored, XP_PER_GOAL]

	if goals_scored >= 10:
		summary += "Perfect Session: +%d XP\n" % XP_PERFECT_SESSION_BONUS
	elif goals_scored >= 7:
		summary += "Good Session: +%d XP\n" % XP_GOOD_SESSION_BONUS

	summary += "[b]Total: %d XP[/b]\n\n" % total_xp
	summary += "[b]Stat XP:[/b]\n"
	summary += "SHO: +%d\n" % sho_xp
	summary += "MEN: +%d\n" % men_xp

	skill_check_details.text = summary

	# Show session end narration
	var context = {"goals": str(goals_scored), "total": str(penalties_taken)}
	var narrative = NarrativeEngine.generate_dialogue("penalty", "session_end", context)
	narration_label.text = "[i]%s[/i]" % narrative.text

	# Store results for when drill is exited
	var results = {
		"penalties_taken": penalties_taken,
		"goals_scored": goals_scored,
		"accuracy": float(goals_scored) / penalties_taken,
		"total_xp": total_xp,
		"sho_xp": sho_xp,
		"men_xp": men_xp,
		"session_results": session_results
	}

	# Save best score for simulation feature
	_save_best_score()

	drill_completed.emit(results)


func _save_best_score() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var current_record = player.training_records.get("penalty_drill", {})
	var previous_best = current_record.get("best_score", 0)

	if goals_scored > previous_best:
		player.training_records["penalty_drill"] = {
			"best_score": goals_scored,
			"attempts": PENALTIES_PER_SESSION,
			"best_accuracy": float(goals_scored) / PENALTIES_PER_SESSION
		}


func _on_difficulty_changed(index: int) -> void:
	var keys = DIFFICULTY_SETTINGS.keys()
	if index < keys.size():
		current_difficulty = keys[index]
	AudioManager.play_ui_click()


func _on_shoot_pressed() -> void:
	if current_state == DrillState.SELECTING_ZONE and not selected_zone.is_empty():
		_start_charging()


func _on_continue_pressed() -> void:
	if current_state == DrillState.SHOWING_RESULT:
		# Reset for next penalty
		selected_zone = ""
		current_power = 0.0
		power_bar.value = 0

		# Reset zone button colors
		for zone in zone_buttons:
			_set_zone_button_color(zone, Color(0.75, 0.75, 0.75))

		_update_modifiers_display()
		skill_check_details.text = "Take a shot to see the skill check math..."
		narration_label.text = "[i]Step up to the spot again. The goalkeeper sets himself...[/i]"

		_set_state(DrillState.SELECTING_ZONE)
		AudioManager.play_ui_click()


func _on_exit_pressed() -> void:
	AudioManager.play_ui_click()

	# Apply rewards if drill was completed
	if current_state == DrillState.DRILL_COMPLETE:
		_apply_rewards()

	# Return to training app (close this scene)
	queue_free()


func _apply_rewards() -> void:
	var player = GameManager.player_data
	if not player:
		return

	# Calculate rewards
	var total_xp = XP_PER_ATTEMPT * penalties_taken
	total_xp += XP_PER_GOAL * goals_scored

	if goals_scored >= 7:
		total_xp += XP_GOOD_SESSION_BONUS
	if goals_scored >= 10:
		total_xp += XP_PERFECT_SESSION_BONUS

	var sho_xp = (STAT_XP_PER_GOAL * goals_scored) + (STAT_XP_PER_MISS * (penalties_taken - goals_scored))
	var men_xp = MEN_XP_PER_ATTEMPT * penalties_taken

	# Apply to player
	player.stamina_current = maxi(player.stamina_current - STAMINA_COST, 0)
	player.add_xp(total_xp)
	player.add_stat_xp("SHO", sho_xp)
	player.add_stat_xp("MEN", men_xp)

	# Advance time
	DesktopManager.advance_time(1)

	# Show notification
	DesktopManager.show_notification(
		"Penalty Practice Complete",
		"Scored %d/%d! Earned %d XP" % [goals_scored, penalties_taken, total_xp],
		"",
		"training"
	)
