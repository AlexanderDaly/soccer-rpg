extends RefCounted
class_name TeammateAI
## TeammateAI - Controls friendly AI units during the team phase

# AI behavior weights based on position
const POSITION_BEHAVIORS = {
	"GK": {"stay": 0.9, "position": 0.1, "support": 0.0},
	"CB": {"stay": 0.4, "position": 0.5, "support": 0.1},
	"FB": {"stay": 0.2, "position": 0.4, "support": 0.4},
	"CDM": {"stay": 0.3, "position": 0.4, "support": 0.3},
	"CM": {"stay": 0.2, "position": 0.3, "support": 0.5},
	"CAM": {"stay": 0.1, "position": 0.3, "support": 0.6},
	"WNG": {"stay": 0.1, "position": 0.3, "support": 0.6},
	"ST": {"stay": 0.1, "position": 0.2, "support": 0.7}
}


## Determine and execute AI action for a teammate
static func take_turn(unit: PlayerUnit, ball: BallController,
					   all_units: Array[PlayerUnit], match_data: MatchData,
					   attacking_right: bool) -> Dictionary:
	if unit.action_points <= 0:
		return {"action": "none", "reason": "no_ap"}

	var has_ball = unit.has_ball
	var team_has_possession = _team_has_possession(unit, ball, all_units)

	if has_ball:
		return _decide_with_ball(unit, ball, all_units, match_data, attacking_right)
	elif team_has_possession:
		return _decide_support_play(unit, ball, all_units, attacking_right)
	else:
		return _decide_defensive_position(unit, ball, all_units, attacking_right)


## Decide action when this unit has the ball
static func _decide_with_ball(unit: PlayerUnit, ball: BallController,
							   all_units: Array[PlayerUnit], match_data: MatchData,
							   attacking_right: bool) -> Dictionary:
	var goal_hex = HexUtils.get_goal_hex(attacking_right)
	var distance_to_goal = HexUtils.hex_distance(unit.hex_position, goal_hex)

	# Get teammates and opponents
	var teammates = _get_teammates(unit, all_units)
	var opponents = _get_opponents(unit, all_units)

	# Check for shooting opportunity (close to goal)
	if distance_to_goal <= 5 and unit.action_points >= 2:
		var blockers = _get_units_in_path(unit.hex_position, goal_hex, opponents)
		if blockers.size() <= 1:
			return {
				"action": "shoot",
				"target": goal_hex,
				"reason": "shooting_opportunity"
			}

	# Check for under pressure (opponent adjacent)
	var pressure = _check_pressure(unit, opponents)

	if pressure.under_pressure:
		# Look for a safe pass
		var pass_option = _find_best_pass(unit, teammates, opponents)
		if pass_option.found:
			return {
				"action": "pass",
				"target": pass_option.target,
				"receiver": pass_option.receiver,
				"reason": "release_pressure"
			}

	# Look for forward pass option
	var forward_pass = _find_forward_pass(unit, teammates, opponents, attacking_right)
	if forward_pass.found:
		return {
			"action": "pass",
			"target": forward_pass.target,
			"receiver": forward_pass.receiver,
			"reason": "forward_pass"
		}

	# Simple pass to nearest teammate
	var simple_pass = _find_best_pass(unit, teammates, opponents)
	if simple_pass.found:
		return {
			"action": "pass",
			"target": simple_pass.target,
			"receiver": simple_pass.receiver,
			"reason": "keep_possession"
		}

	# Move forward if no pass
	var move_target = _get_forward_move(unit, all_units, attacking_right)
	if move_target != unit.hex_position:
		return {
			"action": "move",
			"target": move_target,
			"reason": "carry_ball_forward"
		}

	return {"action": "none", "reason": "no_good_option"}


## Decide support positioning when teammate has ball
static func _decide_support_play(unit: PlayerUnit, ball: BallController,
								  all_units: Array[PlayerUnit],
								  attacking_right: bool) -> Dictionary:
	var ball_carrier = ball.get_possessing_unit()
	if not ball_carrier:
		return {"action": "none", "reason": "no_ball_carrier"}

	var behaviors = POSITION_BEHAVIORS.get(unit.position_role, POSITION_BEHAVIORS["CM"])
	var roll = randf()

	var opponents = _get_opponents(unit, all_units)
	var occupied = _get_occupied_hexes(all_units)

	if roll < behaviors.stay:
		# Stay in position
		return {"action": "none", "reason": "hold_position"}

	if roll < behaviors.stay + behaviors.position:
		# Move to better position
		var formation_hex = _get_formation_position(unit, attacking_right)
		if formation_hex != unit.hex_position and formation_hex not in occupied:
			return {
				"action": "move",
				"target": formation_hex,
				"reason": "formation_position"
			}

	# Make a support run
	var support_hex = _find_support_position(unit, ball_carrier, opponents, occupied, attacking_right)
	if support_hex != unit.hex_position:
		return {
			"action": "move",
			"target": support_hex,
			"reason": "support_run"
		}

	return {"action": "none", "reason": "no_movement_needed"}


