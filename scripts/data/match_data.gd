extends Resource
class_name MatchData
## MatchData - Stores all data for a single match

const TacticalMatchRules = preload("res://scripts/match/tactical/tactical_match_rules.gd")

@export var id: String = ""
@export var match_type: String = ""  # friendly, league, cup, qualifier, world_cup
@export var importance: float = 1.0  # Multiplier for XP/reputation gains
@export var competition_name: String = ""
@export var competition_key: String = ""

# Teams
@export var home_team: TeamData
@export var away_team: TeamData
@export var is_home: bool = true
@export var player_position: String = ""

# Match state
@export var current_half: int = 1
@export var current_minute: int = 0
@export var is_extra_time: bool = false
@export var did_not_play: bool = false
@export var absence_reason: String = ""
@export var absence_detail: String = ""

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

const BASE_MATCH_RATING := 6.0

# Position-aware match rating profiles. The shared component scores are
# weighted differently so roles are judged on the work they are expected to do.
const MATCH_RATING_PROFILES := {
	"GK": {
		"finishing": 0.0,
		"creation": 0.30,
		"defense": 1.25,
		"carry": 0.0,
		"clean_sheet_bonus": 0.90,
		"conceded_penalty": 0.40,
		"win_bonus": 0.25,
		"draw_bonus": 0.10,
		"loss_penalty": 0.20
	},
	"CB": {
		"finishing": 0.05,
		"creation": 0.25,
		"defense": 1.15,
		"carry": 0.05,
		"clean_sheet_bonus": 0.70,
		"conceded_penalty": 0.30,
		"win_bonus": 0.25,
		"draw_bonus": 0.05,
		"loss_penalty": 0.20
	},
	"FB": {
		"finishing": 0.15,
		"creation": 0.50,
		"defense": 0.90,
		"carry": 0.30,
		"clean_sheet_bonus": 0.50,
		"conceded_penalty": 0.22,
		"win_bonus": 0.30,
		"draw_bonus": 0.05,
		"loss_penalty": 0.20
	},
	"CDM": {
		"finishing": 0.10,
		"creation": 0.65,
		"defense": 0.95,
		"carry": 0.15,
		"clean_sheet_bonus": 0.45,
		"conceded_penalty": 0.18,
		"win_bonus": 0.30,
		"draw_bonus": 0.05,
		"loss_penalty": 0.20
	},
	"CM": {
		"finishing": 0.25,
		"creation": 0.90,
		"defense": 0.55,
		"carry": 0.35,
		"clean_sheet_bonus": 0.20,
		"conceded_penalty": 0.10,
		"win_bonus": 0.30,
		"draw_bonus": 0.05,
		"loss_penalty": 0.20
	},
	"CAM": {
		"finishing": 0.45,
		"creation": 1.00,
		"defense": 0.15,
		"carry": 0.40,
		"clean_sheet_bonus": 0.05,
		"conceded_penalty": 0.06,
		"win_bonus": 0.30,
		"draw_bonus": 0.05,
		"loss_penalty": 0.22
	},
	"WNG": {
		"finishing": 0.70,
		"creation": 0.70,
		"defense": 0.10,
		"carry": 0.65,
		"clean_sheet_bonus": 0.0,
		"conceded_penalty": 0.05,
		"win_bonus": 0.35,
		"draw_bonus": 0.05,
		"loss_penalty": 0.22
	},
	"ST": {
		"finishing": 0.95,
		"creation": 0.30,
		"defense": 0.05,
		"carry": 0.45,
		"clean_sheet_bonus": 0.0,
		"conceded_penalty": 0.04,
		"win_bonus": 0.35,
		"draw_bonus": 0.05,
		"loss_penalty": 0.25
	}
}


func setup(player_team: TeamData, opponent_team: TeamData, type: String, player_is_home: bool = true) -> void:
	id = "match_%d" % randi()
	match_type = type
	importance = _calculate_importance(type)
	player_position = GameManager.player_data.position if GameManager.player_data else "CM"

	# Set home/away based on fixture (or random if not specified)
	is_home = player_is_home

	if is_home:
		home_team = player_team
		away_team = opponent_team
	else:
		home_team = opponent_team
		away_team = player_team

	var next_fixture = SeasonManager.get_next_fixture() if SeasonManager and SeasonManager.has_method("get_next_fixture") else {}
	competition_name = str(next_fixture.get("competition", ""))
	if competition_name.is_empty() and SeasonManager and SeasonManager.has_method("get_current_competition_name"):
		competition_name = str(SeasonManager.get_current_competition_name())
	competition_key = TacticalMatchRules.build_competition_key(self)
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
		"prefecture_qualifier":
			return 1.5
		"prefecture_qualifier_final":
			return 2.0
		"national_championship":
			return 1.8
		"national_quarter_final":
			return 2.0
		"national_semi_final":
			return 2.5
		"national_final":
			return 3.0
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
	var profile = _get_match_rating_profile()
	var rating = BASE_MATCH_RATING

	rating += _calculate_finishing_component() * float(profile.get("finishing", 0.0))
	rating += _calculate_creation_component() * float(profile.get("creation", 0.0))
	rating += _calculate_defense_component() * float(profile.get("defense", 0.0))
	rating += _calculate_carry_component() * float(profile.get("carry", 0.0))
	rating += _calculate_result_adjustment(profile)
	rating += _calculate_discipline_adjustment()
	rating += _calculate_goal_prevention_adjustment(profile)

	player_stats.rating = clampf(rating, 1.0, 10.0)
	return player_stats.rating


func _get_match_rating_profile() -> Dictionary:
	var position = _get_player_position()
	return MATCH_RATING_PROFILES.get(position, MATCH_RATING_PROFILES["CM"])


