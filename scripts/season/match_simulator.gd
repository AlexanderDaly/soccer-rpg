extends RefCounted
class_name MatchSimulator
## MatchSimulator - Simulates CPU vs CPU matches with realistic scorelines

# Target total goals per match
const TARGET_TOTAL_GOALS_LEAGUE: float = 2.4
const TARGET_TOTAL_GOALS_KNOCKOUT: float = 2.1  # Slightly tighter in knockouts

# Expected goals bounds
const MIN_EXPECTED_GOALS: float = 0.2
const MAX_EXPECTED_GOALS: float = 4.0

# Home advantage factor
const HOME_ADVANTAGE: float = 0.12

# Attack/defense model tuning
const ATTACK_DEFENSE_EXPONENT: float = 0.6
const CORRELATION_FACTOR: float = 0.12  # Shared-goal component for bivariate Poisson
const FORM_MULTIPLIER: float = 0.06
const RIVALRY_GOAL_MULTIPLIER: float = 1.08
const IMPORTANCE_GOAL_MULTIPLIER: float = 0.05

const ATTACK_STAT_WEIGHTS: Dictionary = {
	"SHO": 0.4,
	"TEC": 0.2,
	"PAS": 0.2,
	"SPD": 0.1,
	"MEN": 0.1
}

const DEFENSE_STAT_WEIGHTS: Dictionary = {
	"DEF": 0.4,
	"PHY": 0.2,
	"MEN": 0.2,
	"STA": 0.1,
	"SPD": 0.1
}

const CONTROL_STAT_WEIGHTS: Dictionary = {
	"PAS": 0.4,
	"MEN": 0.2,
	"TEC": 0.2,
	"STA": 0.1,
	"DEF": 0.1
}

const POSITION_PASS_WEIGHTS: Dictionary = {
	"GK": 0.4,
	"CB": 0.8,
	"FB": 1.0,
	"CDM": 1.5,
	"CM": 1.6,
	"CAM": 1.6,
	"WNG": 1.1,
	"ST": 0.8
}

const POSITION_KEY_PASS_WEIGHTS: Dictionary = {
	"CAM": 2.0,
	"CM": 1.5,
	"WNG": 1.4,
	"FB": 0.9,
	"ST": 0.6,
	"CDM": 0.6,
	"CB": 0.2,
	"GK": 0.05
}


static func simulate_league_match(home_team: TeamData, away_team: TeamData, context: Dictionary = {}) -> Dictionary:
	return _simulate_match(home_team, away_team, false, true, context)


static func simulate_knockout_match(team_a: TeamData, team_b: TeamData, context: Dictionary = {}) -> Dictionary:
	return _simulate_match(team_a, team_b, true, false, context)


