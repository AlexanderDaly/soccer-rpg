extends Control
class_name PostMatchScreen
## PostMatchScreen - Displays match results and player performance

@onready var result_label: Label = $MainContainer/ResultSection/ResultLabel
@onready var score_label: Label = $MainContainer/ResultSection/ScoreLabel
@onready var opponent_label: Label = $MainContainer/ResultSection/OpponentLabel

@onready var rating_label: Label = $MainContainer/PerformanceSection/RatingContainer/RatingValue
@onready var goals_label: Label = $MainContainer/PerformanceSection/StatsGrid/GoalsValue
@onready var assists_label: Label = $MainContainer/PerformanceSection/StatsGrid/AssistsValue
@onready var shots_label: Label = $MainContainer/PerformanceSection/StatsGrid/ShotsValue
@onready var passes_label: Label = $MainContainer/PerformanceSection/StatsGrid/PassesValue
@onready var tackles_label: Label = $MainContainer/PerformanceSection/StatsGrid/TacklesValue
@onready var dribbles_label: Label = $MainContainer/PerformanceSection/StatsGrid/DribblesValue

@onready var xp_gained_label: Label = $MainContainer/RewardsSection/XPGained
@onready var milestones_container: VBoxContainer = $MainContainer/RewardsSection/MilestonesContainer

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
		_display_result()
		_update_season_standings()


func _display_result() -> void:
	# Result header
	if match_result.get("won", false):
		result_label.text = "VICTORY!"
		result_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	elif match_result.get("lost", false):
		result_label.text = "DEFEAT"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	else:
		result_label.text = "DRAW"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.2))

	# Score
	var player_score = match_result.get("player_score", 0)
	var opponent_score = match_result.get("opponent_score", 0)
	score_label.text = "%d - %d" % [player_score, opponent_score]

	# Opponent name
	opponent_label.text = "vs %s" % match_result.get("opponent_name", "Unknown")

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

	# Man of the Match
	if match_result.get("man_of_match", false):
		_add_achievement("Man of the Match!")

	# Cards
	if match_result.get("yellow_cards", 0) > 0:
		_add_card_display(match_result.yellow_cards, false)
	if match_result.get("red_card", false):
		_add_card_display(1, true)

	# Generate narrative
	_display_narrative()


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


func _calculate_xp_display() -> int:
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

	# Record the result in the season manager
	SeasonManager.record_player_match_result(opponent_id, player_score, opponent_score, is_home)

	# Simulate CPU matches for this matchday
	SeasonManager.simulate_cpu_matches_for_current_matchday()


func _on_continue_pressed() -> void:
	AudioManager.play_ui_click()

	# Return to career hub (console dashboard)
	GameManager.change_state(GameManager.GameState.CAREER_HUB)
	get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")
