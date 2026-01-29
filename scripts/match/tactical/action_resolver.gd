extends RefCounted
class_name ActionResolver
## ActionResolver - Executes tactical actions and resolves outcomes

signal action_completed(action_type: String, success: bool, data: Dictionary)

# Action costs
const AP_COST = {
	"move": 1,        # Per 2 hexes
	"pass": 1,
	"through_ball": 2,
	"shoot": 2,
	"dribble": 1,
	"tackle": 1,
	"sprint": 0       # Uses stamina instead
}

const SPRINT_STAMINA_COST: int = 10
const FOUL_BASE_CHANCE: float = 0.15


## Execute a move action
static func execute_move(unit: PlayerUnit, target_hex: Vector2i, occupied_hexes: Array[Vector2i]) -> Dictionary:
	var path = HexUtils.find_path(unit.hex_position, target_hex, occupied_hexes)

	if path.is_empty():
		return {"success": false, "reason": "no_path"}

	var distance = path.size() - 1  # Subtract 1 because path includes starting hex
	var move_range = unit.get_move_range()
	var hexes_per_ap = 2
	var ap_needed = ceili(float(distance) / hexes_per_ap)

	if ap_needed > unit.action_points:
		return {"success": false, "reason": "insufficient_ap", "needed": ap_needed, "have": unit.action_points}

	# Execute the move
	unit.spend_ap(ap_needed)

	return {
		"success": true,
		"path": path,
		"ap_spent": ap_needed,
		"distance": distance
	}


## Execute sprint (bonus move at stamina cost)
static func execute_sprint(unit: PlayerUnit, target_hex: Vector2i, occupied_hexes: Array[Vector2i]) -> Dictionary:
	if unit.stamina < SPRINT_STAMINA_COST:
		return {"success": false, "reason": "insufficient_stamina"}

	var path = HexUtils.find_path(unit.hex_position, target_hex, occupied_hexes)

	if path.is_empty():
		return {"success": false, "reason": "no_path"}

	var distance = path.size() - 1
	var sprint_range = 2  # Sprint gives +2 hex bonus

	if distance > sprint_range:
		return {"success": false, "reason": "out_of_sprint_range"}

	unit.spend_stamina(SPRINT_STAMINA_COST)

	return {
		"success": true,
		"path": path,
		"stamina_spent": SPRINT_STAMINA_COST,
		"distance": distance
	}


## Execute a pass action
static func execute_pass(passer: PlayerUnit, target_hex: Vector2i, receiver: PlayerUnit,
						  defenders: Array[PlayerUnit], match_data: MatchData) -> Dictionary:
	var ap_cost = AP_COST["pass"]

	if passer.action_points < ap_cost:
		return {"success": false, "reason": "insufficient_ap"}

	if not passer.has_ball:
		return {"success": false, "reason": "no_ball"}

	passer.spend_ap(ap_cost)

	# Calculate pass difficulty based on distance
	var distance = HexUtils.hex_distance(passer.hex_position, target_hex)
	var base_difficulty = 0.3 + (distance * 0.03)

	# Roll for pass accuracy
	var pass_stat = passer.get_passing_stat()
	var roll = StatSystem.roll_action_success(pass_stat, 0, base_difficulty)

	# Check for interceptions
	var interception_result = _check_interception(passer.hex_position, target_hex, defenders)

	# Record event
	if match_data:
		match_data.record_event("pass", {
			"is_player": passer.is_player_controlled,
			"successful": roll.success and not interception_result.intercepted,
			"distance": distance
		})

	if not roll.success:
		# Misplaced pass - ball goes loose somewhere along the path
		var miss_hex = _calculate_miss_location(passer.hex_position, target_hex, roll.margin)
		return {
			"success": false,
			"reason": "inaccurate",
			"miss_hex": miss_hex,
			"roll": roll
		}

	if interception_result.intercepted:
		return {
			"success": false,
			"reason": "intercepted",
			"interceptor": interception_result.interceptor,
			"interception_hex": interception_result.hex
		}

	return {
		"success": true,
		"target_hex": target_hex,
		"receiver": receiver,
		"roll": roll
	}


