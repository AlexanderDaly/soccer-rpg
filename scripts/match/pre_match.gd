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
@onready var sim_button: Button = $MainContainer/ButtonSection/SimButton

var match_data: MatchData


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	if sim_button:
		sim_button.pressed.connect(_on_sim_pressed)

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


func _on_sim_pressed() -> void:
	AudioManager.play_ui_click()
	_simulate_match()


func _simulate_match() -> void:
	if not match_data:
		return

	var is_knockout = _is_knockout_match(match_data.match_type)
	var sim_result: Dictionary

	var context: Dictionary = {
		"importance": match_data.importance,
		"rivalry": _is_rival_team(match_data.get_opponent_team().id)
	}

	# Pull form from league standings if available
	if SeasonManager.current_season and SeasonManager.current_season.league:
		var league = SeasonManager.current_season.league
		if match_data.home_team and match_data.home_team.id in league.standings:
			context["home_form"] = league.standings[match_data.home_team.id].form
		if match_data.away_team and match_data.away_team.id in league.standings:
			context["away_form"] = league.standings[match_data.away_team.id].form

	if is_knockout:
		sim_result = MatchSimulator.simulate_knockout_match(match_data.home_team, match_data.away_team, context)
	else:
		sim_result = MatchSimulator.simulate_league_match(match_data.home_team, match_data.away_team, context)

	# Apply simulated scores
	match_data.home_score = sim_result.get("home_score", 0)
	match_data.away_score = sim_result.get("away_score", 0)
	match_data.is_extra_time = sim_result.get("extra_time", false)

	# Simulate player performance based on team goal events
	var player_team_events = sim_result.get("home_goal_events", []) if match_data.is_home else sim_result.get("away_goal_events", [])
	var player_stats = sim_result.get("home_player_stats", {}) if match_data.is_home else sim_result.get("away_player_stats", {})
	var player_line = {}
	if GameManager.player_data and player_stats.has(GameManager.player_data.id):
		player_line = player_stats[GameManager.player_data.id]
	_simulate_player_performance(player_team_events.size(), player_team_events, player_line)

	# End the match with full result payload
	var result = match_data.generate_result()
	result["home_goal_events"] = sim_result.get("home_goal_events", [])
	result["away_goal_events"] = sim_result.get("away_goal_events", [])
	result["card_events"] = sim_result.get("card_events", [])
	result["home_fouls"] = sim_result.get("home_fouls", 0)
	result["away_fouls"] = sim_result.get("away_fouls", 0)
	result["home_stats"] = sim_result.get("home_stats", {})
	result["away_stats"] = sim_result.get("away_stats", {})
	result["home_player_stats"] = sim_result.get("home_player_stats", {})
	result["away_player_stats"] = sim_result.get("away_player_stats", {})
	result["extra_time"] = sim_result.get("extra_time", false)
	result["penalties"] = sim_result.get("penalties", false)
	result["penalty_score_home"] = sim_result.get("penalty_score_home", 0)
	result["penalty_score_away"] = sim_result.get("penalty_score_away", 0)
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


func _simulate_player_performance(team_goals: int, team_goal_events: Array = [], player_line: Dictionary = {}) -> void:
	var player = GameManager.player_data
	if not player:
		return

	# Determine player contribution based on position
	var goal_chance = _get_goal_chance_for_position(player.position)
	var assist_chance = _get_assist_chance_for_position(player.position)
	var channel_multiplier = _get_player_channel_multiplier(player.position, player.dominant_foot)
	goal_chance *= channel_multiplier
	assist_chance *= channel_multiplier

	# Calculate player goals and assists
	if team_goal_events.is_empty():
		for i in range(team_goals):
			if randf() < goal_chance:
				match_data.record_event("goal", {"is_player": true})
			elif randf() < assist_chance:
				match_data.record_event("assist", {"is_player": true})
	else:
		_record_player_goal_events(team_goal_events)

	# Simulate other stats
	if player_line.has("passes_attempted"):
		match_data.player_stats.passes_attempted = int(player_line.get("passes_attempted", 0))
		match_data.player_stats.passes_completed = int(player_line.get("passes_completed", 0))
	else:
		var passes = randi_range(20, 50)
		var pass_accuracy = minf((0.7 + (player.stats.PAS / 200.0)) * channel_multiplier, 1.0)
		for i in range(passes):
			var success = randf() < pass_accuracy
			match_data.record_event("pass", {"is_player": true, "successful": success})

	var tackles = randi_range(2, 8)
	var tackle_success = 0.5 + (player.stats.DEF / 200.0)
	for i in range(tackles):
		var success = randf() < tackle_success
		match_data.record_event("tackle", {"is_player": true, "successful": success})

	var dribbles = randi_range(3, 10)
	var dribble_success = minf((0.5 + (player.stats.TEC / 200.0)) * channel_multiplier, 1.0)
	for i in range(dribbles):
		var success = randf() < dribble_success
		match_data.record_event("dribble", {"is_player": true, "successful": success})

	# Shots (if attacker/midfielder)
	if player.position in ["ST", "WNG", "CAM", "CM"]:
		var goals = match_data.player_stats.goals
		var shots = max(randi_range(1, 5), goals)
		for i in range(shots):
			var on_target = i < goals or randf() < minf((0.4 + player.stats.SHO / 300.0) * channel_multiplier, 1.0)
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


func _record_player_goal_events(team_goal_events: Array) -> void:
	var player = GameManager.player_data
	if not player:
		return

	for event in team_goal_events:
		var minute = int(event.get("minute", 0))
		if minute > 0:
			match_data.current_minute = minute
		if event.get("scorer_id", "") == player.id:
			match_data.record_event("goal", {"is_player": true})
		if event.get("assister_id", "") == player.id:
			match_data.record_event("assist", {"is_player": true})


func _get_player_channel_multiplier(position: String, foot: String) -> float:
	if foot == "both":
		return 1.02
	if position not in ["FB", "WNG", "CAM", "CM", "ST"]:
		return 1.0

	var preferred_side = CareerManager.get_player_channel_side()
	if preferred_side == "center":
		return 1.0
	if foot == preferred_side:
		return 1.1
	return 0.9


func _is_knockout_match(match_type: String) -> bool:
	return match_type in [
		"cup",
		"qualifier",
		"prefecture_qualifier",
		"prefecture_qualifier_final",
		"national_championship",
		"national_quarter_final",
		"national_semi_final",
		"national_final",
		"world_cup",
		"world_cup_final"
	]


func _is_rival_team(team_id: String) -> bool:
	if team_id == "":
		return false

	# Check known rival NPCs for matching team
	var known_rivals = NpcRegistry.get_known_rivals()
	for npc in known_rivals:
		if npc.get("stable_team_id", "") == team_id or npc.get("team_id", "") == team_id:
			return true

	# Check explicit career rivals if defined
	for rival in CareerManager.rivals:
		if rival.get("team_id", "") == team_id or rival.get("stable_team_id", "") == team_id:
			return true

	return false
