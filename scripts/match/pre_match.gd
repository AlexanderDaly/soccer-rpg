extends Control
class_name PreMatchScreen
## PreMatchScreen - Displays match preview before playing

@onready var home_team_name: Label = $MainContainer/MatchupSection/HomeTeam/TeamName
@onready var home_team_overall: Label = $MainContainer/MatchupSection/HomeTeam/TeamOverall
@onready var home_team_formation: Label = $MainContainer/MatchupSection/HomeTeam/Formation
@onready var home_lineup_container: VBoxContainer = $MainContainer/LineupsSection/HomeLineup/PlayerList

@onready var away_team_name: Label = $MainContainer/MatchupSection/AwayTeam/TeamName
@onready var away_team_overall: Label = $MainContainer/MatchupSection/AwayTeam/TeamOverall
@onready var away_team_formation: Label = $MainContainer/MatchupSection/AwayTeam/Formation
@onready var away_lineup_container: VBoxContainer = $MainContainer/LineupsSection/AwayLineup/PlayerList

@onready var match_type_label: Label = $MainContainer/MatchInfoSection/MatchType
@onready var importance_label: Label = $MainContainer/MatchInfoSection/Importance

@onready var play_button: Button = $MainContainer/ButtonSection/PlayButton

var match_data: MatchData


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)

	if GameManager.current_match:
		_setup_match_display(GameManager.current_match)


func _setup_match_display(data: MatchData) -> void:
	match_data = data

	# Home team info
	home_team_name.text = data.home_team.name
	home_team_overall.text = "OVR: %d" % data.home_team.get_average_overall()
	home_team_formation.text = data.home_team.formation

	# Away team info
	away_team_name.text = data.away_team.name
	away_team_overall.text = "OVR: %d" % data.away_team.get_average_overall()
	away_team_formation.text = data.away_team.formation

	# Match info
	match_type_label.text = _get_match_type_display(data.match_type)
	importance_label.text = _get_importance_display(data.importance)

	# Populate lineups
	_populate_lineup(home_lineup_container, data.home_team, data.is_home)
	_populate_lineup(away_lineup_container, data.away_team, not data.is_home)


func _get_match_type_display(match_type: String) -> String:
	match match_type:
		"friendly":
			return "Friendly Match"
		"league":
			return "League Match"
		"cup":
			return "Cup Match"
		"qualifier":
			return "Qualifier"
		"world_cup":
			return "World Cup"
		"world_cup_final":
			return "World Cup Final"
		_:
			return match_type.capitalize()


func _get_importance_display(importance: float) -> String:
	if importance >= 2.5:
		return "CRUCIAL"
	elif importance >= 1.5:
		return "High Stakes"
	elif importance >= 1.0:
		return "Standard"
	else:
		return "Low Stakes"


func _populate_lineup(container: VBoxContainer, team: TeamData, is_player_team: bool) -> void:
	# Clear existing
	for child in container.get_children():
		child.queue_free()

	var starting_eleven = team.get_starting_eleven()

	for player in starting_eleven:
		var player_row = HBoxContainer.new()
		player_row.add_theme_constant_override("separation", 10)

		# Position label
		var pos_label = Label.new()
		pos_label.text = player.position
		pos_label.custom_minimum_size = Vector2(40, 0)
		pos_label.add_theme_font_size_override("font_size", 14)
		player_row.add_child(pos_label)

		# Name label
		var name_label = Label.new()
		name_label.text = player.name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 14)

		# Highlight player character
		if player.get("is_player", false):
			name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Gold
			name_label.text = player.name + " (YOU)"

		player_row.add_child(name_label)

		# Overall label
		var ovr_label = Label.new()
		ovr_label.text = str(player.overall)
		ovr_label.custom_minimum_size = Vector2(30, 0)
		ovr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ovr_label.add_theme_font_size_override("font_size", 14)
		player_row.add_child(ovr_label)

		container.add_child(player_row)


