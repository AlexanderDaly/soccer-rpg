extends Node
## CareerManager - Handles career progression, milestones, and reputation
## Tracks the player's journey from high school to professional career

signal reputation_changed(new_reputation: int)
signal reputation_delta_applied(delta: int, new_value: int, source: String, details: Dictionary)
signal reputation_tier_changed(old_tier: String, new_tier: String)
signal fan_popularity_changed(new_total: int, delta: int, outcome: String)
signal milestone_reached(milestone: String)
signal scout_interest(scout_data: Dictionary)
signal contract_offer_received(offer: Dictionary)

const REPUTATION_MIN := 0
const REPUTATION_MAX := 100
const MILESTONE_REPUTATION_BONUS := 5
const SOCIAL_DAILY_CAP := 4
const MAX_REPUTATION_EVENTS := 100

const REPUTATION_TIERS: Array[Dictionary] = [
	{"id": "unknown", "name": "Unknown", "min": 0, "max": 14},
	{"id": "prospect", "name": "Prospect", "min": 15, "max": 29},
	{"id": "rising_star", "name": "Rising Star", "min": 30, "max": 49},
	{"id": "noted_talent", "name": "Noted Talent", "min": 50, "max": 69},
	{"id": "national_buzz", "name": "National Buzz", "min": 70, "max": 84},
	{"id": "wonderkid", "name": "Wonderkid", "min": 85, "max": 100}
]

const SCOUT_CHANCE_TIER_MULTIPLIER := {
	"unknown": 0.80,
	"prospect": 0.95,
	"rising_star": 1.05,
	"noted_talent": 1.15,
	"national_buzz": 1.25,
	"wonderkid": 1.35
}

const CONTRACT_VALUE_TIER_MULTIPLIER := {
	"unknown": 0.90,
	"prospect": 1.00,
	"rising_star": 1.08,
	"noted_talent": 1.18,
	"national_buzz": 1.30,
	"wonderkid": 1.45
}

const SOCIAL_DIMINISHING_FACTORS := [1.0, 0.5, 0.25, 0.1]
const SOCIAL_ELIGIBLE_LIKE_POST_TYPES := ["news_article", "match_summary", "milestone", "season_update"]

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
var reputation_event_log: Array[Dictionary] = []
var last_match_reputation_report: Dictionary = {}
var social_rep_day_key: String = ""
var social_rep_awarded_today: int = 0
var social_rep_actions_today: int = 0