## Execute a through ball (2 AP, uses vision)
static func execute_through_ball(passer: PlayerUnit, target_hex: Vector2i,
								  defenders: Array[PlayerUnit], match_data: MatchData) -> Dictionary:
	var ap_cost = AP_COST["through_ball"]

	if passer.action_points < ap_cost:
		return {"success": false, "reason": "insufficient_ap"}

	if not passer.has_ball:
		return {"success": false, "reason": "no_ball"}

	passer.spend_ap(ap_cost)

	# Through balls use PAS + MEN (vision)
	var pass_stat = passer.get_passing_stat()
	var men_stat = passer.get_stat("MEN")
	var combined_stat = int(pass_stat * 0.6 + men_stat * 0.4)

	var distance = HexUtils.hex_distance(passer.hex_position, target_hex)
	var base_difficulty = 0.4 + (distance * 0.04)

	var roll = StatSystem.roll_action_success(combined_stat, 0, base_difficulty)

	# Check for interception (through balls are harder to intercept)
	var interception_result = _check_interception(passer.hex_position, target_hex, defenders, 0.7)

	if match_data:
		match_data.record_event("pass", {
			"is_player": passer.is_player_controlled,
			"successful": roll.success and not interception_result.intercepted,
			"through_ball": true,
			"distance": distance
		})

	if not roll.success:
		var miss_hex = _calculate_miss_location(passer.hex_position, target_hex, roll.margin)
		return {
			"success": false,
			"reason": "inaccurate",
			"miss_hex": miss_hex,
			"roll": roll
		}

	if interception_result.intercepted:
		return {
			"success": false,
			"reason": "intercepted",
			"interceptor": interception_result.interceptor,
			"interception_hex": interception_result.hex
		}

	return {
		"success": true,
		"target_hex": target_hex,
		"roll": roll,
		"critical": roll.critical
	}


## Execute a shot
static func execute_shot(shooter: PlayerUnit, goal_hex: Vector2i,
						  goalkeeper: PlayerUnit, blockers: Array[PlayerUnit],
						  match_data: MatchData) -> Dictionary:
	var ap_cost = AP_COST["shoot"]

	if shooter.action_points < ap_cost:
		return {"success": false, "reason": "insufficient_ap"}

	if not shooter.has_ball:
		return {"success": false, "reason": "no_ball"}

	shooter.spend_ap(ap_cost)

	var shot_stat = shooter.get_shooting_stat()
	var distance = HexUtils.hex_distance(shooter.hex_position, goal_hex)
	var difficulty = HexUtils.calculate_shot_difficulty(shooter.hex_position, goal_hex)

	# Check for shot blocks first
	var block_result = _check_shot_block(shooter.hex_position, goal_hex, blockers)

	if block_result.blocked:
		if match_data:
			match_data.record_event("shot", {
				"is_player": shooter.is_player_controlled,
				"on_target": false,
				"blocked": true
			})
		return {
			"success": false,
			"reason": "blocked",
			"blocker": block_result.blocker,
			"block_hex": block_result.hex
		}

	# Roll for shot accuracy
	var shot_roll = StatSystem.roll_action_success(shot_stat, 0, difficulty)

	if not shot_roll.success:
		# Shot missed target
		if match_data:
			match_data.record_event("shot", {
				"is_player": shooter.is_player_controlled,
				"on_target": false
			})
		return {
			"success": false,
			"reason": "off_target",
			"roll": shot_roll
		}

	# Shot is on target - goalkeeper save attempt
	var gk_stat = goalkeeper.get_goalkeeping_stat() if goalkeeper else 30
	var save_difficulty = 0.5 - (shot_roll.margin / 100.0)  # Better shots are harder to save

	if shot_roll.critical:
		save_difficulty += 0.2  # Critical shots are much harder to save

	var save_roll = StatSystem.roll_action_success(gk_stat, 0, save_difficulty)

	if match_data:
		match_data.record_event("shot", {
			"is_player": shooter.is_player_controlled,
			"on_target": true
		})

	if save_roll.success:
		return {
			"success": false,
			"reason": "saved",
			"goalkeeper": goalkeeper,
			"shot_roll": shot_roll,
			"save_roll": save_roll
		}

	# GOAL!
	if match_data:
		match_data.record_event("goal", {
			"is_player": shooter.is_player_controlled,
			"distance": distance
		})

	return {
		"success": true,
		"goal": true,
		"shot_roll": shot_roll,
		"distance": distance,
		"critical": shot_roll.critical
	}


## Execute a dribble (contested move past a defender)
static func execute_dribble(dribbler: PlayerUnit, target_hex: Vector2i,
							 defender: PlayerUnit, match_data: MatchData) -> Dictionary:
	var ap_cost = AP_COST["dribble"]

	if dribbler.action_points < ap_cost:
		return {"success": false, "reason": "insufficient_ap"}

	if not dribbler.has_ball:
		return {"success": false, "reason": "no_ball"}

	dribbler.spend_ap(ap_cost)

	var dribble_stat = dribbler.get_dribbling_stat()
	var defend_stat = defender.get_tackling_stat() if defender else 30

	var roll = StatSystem.roll_action_success(dribble_stat, defend_stat)

	if match_data:
		match_data.record_event("dribble", {
			"is_player": dribbler.is_player_controlled,
			"successful": roll.success
		})

	if not roll.success:
		# Lost the ball
		return {
			"success": false,
			"reason": "dispossessed",
			"defender": defender,
			"roll": roll
		}

	return {
		"success": true,
		"target_hex": target_hex,
		"roll": roll,
		"beat_defender": true
	}