func _get_player_position() -> String:
	if not player_position.is_empty():
		return player_position
	if GameManager.player_data:
		return GameManager.player_data.position
	return "CM"


func _calculate_finishing_component() -> float:
	var score := float(player_stats.goals) * 1.15
	score += float(player_stats.assists) * 0.20

	if player_stats.shots > 0:
		var accuracy = float(player_stats.shots_on_target) / player_stats.shots
		score += float(player_stats.shots_on_target) * 0.12
		score += (accuracy - 0.35) * 0.70
		score += minf(float(player_stats.shots) / 5.0, 1.0) * 0.15

	return score


func _calculate_creation_component() -> float:
	var score := float(player_stats.assists) * 0.80

	if player_stats.passes_attempted > 0:
		var pass_rate = float(player_stats.passes_completed) / player_stats.passes_attempted
		score += (pass_rate - 0.72) * 1.40
		score += minf(float(player_stats.passes_completed) / 35.0, 1.0) * 0.35

	score += minf(float(player_stats.fouls_received) / 3.0, 1.0) * 0.10
	return score


func _calculate_defense_component() -> float:
	var score := 0.0

	if player_stats.tackles_attempted > 0:
		var tackle_rate = float(player_stats.tackles_won) / player_stats.tackles_attempted
		score += (tackle_rate - 0.55) * 0.90
		score += minf(float(player_stats.tackles_won) / 5.0, 1.0) * 0.55

	return score


func _calculate_carry_component() -> float:
	var score := 0.0

	if player_stats.dribbles_attempted > 0:
		var dribble_rate = float(player_stats.dribbles_completed) / player_stats.dribbles_attempted
		score += (dribble_rate - 0.55) * 0.70
		score += minf(float(player_stats.dribbles_completed) / 5.0, 1.0) * 0.40

	return score


func _calculate_result_adjustment(profile: Dictionary) -> float:
	if is_winning():
		return float(profile.get("win_bonus", 0.0))
	if is_draw():
		return float(profile.get("draw_bonus", 0.0))
	return -float(profile.get("loss_penalty", 0.0))


func _calculate_discipline_adjustment() -> float:
	var adjustment := -float(player_stats.yellow_cards) * 0.45
	adjustment -= float(player_stats.fouls_committed) * 0.08

	if player_stats.red_card:
		adjustment -= 2.25

	return adjustment


func _calculate_goal_prevention_adjustment(profile: Dictionary) -> float:
	var adjustment := 0.0

	if get_opponent_score() == 0:
		adjustment += float(profile.get("clean_sheet_bonus", 0.0))

	adjustment -= float(get_opponent_score()) * float(profile.get("conceded_penalty", 0.0))
	return adjustment


func generate_result() -> Dictionary:
	calculate_match_rating()

	var foul_counts = _count_team_fouls()
	
	return {
		"match_id": id,
		"match_type": match_type,
		"competition_name": competition_name,
		"competition_key": competition_key,
		"importance": importance,
		"opponent_name": get_opponent_team().name,
		"did_not_play": did_not_play,
		"absence_reason": absence_reason,
		"absence_detail": absence_detail,
		
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

		# Team fouls
		"home_fouls": foul_counts.home,
		"away_fouls": foul_counts.away,
		
		# Events
		"key_events": _get_key_events(),
		"card_events": _get_card_events(),
		"injury_events": _get_injury_events()
	}


func _get_key_events() -> Array[Dictionary]:
	var key_types = ["goal", "assist", "yellow_card", "red_card", "penalty", "own_goal"]
	var key_events: Array[Dictionary] = []
	
	for event in events:
		if event.type in key_types:
			key_events.append(event)
	
	return key_events


func _count_team_fouls() -> Dictionary:
	var home_fouls = 0
	var away_fouls = 0

	for event in events:
		if event.type != "foul_committed":
			continue

		var data = event.get("data", {})
		if data.has("is_home_team"):
			if data.is_home_team:
				home_fouls += 1
			else:
				away_fouls += 1
		elif data.has("team_id"):
			if data.team_id == home_team.id:
				home_fouls += 1
			elif data.team_id == away_team.id:
				away_fouls += 1

	return {"home": home_fouls, "away": away_fouls}


func _get_card_events() -> Array[Dictionary]:
	var card_events: Array[Dictionary] = []
	for event in events:
		var event_type = str(event.get("type", ""))
		if event_type not in ["yellow_card", "red_card"]:
			continue
		var data = event.get("data", {})
		card_events.append({
			"minute": int(event.get("minute", 0)),
			"team_id": str(data.get("team_id", "")),
			"team_name": str(data.get("team_name", "")),
			"player_id": str(data.get("player_id", "")),
			"player_name": str(data.get("player_name", "")),
			"card_color": "red" if event_type == "red_card" else "yellow",
			"dismissal_reason": str(data.get("dismissal_reason", ""))
		})
	return card_events


func _get_injury_events() -> Array[Dictionary]:
	var injury_events: Array[Dictionary] = []
	for event in events:
		if str(event.get("type", "")) != "injury":
			continue
		var data = event.get("data", {})
		var injury_event = data.duplicate(true)
		injury_event["minute"] = int(event.get("minute", 0))
		injury_events.append(injury_event)
	return injury_events


func to_dict() -> Dictionary:
	return {
		"id": id,
		"match_type": match_type,
		"competition_name": competition_name,
		"competition_key": competition_key,
		"importance": importance,
		"is_home": is_home,
		"player_position": player_position,
		"current_half": current_half,
		"current_minute": current_minute,
		"is_extra_time": is_extra_time,
		"did_not_play": did_not_play,
		"absence_reason": absence_reason,
		"absence_detail": absence_detail,
		"home_score": home_score,
		"away_score": away_score,
		"player_stats": player_stats,
		"events": events
	}