static func _simulate_match(home_team: TeamData, away_team: TeamData, is_knockout: bool, has_home_advantage: bool, context: Dictionary = {}) -> Dictionary:
	var home_form = context.get("home_form", [])
	var away_form = context.get("away_form", [])
	var importance = float(context.get("importance", 1.0))
	var rivalry = bool(context.get("rivalry", false))

	# Calculate team ratings from starting XIs (injuries already filtered)
	var home_ratings = _calculate_team_ratings(home_team)
	var away_ratings = _calculate_team_ratings(away_team)

	var home_attack = maxf(home_ratings.attack, 5.0)
	var home_defense = maxf(home_ratings.defense, 5.0)
	var home_control = maxf(home_ratings.control, 5.0)
	var away_attack = maxf(away_ratings.attack, 5.0)
	var away_defense = maxf(away_ratings.defense, 5.0)
	var away_control = maxf(away_ratings.control, 5.0)

	# Apply form multipliers
	var home_form_mult = _form_multiplier(home_form)
	var away_form_mult = _form_multiplier(away_form)
	home_attack *= home_form_mult
	home_defense *= home_form_mult
	home_control *= home_form_mult
	away_attack *= away_form_mult
	away_defense *= away_form_mult
	away_control *= away_form_mult

	# Apply home advantage
	if has_home_advantage:
		home_attack *= (1.0 + HOME_ADVANTAGE)

	# Base expected goals from attack vs defense matchup
	var home_ratio = pow(home_attack / away_defense, ATTACK_DEFENSE_EXPONENT)
	var away_ratio = pow(away_attack / home_defense, ATTACK_DEFENSE_EXPONENT)

	var target_total = TARGET_TOTAL_GOALS_KNOCKOUT if is_knockout else TARGET_TOTAL_GOALS_LEAGUE

	# Importance slightly dampens or boosts total goals
	var importance_factor = clampf(1.0 - (importance - 1.0) * IMPORTANCE_GOAL_MULTIPLIER, 0.9, 1.05)
	target_total *= importance_factor

	# Rivalries tend to be higher intensity
	if rivalry:
		target_total *= RIVALRY_GOAL_MULTIPLIER

	# Normalize to target total goals
	var ratio_sum = maxf(home_ratio + away_ratio, 0.01)
	var home_expected = (home_ratio / ratio_sum) * target_total
	var away_expected = (away_ratio / ratio_sum) * target_total

	# Simulate cards (used to adjust expected goals)
	var card_rate_mult = 1.0 + maxf(0.0, importance - 1.0) * 0.1
	if rivalry:
		card_rate_mult += 0.1

	var home_cards = _generate_card_events(home_team, 90, card_rate_mult)
	var away_cards = _generate_card_events(away_team, 90, card_rate_mult)

	# Simulate fouls
	var foul_base = MEAN_FOULS_PER_TEAM_KNOCKOUT if is_knockout else MEAN_FOULS_PER_TEAM_LEAGUE
	var foul_multiplier = 1.0 + maxf(0.0, importance - 1.0) * FOULS_IMPORTANCE_MULTIPLIER
	if rivalry:
		foul_multiplier *= FOULS_RIVALRY_MULTIPLIER

	var home_fouls = _generate_fouls(foul_base * foul_multiplier)
	var away_fouls = _generate_fouls(foul_base * foul_multiplier)

	# Apply red card effects to expected goals
	home_expected = _apply_red_card_effects(home_expected, home_cards)
	away_expected = _apply_red_card_effects(away_expected, away_cards)

	var home_red_effect = _red_card_opponent_bonus(home_cards)
	var away_red_effect = _red_card_opponent_bonus(away_cards)
	home_expected *= (1.0 + away_red_effect)
	away_expected *= (1.0 + home_red_effect)

	# Small random variance per team
	home_expected *= randf_range(0.92, 1.08)
	away_expected *= randf_range(0.92, 1.08)

	# Clamp expected goals
	home_expected = clampf(home_expected, MIN_EXPECTED_GOALS, MAX_EXPECTED_GOALS)
	away_expected = clampf(away_expected, MIN_EXPECTED_GOALS, MAX_EXPECTED_GOALS)

	# Generate scores using bivariate Poisson
	var scores = _sample_bivariate_poisson(home_expected, away_expected)
	var home_score = scores.home
	var away_score = scores.away

	var home_stat_line = _generate_team_stat_line(home_expected, home_score)
	var away_stat_line = _generate_team_stat_line(away_expected, away_score)

	var pass_stats = _generate_pass_stats(
		home_team, away_team,
		home_control, away_control,
		home_defense, away_defense,
		home_form_mult, away_form_mult,
		home_stat_line, away_stat_line,
		is_knockout, importance, rivalry
	)

	home_stat_line.merge(pass_stats.home.team, true)
	away_stat_line.merge(pass_stats.away.team, true)

	var home_goal_minutes = _generate_goal_minutes(home_score)
	var away_goal_minutes = _generate_goal_minutes(away_score)

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
		"home_goal_events": _attribute_goals(home_team, home_score, home_goal_minutes),
		"away_goal_events": _attribute_goals(away_team, away_score, away_goal_minutes),
		"card_events": home_cards + away_cards,
		"home_fouls": home_fouls,
		"away_fouls": away_fouls,
		"home_stats": home_stat_line,
		"away_stats": away_stat_line,
		"home_player_stats": pass_stats.home.players,
		"away_player_stats": pass_stats.away.players
	}

	# Handle knockout draws
	if is_knockout and home_score == away_score:
		var pre_home = home_score
		var pre_away = away_score
		result = _handle_knockout_draw(result, home_ratings.overall, away_ratings.overall)
		# Add an extra-time goal event if needed
		if result.extra_time and not result.penalties:
			if result.home_score > pre_home:
				result.home_goal_events.append_array(_attribute_goals(home_team, 1, [_generate_extra_time_minute()]))
			elif result.away_score > pre_away:
				result.away_goal_events.append_array(_attribute_goals(away_team, 1, [_generate_extra_time_minute()]))

	return result


