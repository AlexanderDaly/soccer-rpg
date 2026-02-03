extends RefCounted
class_name MatchSimulator
## MatchSimulator - Simulates CPU vs CPU matches with realistic scorelines

# Average goals per team in high school soccer
const MEAN_GOALS_HIGH_SCHOOL: float = 1.2
const MEAN_GOALS_KNOCKOUT: float = 1.0  # More defensive in knockouts

# Home advantage factor
const HOME_ADVANTAGE: float = 0.15


static func simulate_league_match(home_team: TeamData, away_team: TeamData) -> Dictionary:
	return _simulate_match(home_team, away_team, false, true)


static func simulate_knockout_match(team_a: TeamData, team_b: TeamData) -> Dictionary:
	return _simulate_match(team_a, team_b, true, false)


static func _simulate_match(home_team: TeamData, away_team: TeamData, is_knockout: bool, has_home_advantage: bool) -> Dictionary:
	# Calculate team strengths
	var home_strength = _calculate_team_strength(home_team)
	var away_strength = _calculate_team_strength(away_team)

	# Ensure minimum strength to prevent division by zero
	home_strength = maxf(home_strength, 10.0)
	away_strength = maxf(away_strength, 10.0)

	# Apply home advantage
	if has_home_advantage:
		home_strength *= (1.0 + HOME_ADVANTAGE)

	# Calculate expected goals using Poisson-like distribution
	var base_mean = MEAN_GOALS_KNOCKOUT if is_knockout else MEAN_GOALS_HIGH_SCHOOL

	# Adjust expected goals based on relative strength
	var strength_ratio = home_strength / away_strength
	var home_expected = base_mean * strength_ratio
	var away_expected = base_mean / strength_ratio

	# Clamp expected goals to reasonable range
	home_expected = clampf(home_expected, 0.3, 3.5)
	away_expected = clampf(away_expected, 0.3, 3.5)

	# Generate scores using Poisson-like random
	var home_score = _poisson_random(home_expected)
	var away_score = _poisson_random(away_expected)

	var result = {
		"home_team_id": home_team.id,
		"away_team_id": away_team.id,
		"home_team_name": home_team.name,
		"away_team_name": away_team.name,
		"home_score": home_score,
		"away_score": away_score,
		"extra_time": false,
		"penalties": false,
		"penalty_score_home": 0,
		"penalty_score_away": 0,
		"home_goal_events": _attribute_goals(home_team, home_score),
		"away_goal_events": _attribute_goals(away_team, away_score)
	}

	# Handle knockout draws
	if is_knockout and home_score == away_score:
		result = _handle_knockout_draw(result, home_strength, away_strength)

	return result


static func _calculate_team_strength(team: TeamData) -> float:
	if not team:
		return 50.0

	# Base strength from average overall
	var base_strength = float(team.get_average_overall())

	# Tier bonus
	var tier_bonus = team.tier * 5.0

	# Random form factor (-5 to +10)
	var form_factor = randf_range(-5.0, 10.0)

	return base_strength + tier_bonus + form_factor


static func _poisson_random(mean: float) -> int:
	# Simple Poisson-like random number generation
	# Using inverse transform sampling approximation
	var L = exp(-mean)
	var k = 0
	var p = 1.0

	while p > L:
		k += 1
		p *= randf()

	return k - 1


static func _handle_knockout_draw(result: Dictionary, home_strength: float, away_strength: float) -> Dictionary:
	# Ensure minimum strengths for calculations
	var safe_home_strength = maxf(home_strength, 10.0)
	var safe_away_strength = maxf(away_strength, 10.0)

	# 40% chance of extra time goal, 60% goes to penalties
	if randf() < 0.4:
		# Extra time goal
		result.extra_time = true

		# Determine which team scores based on strength
		var home_chance = safe_home_strength / (safe_home_strength + safe_away_strength)
		if randf() < home_chance:
			result.home_score += 1
		else:
			result.away_score += 1
	else:
		# Penalties
		result.extra_time = true
		result.penalties = true
		var penalty_result = _simulate_penalty_shootout(home_strength, away_strength)
		result.penalty_score_home = penalty_result.home
		result.penalty_score_away = penalty_result.away

	return result


