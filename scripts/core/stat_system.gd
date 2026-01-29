extends Node
## StatSystem - Manages player stats, growth, and calculations
## Based on the stat model designed for tactical soccer gameplay

signal stat_changed(player_id: String, stat_name: String, old_value: int, new_value: int)
signal level_up(player_id: String, new_level: int)
signal skill_unlocked(player_id: String, skill_id: String)

# Primary stat definitions (1-99 scale)
const PRIMARY_STATS = {
	"SPD": "Speed",        # Movement range, chase/escape
	"STA": "Stamina",      # Actions per match, recovery
	"TEC": "Technique",    # Dribble, first touch, skill moves
	"PAS": "Passing",      # Pass accuracy, range, through-balls
	"SHO": "Shooting",     # Shot power, accuracy, long-range
	"DEF": "Defense",      # Tackle, interception, marking
	"PHY": "Physical",     # Aerial duels, hold-up, resistance
	"MEN": "Mental"        # Composure, consistency, pressure handling
}

# Secondary stat formulas (derived from primaries)
const SECONDARY_FORMULAS = {
	"acceleration": {"SPD": 0.7, "PHY": 0.3},
	"vision": {"PAS": 0.5, "MEN": 0.5},
	"finishing": {"SHO": 0.6, "TEC": 0.3, "MEN": 0.1},
	"long_shots": {"SHO": 0.7, "TEC": 0.3},
	"crossing": {"PAS": 0.6, "TEC": 0.4},
	"heading": {"PHY": 0.6, "SHO": 0.4},
	"tackling": {"DEF": 0.7, "PHY": 0.3},
	"interception": {"DEF": 0.5, "MEN": 0.5},
	"positioning": {"MEN": 0.6, "DEF": 0.4},
	"reflexes": {"SPD": 0.5, "MEN": 0.5}  # Goalkeeper specific
}

# Position archetype stat weights (for growth and effectiveness)
const POSITION_WEIGHTS = {
	"GK": {"SPD": 0.6, "STA": 0.5, "TEC": 0.7, "PAS": 0.6, "SHO": 0.2, "DEF": 0.8, "PHY": 0.9, "MEN": 1.0},
	"CB": {"SPD": 0.6, "STA": 0.7, "TEC": 0.5, "PAS": 0.6, "SHO": 0.3, "DEF": 1.0, "PHY": 0.9, "MEN": 0.8},
	"FB": {"SPD": 0.9, "STA": 0.9, "TEC": 0.7, "PAS": 0.7, "SHO": 0.4, "DEF": 0.8, "PHY": 0.6, "MEN": 0.6},
	"CDM": {"SPD": 0.6, "STA": 0.8, "TEC": 0.7, "PAS": 0.8, "SHO": 0.5, "DEF": 0.9, "PHY": 0.8, "MEN": 0.9},
	"CM": {"SPD": 0.7, "STA": 0.9, "TEC": 0.8, "PAS": 0.9, "SHO": 0.6, "DEF": 0.6, "PHY": 0.6, "MEN": 0.8},
	"CAM": {"SPD": 0.7, "STA": 0.7, "TEC": 1.0, "PAS": 0.9, "SHO": 0.8, "DEF": 0.3, "PHY": 0.5, "MEN": 0.8},
	"WNG": {"SPD": 1.0, "STA": 0.8, "TEC": 0.9, "PAS": 0.7, "SHO": 0.7, "DEF": 0.3, "PHY": 0.5, "MEN": 0.6},
	"ST": {"SPD": 0.8, "STA": 0.7, "TEC": 0.8, "PAS": 0.6, "SHO": 1.0, "DEF": 0.2, "PHY": 0.8, "MEN": 0.8}
}

# XP required per level (exponential curve)
const BASE_XP_PER_LEVEL = 100
const XP_GROWTH_RATE = 1.15

# Form/morale modifier ranges
const FORM_MODIFIERS = {
	"terrible": -10,
	"poor": -5,
	"average": 0,
	"good": 5,
	"excellent": 10
}


func _ready() -> void:
	print("[StatSystem] Initialized")


## Calculate a secondary stat from primary stats
func calculate_secondary(player_stats: Dictionary, secondary_name: String) -> int:
	if secondary_name not in SECONDARY_FORMULAS:
		push_warning("Unknown secondary stat: %s" % secondary_name)
		return 0
	
	var formula = SECONDARY_FORMULAS[secondary_name]
	var result: float = 0.0
	
	for stat_key in formula:
		if stat_key in player_stats:
			result += player_stats[stat_key] * formula[stat_key]
	
	return roundi(result)


