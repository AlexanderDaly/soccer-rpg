class_name TrainingDrillBase
extends Control
## Abstract base class for training drills
## Provides shared functionality for difficulty selection, XP rewards, button styling, etc.

signal drill_completed(results: Dictionary)

# ===== VIRTUAL METHODS - Override in subclasses =====

## Returns the drill identifier (e.g., "freekick", "penalty", "rondo")
func _get_drill_name() -> String:
	return "drill"


## Returns the primary stat trained by this drill
func _get_primary_stat() -> String:
	return "SHO"


## Returns the secondary stat trained by this drill
func _get_secondary_stat() -> String:
	return "TEC"


## Returns the difficulty settings dictionary for this drill
func _get_difficulty_settings() -> Dictionary:
	return {}


## Returns XP earned per successful attempt
func _get_xp_per_success() -> int:
	return 10


## Returns additional bonus XP (e.g., top corner bonus, quick pass bonus)
func _calculate_bonus_xp() -> int:
	return 0


## Returns the label for successes (e.g., "Goals", "Successful Passes")
func _get_success_label() -> String:
	return "Successes"


## Returns true if the drill is in a completed state
func _is_drill_complete() -> bool:
	return false


## Called when showing the completion notification
func _get_completion_title() -> String:
	return "Training Complete"


## Called when showing the completion notification
func _get_completion_message(total_xp: int) -> String:
	return "Scored %d/%d! Earned %d XP" % [successes, attempts_taken, total_xp]


# ===== SHARED STATE =====

var current_difficulty: String = "youth"
var attempts_taken: int = 0
var successes: int = 0
var session_results: Array[Dictionary] = []


# ===== SHARED IMPLEMENTATIONS =====

## Sets up the difficulty selector dropdown
func _setup_difficulty_selector(selector: OptionButton) -> void:
	selector.clear()
	var idx = 0
	var settings = _get_difficulty_settings()
	for diff_id in settings:
		var diff = settings[diff_id]
		var text = diff.name
		if not diff.get("unlocked", true):
			text += " (Locked)"
		selector.add_item(text, idx)
		if not diff.get("unlocked", true):
			selector.set_item_disabled(idx, true)
		idx += 1
	selector.selected = 0
	selector.item_selected.connect(_on_difficulty_changed)


## Handles difficulty selection change
func _on_difficulty_changed(index: int) -> void:
	var keys = _get_difficulty_settings().keys()
	if index < keys.size():
		current_difficulty = keys[index]
	AudioManager.play_ui_click()


## Creates a StyleBoxFlat with the given colors
func _create_button_style(bg_color: Color, border_color: Color, corner_radius: int = 6) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.set_corner_radius_all(corner_radius)
	return style


## Styles the continue and exit buttons with console theme
func _style_footer_buttons(continue_btn: Button, exit_btn: Button) -> void:
	# Style Continue button with console green accent
	var continue_style = _create_button_style(Color(0, 0.6, 0.3), Color(0, 0.8, 0.4))
	continue_btn.add_theme_stylebox_override("normal", continue_style)
	continue_btn.add_theme_color_override("font_color", TrainingConstants.TEXT_PRIMARY)

	var continue_hover = continue_style.duplicate()
	continue_hover.bg_color = Color(0, 0.7, 0.35)
	continue_btn.add_theme_stylebox_override("hover", continue_hover)

	var continue_pressed = continue_style.duplicate()
	continue_pressed.bg_color = Color(0, 0.5, 0.25)
	continue_btn.add_theme_stylebox_override("pressed", continue_pressed)

	# Style Exit button with dark panel style
	var exit_style = _create_button_style(TrainingConstants.COLOR_DEFAULT, TrainingConstants.BORDER_COLOR)
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	exit_btn.add_theme_color_override("font_color", TrainingConstants.TEXT_PRIMARY)

	var exit_hover = exit_style.duplicate()
	exit_hover.bg_color = Color(0.15, 0.2, 0.3)
	exit_btn.add_theme_stylebox_override("hover", exit_hover)

	var exit_pressed = exit_style.duplicate()
	exit_pressed.bg_color = Color(0.08, 0.12, 0.2)
	exit_btn.add_theme_stylebox_override("pressed", exit_pressed)