## Decide defensive positioning
static func _decide_defensive_position(unit: PlayerUnit, ball: BallController,
										all_units: Array[PlayerUnit],
										attacking_right: bool) -> Dictionary:
	var ball_hex = ball.hex_position
	var opponents = _get_opponents(unit, all_units)
	var occupied = _get_occupied_hexes(all_units)

	# Get formation position
	var formation_hex = _get_formation_position(unit, not attacking_right)  # Flip for defense

	# Goalkeepers stay in goal
	if unit.is_goalkeeper():
		var goal_hex = HexUtils.HOME_GOAL_HEX if attacking_right else HexUtils.AWAY_GOAL_HEX
		if unit.hex_position != Vector2i(goal_hex.x + (1 if attacking_right else -1), goal_hex.y):
			return {
				"action": "move",
				"target": Vector2i(goal_hex.x + (1 if attacking_right else -1), goal_hex.y),
				"reason": "return_to_goal"
			}
		return {"action": "none", "reason": "in_goal"}

	# Defenders track the ball
	if unit.position_role in ["CB", "FB", "CDM"]:
		var intercept_hex = _find_intercept_position(unit, ball_hex, opponents, occupied, attacking_right)
		if intercept_hex != unit.hex_position:
			return {
				"action": "move",
				"target": intercept_hex,
				"reason": "track_ball"
			}

	# Return to formation
	if formation_hex != unit.hex_position and formation_hex not in occupied:
		var path = HexUtils.find_path(unit.hex_position, formation_hex, occupied)
		if path.size() > 1:
			var move_range = unit.get_move_range()
			var target_index = min(move_range, path.size() - 1)
			return {
				"action": "move",
				"target": path[target_index],
				"reason": "return_to_formation"
			}

	return {"action": "none", "reason": "in_position"}


## Helper functions

static func _team_has_possession(unit: PlayerUnit, ball: BallController,
								  all_units: Array[PlayerUnit]) -> bool:
	if ball.is_possessed():
		var possessor = ball.get_possessing_unit()
		return possessor and possessor.is_home_team == unit.is_home_team
	return false