static func _calculate_team_ratings(team: TeamData) -> Dictionary:
	if not team:
		return {"attack": 50.0, "defense": 50.0, "control": 50.0, "overall": 50.0}

	var starters = team.get_starting_eleven()
	if starters.is_empty():
		var fallback = float(team.get_average_overall())
		return {"attack": fallback, "defense": fallback, "control": fallback, "overall": fallback}

	var attack_sum: float = 0.0
	var defense_sum: float = 0.0
	var control_sum: float = 0.0
	var overall_sum: float = 0.0
	var count: int = 0

	for player in starters:
		var stats = player.get("stats", {})
		attack_sum += _weighted_stat(stats, ATTACK_STAT_WEIGHTS)
		defense_sum += _weighted_stat(stats, DEFENSE_STAT_WEIGHTS)
		control_sum += _weighted_stat(stats, CONTROL_STAT_WEIGHTS)
		overall_sum += float(player.get("overall", 50))
		count += 1

	if count == 0:
		return {"attack": 50.0, "defense": 50.0, "control": 50.0, "overall": 50.0}

	var tier_multiplier = 1.0 + maxf(float(team.tier - 1), 0.0) * 0.03

	return {
		"attack": (attack_sum / count) * tier_multiplier,
		"defense": (defense_sum / count) * tier_multiplier,
		"control": (control_sum / count) * tier_multiplier,
		"overall": (overall_sum / count) * tier_multiplier
	}


static func _weighted_stat(stats: Dictionary, weights: Dictionary) -> float:
	var total: float = 0.0
	var weight_sum: float = 0.0

	for key in weights:
		if stats.has(key):
			total += float(stats[key]) * weights[key]
			weight_sum += weights[key]

	if weight_sum <= 0.0:
		return 50.0

	return total / weight_sum


static func _poisson_random(mean: float) -> int:
	if mean <= 0.0:
		return 0
	# Simple Poisson-like random number generation
	# Using inverse transform sampling approximation
	var L = exp(-mean)
	var k = 0
	var p = 1.0

	while p > L:
		k += 1
		p *= randf()

	return k - 1


static func _form_multiplier(form: Variant) -> float:
	if form is Array:
		var results = form as Array
		if results.is_empty():
			return 1.0
		var score = 0.0
		for result in results:
			if result == "W":
				score += 1.0
			elif result == "L":
				score -= 1.0
		var avg = score / maxf(1.0, float(results.size()))
		return clampf(1.0 + avg * FORM_MULTIPLIER, 0.9, 1.1)

	if form is float or form is int:
		return clampf(1.0 + float(form) * FORM_MULTIPLIER, 0.9, 1.1)

	return 1.0


static func _sample_bivariate_poisson(home_mean: float, away_mean: float) -> Dictionary:
	var shared = minf(home_mean, away_mean) * CORRELATION_FACTOR
	var lambda1 = maxf(home_mean - shared, 0.01)
	var lambda2 = maxf(away_mean - shared, 0.01)

	var x = _poisson_random(lambda1)
	var y = _poisson_random(lambda2)
	var z = _poisson_random(shared)

	return {
		"home": x + z,
		"away": y + z
	}