# Milestones tracking
var completed_milestones: Array[String] = []
const MILESTONES = {
	"first_goal": {"name": "First Goal", "description": "Score your first career goal"},
	"first_assist": {"name": "First Assist", "description": "Record your first assist"},
	"first_motm": {"name": "Star Player", "description": "Win your first Man of the Match award"},
	"ten_goals": {"name": "Rising Striker", "description": "Score 10 career goals"},
	"golden_boot": {"name": "Golden Boot", "description": "Win the league's top scorer award"},
	"playmaker_award": {"name": "Playmaker", "description": "Win the league's top assists award"},
	"golden_glove": {"name": "Golden Glove", "description": "Win the goalkeeper of the season award"},
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


func reset_for_new_career() -> void:
	match_history.clear()
	career_stats = {
		"matches_played": 0,
		"goals": 0,
		"assists": 0,
		"clean_sheets": 0,
		"man_of_match_awards": 0,
		"trophies": [],
		"current_season": 1
	}
	completed_milestones.clear()
	rivals.clear()
	rival_encounters.clear()
	scout_attention.clear()

	reputation = 10
	media_coverage = 0
	fan_popularity = 0
	reputation_event_log.clear()
	last_match_reputation_report = {}
	social_rep_day_key = _get_current_day_key()
	social_rep_awarded_today = 0
	social_rep_actions_today = 0


func record_match_result(result: Dictionary) -> void:
	match_history.append(result)

	# Update career stats
	career_stats["matches_played"] = int(career_stats.get("matches_played", 0)) + 1
	career_stats["goals"] = int(career_stats.get("goals", 0)) + int(result.get("goals", 0))
	career_stats["assists"] = int(career_stats.get("assists", 0)) + int(result.get("assists", 0))

	if result.get("clean_sheet", false):
		career_stats["clean_sheets"] = int(career_stats.get("clean_sheets", 0)) + 1

	if result.get("man_of_match", false):
		career_stats["man_of_match_awards"] = int(career_stats.get("man_of_match_awards", 0)) + 1

	var breakdown: Array[Dictionary] = []
	var match_delta = _calculate_match_reputation_delta(result, breakdown)
	var rep_before = reputation
	_apply_reputation_delta(match_delta, "match_performance", {"breakdown": breakdown, "match_id": result.get("match_id", "")})

	var milestone_ids = _check_milestones(result)
	for milestone_id in milestone_ids:
		if award_milestone(milestone_id):
			breakdown.append({"source": "milestone", "delta": MILESTONE_REPUTATION_BONUS, "milestone_id": milestone_id})

	var total_delta = reputation - rep_before
	var tier = get_reputation_tier()
	last_match_reputation_report = {
		"reputation_before": rep_before,
		"reputation_after": reputation,
		"reputation_delta": total_delta,
		"reputation_tier": tier.get("name", "Unknown"),
		"reputation_tier_id": tier.get("id", "unknown"),
		"reputation_breakdown": breakdown.duplicate(true),
		"milestones_awarded": milestone_ids.duplicate(),
		"match_delta": match_delta
	}

	# Attach report to the payload consumed by UI screens.
	result["reputation_before"] = rep_before
	result["reputation_after"] = reputation
	result["reputation_delta"] = total_delta
	result["reputation_tier"] = tier.get("name", "Unknown")
	result["reputation_breakdown"] = breakdown.duplicate(true)

	# Keep flavor metrics in sync with current profile.
	media_coverage = clampi(reputation, REPUTATION_MIN, REPUTATION_MAX)
	_update_fan_popularity_from_match(result)

	# Check for scout interest
	_check_scout_interest(result)


func _check_milestones(_result: Dictionary) -> Array[String]:
	var newly_completed: Array[String] = []

	if "first_goal" not in completed_milestones and int(career_stats.get("goals", 0)) > 0:
		newly_completed.append("first_goal")

	if "first_assist" not in completed_milestones and int(career_stats.get("assists", 0)) > 0:
		newly_completed.append("first_assist")

	if "first_motm" not in completed_milestones and int(career_stats.get("man_of_match_awards", 0)) > 0:
		newly_completed.append("first_motm")

	if "ten_goals" not in completed_milestones and int(career_stats.get("goals", 0)) >= 10:
		newly_completed.append("ten_goals")

	return newly_completed


func _complete_milestone(milestone_id: String) -> bool:
	if milestone_id in MILESTONES and milestone_id not in completed_milestones:
		completed_milestones.append(milestone_id)
		print("[CareerManager] Milestone reached: %s" % MILESTONES[milestone_id].name)
		milestone_reached.emit(milestone_id)
		return true
	return false


func award_milestone(milestone_id: String, details: Dictionary = {}) -> bool:
	if not _complete_milestone(milestone_id):
		return false
	var rep_details = details.duplicate(true)
	rep_details["milestone_id"] = milestone_id
	_apply_reputation_delta(MILESTONE_REPUTATION_BONUS, "milestone", rep_details)
	return true


func _calculate_match_reputation_delta(result: Dictionary, breakdown: Array[Dictionary]) -> int:
	var raw_delta = 0

	var goals = int(result.get("goals", 0))
	if goals > 0:
		var goals_delta = goals * 2
		raw_delta += goals_delta
		breakdown.append({"source": "goals", "delta": goals_delta})

	var assists = int(result.get("assists", 0))
	if assists > 0:
		raw_delta += assists
		breakdown.append({"source": "assists", "delta": assists})

	if bool(result.get("won", false)):
		raw_delta += 2
		breakdown.append({"source": "win", "delta": 2})
	elif bool(result.get("lost", false)):
		raw_delta -= 2
		breakdown.append({"source": "loss", "delta": -2})

	if bool(result.get("man_of_match", false)):
		raw_delta += 4
		breakdown.append({"source": "man_of_match", "delta": 4})

	if bool(result.get("clean_sheet", false)):
		raw_delta += 1
		breakdown.append({"source": "clean_sheet", "delta": 1})

	var yellow_cards = mini(int(result.get("yellow_cards", 0)), 2)
	if yellow_cards > 0:
		var yellow_delta = -yellow_cards
		raw_delta += yellow_delta
		breakdown.append({"source": "yellow_cards", "delta": yellow_delta})

	if bool(result.get("red_card", false)):
		raw_delta -= 4
		breakdown.append({"source": "red_card", "delta": -4})

	var rating = float(result.get("rating", 6.0))
	if rating >= 8.5:
		raw_delta += 2
		breakdown.append({"source": "rating", "delta": 2, "rating": rating})
	elif rating >= 7.0:
		raw_delta += 1
		breakdown.append({"source": "rating", "delta": 1, "rating": rating})
	elif rating < 5.5:
		raw_delta -= 2
		breakdown.append({"source": "rating", "delta": -2, "rating": rating})
	elif rating < 6.5:
		raw_delta -= 1
		breakdown.append({"source": "rating", "delta": -1, "rating": rating})

	var importance = clampf(float(result.get("importance", 1.0)), 0.5, 3.0)
	var scaled_delta = roundi(float(raw_delta) * importance)
	breakdown.append({"source": "importance_scale", "delta": scaled_delta - raw_delta, "importance": importance})
	return scaled_delta


func _apply_reputation_delta(amount: int, source: String, details: Dictionary = {}) -> Dictionary:
	var old_rep = reputation
	reputation = clampi(reputation + amount, REPUTATION_MIN, REPUTATION_MAX)
	var applied_delta = reputation - old_rep
	var old_tier_id = get_reputation_tier(old_rep).get("id", "unknown")
	var new_tier = get_reputation_tier(reputation)
	var new_tier_id = new_tier.get("id", "unknown")

	var entry = {
		"timestamp": Time.get_unix_time_from_system(),
		"source": source,
		"requested_delta": amount,
		"applied_delta": applied_delta,
		"before": old_rep,
		"after": reputation,
		"details": details.duplicate(true)
	}
	reputation_event_log.append(entry)
	if reputation_event_log.size() > MAX_REPUTATION_EVENTS:
		reputation_event_log.pop_front()

	if applied_delta != 0:
		reputation_changed.emit(reputation)
		reputation_delta_applied.emit(applied_delta, reputation, source, details)
		if old_tier_id != new_tier_id:
			reputation_tier_changed.emit(old_tier_id, new_tier_id)

	return entry


func apply_social_reputation(action_type: String, payload: Dictionary = {}) -> Dictionary:
	_sync_social_day()

	var base_delta = 0
	match action_type:
		"player_post":
			base_delta = 2
		"player_reply":
			base_delta = 1
		"like":
			var post_type = str(payload.get("post_type", ""))
			var liked = bool(payload.get("liked", false))
			if liked and post_type in SOCIAL_ELIGIBLE_LIKE_POST_TYPES:
				base_delta = 1
		_:
			base_delta = int(payload.get("base_delta", 0))

	if base_delta <= 0:
		return {"requested_delta": base_delta, "applied_delta": 0, "reason": "ineligible"}

	var action_idx = social_rep_actions_today
	social_rep_actions_today += 1
	var factor = float(SOCIAL_DIMINISHING_FACTORS[min(action_idx, SOCIAL_DIMINISHING_FACTORS.size() - 1)])
	var diminished_delta = int(round(float(base_delta) * factor))
	if diminished_delta <= 0:
		return {"requested_delta": base_delta, "applied_delta": 0, "reason": "diminished_to_zero", "factor": factor}

	var remaining = maxi(SOCIAL_DAILY_CAP - social_rep_awarded_today, 0)
	var applied = mini(diminished_delta, remaining)
	if applied <= 0:
		return {"requested_delta": base_delta, "applied_delta": 0, "reason": "daily_cap_reached", "factor": factor}

	social_rep_awarded_today += applied
	_apply_reputation_delta(applied, "social_%s" % action_type, {
		"action_type": action_type,
		"factor": factor,
		"payload": payload.duplicate(true),
		"remaining_after": maxi(SOCIAL_DAILY_CAP - social_rep_awarded_today, 0)
	})

	return {
		"requested_delta": base_delta,
		"diminished_delta": diminished_delta,
		"applied_delta": applied,
		"factor": factor,
		"daily_awarded": social_rep_awarded_today,
		"daily_cap": SOCIAL_DAILY_CAP
	}


func apply_social_reputation_delta(delta: int, reason: String) -> void:
	# Compatibility shim for older callers/tests.
	if delta <= 0:
		return
	_sync_social_day()
	var remaining = maxi(SOCIAL_DAILY_CAP - social_rep_awarded_today, 0)
	var applied = mini(delta, remaining)
	if applied <= 0:
		return
	social_rep_awarded_today += applied
	social_rep_actions_today += 1
	_apply_reputation_delta(applied, "social_legacy", {"reason": reason, "requested_delta": delta})
	print("[CareerManager] Social reputation delta %d (%s)" % [applied, reason])


func _check_scout_interest(result: Dictionary) -> void:
	# Only scouts watch if reputation is high enough
	if reputation < 20:
		return

	# Chance of scout attendance based on reputation, match importance, and tier.
	var tier_id = str(get_reputation_tier().get("id", "unknown"))
	var tier_multiplier = float(SCOUT_CHANCE_TIER_MULTIPLIER.get(tier_id, 1.0))
	var scout_chance = (float(reputation) / 100.0) * float(result.get("importance", 1.0)) * tier_multiplier
	scout_chance = clampf(scout_chance, 0.0, 0.98)

	if randf() < scout_chance:
		var scout = _generate_scout()

		# Scout evaluates performance
		var impression = _calculate_scout_impression(result)
		scout_attention[scout.team_id] = int(scout_attention.get(scout.team_id, 0)) + impression

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
	impression += int(result.get("goals", 0)) * 10
	impression += int(result.get("assists", 0)) * 7
	impression += int(result.get("successful_passes", 0)) / 5
	impression += int(result.get("successful_tackles", 0)) * 3

	if result.get("man_of_match", false):
		impression += 20

	return impression


func generate_contract_offer(team_id: String) -> Dictionary:
	var interest = int(scout_attention.get(team_id, 0))

	if interest < 30:
		return {}  # Not enough interest

	var tier = get_reputation_tier()
	var tier_id = str(tier.get("id", "unknown"))
	var offer = {
		"team_id": team_id,
		"team_name": _team_name_from_scouting_pool(team_id),
		"salary": _calculate_offer_salary(interest, tier_id),
		"duration_years": randi_range(1, 3),
		"signing_bonus": _calculate_signing_bonus(interest, tier_id),
		"squad_role": _determine_squad_role(interest),
		"reputation_tier": tier.get("name", "Unknown")
	}

	contract_offer_received.emit(offer)
	return offer


func _calculate_offer_salary(interest: int, tier_id: String) -> int:
	var tier_multiplier = float(CONTRACT_VALUE_TIER_MULTIPLIER.get(tier_id, 1.0))
	return roundi(interest * 1000 * tier_multiplier * (1.0 + randf() * 0.3))


func _calculate_signing_bonus(interest: int, tier_id: String) -> int:
	var tier_multiplier = float(CONTRACT_VALUE_TIER_MULTIPLIER.get(tier_id, 1.0))
	return roundi(interest * 500 * tier_multiplier * randf())


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
		"reputation_tier": get_reputation_tier().get("name", "Unknown"),
		"stats": career_stats,
		"milestones": completed_milestones.size(),
		"total_milestones": MILESTONES.size()
	}