## Styles a shoot/action button with console theme
func _style_shoot_button(btn: Button) -> void:
	var shoot_style = _create_button_style(TrainingConstants.COLOR_DEFAULT, TrainingConstants.ACCENT_GREEN)
	btn.add_theme_stylebox_override("normal", shoot_style)
	btn.add_theme_color_override("font_color", TrainingConstants.TEXT_PRIMARY)

	var shoot_hover = shoot_style.duplicate()
	shoot_hover.bg_color = Color(0.15, 0.2, 0.3)
	btn.add_theme_stylebox_override("hover", shoot_hover)

	var shoot_pressed = shoot_style.duplicate()
	shoot_pressed.bg_color = Color(0, 0.5, 0.25)
	btn.add_theme_stylebox_override("pressed", shoot_pressed)

	var shoot_disabled = shoot_style.duplicate()
	shoot_disabled.bg_color = Color(0.08, 0.1, 0.15)
	shoot_disabled.border_color = Color(0.2, 0.25, 0.35)
	btn.add_theme_stylebox_override("disabled", shoot_disabled)
	btn.add_theme_color_override("font_disabled_color", TrainingConstants.TEXT_MUTED)


## Updates power bar color based on current power value
func _update_power_bar_color(power_bar: ProgressBar, power: float) -> void:
	var color: Color
	if power < 40:
		color = TrainingConstants.COLOR_FAIL
	elif power < 70:
		color = TrainingConstants.COLOR_WARNING
	elif power <= 85:
		color = TrainingConstants.COLOR_SUCCESS
	else:
		color = TrainingConstants.COLOR_CONTESTED

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(4)
	power_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = TrainingConstants.COLOR_DEFAULT
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = TrainingConstants.BORDER_COLOR
	bg_style.set_corner_radius_all(4)
	power_bar.add_theme_stylebox_override("background", bg_style)


## Updates timer bar color based on time remaining percentage
func _update_timer_bar_color(timer_bar: ProgressBar, time_remaining: float, max_time: float) -> void:
	var pct = time_remaining / max_time
	var color: Color

	if pct > 0.66:
		color = TrainingConstants.COLOR_SUCCESS
	elif pct > 0.33:
		color = TrainingConstants.COLOR_WARNING
	else:
		color = TrainingConstants.COLOR_FAIL

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = TrainingConstants.COLOR_DEFAULT
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = TrainingConstants.BORDER_COLOR
	bg_style.set_corner_radius_all(4)
	timer_bar.add_theme_stylebox_override("background", bg_style)


## Sets color for a zone/teammate button
func _set_button_style(btn: Button, bg_color: Color, border_color: Color = TrainingConstants.BORDER_COLOR) -> void:
	var style = _create_button_style(bg_color, border_color)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", TrainingConstants.TEXT_PRIMARY)


## Calculates total XP earned from the session
func _calculate_total_xp() -> int:
	var total = TrainingConstants.XP_PER_ATTEMPT * attempts_taken
	total += _get_xp_per_success() * successes
	total += _calculate_bonus_xp()

	if successes >= 7:
		total += TrainingConstants.XP_GOOD_SESSION_BONUS
	if successes >= 10:
		total += TrainingConstants.XP_PERFECT_SESSION_BONUS

	return total


## Calculates stat XP for primary or secondary stat
func _calculate_primary_stat_xp() -> int:
	return (TrainingConstants.STAT_XP_PER_SUCCESS * successes) + (TrainingConstants.STAT_XP_PER_FAIL * (attempts_taken - successes))


## Calculates secondary stat XP (typically per attempt)
func _calculate_secondary_stat_xp(xp_per_attempt: int = 2) -> int:
	return xp_per_attempt * attempts_taken