static func _red_card_effect(minute: int) -> float:
	var t = clampf(float(minute), 1.0, 90.0) / 90.0
	return lerpf(0.35, 0.1, t)


static func _apply_red_card_effects(expected: float, card_events: Array) -> float:
	var adjusted = expected
	for event in card_events:
		if event.get("card_color", "") == "red":
			var minute = int(event.get("minute", 90))
			var effect = _red_card_effect(minute)
			adjusted *= (1.0 - effect)
	return adjusted


static func _red_card_opponent_bonus(card_events: Array) -> float:
	var bonus = 0.0
	for event in card_events:
		if event.get("card_color", "") == "red":
			var minute = int(event.get("minute", 90))
			bonus += _red_card_effect(minute) * 0.5
	return clampf(bonus, 0.0, 0.4)


static func _generate_team_stat_line(expected_goals: float, goals_scored: int) -> Dictionary:
	# Approximate shot volume from expected goals with variance
	var conversion = clampf(0.11 + randf_range(-0.03, 0.03), 0.07, 0.2)
	var shots = roundi(expected_goals / conversion + randf_range(-2.0, 2.0))
	shots = clampi(max(shots, goals_scored), goals_scored, 25)

	var on_target_rate = clampf(0.32 + randf_range(-0.05, 0.08), 0.25, 0.55)
	var shots_on_target = roundi(shots * on_target_rate)
	shots_on_target = clampi(max(shots_on_target, goals_scored), goals_scored, shots)

	var xg = snapped(expected_goals, 0.01)

	return {
		"shots": shots,
		"shots_on_target": shots_on_target,
		"xg": xg
	}


static func _generate_fouls(mean: float) -> int:
	var fouls = _poisson_random(mean)
	return clampi(fouls, 3, 25)


static func _generate_pass_stats(home_team: TeamData, away_team: TeamData,
		home_control: float, away_control: float,
		home_defense: float, away_defense: float,
		home_form_mult: float, away_form_mult: float,
		home_stat_line: Dictionary, away_stat_line: Dictionary,
		is_knockout: bool, importance: float, rivalry: bool) -> Dictionary:
	var base_total = 390 if is_knockout else 420
	var tempo_factor = clampf(1.0 - (importance - 1.0) * 0.05, 0.9, 1.05)
	if rivalry:
		tempo_factor *= 1.02
	var total_passes = roundi(base_total * tempo_factor + randf_range(-30.0, 30.0))
	total_passes = clampi(total_passes, 240, 620)

	var home_control_adj = home_control * home_form_mult
	var away_control_adj = away_control * away_form_mult
	var diff = (home_control_adj - away_control_adj) / 12.0
	var possession_home = clampf(1.0 / (1.0 + exp(-diff)), 0.35, 0.65)

	var home_attempts = roundi(total_passes * possession_home)
	var away_attempts = total_passes - home_attempts

	var home_accuracy = _pass_accuracy(home_control_adj, away_defense, rivalry)
	var away_accuracy = _pass_accuracy(away_control_adj, home_defense, rivalry)

	var home_completed = roundi(home_attempts * home_accuracy)
	var away_completed = roundi(away_attempts * away_accuracy)

	var home_player = _distribute_passes(home_team, home_attempts, home_completed, home_accuracy, home_stat_line)
	var away_player = _distribute_passes(away_team, away_attempts, away_completed, away_accuracy, away_stat_line)

	return {
		"home": {
			"team": {
				"possession": possession_home,
				"passes_attempted": home_attempts,
				"passes_completed": home_completed,
				"pass_accuracy": home_accuracy
			},
			"players": home_player
		},
		"away": {
			"team": {
				"possession": 1.0 - possession_home,
				"passes_attempted": away_attempts,
				"passes_completed": away_completed,
				"pass_accuracy": away_accuracy
			},
			"players": away_player
		}
	}


