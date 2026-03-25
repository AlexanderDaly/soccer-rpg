extends Control
class_name PostMatchScreen
## PostMatchScreen - Displays match results and player performance

@onready var result_label: Label = $MainContainer/ResultSection/ResultLabel
@onready var score_label: Label = $MainContainer/ResultSection/ScoreLabel
@onready var opponent_label: Label = $MainContainer/ResultSection/OpponentLabel
@onready var team_stats_label: Label = $MainContainer/ResultSection/TeamStatsLabel

@onready var rating_label: Label = $MainContainer/PerformanceSection/RatingContainer/RatingValue
@onready var goals_label: Label = $MainContainer/PerformanceSection/StatsGrid/GoalsValue
@onready var assists_label: Label = $MainContainer/PerformanceSection/StatsGrid/AssistsValue
@onready var shots_label: Label = $MainContainer/PerformanceSection/StatsGrid/ShotsValue
@onready var passes_label: Label = $MainContainer/PerformanceSection/StatsGrid/PassesValue
@onready var tackles_label: Label = $MainContainer/PerformanceSection/StatsGrid/TacklesValue
@onready var dribbles_label: Label = $MainContainer/PerformanceSection/StatsGrid/DribblesValue

@onready var xp_gained_label: Label = $MainContainer/RewardsSection/XPGained
@onready var reputation_label: Label = $MainContainer/RewardsSection/ReputationLabel
@onready var reputation_breakdown_label: Label = $MainContainer/RewardsSection/ReputationBreakdown
@onready var milestones_container: VBoxContainer = $MainContainer/RewardsSection/MilestonesContainer

@onready var event_list: VBoxContainer = $MainContainer/EventSection/EventScroll/EventList

@onready var narrative_label: Label = $MainContainer/NarrativeSection/NarrativeText

@onready var continue_button: Button = $MainContainer/ButtonSection/ContinueButton

var match_result: Dictionary


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)

	# Connect to milestone signal
	CareerManager.milestone_reached.connect(_on_milestone_reached)

	# Get the result from the last match
	if not CareerManager.match_history.is_empty():
		match_result = CareerManager.match_history.back()
		_roll_for_injuries()
		_display_result()
		_update_season_standings()


func _display_result() -> void:
	if match_result.get("did_not_play", false):
		result_label.text = "MATCH SIMULATED"
		result_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))

	# Result header
	if not match_result.get("did_not_play", false) and match_result.get("won", false):
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	elif not match_result.get("did_not_play", false) and match_result.get("lost", false):
		result_label.text = "DEFEAT"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	elif not match_result.get("did_not_play", false):
		result_label.text = "DRAW"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))

	# Score
	var player_score = match_result.get("player_score", 0)
	var opponent_score = match_result.get("opponent_score", 0)
	score_label.text = "%d - %d" % [player_score, opponent_score]

	# Opponent name
	opponent_label.text = "vs %s" % match_result.get("opponent_name", "Unknown")
	if match_result.get("did_not_play", false):
		var absence_detail = str(match_result.get("absence_detail", ""))
		if absence_detail.is_empty():
			absence_detail = str(match_result.get("absence_reason", "Unavailable")).capitalize()
		opponent_label.text += " | %s" % absence_detail
	_update_team_stats_label()

	# Player rating
	var rating = match_result.get("rating", 6.0)
	rating_label.text = "%.1f" % rating
	_color_rating(rating)

	# Stats
	goals_label.text = str(match_result.get("goals", 0))
	assists_label.text = str(match_result.get("assists", 0))
	shots_label.text = "%d/%d" % [match_result.get("shots_on_target", 0), match_result.get("shots", 0)]
	passes_label.text = str(match_result.get("successful_passes", 0))
	tackles_label.text = str(match_result.get("successful_tackles", 0))
	dribbles_label.text = str(match_result.get("successful_dribbles", 0))

	# Calculate and display XP gained
	var xp_gained = _calculate_xp_display()
	xp_gained_label.text = "+%d XP" % xp_gained
	_display_reputation()

	# Man of the Match
	if match_result.get("man_of_match", false):
		_add_achievement("Man of the Match!")

	# Cards
	if match_result.get("yellow_cards", 0) > 0:
		_add_card_display(match_result.yellow_cards, false)
	if match_result.get("red_card", false):
		_add_card_display(1, true)

	# Event timeline
	_display_event_timeline()

	# Generate narrative
	_display_narrative()

	for injury_event in match_result.get("injury_events", []):
		_add_injury_display(
			str(injury_event.get("player_name", "Player")),
			str(injury_event.get("description", "injury")),
			str(injury_event.get("type", "minor"))
		)


