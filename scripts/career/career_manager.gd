extends Node
## CareerManager - Handles career progression, milestones, and reputation
## Tracks the player's journey from high school to professional career

signal reputation_changed(new_reputation: int)
signal milestone_reached(milestone: String)
signal scout_interest(scout_data: Dictionary)
signal contract_offer_received(offer: Dictionary)

# Career statistics
var match_history: Array[Dictionary] = []
var career_stats: Dictionary = {
	"matches_played": 0,
	"goals": 0,
	"assists": 0,
	"clean_sheets": 0,
	"man_of_match_awards": 0,
	"trophies": [],
	"current_season": 1
}

# Reputation system (0-100)
var reputation: int = 10  # Start as unknown high schooler
var scout_attention: Dictionary = {}  # team_id -> interest level
var media_coverage: int = 0
var fan_popularity: int = 0

# Milestones tracking
var completed_milestones: Array[String] = []
const MILESTONES = {
	"first_goal": {"name": "First Goal", "description": "Score your first career goal"},
	"first_assist": {"name": "First Assist", "description": "Record your first assist"},
	"first_motm": {"name": "Star Player", "description": "Win your first Man of the Match award"},
	"ten_goals": {"name": "Rising Striker", "description": "Score 10 career goals"},
	"prefecture_league_champion": {"name": "League Champion", "description": "Win your prefecture league"},
	"prefecture_qualifier_winner": {"name": "Prefecture Champion", "description": "Win the prefecture qualifier tournament"},
	"national_participant": {"name": "National Stage", "description": "Qualify for the National Championship"},
	"national_quarter_finalist": {"name": "National Contender", "description": "Reach the quarter-finals at nationals"},
	"national_semi_finalist": {"name": "Final Four", "description": "Reach the semi-finals at nationals"},
	"national_finalist": {"name": "Grand Finalist", "description": "Reach the National Championship final"},
	"national_champion": {"name": "National Champion", "description": "Win the National High School Championship"},
	"u20_callup": {"name": "International Call-up", "description": "Get selected for the U20 national team"},
	"u20_debut": {"name": "International Debut", "description": "Play your first U20 international match"},
	"world_cup_goal": {"name": "World Cup Hero", "description": "Score in the U20 World Cup"},
	"first_pro_contract": {"name": "Professional", "description": "Sign your first professional contract"}
}

# Rival tracking
var rivals: Array[Dictionary] = []
var rival_encounters: Dictionary = {}  # rival_id -> encounter history


func _ready() -> void:
	print("[CareerManager] Initialized")


func record_match_result(result: Dictionary) -> void:
	match_history.append(result)
	
	# Update career stats
	career_stats.matches_played += 1
	career_stats.goals += result.get("goals", 0)
	career_stats.assists += result.get("assists", 0)
	
	if result.get("clean_sheet", false):
		career_stats.clean_sheets += 1
	
	if result.get("man_of_match", false):
		career_stats.man_of_match_awards += 1
	
	# Check for milestones
	_check_milestones(result)
	
	# Update reputation
	_update_reputation(result)
	
	# Check for scout interest
	_check_scout_interest(result)


func _check_milestones(result: Dictionary) -> void:
	if "first_goal" not in completed_milestones and career_stats.goals > 0:
		_complete_milestone("first_goal")
	
	if "first_assist" not in completed_milestones and career_stats.assists > 0:
		_complete_milestone("first_assist")
	
	if "first_motm" not in completed_milestones and career_stats.man_of_match_awards > 0:
		_complete_milestone("first_motm")
	
	if "ten_goals" not in completed_milestones and career_stats.goals >= 10:
		_complete_milestone("ten_goals")


func _complete_milestone(milestone_id: String) -> void:
	if milestone_id in MILESTONES and milestone_id not in completed_milestones:
		completed_milestones.append(milestone_id)
		print("[CareerManager] Milestone reached: %s" % MILESTONES[milestone_id].name)
		milestone_reached.emit(milestone_id)
		
		# Milestones boost reputation
		_add_reputation(5)


func _update_reputation(result: Dictionary) -> void:
	var rep_change = 0
	
	# Performance-based reputation gains
	rep_change += result.get("goals", 0) * 2
	rep_change += result.get("assists", 0) * 1
	
	if result.get("man_of_match", false):
		rep_change += 5
	
	if result.get("won", false):
		rep_change += 1
	elif result.get("lost", false):
		rep_change -= 1
	
	# Scale by match importance
	var importance_multiplier = result.get("importance", 1.0)
	rep_change = roundi(rep_change * importance_multiplier)
	
	_add_reputation(rep_change)