func _on_play_pressed() -> void:
	AudioManager.play_ui_click()

	# Launch tactical match
	GameManager.change_state(GameManager.GameState.IN_MATCH)
	get_tree().change_scene_to_file("res://scenes/match/tactical/tactical_match.tscn")


func _simulate_match() -> void:
	# Simple match simulation based on team strengths
	var player_team = match_data.get_player_team()
	var opponent_team = match_data.get_opponent_team()

	var player_strength = player_team.get_average_overall()
	var opponent_strength = opponent_team.get_average_overall()

	# Calculate expected goals based on team strength difference
	var strength_diff = (player_strength - opponent_strength) / 20.0

	var player_expected_goals = 1.5 + strength_diff + randf() * 1.5
	var opponent_expected_goals = 1.5 - strength_diff + randf() * 1.5

	# Generate actual goals with some randomness
	var player_goals = _generate_goals(player_expected_goals)
	var opponent_goals = _generate_goals(opponent_expected_goals)

	# Set scores
	if match_data.is_home:
		match_data.home_score = player_goals
		match_data.away_score = opponent_goals
	else:
		match_data.home_score = opponent_goals
		match_data.away_score = player_goals

	# Simulate player performance
	_simulate_player_performance(player_goals)

	# End the match
	var result = match_data.generate_result()
	GameManager.end_match(result)

	# Transition to post-match screen
	get_tree().change_scene_to_file("res://scenes/match/post_match.tscn")


func _generate_goals(expected: float) -> int:
	# Poisson-like distribution around expected value
	var goals = 0
	var probability = exp(-expected)
	var cumulative = probability
	var random_value = randf()

	while cumulative < random_value and goals < 10:
		goals += 1
		probability *= expected / goals
		cumulative += probability

	return goals


func _simulate_player_performance(team_goals: int) -> void:
	var player = GameManager.player_data
	if not player:
		return

	# Determine player contribution based on position
	var goal_chance = _get_goal_chance_for_position(player.position)
	var assist_chance = _get_assist_chance_for_position(player.position)

	# Calculate player goals and assists
	for i in range(team_goals):
		if randf() < goal_chance:
			match_data.record_event("goal", {"is_player": true})
		elif randf() < assist_chance:
			match_data.record_event("assist", {"is_player": true})

	# Simulate other stats
	var passes = randi_range(20, 50)
	var pass_accuracy = 0.7 + (player.stats.PAS / 200.0)
	for i in range(passes):
		var success = randf() < pass_accuracy
		match_data.record_event("pass", {"is_player": true, "successful": success})

	var tackles = randi_range(2, 8)
	var tackle_success = 0.5 + (player.stats.DEF / 200.0)
	for i in range(tackles):
		var success = randf() < tackle_success
		match_data.record_event("tackle", {"is_player": true, "successful": success})

	var dribbles = randi_range(3, 10)
	var dribble_success = 0.5 + (player.stats.TEC / 200.0)
	for i in range(dribbles):
		var success = randf() < dribble_success
		match_data.record_event("dribble", {"is_player": true, "successful": success})

	# Shots (if attacker/midfielder)
	if player.position in ["ST", "WNG", "CAM", "CM"]:
		var shots = randi_range(1, 5)
		for i in range(shots):
			var on_target = randf() < (0.4 + player.stats.SHO / 300.0)
			match_data.record_event("shot", {"is_player": true, "on_target": on_target})

	# Small chance of cards
	if randf() < 0.1:
		match_data.record_event("yellow_card", {"is_player": true})


func _get_goal_chance_for_position(position: String) -> float:
	match position:
		"ST":
			return 0.4
		"WNG", "CAM":
			return 0.25
		"CM":
			return 0.15
		"CDM", "FB":
			return 0.08
		"CB":
			return 0.05
		"GK":
			return 0.01
		_:
			return 0.1


func _get_assist_chance_for_position(position: String) -> float:
	match position:
		"CAM", "WNG":
			return 0.35
		"CM":
			return 0.3
		"ST":
			return 0.2
		"FB":
			return 0.2
		"CDM":
			return 0.15
		"CB":
			return 0.08
		"GK":
			return 0.02
		_:
			return 0.15