func _color_rating(rating: float) -> void:
	if rating >= 8.0:
		rating_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))  # Green
	elif rating >= 7.0:
		rating_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.2))  # Yellow-green
	elif rating >= 6.0:
		rating_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))  # Yellow
	elif rating >= 5.0:
		rating_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))  # Orange
	else:
		rating_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))  # Red


func _update_team_stats_label() -> void:
	if not team_stats_label:
		return

	var home_stats = match_result.get("home_stats", {})
	var away_stats = match_result.get("away_stats", {})

	if home_stats.is_empty() or away_stats.is_empty():
		team_stats_label.text = "Team stats unavailable"
		return

	var current_match = GameManager.current_match
	var home_name = current_match.home_team.name if current_match and current_match.home_team else "Home"
	var away_name = current_match.away_team.name if current_match and current_match.away_team else "Away"

	var home_shots = int(home_stats.get("shots", 0))
	var home_on_target = int(home_stats.get("shots_on_target", 0))
	var home_xg = float(home_stats.get("xg", 0.0))
	var home_passes = int(home_stats.get("passes_completed", 0))
	var home_attempts = int(home_stats.get("passes_attempted", 0))
	var home_poss = float(home_stats.get("possession", 0.0)) * 100.0

	var away_shots = int(away_stats.get("shots", 0))
	var away_on_target = int(away_stats.get("shots_on_target", 0))
	var away_xg = float(away_stats.get("xg", 0.0))
	var away_passes = int(away_stats.get("passes_completed", 0))
	var away_attempts = int(away_stats.get("passes_attempted", 0))
	var away_poss = float(away_stats.get("possession", 0.0)) * 100.0

	var home_line = "%s %d(%d) xG %.2f | %d%% %d/%d" % [home_name, home_shots, home_on_target, home_xg, roundi(home_poss), home_passes, home_attempts]
	var away_line = "%s %d(%d) xG %.2f | %d%% %d/%d" % [away_name, away_shots, away_on_target, away_xg, roundi(away_poss), away_passes, away_attempts]
	team_stats_label.text = "%s  |  %s" % [home_line, away_line]


func _calculate_xp_display() -> int:
	if match_result.get("did_not_play", false):
		return 0
	var base_xp = 50

	if match_result.get("goals", 0) > 0:
		base_xp += match_result.goals * 20
	if match_result.get("assists", 0) > 0:
		base_xp += match_result.assists * 15
	if match_result.get("won", false):
		base_xp += 30
	if match_result.get("clean_sheet", false):
		base_xp += 20
	if match_result.get("man_of_match", false):
		base_xp += 50

	return base_xp


func _add_achievement(text: String) -> void:
	var achievement = Label.new()
	achievement.text = text
	achievement.add_theme_font_size_override("font_size", 18)
	achievement.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))  # Gold
	achievement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milestones_container.add_child(achievement)


func _add_card_display(count: int, is_red: bool) -> void:
	var card_label = Label.new()
	if is_red:
		card_label.text = "RED CARD"
		card_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	else:
		card_label.text = "YELLOW CARD" + (" x%d" % count if count > 1 else "")
		card_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.1))

	card_label.add_theme_font_size_override("font_size", 16)
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milestones_container.add_child(card_label)


func _on_milestone_reached(milestone_id: String) -> void:
	if milestone_id in CareerManager.MILESTONES:
		var milestone = CareerManager.MILESTONES[milestone_id]
		_add_achievement("MILESTONE: %s" % milestone.name)


