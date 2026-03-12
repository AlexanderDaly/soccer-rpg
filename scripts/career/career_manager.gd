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
const RELATIONSHIP_MIN := -100
const RELATIONSHIP_MAX := 100
const TRUST_MIN := 0
const TRUST_MAX := 100
const RELATIONSHIP_PASS_BONUS := 3
const RELATIONSHIP_RATING_COMBO_BONUS := 0.15
const MAX_SCOUT_RELATIONSHIP := 30

const TEAM_POOLS := {
	"youth": [
		{"id": "metro_youth_academy", "name": "Metro Youth Academy", "short_name": "MYA", "league": "Youth Elite", "tier": 2},
		{"id": "harbor_development", "name": "Harbor Development", "short_name": "HDC", "league": "Youth Elite", "tier": 2},
		{"id": "crest_academy", "name": "Crest Academy", "short_name": "CRE", "league": "Youth Elite", "tier": 2},
		{"id": "capital_prospects", "name": "Capital Prospects", "short_name": "CAP", "league": "Youth Elite", "tier": 2},
		{"id": "phoenix_juniors", "name": "Phoenix Juniors", "short_name": "PHX", "league": "Youth Elite", "tier": 2},
		{"id": "north_star_u19", "name": "North Star U19", "short_name": "NST", "league": "Youth Elite", "tier": 2},
		{"id": "riverside_future", "name": "Riverside Future", "short_name": "RSF", "league": "Youth Elite", "tier": 2},
		{"id": "summit_labs", "name": "Summit Labs", "short_name": "SUM", "league": "Youth Elite", "tier": 2}
	],
	"pro": [
		{"id": "city_united", "name": "City United", "short_name": "CTU", "league": "Division One", "tier": 2},
		{"id": "capital_fc", "name": "Capital FC", "short_name": "CAP", "league": "Division One", "tier": 3},
		{"id": "royal_athletic", "name": "Royal Athletic", "short_name": "RAL", "league": "Premier Crown", "tier": 4},
		{"id": "united_stars", "name": "United Stars", "short_name": "UST", "league": "Premier Crown", "tier": 4},
		{"id": "ironworks_sc", "name": "Ironworks SC", "short_name": "IRN", "league": "Division One", "tier": 3},
		{"id": "harbor_city", "name": "Harbor City", "short_name": "HBC", "league": "Division One", "tier": 3},
		{"id": "mountain_rovers", "name": "Mountain Rovers", "short_name": "MTR", "league": "Division One", "tier": 2},
		{"id": "lumen_fc", "name": "Lumen FC", "short_name": "LMN", "league": "Premier Crown", "tier": 4}
	],
	"u20_qualifiers": [
		{"id": "u20_japan", "name": "Japan U20", "short_name": "JPN", "league": "U20 Qualifiers", "tier": 3},
		{"id": "u20_brazil", "name": "Brazil U20", "short_name": "BRA", "league": "U20 Qualifiers", "tier": 3},
		{"id": "u20_germany", "name": "Germany U20", "short_name": "GER", "league": "U20 Qualifiers", "tier": 3},
		{"id": "u20_spain", "name": "Spain U20", "short_name": "ESP", "league": "U20 Qualifiers", "tier": 3},
		{"id": "u20_france", "name": "France U20", "short_name": "FRA", "league": "U20 Qualifiers", "tier": 3},
		{"id": "u20_argentina", "name": "Argentina U20", "short_name": "ARG", "league": "U20 Qualifiers", "tier": 3}
	],
	"u20_world_cup": [
		{"id": "u20_japan", "name": "Japan U20", "short_name": "JPN", "league": "U20 World Cup", "tier": 3},
		{"id": "u20_brazil", "name": "Brazil U20", "short_name": "BRA", "league": "U20 World Cup", "tier": 3},
		{"id": "u20_germany", "name": "Germany U20", "short_name": "GER", "league": "U20 World Cup", "tier": 3},
		{"id": "u20_spain", "name": "Spain U20", "short_name": "ESP", "league": "U20 World Cup", "tier": 3},
		{"id": "u20_france", "name": "France U20", "short_name": "FRA", "league": "U20 World Cup", "tier": 3},
		{"id": "u20_argentina", "name": "Argentina U20", "short_name": "ARG", "league": "U20 World Cup", "tier": 3},
		{"id": "u20_england", "name": "England U20", "short_name": "ENG", "league": "U20 World Cup", "tier": 3},
		{"id": "u20_italy", "name": "Italy U20", "short_name": "ITA", "league": "U20 World Cup", "tier": 3}
	]
}

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
var current_contract: Dictionary = {}
var club_history: Array[Dictionary] = []
var pending_contract_offers: Array[Dictionary] = []
var relationships: Dictionary = {}
var coach_trust: int = 50
var scout_relationships: Dictionary = {}
var queued_contract_offer: Dictionary = {}

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
	pending_contract_offers.clear()
	club_history.clear()
	relationships.clear()
	scout_relationships.clear()
	queued_contract_offer = {}
	coach_trust = 50
	current_contract = {}

	reputation = 10
	media_coverage = 0
	fan_popularity = 0
	reputation_event_log.clear()
	last_match_reputation_report = {}
	social_rep_day_key = _get_current_day_key()
	social_rep_awarded_today = 0
	social_rep_actions_today = 0