static func _pass_accuracy(control_rating: float, opponent_defense: float, rivalry: bool) -> float:
	var diff = (control_rating - opponent_defense) / 160.0
	var accuracy = 0.72 + diff + randf_range(-0.02, 0.02)
	if rivalry:
		accuracy -= 0.02
	return clampf(accuracy, 0.6, 0.9)


static func _distribute_passes(team: TeamData, attempts: int, completed: int,
		team_accuracy: float, stat_line: Dictionary) -> Dictionary:
	var players = team.get_starting_eleven()
	if players.is_empty():
		return {}

	var weights: Array[Dictionary] = []
	var total_weight: float = 0.0
	for player in players:
		var pos = player.get("position", "CM")
		var base_weight = POSITION_PASS_WEIGHTS.get(pos, 1.0)
		var pas = float(player.get("stats", {}).get("PAS", 50))
		var weight = base_weight * (pas / 50.0)
		total_weight += weight
		weights.append({"player": player, "weight": weight})

	var player_attempts: Dictionary = {}
	for i in range(attempts):
		var chosen = _weighted_pick(weights, total_weight)
		if chosen.is_empty():
			break
		var pid = chosen.get("id", "")
		player_attempts[pid] = player_attempts.get(pid, 0) + 1

	var player_completions: Dictionary = {}
	var completion_total = 0
	for player in players:
		var pid = player.get("id", "")
		var atts = player_attempts.get(pid, 0)
		if atts <= 0:
			player_completions[pid] = 0
			continue
		var pas = float(player.get("stats", {}).get("PAS", 50))
		var player_accuracy = clampf(team_accuracy + (pas - 50.0) / 250.0, 0.5, 0.95)
		var comps = roundi(atts * player_accuracy)
		player_completions[pid] = comps
		completion_total += comps

	# Normalize completions to team total
	var diff = completed - completion_total
	if diff != 0:
		var sorted_players = players.duplicate()
		sorted_players.sort_custom(func(a, b): return player_attempts.get(a.get("id", ""), 0) > player_attempts.get(b.get("id", ""), 0))
		var idx = 0
		while diff != 0 and sorted_players.size() > 0:
			var pid = sorted_players[idx % sorted_players.size()].get("id", "")
			if pid != "":
				player_completions[pid] = max(player_completions.get(pid, 0) + (1 if diff > 0 else -1), 0)
				diff += -1 if diff > 0 else 1
			idx += 1

	# Key passes derived from shot volume
	var key_passes_total = clampi(roundi((stat_line.get("shots_on_target", 0) + stat_line.get("shots", 0)) * 0.6), 3, 18)
	var key_passes = _distribute_key_passes(players, key_passes_total)

	var result: Dictionary = {}
	for player in players:
		var pid = player.get("id", "")
		if pid == "":
			continue
		result[pid] = {
			"passes_attempted": player_attempts.get(pid, 0),
			"passes_completed": player_completions.get(pid, 0),
			"key_passes": key_passes.get(pid, 0)
		}

	return result


static func _weighted_pick(weights: Array[Dictionary], total_weight: float) -> Dictionary:
	if total_weight <= 0.0:
		return {}
	var roll = randf() * total_weight
	var cumulative = 0.0
	for entry in weights:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.player
	return weights[-1].player


static func _distribute_key_passes(players: Array, total: int) -> Dictionary:
	var weights: Array[Dictionary] = []
	var total_weight = 0.0
	for player in players:
		var pos = player.get("position", "CM")
		var base_weight = POSITION_KEY_PASS_WEIGHTS.get(pos, 1.0)
		var pas = float(player.get("stats", {}).get("PAS", 50))
		var weight = base_weight * (pas / 50.0)
		total_weight += weight
		weights.append({"player": player, "weight": weight})

	var result: Dictionary = {}
	for i in range(total):
		var chosen = _weighted_pick(weights, total_weight)
		if chosen.is_empty():
			break
		var pid = chosen.get("id", "")
		result[pid] = result.get(pid, 0) + 1

	return result


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