func _display_narrative() -> void:
	# Generate a simple narrative based on performance
	var narrative = _generate_match_narrative()
	narrative_label.text = narrative


func _display_event_timeline() -> void:
	if not event_list:
		return

	# Clear existing
	for child in event_list.get_children():
		child.queue_free()

	var timeline_events = _collect_timeline_events()
	if timeline_events.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No major events recorded."
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		event_list.add_child(empty_label)
		return

	timeline_events.sort_custom(func(a, b): return a.minute < b.minute)

	for event in timeline_events:
		_add_timeline_entry(event)


func _collect_timeline_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	var current_match = GameManager.current_match
	var home_name = current_match.home_team.name if current_match and current_match.home_team else "Home"
	var away_name = current_match.away_team.name if current_match and current_match.away_team else "Away"
	var player_team_id = GameManager.current_team.id if GameManager.current_team else ""
	var player_id = GameManager.player_data.id if GameManager.player_data else ""

	var home_goal_events = match_result.get("home_goal_events", [])
	var away_goal_events = match_result.get("away_goal_events", [])
	var card_events = match_result.get("card_events", [])
	var key_events = match_result.get("key_events", [])
	var injury_events = match_result.get("injury_events", [])

	for event in home_goal_events:
		events.append(_build_timeline_event(event, home_name, player_team_id, player_id))

	for event in away_goal_events:
		events.append(_build_timeline_event(event, away_name, player_team_id, player_id))

	for event in card_events:
		events.append(_build_sim_card_event(event, player_team_id, player_id))

	for event in key_events:
		var event_type = event.get("type", "")
		if event_type == "yellow_card" or event_type == "red_card":
			events.append(_build_card_event(event, home_name, away_name, player_team_id, player_id))

	for event in injury_events:
		events.append(_build_injury_event(event, home_name, player_team_id))

	return events


func _build_timeline_event(event: Dictionary, fallback_team_name: String, player_team_id: String, player_id: String) -> Dictionary:
	var team_name = event.get("team_name", fallback_team_name)
	var team_id = event.get("team_id", "")
	var is_player_team = team_id != "" and team_id == player_team_id
	if not is_player_team and team_id == "" and GameManager.current_team:
		is_player_team = team_name == GameManager.current_team.name

	return {
		"type": "goal",
		"minute": int(event.get("minute", 0)),
		"team_name": team_name,
		"scorer_name": event.get("scorer_name", "Unknown"),
		"scorer_id": event.get("scorer_id", ""),
		"assister_name": event.get("assister_name", ""),
		"is_player_team": is_player_team,
		"is_player_scorer": event.get("scorer_id", "") == player_id
	}


func _add_timeline_entry(event: Dictionary) -> void:
	var label = Label.new()
	var minute = event.get("minute", 0)
	var minute_text = "%d'" % minute if minute > 0 else "--'"
	var team_name = event.get("team_name", "Team")
	var event_type = event.get("type", "goal")
	var line = ""

	match event_type:
		"goal":
			var scorer = event.get("scorer_name", "Unknown")
			var assister = event.get("assister_name", "")
			line = "%s %s - %s" % [minute_text, team_name, scorer]
			if assister != "":
				line += " (A: %s)" % assister
			if event.get("is_player_scorer", false):
				line += " (YOU)"
		"card":
			var card_color = event.get("card_color", "yellow").to_upper()
			var card_player = event.get("player_name", "Player")
			line = "%s %s - %s CARD (%s)" % [minute_text, team_name, card_color, card_player]
		"injury":
			var injury_player = event.get("player_name", "Player")
			var description = event.get("description", "injury")
			var matches_out = int(event.get("matches_out", 0))
			line = "%s %s - Injury: %s (%s)" % [minute_text, team_name, injury_player, description]
			if matches_out > 0:
				line += " - %d match%s" % [matches_out, "es" if matches_out != 1 else ""]
		_:
			line = "%s %s - Event" % [minute_text, team_name]

	label.text = line
	label.add_theme_font_size_override("font_size", 14)
	if event.get("is_player_team", false):
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	event_list.add_child(label)