func initialize_new_career_state(team: TeamData) -> void:
	if not GameManager.player_data:
		return

	var player = GameManager.player_data
	var background = player.get_background_profile()
	reputation = clampi(10 + int(background.get("reputation_bonus", 0)), REPUTATION_MIN, REPUTATION_MAX)
	coach_trust = clampi(50 + int(background.get("coach_trust_bonus", 0)), TRUST_MIN, TRUST_MAX)
	current_contract = {
		"team_id": team.id if team else "",
		"team_name": team.name if team else "High School",
		"phase": "HIGH_SCHOOL",
		"role": "starter",
		"salary": 0,
		"duration_years": 3,
		"status": "student"
	}


func record_match_result(result: Dictionary) -> void:
	_apply_relationship_rating_bonus(result)
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
	_apply_match_relationship_effects(result)
	_maybe_trigger_u20_callup()

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

	if "world_cup_goal" not in completed_milestones and str(_result.get("match_type", "")) in ["world_cup", "world_cup_final"] and int(_result.get("goals", 0)) > 0:
		newly_completed.append("world_cup_goal")

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


func handle_primary_season_completion(summary: Dictionary) -> void:
	career_stats["current_season"] = int(career_stats.get("current_season", 1)) + 1
	if summary.get("national_champion", false):
		var trophies = career_stats.get("trophies", []).duplicate()
		trophies.append(summary.get("competition_name", "Championship"))
		career_stats["trophies"] = trophies
	process_pending_offer_expirations()