## Applies rewards to the player after drill completion
func _apply_rewards() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var total_xp = _calculate_total_xp()
	var primary_xp = _calculate_primary_stat_xp()
	var secondary_xp = _calculate_secondary_stat_xp()

	player.stamina_current = maxi(player.stamina_current - TrainingConstants.STAMINA_COST, 0)
	player.add_xp(total_xp)
	player.add_stat_xp(_get_primary_stat(), primary_xp)
	player.add_stat_xp(_get_secondary_stat(), secondary_xp)

	DesktopManager.advance_time(1)

	DesktopManager.show_notification(
		_get_completion_title(),
		_get_completion_message(total_xp),
		"",
		"training"
	)


## Saves the best score to player training records
func _save_best_score() -> void:
	var player = GameManager.player_data
	if not player:
		return

	var record_key = _get_drill_name() + "_drill"
	var current_record = player.training_records.get(record_key, {})
	var previous_best = current_record.get("best_score", 0)

	if successes > previous_best:
		player.training_records[record_key] = {
			"best_score": successes,
			"attempts": TrainingConstants.ATTEMPTS_PER_SESSION,
			"best_accuracy": float(successes) / TrainingConstants.ATTEMPTS_PER_SESSION
		}


## Handles exit button pressed
func _handle_exit() -> void:
	AudioManager.play_ui_click()
	if _is_drill_complete():
		_apply_rewards()
	get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")


## Builds the XP summary string for drill completion
func _build_xp_summary() -> String:
	var total_xp = _calculate_total_xp()
	var primary_xp = _calculate_primary_stat_xp()
	var secondary_xp = _calculate_secondary_stat_xp()

	var summary = "[b]Drill Complete![/b]\n\n"
	summary += "%s: %d / %d (%.0f%%)\n\n" % [
		_get_success_label(),
		successes,
		attempts_taken,
		(float(successes) / attempts_taken) * 100
	]

	summary += "[b]XP Earned:[/b]\n"
	summary += "Base: %d XP (%d attempts × %d)\n" % [
		TrainingConstants.XP_PER_ATTEMPT * attempts_taken,
		attempts_taken,
		TrainingConstants.XP_PER_ATTEMPT
	]
	summary += "%s: +%d XP (%d × %d)\n" % [
		_get_success_label(),
		_get_xp_per_success() * successes,
		successes,
		_get_xp_per_success()
	]

	var bonus_xp = _calculate_bonus_xp()
	if bonus_xp > 0:
		summary += _get_bonus_xp_breakdown()

	if successes >= 10:
		summary += "Perfect Session: +%d XP\n" % TrainingConstants.XP_PERFECT_SESSION_BONUS
	elif successes >= 7:
		summary += "Good Session: +%d XP\n" % TrainingConstants.XP_GOOD_SESSION_BONUS

	summary += "[b]Total: %d XP[/b]\n\n" % total_xp
	summary += "[b]Stat XP:[/b]\n"
	summary += "%s: +%d\n" % [_get_primary_stat(), primary_xp]
	summary += "%s: +%d\n" % [_get_secondary_stat(), secondary_xp]

	return summary


## Override to provide bonus XP breakdown string
func _get_bonus_xp_breakdown() -> String:
	return ""


## Shows session start narration
func _show_session_start_narration(narration_label: RichTextLabel) -> void:
	var narrative = NarrativeEngine.generate_dialogue(_get_drill_name(), "session_start", {})
	narration_label.text = "[i]%s[/i]" % narrative.text


## Shows session end narration
func _show_session_end_narration(narration_label: RichTextLabel) -> void:
	var context = {"goals": str(successes), "successes": str(successes), "total": str(attempts_taken)}
	var narrative = NarrativeEngine.generate_dialogue(_get_drill_name(), "session_end", context)
	narration_label.text = "[i]%s[/i]" % narrative.text


## Updates the score display
func _update_score_display(score_label: Label, counter_label: Label, counter_prefix: String = "Attempt") -> void:
	score_label.text = "%d / %d" % [successes, TrainingConstants.ATTEMPTS_PER_SESSION]
	counter_label.text = "%s %d of %d" % [
		counter_prefix,
		mini(attempts_taken + 1, TrainingConstants.ATTEMPTS_PER_SESSION),
		TrainingConstants.ATTEMPTS_PER_SESSION
	]