func _build_card_event(event: Dictionary, home_name: String, away_name: String, player_team_id: String, player_id: String) -> Dictionary:
	var data = event.get("data", {})
	var minute = int(event.get("minute", 0))
	var is_player = data.get("is_player", false)
	var team_name = data.get("team_name", "")
	var team_id = data.get("team_id", "")
	var player_name = data.get("player_name", "")

	if team_name == "":
		var is_player_home = GameManager.current_match and GameManager.current_match.is_home
		if is_player:
			team_name = home_name if is_player_home else away_name
		else:
			team_name = away_name if is_player_home else home_name

	if team_id == "" and is_player:
		team_id = player_team_id

	if player_name == "":
		player_name = GameManager.player_data.name if is_player and GameManager.player_data else "Player"
	var card_color = "red" if event.get("type", "") == "red_card" else "yellow"

	return {
		"type": "card",
		"minute": minute,
		"team_name": team_name,
		"team_id": team_id,
		"player_name": player_name,
		"card_color": card_color,
		"is_player_team": team_id != "" and team_id == player_team_id,
		"is_player_scorer": false
	}


func _build_sim_card_event(event: Dictionary, player_team_id: String, player_id: String) -> Dictionary:
	var team_id = event.get("team_id", "")
	var team_name = event.get("team_name", "Team")
	var player_id_event = event.get("player_id", "")

	return {
		"type": "card",
		"minute": int(event.get("minute", 0)),
		"team_name": team_name,
		"team_id": team_id,
		"player_name": event.get("player_name", "Player"),
		"card_color": event.get("card_color", "yellow"),
		"is_player_team": team_id != "" and team_id == player_team_id,
		"is_player_scorer": player_id_event != "" and player_id_event == player_id
	}


func _build_injury_event(event: Dictionary, fallback_team_name: String, player_team_id: String) -> Dictionary:
	var team_name = event.get("team_name", fallback_team_name)
	var team_id = event.get("team_id", player_team_id)

	return {
		"type": "injury",
		"minute": int(event.get("minute", 90)),
		"team_name": team_name,
		"team_id": team_id,
		"player_name": event.get("player_name", "Player"),
		"description": event.get("description", "injury"),
		"matches_out": int(event.get("matches_out", 0)),
		"is_player_team": true,
		"is_player_scorer": false
	}


func _generate_match_narrative() -> String:
	var lines: Array[String] = []
	var player_name = GameManager.player_data.name if GameManager.player_data else "The player"

	# Result-based opening
	if match_result.get("won", false):
		lines.append("A strong performance secures the victory.")
	elif match_result.get("lost", false):
		lines.append("Despite best efforts, the result didn't go our way.")
	else:
		lines.append("A hard-fought battle ends with honors even.")

	# Goals
	var goals = match_result.get("goals", 0)
	if goals > 1:
		lines.append("%s delivered a stunning performance with %d goals!" % [player_name, goals])
	elif goals == 1:
		lines.append("%s found the back of the net with a well-taken goal." % player_name)

	# Assists
	var assists = match_result.get("assists", 0)
	if assists > 1:
		lines.append("Created %d assists, showing excellent vision and creativity." % assists)
	elif assists == 1:
		lines.append("Also contributed with a key assist.")

	# Man of the Match
	if match_result.get("man_of_match", false):
		lines.append("An outstanding display earns the Man of the Match award!")

	# Rating commentary
	var rating = match_result.get("rating", 6.0)
	if rating >= 8.5:
		lines.append("A near-perfect performance that will be remembered.")
	elif rating >= 7.5:
		lines.append("An impressive showing that caught the eye of scouts.")
	elif rating < 5.5:
		lines.append("Room for improvement, but experience gained.")

	return "\n".join(lines)