func get_team_pool(pool_id: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for team in TEAM_POOLS.get(pool_id, []):
		pool.append(team.duplicate(true))
	return pool


func create_team_from_catalog(team_info: Dictionary, phase: GameManager.CareerPhase) -> TeamData:
	var team = TeamData.new()
	team.id = str(team_info.get("id", "team_%d" % randi()))
	team.name = str(team_info.get("name", "Unknown Club"))
	team.short_name = str(team_info.get("short_name", team.name.substr(0, mini(3, team.name.length())).to_upper()))
	team.league = str(team_info.get("league", "Unknown League"))
	team.tier = int(team_info.get("tier", 2))
	team.formation = ["4-3-3", "4-2-3-1", "4-4-2", "3-5-2"][randi() % 4]
	team.generate_teammates(10, phase, false)
	return team


func get_teammate_pass_modifier(teammate_id: String) -> int:
	var rel = relationships.get(teammate_id, {})
	var affinity = int(rel.get("affinity", 0))
	if affinity >= 40:
		return RELATIONSHIP_PASS_BONUS
	if affinity <= -40:
		return -RELATIONSHIP_PASS_BONUS
	return 0


func get_player_channel_side() -> String:
	if not GameManager.player_data:
		return "center"
	var position = GameManager.player_data.position
	if position not in ["FB", "WNG", "CAM", "CM", "ST"]:
		return "center"
	var hash_seed = "%s_%s" % [GameManager.player_data.id, position]
	return "left" if abs(hash_seed.hash()) % 2 == 0 else "right"


func get_combination_rating_bonus(team_goal_events: Array) -> float:
	if not GameManager.player_data:
		return 0.0

	var player_id = GameManager.player_data.id
	var bonus = 0.0
	for event in team_goal_events:
		var scorer_id = str(event.get("scorer_id", ""))
		var assister_id = str(event.get("assister_id", ""))
		if scorer_id == player_id and not assister_id.is_empty():
			bonus += _combo_bonus_for_teammate(assister_id)
		elif assister_id == player_id and not scorer_id.is_empty():
			bonus += _combo_bonus_for_teammate(scorer_id)

	return bonus


func update_relationship(entity_id: String, affinity_delta: int = 0, trust_delta: int = 0, entity_type: String = "teammate", entity_name: String = "") -> Dictionary:
	if entity_id.is_empty():
		return {}

	var rel = relationships.get(entity_id, {
		"entity_id": entity_id,
		"type": entity_type,
		"name": entity_name,
		"affinity": 0,
		"trust": 50
	})

	var positive_multiplier = GameManager.player_data.get_positive_relationship_multiplier() if GameManager.player_data else 1.0
	var loss_multiplier = GameManager.player_data.get_relationship_loss_multiplier() if GameManager.player_data else 1.0
	var adjusted_affinity = _scale_relationship_delta(affinity_delta, positive_multiplier, loss_multiplier)
	var adjusted_trust = _scale_relationship_delta(trust_delta, positive_multiplier, loss_multiplier)

	rel["affinity"] = clampi(int(rel.get("affinity", 0)) + adjusted_affinity, RELATIONSHIP_MIN, RELATIONSHIP_MAX)
	rel["trust"] = clampi(int(rel.get("trust", 50)) + adjusted_trust, TRUST_MIN, TRUST_MAX)
	if not entity_name.is_empty():
		rel["name"] = entity_name
	relationships[entity_id] = rel
	return rel


func update_coach_trust(delta: int) -> void:
	var positive_multiplier = GameManager.player_data.get_positive_relationship_multiplier() if GameManager.player_data else 1.0
	var loss_multiplier = GameManager.player_data.get_relationship_loss_multiplier() if GameManager.player_data else 1.0
	coach_trust = clampi(coach_trust + _scale_relationship_delta(delta, positive_multiplier, loss_multiplier), TRUST_MIN, TRUST_MAX)


func get_effective_scout_interest(team_id: String) -> int:
	return int(scout_attention.get(team_id, 0)) + int(scout_relationships.get(team_id, 0))


func process_pending_offer_expirations() -> void:
	if pending_contract_offers.is_empty():
		return

	var remaining: Array[Dictionary] = []
	for offer in pending_contract_offers:
		if _offer_has_expired(offer):
			if DesktopManager:
				DesktopManager.show_notification(
					"Offer Expired",
					"%s pulled their contract offer." % offer.get("team_name", "A club"),
					"",
					"email"
				)
			continue
		remaining.append(offer)

	pending_contract_offers = remaining


func on_date_advanced() -> void:
	process_pending_offer_expirations()


func generate_progression_offers(summary: Dictionary = {}) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var player = GameManager.player_data
	if not player:
		return offers

	if player.school_year < 3:
		return offers

	var has_major_award = not career_stats.get("awards", []).is_empty() or summary.get("national_champion", false)
	var eligible_teams: Array[String] = []

	if reputation >= 25:
		for team in get_team_pool("youth"):
			eligible_teams.append(team.get("id", ""))

	if reputation >= 55 or has_major_award:
		for team in get_team_pool("pro"):
			eligible_teams.append(team.get("id", ""))

	var seen: Dictionary = {}
	for team_id in scout_attention:
		if eligible_teams.has(team_id):
			seen[team_id] = true
			var offer = generate_contract_offer(team_id, true)
			if not offer.is_empty():
				offers.append(offer)

	for team_id in eligible_teams:
		if offers.size() >= 3:
			break
		if seen.has(team_id):
			continue
		var offer = generate_contract_offer(team_id, true)
		if not offer.is_empty():
			offers.append(offer)

	if offers.is_empty():
		var fallback_id = "metro_youth_academy"
		var fallback_offer = generate_contract_offer(fallback_id, true, {"forced": true})
		if not fallback_offer.is_empty():
			offers.append(fallback_offer)

	return offers


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
		scout_relationships[scout.team_id] = mini(int(scout_relationships.get(scout.team_id, 0)) + 5, MAX_SCOUT_RELATIONSHIP)

		scout_interest.emit(scout)
		var can_offer_now = GameManager.current_career_phase != GameManager.CareerPhase.HIGH_SCHOOL
		if GameManager.current_career_phase == GameManager.CareerPhase.HIGH_SCHOOL and GameManager.player_data and GameManager.player_data.school_year >= 3 and not SeasonManager.has_active_season():
			can_offer_now = true
		if can_offer_now:
			generate_contract_offer(scout.team_id)


func _generate_scout() -> Dictionary:
	# Generate a scout from a team based on career phase
	var phase = GameManager.current_career_phase
	var teams = _get_scouting_teams(phase)
	var team = teams[randi() % teams.size()]

	return {
		"team_id": team.get("id", ""),
		"team_name": team.get("name", ""),
		"scout_name": _generate_scout_name(),
		"league": team.get("league", "")
	}


func _get_scouting_teams(phase: GameManager.CareerPhase) -> Array:
	match phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			return get_team_pool("youth")
		GameManager.CareerPhase.YOUTH_ACADEMY:
			return get_team_pool("pro")
		_:
			return get_team_pool("pro")


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


func generate_contract_offer(team_id: String, force: bool = false, context: Dictionary = {}) -> Dictionary:
	var interest = get_effective_scout_interest(team_id)
	var threshold = _get_offer_interest_threshold()

	if not force and interest < threshold:
		return {}  # Not enough interest

	if _has_pending_offer_from_team(team_id):
		return {}

	var tier = get_reputation_tier()
	var tier_id = str(tier.get("id", "unknown"))
	var team_info = _find_team_in_pools(team_id)
	var target_phase = _target_phase_for_team(team_info)
	if GameManager.current_career_phase == GameManager.CareerPhase.HIGH_SCHOOL and GameManager.player_data and GameManager.player_data.school_year < 3:
		return {}

	var apply_in_offseason = bool(context.get("apply_in_offseason", false))
	if not force and GameManager.current_career_phase != GameManager.CareerPhase.HIGH_SCHOOL and SeasonManager.has_active_season():
		apply_in_offseason = true

	var expiry_days = 5 if GameManager.player_data and GameManager.player_data.career_difficulty == "hardcore" else 10
	var offer = {
		"team_id": team_id,
		"team_name": team_info.get("name", _team_name_from_scouting_pool(team_id)),
		"salary": _calculate_offer_salary(interest, tier_id),
		"wages": _calculate_offer_salary(interest, tier_id),
		"duration_years": randi_range(1, 3),
		"length": randi_range(1, 3),
		"signing_bonus": _calculate_signing_bonus(interest, tier_id),
		"squad_role": _determine_squad_role(interest),
		"reputation_tier": tier.get("name", "Unknown")
	}
	offer["duration_years"] = int(offer.get("length", offer.get("duration_years", 2)))
	offer["target_phase"] = target_phase
	offer["offer_window"] = "midseason" if apply_in_offseason else "offseason"
	offer["starts_next_window"] = apply_in_offseason
	offer["expires_on"] = _date_after_days(expiry_days)
	offer["effective_interest"] = interest
	offer["league"] = team_info.get("league", "")
	offer["role_floor"] = "rotation" if coach_trust >= 70 else "prospect"

	pending_contract_offers.append(offer)

	contract_offer_received.emit(offer)
	return offer


func _calculate_offer_salary(interest: int, tier_id: String) -> int:
	var tier_multiplier = float(CONTRACT_VALUE_TIER_MULTIPLIER.get(tier_id, 1.0))
	return roundi(interest * 1000 * tier_multiplier * (1.0 + randf() * 0.3))


func _calculate_signing_bonus(interest: int, tier_id: String) -> int:
	var tier_multiplier = float(CONTRACT_VALUE_TIER_MULTIPLIER.get(tier_id, 1.0))
	return roundi(interest * 500 * tier_multiplier * randf())


func _determine_squad_role(interest: int) -> String:
	var role = "prospect"
	if interest > 80:
		role = "starter"
	elif interest > 50:
		role = "rotation"

	if coach_trust >= 70 and role == "prospect":
		role = "rotation"
	elif coach_trust <= 30:
		if role == "starter":
			role = "rotation"
		elif role == "rotation":
			role = "prospect"

	return role


func get_career_summary() -> Dictionary:
	return {
		"phase": GameManager.get_career_phase_name(),
		"national_phase": GameManager.get_national_phase_name(),
		"reputation": reputation,
		"reputation_tier": get_reputation_tier().get("name", "Unknown"),
		"stats": career_stats,
		"coach_trust": coach_trust,
		"active_contract": current_contract,
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
			scout_attention[team.get("id", "")] = 20

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
	if offer.is_empty():
		return
	_remove_pending_offer(offer.get("team_id", ""))

	if bool(offer.get("starts_next_window", false)) and SeasonManager.has_active_season():
		queued_contract_offer = offer.duplicate(true)
		_apply_reputation_delta(1, "contract_queued", {"team_id": offer.get("team_id", "")})
		update_relationship(str(offer.get("team_id", "")), 4, 3, "scout", str(offer.get("team_name", "")))
		return

	_commit_contract_offer(offer)


func decline_contract(offer: Dictionary) -> void:
	if offer.is_empty():
		return
	_remove_pending_offer(offer.get("team_id", ""))
	update_relationship(str(offer.get("team_id", "")), -3, -2, "scout", str(offer.get("team_name", "")))


func has_queued_contract() -> bool:
	return not queued_contract_offer.is_empty()


func apply_queued_contract() -> void:
	if queued_contract_offer.is_empty():
		return
	var offer = queued_contract_offer.duplicate(true)
	queued_contract_offer = {}
	_commit_contract_offer(offer)


func _apply_relationship_rating_bonus(result: Dictionary) -> void:
	var player_goal_events = _extract_player_team_goal_events(result)
	var bonus = get_combination_rating_bonus(player_goal_events)
	if bonus <= 0.0:
		return
	result["rating"] = clampf(float(result.get("rating", 6.0)) + bonus, 1.0, 10.0)
	result["relationship_combo_bonus"] = bonus


func _apply_match_relationship_effects(result: Dictionary) -> void:
	if not GameManager.player_data:
		return

	var player_id = GameManager.player_data.id
	var player_goal_events = _extract_player_team_goal_events(result)

	for event in player_goal_events:
		var scorer_id = str(event.get("scorer_id", ""))
		var assister_id = str(event.get("assister_id", ""))
		if assister_id == player_id and not scorer_id.is_empty():
			update_relationship(scorer_id, 8, 3, "teammate", str(event.get("scorer_name", "")))
		elif scorer_id == player_id and not assister_id.is_empty():
			update_relationship(assister_id, 6, 3, "teammate", str(event.get("assister_name", "")))

	if bool(result.get("won", false)):
		update_coach_trust(4)
	elif bool(result.get("lost", false)):
		var poor_penalty = GameManager.player_data.get_poor_match_penalty_multiplier()
		update_coach_trust(-roundi(4.0 * poor_penalty))
		for rel_id in relationships:
			var rel = relationships[rel_id]
			if rel.get("type", "") == "teammate":
				update_relationship(str(rel_id), -2, -1, "teammate", str(rel.get("name", "")))

	if int(result.get("yellow_cards", 0)) > 0:
		update_coach_trust(-2 * int(result.get("yellow_cards", 0)))
	if bool(result.get("red_card", false)):
		update_coach_trust(-6)

	var rating = float(result.get("rating", 6.0))
	if rating >= 8.0:
		update_coach_trust(3)
	elif rating < 5.5:
		var penalty_mult = GameManager.player_data.get_poor_match_penalty_multiplier()
		update_coach_trust(-roundi(3.0 * penalty_mult))


func _maybe_trigger_u20_callup() -> void:
	if not GameManager.player_data:
		return
	if GameManager.current_national_phase != GameManager.NationalPhase.NONE:
		return
	if GameManager.player_data.age > 20 or reputation < 40:
		return
	if award_milestone("u20_callup", {"source": "callup"}):
		GameManager.set_national_phase(GameManager.NationalPhase.U20_QUALIFIERS)
		if SeasonManager and SeasonManager.has_method("initialize_season") and GameManager.current_team:
			SeasonManager.initialize_season(GameManager.current_prefecture, GameManager.current_team)


func _combo_bonus_for_teammate(teammate_id: String) -> float:
	var rel = relationships.get(teammate_id, {})
	var affinity = int(rel.get("affinity", 0))
	if affinity >= 40:
		return RELATIONSHIP_RATING_COMBO_BONUS
	if affinity <= -40:
		return -RELATIONSHIP_RATING_COMBO_BONUS
	return 0.0


func _extract_player_team_goal_events(result: Dictionary) -> Array:
	if result.has("player_goal_events"):
		return result.get("player_goal_events", [])

	var is_home = GameManager.current_match.is_home if GameManager.current_match else true
	return result.get("home_goal_events", []) if is_home else result.get("away_goal_events", [])


func _scale_relationship_delta(delta: int, positive_multiplier: float, loss_multiplier: float) -> int:
	if delta > 0:
		return roundi(float(delta) * positive_multiplier)
	if delta < 0:
		return roundi(float(delta) * loss_multiplier)
	return 0


func _offer_has_expired(offer: Dictionary) -> bool:
	var expires_on = offer.get("expires_on", {})
	if expires_on.is_empty():
		return false
	return _compare_dates(DesktopManager.game_date, expires_on) >= 0


func _compare_dates(a: Dictionary, b: Dictionary) -> int:
	var a_value = int(a.get("year", 0)) * 10000 + int(a.get("month", 0)) * 100 + int(a.get("day", 0))
	var b_value = int(b.get("year", 0)) * 10000 + int(b.get("month", 0)) * 100 + int(b.get("day", 0))
	if a_value == b_value:
		return 0
	return 1 if a_value > b_value else -1


func _date_after_days(days: int) -> Dictionary:
	var date = DesktopManager.game_date.duplicate(true) if DesktopManager and DesktopManager.game_date else {"year": 2024, "month": 4, "day": 1}
	date["day"] = int(date.get("day", 1)) + days
	while int(date.get("day", 1)) > 30:
		date["day"] = int(date.get("day", 1)) - 30
		date["month"] = int(date.get("month", 1)) + 1
	while int(date.get("month", 1)) > 12:
		date["month"] = int(date.get("month", 1)) - 12
		date["year"] = int(date.get("year", 2024)) + 1
	return date


func _get_offer_interest_threshold() -> int:
	var difficulty_multiplier = GameManager.player_data.get_scout_threshold_multiplier() if GameManager.player_data else 1.0
	var coach_multiplier = 0.9 if coach_trust >= 70 else 1.1 if coach_trust <= 30 else 1.0
	return roundi(30.0 * difficulty_multiplier * coach_multiplier)


func _has_pending_offer_from_team(team_id: String) -> bool:
	for offer in pending_contract_offers:
		if offer.get("team_id", "") == team_id:
			return true
	return false


func _find_team_in_pools(team_id: String) -> Dictionary:
	for pool_id in TEAM_POOLS:
		for team in TEAM_POOLS[pool_id]:
			if team.get("id", "") == team_id:
				return team
	return {}


func _target_phase_for_team(team_info: Dictionary) -> GameManager.CareerPhase:
	var league = str(team_info.get("league", ""))
	return GameManager.CareerPhase.YOUTH_ACADEMY if league == "Youth Elite" else GameManager.CareerPhase.PRO_CAREER


func _remove_pending_offer(team_id: String) -> void:
	for i in range(pending_contract_offers.size() - 1, -1, -1):
		if pending_contract_offers[i].get("team_id", "") == team_id:
			pending_contract_offers.remove_at(i)


func _commit_contract_offer(offer: Dictionary) -> void:
	var team_info = _find_team_in_pools(str(offer.get("team_id", "")))
	var target_phase = offer.get("target_phase", _target_phase_for_team(team_info))
	var new_team = create_team_from_catalog(team_info, target_phase)
	var old_contract = current_contract.duplicate(true)

	if not old_contract.is_empty():
		club_history.append(old_contract)

	current_contract = {
		"team_id": offer.get("team_id", ""),
		"team_name": offer.get("team_name", ""),
		"phase": GameManager.CareerPhase.keys()[target_phase],
		"role": offer.get("squad_role", "prospect"),
		"salary": offer.get("salary", 0),
		"duration_years": offer.get("duration_years", 1),
		"status": "active",
		"signed_on": DesktopManager.get_date_string() if DesktopManager else ""
	}

	GameManager.current_team = new_team
	GameManager.set_career_phase(target_phase)
	update_relationship(str(offer.get("team_id", "")), 6, 4, "scout", str(offer.get("team_name", "")))
	_apply_reputation_delta(3, "contract_accept", {"team_id": offer.get("team_id", "")})
	if target_phase == GameManager.CareerPhase.PRO_CAREER:
		award_milestone("first_pro_contract", {"from_contract": true})

	SeasonManager.initialize_season(GameManager.current_prefecture, GameManager.current_team)


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
	var team = _find_team_in_pools(team_id)
	return team.get("name", "Unknown")