static func simulate_batch_league_matches(fixtures: Array[Dictionary], teams_by_id: Dictionary, league_data = null, importance: float = 1.0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for fixture in fixtures:
		var home_team = teams_by_id.get(fixture.home_id) as TeamData
		var away_team = teams_by_id.get(fixture.away_id) as TeamData

		if home_team and away_team:
			var context: Dictionary = {"importance": importance}
			if league_data and league_data.standings and fixture.home_id in league_data.standings:
				context["home_form"] = league_data.standings[fixture.home_id].form
			if league_data and league_data.standings and fixture.away_id in league_data.standings:
				context["away_form"] = league_data.standings[fixture.away_id].form
			var result = simulate_league_match(home_team, away_team, context)
			result["fixture"] = fixture
			results.append(result)

	return results


static func simulate_batch_knockout_matches(matches: Array[Dictionary], teams_by_id: Dictionary, importance: float = 1.0) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for match_data in matches:
		var team_a = teams_by_id.get(match_data.team_a_id) as TeamData
		var team_b = teams_by_id.get(match_data.team_b_id) as TeamData

		if team_a and team_b:
			var context: Dictionary = {"importance": importance}
			var result = simulate_knockout_match(team_a, team_b, context)
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

# Card simulation
const MEAN_YELLOW_CARDS: float = 1.3
const RED_CARD_CHANCE: float = 0.06

# Foul simulation
const MEAN_FOULS_PER_TEAM_LEAGUE: float = 10.0
const MEAN_FOULS_PER_TEAM_KNOCKOUT: float = 11.0
const FOULS_IMPORTANCE_MULTIPLIER: float = 0.08
const FOULS_RIVALRY_MULTIPLIER: float = 1.1


static func _attribute_goals(team: TeamData, goals_scored: int, minutes: Array = []) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	if goals_scored == 0 or not team:
		return events

	var players = team.get_starting_eleven()
	if players.is_empty():
		return events

	var goal_minutes = minutes if minutes.size() >= goals_scored else _generate_goal_minutes(goals_scored)

	for i in range(goals_scored):
		var minute = goal_minutes[i] if i < goal_minutes.size() else randi_range(1, 90)
		var event: Dictionary = _create_goal_event(team, minute)

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


static func _create_goal_event(team: TeamData, minute: int) -> Dictionary:
	return {
		"minute": minute,
		"team_id": team.id if team else "",
		"team_name": team.name if team else ""
	}


static func _generate_goal_minutes(goals_scored: int) -> Array[int]:
	var minutes: Array[int] = []
	for _i in range(goals_scored):
		minutes.append(randi_range(1, 90))
	minutes.sort()
	return minutes


static func _generate_extra_time_minute() -> int:
	return randi_range(91, 120)


static func _generate_card_events(team: TeamData, max_minute: int = 90, multiplier: float = 1.0) -> Array[Dictionary]:
	var events: Array[Dictionary] = []

	if not team:
		return events

	var players = team.get_starting_eleven()
	if players.is_empty():
		return events

	var yellow_count = clampi(_poisson_random(MEAN_YELLOW_CARDS * multiplier), 0, 3)
	for _i in range(yellow_count):
		var player = players[randi() % players.size()]
		events.append({
			"minute": randi_range(1, max_minute),
			"team_id": team.id,
			"team_name": team.name,
			"player_id": player.get("id", ""),
			"player_name": player.get("name", "Player"),
			"card_color": "yellow"
		})

	if randf() < RED_CARD_CHANCE * multiplier:
		var red_player = players[randi() % players.size()]
		events.append({
			"minute": randi_range(1, max_minute),
			"team_id": team.id,
			"team_name": team.name,
			"player_id": red_player.get("id", ""),
			"player_name": red_player.get("name", "Player"),
			"card_color": "red"
		})

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