func _display_reputation() -> void:
	if not reputation_label:
		return

	var rep_before = int(match_result.get("reputation_before", CareerManager.reputation))
	var rep_after = int(match_result.get("reputation_after", CareerManager.reputation))
	var rep_delta = int(match_result.get("reputation_delta", rep_after - rep_before))
	var tier_name = str(match_result.get("reputation_tier", "Unknown"))

	var delta_prefix = "+" if rep_delta > 0 else ""
	reputation_label.text = "Reputation: %s%d -> %d (%s)" % [delta_prefix, rep_delta, rep_after, tier_name]
	if rep_delta > 0:
		reputation_label.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
	elif rep_delta < 0:
		reputation_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	else:
		reputation_label.add_theme_color_override("font_color", Color(0.7, 0.78, 0.86))

	if not reputation_breakdown_label:
		return
	var breakdown = match_result.get("reputation_breakdown", [])
	reputation_breakdown_label.text = _format_reputation_breakdown(breakdown)


func _format_reputation_breakdown(breakdown: Array) -> String:
	if breakdown.is_empty():
		return "No reputation changes."

	var parts: Array[String] = []
	for entry in breakdown:
		var source = str(entry.get("source", "change"))
		var delta = int(entry.get("delta", 0))
		if delta == 0:
			continue
		var label = source.replace("_", " ").capitalize()
		var prefix = "+" if delta > 0 else ""
		parts.append("%s %s%d" % [label, prefix, delta])
		if parts.size() >= 4:
			break

	if parts.is_empty():
		return "No significant modifiers."
	return "Breakdown: " + " | ".join(parts)


func _update_season_standings() -> void:
	# Update season manager with match result
	if not SeasonManager.has_active_season():
		return

	var opponent_id = ""
	var current_match = GameManager.current_match
	if current_match:
		var opponent_team = current_match.get_opponent_team()
		if opponent_team:
			opponent_id = opponent_team.id

	var player_score = match_result.get("player_score", 0)
	var opponent_score = match_result.get("opponent_score", 0)
	var is_home = current_match.is_home if current_match else true

	# Extract goal events from match result for season tracking
	var home_goal_events = match_result.get("home_goal_events", [])
	var away_goal_events = match_result.get("away_goal_events", [])
	var player_goal_events: Array = []
	var opponent_goal_events: Array = []

	if is_home:
		player_goal_events = home_goal_events
		opponent_goal_events = away_goal_events
	else:
		player_goal_events = away_goal_events
		opponent_goal_events = home_goal_events

	# Record the result in the season manager with goal events
	var extra_time = match_result.get("extra_time", false)
	var penalties = match_result.get("penalties", false)
	var pen_player = 0
	var pen_opponent = 0
	var home_fouls = int(match_result.get("home_fouls", 0))
	var away_fouls = int(match_result.get("away_fouls", 0))

	if penalties:
		var pen_home = match_result.get("penalty_score_home", 0)
		var pen_away = match_result.get("penalty_score_away", 0)
		if is_home:
			pen_player = pen_home
			pen_opponent = pen_away
		else:
			pen_player = pen_away
			pen_opponent = pen_home

	SeasonManager.record_player_match_result(
		opponent_id, player_score, opponent_score, is_home,
		extra_time, penalties, pen_player, pen_opponent,
		player_goal_events, opponent_goal_events,
		home_fouls, away_fouls
	)

	# Simulate CPU matches for this matchday
	SeasonManager.simulate_cpu_matches_for_current_matchday()


func _roll_for_injuries() -> void:
	"""Preserve tactical injury events; simulation does not roll new post-match injuries."""
	if match_result and not match_result.has("injury_events"):
		match_result["injury_events"] = []


func _add_injury_display(player_name: String, description: String, injury_type: String) -> void:
	"""Add injury information to the milestones container."""
	var injury_label = Label.new()
	injury_label.text = "INJURY: %s - %s" % [player_name, description]
	injury_label.add_theme_color_override("font_color", InjurySystem.get_severity_color(injury_type))
	injury_label.add_theme_font_size_override("font_size", 16)
	injury_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	milestones_container.add_child(injury_label)


func _on_continue_pressed() -> void:
	AudioManager.play_ui_click()

	# Return to career hub (console dashboard)
	GameManager.change_state(GameManager.GameState.CAREER_HUB)
	get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")