static func _get_teammates(unit: PlayerUnit, all_units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var teammates: Array[PlayerUnit] = []
	for other in all_units:
		if other != unit and other.is_home_team == unit.is_home_team:
			teammates.append(other)
	return teammates


static func _get_opponents(unit: PlayerUnit, all_units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var opponents: Array[PlayerUnit] = []
	for other in all_units:
		if other.is_home_team != unit.is_home_team:
			opponents.append(other)
	return opponents


static func _get_occupied_hexes(all_units: Array[PlayerUnit]) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for unit in all_units:
		occupied.append(unit.hex_position)
	return occupied


static func _check_pressure(unit: PlayerUnit, opponents: Array[PlayerUnit]) -> Dictionary:
	for opponent in opponents:
		if HexUtils.hex_distance(unit.hex_position, opponent.hex_position) <= 1:
			return {"under_pressure": true, "presser": opponent}
	return {"under_pressure": false}


static func _find_best_pass(passer: PlayerUnit, teammates: Array[PlayerUnit],
							 opponents: Array[PlayerUnit]) -> Dictionary:
	var best_target: PlayerUnit = null
	var best_score: float = -1.0

	for teammate in teammates:
		if teammate.is_goalkeeper():
			continue

		var distance = HexUtils.hex_distance(passer.hex_position, teammate.hex_position)
		if distance < 2 or distance > 10:
			continue

		# Score based on openness
		var openness = _calculate_openness(teammate, opponents)
		var score = openness - (distance * 0.1)

		if score > best_score:
			best_score = score
			best_target = teammate

	if best_target:
		return {"found": true, "target": best_target.hex_position, "receiver": best_target}
	return {"found": false}


static func _find_forward_pass(passer: PlayerUnit, teammates: Array[PlayerUnit],
								opponents: Array[PlayerUnit], attacking_right: bool) -> Dictionary:
	var best_target: PlayerUnit = null
	var best_score: float = -1.0
	var forward_dir = 1 if attacking_right else -1

	for teammate in teammates:
		var x_diff = (teammate.hex_position.x - passer.hex_position.x) * forward_dir
		if x_diff <= 0:
			continue  # Not forward

		var distance = HexUtils.hex_distance(passer.hex_position, teammate.hex_position)
		if distance < 2 or distance > 12:
			continue

		var openness = _calculate_openness(teammate, opponents)
		var score = openness + (x_diff * 0.2)

		if score > best_score:
			best_score = score
			best_target = teammate

	if best_target and best_score > 0.3:
		return {"found": true, "target": best_target.hex_position, "receiver": best_target}
	return {"found": false}


static func _calculate_openness(unit: PlayerUnit, opponents: Array[PlayerUnit]) -> float:
	var min_distance = 100.0
	for opponent in opponents:
		var dist = HexUtils.hex_distance(unit.hex_position, opponent.hex_position)
		min_distance = min(min_distance, dist)
	return min_distance / 10.0


static func _get_forward_move(unit: PlayerUnit, all_units: Array[PlayerUnit],
							   attacking_right: bool) -> Vector2i:
	var forward_dir = 1 if attacking_right else -1
	var occupied = _get_occupied_hexes(all_units)
	var move_range = unit.get_move_range()

	var best_hex = unit.hex_position
	var best_forward = 0

	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)
	for hex in reachable:
		var forward_gain = (hex.x - unit.hex_position.x) * forward_dir
		if forward_gain > best_forward:
			best_forward = forward_gain
			best_hex = hex

	return best_hex


static func _get_formation_position(unit: PlayerUnit, attacking_right: bool) -> Vector2i:
	# Simplified formation positioning
	var base_positions = HexUtils.get_formation_positions("4-4-2", unit.is_home_team == attacking_right)

	for pos_data in base_positions:
		if pos_data.position == unit.position_role:
			return pos_data.hex

	return unit.hex_position


static func _find_support_position(unit: PlayerUnit, ball_carrier: PlayerUnit,
									opponents: Array[PlayerUnit], occupied: Array[Vector2i],
									attacking_right: bool) -> Vector2i:
	var forward_dir = 1 if attacking_right else -1
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	var best_hex = unit.hex_position
	var best_score = -1.0

	for hex in reachable:
		# Score based on: distance to ball carrier, forward position, openness
		var dist_to_ball = HexUtils.hex_distance(hex, ball_carrier.hex_position)
		if dist_to_ball < 3 or dist_to_ball > 8:
			continue

		var forward_gain = (hex.x - unit.hex_position.x) * forward_dir
		var openness = 10.0
		for opp in opponents:
			openness = min(openness, HexUtils.hex_distance(hex, opp.hex_position))

		var score = openness + forward_gain * 0.5 - abs(dist_to_ball - 5) * 0.3

		if score > best_score:
			best_score = score
			best_hex = hex

	return best_hex


static func _find_intercept_position(unit: PlayerUnit, ball_hex: Vector2i,
									  opponents: Array[PlayerUnit], occupied: Array[Vector2i],
									  attacking_right: bool) -> Vector2i:
	var own_goal = HexUtils.HOME_GOAL_HEX if attacking_right else HexUtils.AWAY_GOAL_HEX
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	var best_hex = unit.hex_position
	var best_score = -1.0

	for hex in reachable:
		# Position between ball and own goal
		var ball_to_goal = HexUtils.hex_distance(ball_hex, own_goal)
		var hex_to_goal = HexUtils.hex_distance(hex, own_goal)
		var hex_to_ball = HexUtils.hex_distance(hex, ball_hex)

		# Good if we're between ball and goal
		var is_between = hex_to_ball + hex_to_goal <= ball_to_goal + 2

		var score = 0.0
		if is_between:
			score = 10.0 - hex_to_ball * 0.5

		if score > best_score:
			best_score = score
			best_hex = hex

	return best_hex


static func _get_units_in_path(from: Vector2i, to: Vector2i,
								units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var line = HexUtils.get_hex_line(from, to)
	var blocking: Array[PlayerUnit] = []

	for unit in units:
		if unit.hex_position in line:
			blocking.append(unit)

	return blocking
