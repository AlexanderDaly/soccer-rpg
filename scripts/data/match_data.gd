extends Resource
class_name MatchData
## MatchData - Stores all data for a single match

@export var id: String = ""
@export var match_type: String = ""  # friendly, league, cup, qualifier, world_cup
@export var importance: float = 1.0  # Multiplier for XP/reputation gains

# Teams
@export var home_team: TeamData
@export var away_team: TeamData
@export var is_home: bool = true

# Match state
@export var current_half: int = 1
@export var current_minute: int = 0
@export var is_extra_time: bool = false

# Score
@export var home_score: int = 0
@export var away_score: int = 0

# Player performance tracking
@export var player_stats: Dictionary = {
	"goals": 0,
	"assists": 0,
	"shots": 0,
	"shots_on_target": 0,
	"passes_attempted": 0,
	"passes_completed": 0,
	"tackles_attempted": 0,
	"tackles_won": 0,
	"dribbles_attempted": 0,
	"dribbles_completed": 0,
	"fouls_committed": 0,
	"fouls_received": 0,
	"yellow_cards": 0,
	"red_card": false,
	"distance_covered": 0,
	"sprints": 0,
	"rating": 6.0  # Match rating 1-10
}

# Match events log
@export var events: Array[Dictionary] = []

# Tactical grid state (for turn-based system)
@export var grid_state: Dictionary = {}


func setup(player_team: TeamData, opponent_team: TeamData, type: String) -> void:
	id = "match_%d" % randi()
	match_type = type
	importance = _calculate_importance(type)
	
	# Randomly determine home/away
	is_home = randf() > 0.5
	
	if is_home:
		home_team = player_team
		away_team = opponent_team
	else:
		home_team = opponent_team
		away_team = player_team
	
	_initialize_grid()


func _calculate_importance(type: String) -> float:
	match type:
		"friendly":
			return 0.5
		"league":
			return 1.0
		"cup":
			return 1.5
		"qualifier":
			return 1.8
		"world_cup":
			return 2.5
		"world_cup_final":
			return 3.0
		_:
			return 1.0


func _initialize_grid() -> void:
	# Initialize the tactical grid for turn-based gameplay
	# Standard pitch is approximately 105m x 68m
	# Using a hex grid with ~5m hexes = 21 x 14 grid
	grid_state = {
		"width": 21,
		"height": 14,
		"ball_position": Vector2i(10, 7),  # Center
		"player_positions": {},
		"current_phase": "kickoff"  # kickoff, attack, defend, set_piece
	}


func record_event(event_type: String, data: Dictionary = {}) -> void:
	var event = {
		"type": event_type,
		"minute": current_minute,
		"half": current_half,
		"data": data,
		"timestamp": Time.get_unix_time_from_system()
	}
	events.append(event)
	
	# Update player stats based on event type
	_update_stats_from_event(event_type, data)


func _update_stats_from_event(event_type: String, data: Dictionary) -> void:
	var is_player_action = data.get("is_player", false)
	
	if not is_player_action:
		return
	
	match event_type:
		"goal":
			player_stats.goals += 1
			# Note: shots and shots_on_target are tracked by the "shot" event
		"assist":
			player_stats.assists += 1
		"shot":
			player_stats.shots += 1
			if data.get("on_target", false):
				player_stats.shots_on_target += 1
		"pass":
			player_stats.passes_attempted += 1
			if data.get("successful", false):
				player_stats.passes_completed += 1
		"tackle":
			player_stats.tackles_attempted += 1
			if data.get("successful", false):
				player_stats.tackles_won += 1
		"dribble":
			player_stats.dribbles_attempted += 1
			if data.get("successful", false):
				player_stats.dribbles_completed += 1
		"foul_committed":
			player_stats.fouls_committed += 1
		"foul_received":
			player_stats.fouls_received += 1
		"yellow_card":
			player_stats.yellow_cards += 1
		"red_card":
			player_stats.red_card = true