## Calculate all secondary stats for a player
func calculate_all_secondaries(player_stats: Dictionary) -> Dictionary:
	var secondaries = {}
	for secondary_name in SECONDARY_FORMULAS:
		secondaries[secondary_name] = calculate_secondary(player_stats, secondary_name)
	return secondaries


## Calculate overall rating based on position
func calculate_overall(player_stats: Dictionary, position: String) -> int:
	if position not in POSITION_WEIGHTS:
		position = "CM"  # Default fallback
	
	var weights = POSITION_WEIGHTS[position]
	var weighted_sum: float = 0.0
	var weight_total: float = 0.0
	
	for stat_key in weights:
		if stat_key in player_stats:
			weighted_sum += player_stats[stat_key] * weights[stat_key]
			weight_total += weights[stat_key]
	
	if weight_total > 0:
		return roundi(weighted_sum / weight_total)
	return 50  # Default


## Apply form modifier to stats
func apply_form_modifier(base_stat: int, form: String) -> int:
	var modifier = FORM_MODIFIERS.get(form, 0)
	return clampi(base_stat + modifier, 1, 99)


## Calculate XP required for a given level
func xp_for_level(level: int) -> int:
	return roundi(BASE_XP_PER_LEVEL * pow(XP_GROWTH_RATE, level - 1))


## Calculate total XP required to reach a level from level 1
func total_xp_for_level(level: int) -> int:
	var total = 0
	for i in range(1, level):
		total += xp_for_level(i)
	return total


## Process match performance and award XP/stat gains
func process_match_performance(result: Dictionary) -> void:
	var player = GameManager.player_data
	if not player:
		return
	
	var xp_gained = _calculate_match_xp(result)
	player.add_xp(xp_gained)
	
	# Award stat points based on actions taken
	var stat_gains = _calculate_stat_gains(result)
	for stat_key in stat_gains:
		player.add_stat_xp(stat_key, stat_gains[stat_key])


func _calculate_match_xp(result: Dictionary) -> int:
	var base_xp = 50
	
	# Bonuses for performance
	if result.get("goals", 0) > 0:
		base_xp += result.goals * 20
	if result.get("assists", 0) > 0:
		base_xp += result.assists * 15
	if result.get("won", false):
		base_xp += 30
	if result.get("clean_sheet", false):
		base_xp += 20
	if result.get("man_of_match", false):
		base_xp += 50
	
	return base_xp


func _calculate_stat_gains(result: Dictionary) -> Dictionary:
	var gains = {}
	
	# Map actions to stat growth
	if result.get("successful_passes", 0) > 10:
		gains["PAS"] = 1
	if result.get("successful_tackles", 0) > 3:
		gains["DEF"] = 1
	if result.get("shots_on_target", 0) > 2:
		gains["SHO"] = 1
	if result.get("successful_dribbles", 0) > 3:
		gains["TEC"] = 1
	if result.get("distance_covered", 0) > 10000:  # meters
		gains["STA"] = 1
	
	return gains


## Generate random stats for NPC players
func generate_npc_stats(position: String, quality_tier: int) -> Dictionary:
	# quality_tier: 1=low, 2=medium, 3=high, 4=elite
	var base_range = [30, 45, 60, 75][clampi(quality_tier - 1, 0, 3)]
	var variance = 15
	
	var stats = {}
	var weights = POSITION_WEIGHTS.get(position, POSITION_WEIGHTS["CM"])
	
	for stat_key in PRIMARY_STATS:
		var weight = weights.get(stat_key, 0.5)
		var weighted_base = base_range + roundi((weight - 0.5) * 20)
		stats[stat_key] = clampi(weighted_base + randi_range(-variance, variance), 1, 99)
	
	return stats


## Roll for action success (used in match system)
func roll_action_success(actor_stat: int, defender_stat: int = 0, difficulty: float = 0.5) -> Dictionary:
	# Returns success, critical success, or failure with margin
	var actor_roll = randf() * 100
	var success_threshold = actor_stat * (1.0 - difficulty)
	
	if defender_stat > 0:
		success_threshold = (actor_stat / float(actor_stat + defender_stat)) * 100
	
	var result = {
		"success": actor_roll < success_threshold,
		"critical": actor_roll < success_threshold * 0.2,  # Critical on bottom 20% of success range
		"margin": success_threshold - actor_roll
	}
	
	return result