func _add_reputation(amount: int) -> void:
	var old_rep = reputation
	reputation = clampi(reputation + amount, 0, 100)
	
	if reputation != old_rep:
		reputation_changed.emit(reputation)


func _check_scout_interest(result: Dictionary) -> void:
	# Only scouts watch if reputation is high enough
	if reputation < 20:
		return
	
	# Chance of scout attendance based on reputation and match importance
	var scout_chance = (reputation / 100.0) * result.get("importance", 1.0)
	
	if randf() < scout_chance:
		var scout = _generate_scout()
		
		# Scout evaluates performance
		var impression = _calculate_scout_impression(result)
		scout_attention[scout.team_id] = scout_attention.get(scout.team_id, 0) + impression
		
		scout_interest.emit(scout)


func _generate_scout() -> Dictionary:
	# Generate a scout from a team based on career phase
	var phase = GameManager.current_career_phase
	var teams = _get_scouting_teams(phase)
	var team = teams[randi() % teams.size()]
	
	return {
		"team_id": team.id,
		"team_name": team.name,
		"scout_name": _generate_scout_name(),
		"league": team.league
	}


func _get_scouting_teams(phase: GameManager.CareerPhase) -> Array:
	# Return appropriate teams for the career phase
	# This would load from resources in full implementation
	match phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			return [
				{"id": "youth_academy_1", "name": "Metro Youth Academy", "league": "Youth"},
				{"id": "youth_academy_2", "name": "Elite Development Center", "league": "Youth"}
			]
		GameManager.CareerPhase.YOUTH_ACADEMY, GameManager.CareerPhase.U20_QUALIFIERS:
			return [
				{"id": "div2_team_1", "name": "City United", "league": "Division 2"},
				{"id": "div1_team_1", "name": "Capital FC", "league": "Division 1"}
			]
		_:
			return [
				{"id": "top_team_1", "name": "Royal Athletic", "league": "Premier"},
				{"id": "top_team_2", "name": "United Stars", "league": "Premier"}
			]


func _generate_scout_name() -> String:
	var first_names = ["Kenji", "Takeshi", "Yuki", "Hiroshi", "Marcus", "David", "Miguel"]
	var last_names = ["Tanaka", "Yamamoto", "Suzuki", "Watanabe", "Schmidt", "Martinez", "Silva"]
	return "%s %s" % [first_names[randi() % first_names.size()], last_names[randi() % last_names.size()]]


func _calculate_scout_impression(result: Dictionary) -> int:
	var impression = 0
	impression += result.get("goals", 0) * 10
	impression += result.get("assists", 0) * 7
	impression += result.get("successful_passes", 0) / 5
	impression += result.get("successful_tackles", 0) * 3
	
	if result.get("man_of_match", false):
		impression += 20
	
	return impression


func generate_contract_offer(team_id: String) -> Dictionary:
	var interest = scout_attention.get(team_id, 0)
	
	if interest < 30:
		return {}  # Not enough interest
	
	var offer = {
		"team_id": team_id,
		"salary": _calculate_offer_salary(interest),
		"duration_years": randi_range(1, 3),
		"signing_bonus": _calculate_signing_bonus(interest),
		"squad_role": _determine_squad_role(interest)
	}
	
	contract_offer_received.emit(offer)
	return offer


func _calculate_offer_salary(interest: int) -> int:
	return roundi(interest * 1000 * (1.0 + randf() * 0.3))


func _calculate_signing_bonus(interest: int) -> int:
	return roundi(interest * 500 * randf())


func _determine_squad_role(interest: int) -> String:
	if interest > 80:
		return "starter"
	elif interest > 50:
		return "rotation"
	else:
		return "prospect"


func get_career_summary() -> Dictionary:
	return {
		"phase": GameManager.get_career_phase_name(),
		"reputation": reputation,
		"stats": career_stats,
		"milestones": completed_milestones.size(),
		"total_milestones": MILESTONES.size()
	}


func add_rival(rival_data: Dictionary) -> void:
	rivals.append(rival_data)
	rival_encounters[rival_data.id] = []


func record_rival_encounter(rival_id: String, result: Dictionary) -> void:
	if rival_id in rival_encounters:
		rival_encounters[rival_id].append(result)
		
		# Update narrative context for this rivalry
		NarrativeEngine.update_rivalry_context(rival_id, result)