## Execute a tackle
static func execute_tackle(tackler: PlayerUnit, target: PlayerUnit,
							match_data: MatchData) -> Dictionary:
	var ap_cost = AP_COST["tackle"]

	if tackler.action_points < ap_cost:
		return {"success": false, "reason": "insufficient_ap"}

	if not target.has_ball:
		return {"success": false, "reason": "target_no_ball"}

	# Must be adjacent
	var distance = HexUtils.hex_distance(tackler.hex_position, target.hex_position)
	if distance > 1:
		return {"success": false, "reason": "too_far"}

	tackler.spend_ap(ap_cost)

	var tackle_stat = tackler.get_tackling_stat()
	var dribble_stat = target.get_dribbling_stat()

	var roll = StatSystem.roll_action_success(tackle_stat, dribble_stat)

	# Check for foul
	var foul_roll = randf()
	var foul_chance = FOUL_BASE_CHANCE
	if not roll.success:
		foul_chance += 0.15  # Failed tackles more likely to be fouls

	var is_foul = foul_roll < foul_chance
	var card: String = ""

	if is_foul:
		var card_roll = randf()
		if card_roll < 0.02:
			card = "red"
		elif card_roll < 0.15:
			card = "yellow"

		if match_data:
			match_data.record_event("foul_committed", {
				"is_player": tackler.is_player_controlled
			})
			if card == "yellow":
				match_data.record_event("yellow_card", {
					"is_player": tackler.is_player_controlled
				})
			elif card == "red":
				match_data.record_event("red_card", {
					"is_player": tackler.is_player_controlled
				})

	if match_data:
		match_data.record_event("tackle", {
			"is_player": tackler.is_player_controlled,
			"successful": roll.success and not is_foul
		})

	if is_foul:
		return {
			"success": false,
			"reason": "foul",
			"card": card,
			"free_kick_hex": target.hex_position,
			"roll": roll
		}

	if not roll.success:
		return {
			"success": false,
			"reason": "failed",
			"roll": roll
		}

	return {
		"success": true,
		"won_ball": true,
		"target": target,
		"roll": roll
	}


## Check if a pass can be intercepted
static func _check_interception(from: Vector2i, to: Vector2i,
								 defenders: Array[PlayerUnit],
								 difficulty_modifier: float = 1.0) -> Dictionary:
	var pass_line = HexUtils.get_hex_line(from, to)

	for defender in defenders:
		for hex in pass_line:
			if HexUtils.hex_distance(hex, defender.hex_position) <= 1:
				# Defender can attempt interception
				var interception_stat = defender.get_stat("DEF") * 0.5 + defender.get_stat("MEN") * 0.5
				var roll = StatSystem.roll_action_success(int(interception_stat), 0, 0.6 * difficulty_modifier)

				if roll.success:
					return {
						"intercepted": true,
						"interceptor": defender,
						"hex": hex
					}

	return {"intercepted": false}


## Check if a shot can be blocked
static func _check_shot_block(from: Vector2i, to: Vector2i,
							   blockers: Array[PlayerUnit]) -> Dictionary:
	var shot_line = HexUtils.get_hex_line(from, to)

	for blocker in blockers:
		for hex in shot_line:
			if hex == blocker.hex_position:
				# Blocker is directly in the way
				var block_stat = blocker.get_stat("DEF")
				var roll = StatSystem.roll_action_success(block_stat, 0, 0.5)

				if roll.success:
					return {
						"blocked": true,
						"blocker": blocker,
						"hex": hex
					}

	return {"blocked": false}


## Calculate where a missed pass lands
static func _calculate_miss_location(from: Vector2i, intended: Vector2i, margin: float) -> Vector2i:
	var direction = Vector2(intended.x - from.x, intended.y - from.y)
	var perpendicular = Vector2(-direction.y, direction.x).normalized()

	# Larger negative margin = bigger miss
	var miss_amount = abs(margin) / 20.0
	var side = 1 if randf() > 0.5 else -1

	var miss_offset = perpendicular * miss_amount * side
	var miss_hex = Vector2i(
		intended.x + roundi(miss_offset.x),
		intended.y + roundi(miss_offset.y)
	)

	# Clamp to valid grid
	miss_hex.x = clampi(miss_hex.x, 0, HexUtils.GRID_WIDTH - 1)
	miss_hex.y = clampi(miss_hex.y, 0, HexUtils.GRID_HEIGHT - 1)

	return miss_hex