func advance_time(minutes: int) -> void:
	current_minute += minutes
	
	# Check for half time
	if current_minute >= 45 and current_half == 1:
		current_half = 2
		current_minute = 45
		record_event("half_time")
	
	# Check for full time
	if current_minute >= 90 and current_half == 2:
		if not is_extra_time:
			record_event("full_time")


func get_player_team() -> TeamData:
	return home_team if is_home else away_team


func get_opponent_team() -> TeamData:
	return away_team if is_home else home_team


func get_player_score() -> int:
	return home_score if is_home else away_score


func get_opponent_score() -> int:
	return away_score if is_home else home_score


func is_winning() -> bool:
	return get_player_score() > get_opponent_score()


func is_losing() -> bool:
	return get_player_score() < get_opponent_score()


func is_draw() -> bool:
	return get_player_score() == get_opponent_score()


func calculate_match_rating() -> float:
	# Calculate player's match rating based on performance
	var rating = 6.0  # Base rating
	
	# Goals and assists are heavily weighted
	rating += player_stats.goals * 0.8
	rating += player_stats.assists * 0.5
	
	# Pass completion rate
	if player_stats.passes_attempted > 0:
		var pass_rate = float(player_stats.passes_completed) / player_stats.passes_attempted
		rating += (pass_rate - 0.7) * 2.0  # Bonus/penalty vs 70% baseline
	
	# Tackle success
	if player_stats.tackles_attempted > 0:
		var tackle_rate = float(player_stats.tackles_won) / player_stats.tackles_attempted
		rating += (tackle_rate - 0.5) * 1.0
	
	# Shots on target
	if player_stats.shots > 0:
		var accuracy = float(player_stats.shots_on_target) / player_stats.shots
		rating += accuracy * 0.5
	
	# Penalties
	rating -= player_stats.yellow_cards * 0.5
	if player_stats.red_card:
		rating -= 2.0
	
	# Team result bonus/penalty
	if is_winning():
		rating += 0.5
	elif is_losing():
		rating -= 0.3
	
	# Clamp to valid range
	player_stats.rating = clampf(rating, 1.0, 10.0)
	return player_stats.rating


func generate_result() -> Dictionary:
	calculate_match_rating()
	
	return {
		"match_id": id,
		"match_type": match_type,
		"importance": importance,
		"opponent_name": get_opponent_team().name,
		
		# Result
		"won": is_winning(),
		"lost": is_losing(),
		"draw": is_draw(),
		"player_score": get_player_score(),
		"opponent_score": get_opponent_score(),
		
		# Player performance
		"goals": player_stats.goals,
		"assists": player_stats.assists,
		"rating": player_stats.rating,
		"man_of_match": player_stats.rating >= 8.5,
		"clean_sheet": get_opponent_score() == 0,
		
		# Detailed stats
		"shots": player_stats.shots,
		"shots_on_target": player_stats.shots_on_target,
		"successful_passes": player_stats.passes_completed,
		"successful_tackles": player_stats.tackles_won,
		"successful_dribbles": player_stats.dribbles_completed,
		"distance_covered": player_stats.distance_covered,
		
		# Cards
		"yellow_cards": player_stats.yellow_cards,
		"red_card": player_stats.red_card,
		
		# Events
		"key_events": _get_key_events()
	}


func _get_key_events() -> Array[Dictionary]:
	var key_types = ["goal", "assist", "yellow_card", "red_card", "penalty", "own_goal"]
	var key_events: Array[Dictionary] = []
	
	for event in events:
		if event.type in key_types:
			key_events.append(event)
	
	return key_events


func to_dict() -> Dictionary:
	return {
		"id": id,
		"match_type": match_type,
		"importance": importance,
		"is_home": is_home,
		"current_half": current_half,
		"current_minute": current_minute,
		"home_score": home_score,
		"away_score": away_score,
		"player_stats": player_stats,
		"events": events
	}