static func _simulate_penalty_shootout(home_strength: float, away_strength: float) -> Dictionary:
	# Simulate a penalty shootout
	var home_scored = 0
	var away_scored = 0

	# Base conversion rate ~75% for high school
	var base_rate = 0.75

	# Slight strength influence on penalties
	var home_rate = base_rate + (home_strength - 50) * 0.002
	var away_rate = base_rate + (away_strength - 50) * 0.002

	home_rate = clampf(home_rate, 0.6, 0.9)
	away_rate = clampf(away_rate, 0.6, 0.9)

	# First 5 rounds
	for i in range(5):
		if randf() < home_rate:
			home_scored += 1
		if randf() < away_rate:
			away_scored += 1

	# Sudden death if tied (with safety limit to prevent infinite loop)
	var sudden_death_rounds = 0
	const MAX_SUDDEN_DEATH_ROUNDS = 20  # Safety limit

	while home_scored == away_scored and sudden_death_rounds < MAX_SUDDEN_DEATH_ROUNDS:
		sudden_death_rounds += 1
		var home_converts = randf() < home_rate
		var away_converts = randf() < away_rate

		if home_converts:
			home_scored += 1
		if away_converts:
			away_scored += 1

		# If both miss or both score, continue
		if home_converts != away_converts:
			break

	# If still tied after max rounds, randomly pick winner (extremely rare edge case)
	if home_scored == away_scored:
		if randf() < 0.5:
			home_scored += 1
		else:
			away_scored += 1

	return {
		"home": home_scored,
		"away": away_scored
	}


static func simulate_batch_league_matches(fixtures: Array[Dictionary], teams_by_id: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for fixture in fixtures:
		var home_team = teams_by_id.get(fixture.home_id) as TeamData
		var away_team = teams_by_id.get(fixture.away_id) as TeamData

		if home_team and away_team:
			var result = simulate_league_match(home_team, away_team)
			result["fixture"] = fixture
			results.append(result)

	return results


static func simulate_batch_knockout_matches(matches: Array[Dictionary], teams_by_id: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for match_data in matches:
		var team_a = teams_by_id.get(match_data.team_a_id) as TeamData
		var team_b = teams_by_id.get(match_data.team_b_id) as TeamData

		if team_a and team_b:
			var result = simulate_knockout_match(team_a, team_b)
			result["match_data"] = match_data
			results.append(result)

	return results


static func get_winner_id(result: Dictionary) -> String:
	if result.penalties:
		if result.penalty_score_home > result.penalty_score_away:
			return result.home_team_id
		else:
			return result.away_team_id
	else:
		if result.home_score > result.away_score:
			return result.home_team_id
		elif result.away_score > result.home_score:
			return result.away_team_id
		else:
			return ""  # Draw (only in league)


static func format_result_string(result: Dictionary) -> String:
	var score_str = "%d - %d" % [result.home_score, result.away_score]

	if result.penalties:
		score_str += " (ET, %d-%d pen)" % [result.penalty_score_home, result.penalty_score_away]
	elif result.extra_time:
		score_str += " (AET)"

	return "%s %s %s" % [result.home_team_name, score_str, result.away_team_name]


# Position weights for goal scoring probability
const POSITION_GOAL_WEIGHTS: Dictionary = {
	"ST": 5.0,
	"WNG": 2.5,
	"CAM": 2.0,
	"CM": 1.0,
	"CDM": 0.5,
	"FB": 0.3,
	"CB": 0.2,
	"GK": 0.01
}

# Chance of a goal having an assist
const ASSIST_CHANCE: float = 0.7


static func _attribute_goals(team: TeamData, goals_scored: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	if goals_scored == 0 or not team:
		return events

	var players = team.get_starting_eleven()
	if players.is_empty():
		return events

	for _i in range(goals_scored):
		var event: Dictionary = {}

		# Select scorer
		var scorer = _weighted_player_select(players, POSITION_GOAL_WEIGHTS)
		event["scorer_id"] = scorer.get("id", "")
		event["scorer_name"] = scorer.get("name", "Unknown")

		# 70% chance of assist
		if randf() < ASSIST_CHANCE:
			# Assister should be different from scorer, midfielders/wingers more likely
			var assister = _weighted_player_select(players, POSITION_GOAL_WEIGHTS, scorer.get("id", ""))
			if not assister.is_empty():
				event["assister_id"] = assister.get("id", "")
				event["assister_name"] = assister.get("name", "Unknown")

		events.append(event)

	return events


static func _weighted_player_select(players: Array, weights: Dictionary, exclude_id: String = "") -> Dictionary:
	if players.is_empty():
		return {}

	var total_weight: float = 0.0
	var player_weights: Array[Dictionary] = []

	for player in players:
		var player_id = player.get("id", "")
		if player_id == exclude_id:
			continue

		var position = player.get("position", "CM")
		var base_weight = weights.get(position, 1.0)

		# Factor in player overall rating
		var overall = player.get("overall", 50)
		var rating_factor = overall / 50.0  # Normalize around 50

		var final_weight = base_weight * rating_factor
		total_weight += final_weight

		player_weights.append({
			"player": player,
			"weight": final_weight
		})

	if total_weight == 0 or player_weights.is_empty():
		return players[0] if players.size() > 0 else {}

	# Weighted random selection
	var roll = randf() * total_weight
	var cumulative: float = 0.0

	for pw in player_weights:
		cumulative += pw.weight
		if roll <= cumulative:
			return pw.player

	return player_weights[-1].player