func get_reputation_tier(score: int = -1) -> Dictionary:
	var lookup = score
	if lookup < 0:
		lookup = reputation
	for tier in REPUTATION_TIERS:
		if lookup >= int(tier.get("min", 0)) and lookup <= int(tier.get("max", REPUTATION_MAX)):
			return tier
	return REPUTATION_TIERS[0]


func get_reputation_summary() -> Dictionary:
	var tier = get_reputation_tier()
	_sync_social_day()
	return {
		"score": reputation,
		"tier_id": tier.get("id", "unknown"),
		"tier_name": tier.get("name", "Unknown"),
		"media_coverage": media_coverage,
		"fan_popularity": fan_popularity,
		"daily_social_awarded": social_rep_awarded_today,
		"daily_social_cap": SOCIAL_DAILY_CAP,
		"daily_social_actions": social_rep_actions_today,
		"event_log_size": reputation_event_log.size()
	}


func get_last_match_reputation_report() -> Dictionary:
	return last_match_reputation_report.duplicate(true)


func add_rival(rival_data: Dictionary) -> void:
	rivals.append(rival_data)
	rival_encounters[rival_data.id] = []


func record_rival_encounter(rival_id: String, result: Dictionary) -> void:
	if rival_id in rival_encounters:
		rival_encounters[rival_id].append(result)

		# Update narrative context for this rivalry
		NarrativeEngine.update_rivalry_context(rival_id, result)


func record_season_award(award_type: String, stat_value: int = 0) -> void:
	# Record that player won a season award
	# award_type: "golden_boot", "playmaker_award", or "golden_glove"

	# Complete the corresponding milestone
	award_milestone(award_type, {"from_award": true})

	# Awards give extra reputation boost (on top of milestone bonus)
	var bonus_rep = 10 + int(stat_value / 2)  # Bigger bonus for higher stats
	_apply_reputation_delta(bonus_rep, "season_award", {"award_type": award_type, "stat_value": stat_value})

	# Increase scout attention significantly
	for team_id in scout_attention:
		scout_attention[team_id] = int(scout_attention[team_id]) + 15

	# If no scouts watching yet, generate interest from some teams
	if scout_attention.is_empty() and reputation >= 15:
		var teams = _get_scouting_teams(GameManager.current_career_phase)
		for team in teams:
			scout_attention[team.id] = 20

	# Store in career stats
	if not career_stats.has("awards"):
		career_stats["awards"] = []
	career_stats["awards"].append({
		"type": award_type,
		"value": stat_value,
		"season": int(career_stats.get("current_season", 1))
	})

	print("[CareerManager] Player won %s with %d" % [award_type, stat_value])


func _update_fan_popularity_from_match(result: Dictionary) -> void:
	var outcome = "draw"
	var base_change = 0.0
	if bool(result.get("won", false)):
		outcome = "win"
		base_change = 3.0 + (float(reputation) * 0.3)
	elif bool(result.get("lost", false)):
		outcome = "loss"
		base_change = -(1.0 + (float(reputation) * 0.05))
	else:
		result["followers_delta"] = 0
		result["followers_total"] = fan_popularity
		return

	var importance = clampf(float(result.get("importance", 1.0)), 0.5, 3.0)
	var raw_change = base_change * importance
	var proposed_delta = int(raw_change) if raw_change >= 0.0 else -int(abs(raw_change))
	var old_followers = fan_popularity
	fan_popularity = maxi(fan_popularity + proposed_delta, 0)
	var applied_delta = fan_popularity - old_followers

	result["followers_delta"] = applied_delta
	result["followers_total"] = fan_popularity

	if applied_delta != 0:
		fan_popularity_changed.emit(fan_popularity, applied_delta, outcome)


func accept_contract(offer: Dictionary) -> void:
	# Stubbed acceptance path for existing email UI hooks.
	if offer.is_empty():
		return
	award_milestone("first_pro_contract", {"from_contract": true})
	_apply_reputation_delta(3, "contract_accept", {"team_id": offer.get("team_id", "")})


func _sync_social_day() -> void:
	var day_key = _get_current_day_key()
	if social_rep_day_key == day_key:
		return
	social_rep_day_key = day_key
	social_rep_awarded_today = 0
	social_rep_actions_today = 0


func _get_current_day_key() -> String:
	if DesktopManager and DesktopManager.game_date:
		var d = DesktopManager.game_date
		return "%04d-%02d-%02d" % [int(d.get("year", 2024)), int(d.get("month", 1)), int(d.get("day", 1))]
	var date = Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(date.get("year", 2024)), int(date.get("month", 1)), int(date.get("day", 1))]


func _team_name_from_scouting_pool(team_id: String) -> String:
	var teams = _get_scouting_teams(GameManager.current_career_phase)
	for team in teams:
		if team.get("id", "") == team_id:
			return team.get("name", "Unknown")
	return "Unknown"
