extends RefCounted
class_name OpponentAI
## OpponentAI - Controls opponent units during the opponent phase

# AI behavior based on tactics
const MENTALITY_MODIFIERS = {
	"defensive": {"press_range": 3, "hold_line": 0.7, "shoot_threshold": 4},
	"balanced": {"press_range": 5, "hold_line": 0.5, "shoot_threshold": 5},
	"attacking": {"press_range": 7, "hold_line": 0.3, "shoot_threshold": 6},
	"all-out-attack": {"press_range": 10, "hold_line": 0.1, "shoot_threshold": 8}
}


## Determine and execute AI action for an opponent
static func take_turn(unit: PlayerUnit, ball: BallController,
					   all_units: Array[PlayerUnit], match_data: MatchData,
					   tactics: Dictionary, attacking_right: bool) -> Dictionary:
	if unit.action_points <= 0:
		return {"action": "none", "reason": "no_ap"}

	var mentality = tactics.get("mentality", "balanced")
	var modifiers = MENTALITY_MODIFIERS.get(mentality, MENTALITY_MODIFIERS["balanced"])

	var has_ball = unit.has_ball
	var team_has_possession = _team_has_possession(unit, ball, all_units)

	if has_ball:
		return _decide_with_ball(unit, ball, all_units, match_data, modifiers, attacking_right)
	elif team_has_possession:
		return _decide_support_play(unit, ball, all_units, modifiers, attacking_right)
	else:
		return _decide_defensive_action(unit, ball, all_units, match_data, modifiers, attacking_right)


## AI decision when in possession
static func _decide_with_ball(unit: PlayerUnit, ball: BallController,
							   all_units: Array[PlayerUnit], match_data: MatchData,
							   modifiers: Dictionary, attacking_right: bool) -> Dictionary:
	var goal_hex = HexUtils.get_goal_hex(attacking_right)
	var distance_to_goal = HexUtils.hex_distance(unit.hex_position, goal_hex)

	var teammates = _get_teammates(unit, all_units)
	var opponents = _get_opponents(unit, all_units)

	# Shooting decision
	if distance_to_goal <= modifiers.shoot_threshold and unit.action_points >= 2:
		var blockers = _get_blocking_units(unit.hex_position, goal_hex, opponents)
		var gk = _find_goalkeeper(opponents)

		# Higher chance to shoot when close
		var shoot_chance = 1.0 - (distance_to_goal / 10.0)
		if blockers.size() <= 1 and randf() < shoot_chance:
			return {
				"action": "shoot",
				"target": goal_hex,
				"reason": "shooting_chance"
			}

	# Check for pressure
	var nearest_opponent = _find_nearest_opponent(unit, opponents)
	var under_pressure = nearest_opponent and HexUtils.hex_distance(unit.hex_position, nearest_opponent.hex_position) <= 2

	if under_pressure:
		# Quick pass to release pressure
		var pass_option = _find_safe_pass(unit, teammates, opponents)
		if pass_option.found:
			return {
				"action": "pass",
				"target": pass_option.target,
				"receiver": pass_option.receiver,
				"reason": "escape_pressure"
			}

		# Try to dribble past
		if unit.action_points >= 1:
			var dribble_target = _find_dribble_escape(unit, nearest_opponent, all_units, attacking_right)
			if dribble_target != unit.hex_position:
				return {
					"action": "dribble",
					"target": dribble_target,
					"defender": nearest_opponent,
					"reason": "dribble_escape"
				}

	# Look for through ball opportunity
	if unit.action_points >= 2:
		var through_ball = _find_through_ball(unit, teammates, opponents, attacking_right)
		if through_ball.found:
			return {
				"action": "through_ball",
				"target": through_ball.target,
				"reason": "through_ball_opportunity"
			}

	# Standard forward pass
	var forward_pass = _find_forward_pass(unit, teammates, opponents, attacking_right)
	if forward_pass.found:
		return {
			"action": "pass",
			"target": forward_pass.target,
			"receiver": forward_pass.receiver,
			"reason": "progress_ball"
		}

	# Carry ball forward
	if unit.action_points >= 1:
		var move_target = _find_forward_space(unit, all_units, attacking_right)
		if move_target != unit.hex_position:
			return {
				"action": "move",
				"target": move_target,
				"reason": "carry_forward"
			}

	# Safe sideways/backward pass
	var safe_pass = _find_safe_pass(unit, teammates, opponents)
	if safe_pass.found:
		return {
			"action": "pass",
			"target": safe_pass.target,
			"receiver": safe_pass.receiver,
			"reason": "retain_possession"
		}

	return {"action": "none", "reason": "no_option"}


## AI support movement when teammate has ball
static func _decide_support_play(unit: PlayerUnit, ball: BallController,
								  all_units: Array[PlayerUnit],
								  modifiers: Dictionary, attacking_right: bool) -> Dictionary:
	if unit.is_goalkeeper():
		return {"action": "none", "reason": "goalkeeper"}

	var ball_carrier = ball.get_possessing_unit()
	if not ball_carrier:
		return {"action": "none", "reason": "no_carrier"}

	var opponents = _get_opponents(unit, all_units)
	var occupied = _get_occupied_hexes(all_units)

	# Make a run to create space or receive pass
	var run_target = _calculate_support_run(unit, ball_carrier, opponents, occupied, attacking_right)

	if run_target != unit.hex_position:
		return {
			"action": "move",
			"target": run_target,
			"reason": "support_run"
		}

	return {"action": "none", "reason": "hold_position"}


## AI defensive action when opponent has ball
static func _decide_defensive_action(unit: PlayerUnit, ball: BallController,
									  all_units: Array[PlayerUnit], match_data: MatchData,
									  modifiers: Dictionary, attacking_right: bool) -> Dictionary:
	var ball_hex = ball.hex_position
	var ball_carrier = ball.get_possessing_unit()
	var opponents = _get_opponents(unit, all_units)
	var occupied = _get_occupied_hexes(all_units)

	var own_goal = HexUtils.HOME_GOAL_HEX if not attacking_right else HexUtils.AWAY_GOAL_HEX
	var dist_to_ball = HexUtils.hex_distance(unit.hex_position, ball_hex)

	# Goalkeeper positioning
	if unit.is_goalkeeper():
		var gk_position = _calculate_gk_position(ball_hex, own_goal)
		if gk_position != unit.hex_position and gk_position not in occupied:
			return {
				"action": "move",
				"target": gk_position,
				"reason": "gk_positioning"
			}
		return {"action": "none", "reason": "gk_set"}

	# Tackle if adjacent to ball carrier
	if ball_carrier and HexUtils.hex_distance(unit.hex_position, ball_carrier.hex_position) == 1:
		if unit.action_points >= 1:
			return {
				"action": "tackle",
				"target": ball_carrier,
				"reason": "tackle_opportunity"
			}

	# Press the ball if in press range
	if dist_to_ball <= modifiers.press_range:
		var press_target = _calculate_press_position(unit, ball_hex, occupied, own_goal)
		if press_target != unit.hex_position:
			return {
				"action": "move",
				"target": press_target,
				"reason": "press_ball"
			}

	# Hold defensive line
	if randf() < modifiers.hold_line:
		var defensive_position = _calculate_defensive_position(unit, ball_hex, own_goal, occupied, attacking_right)
		if defensive_position != unit.hex_position:
			return {
				"action": "move",
				"target": defensive_position,
				"reason": "defensive_shape"
			}

	# Track nearest attacker
	var nearest_attacker = _find_nearest_attacker_to_mark(unit, opponents, all_units)
	if nearest_attacker:
		var mark_position = _calculate_marking_position(unit, nearest_attacker, own_goal, occupied)
		if mark_position != unit.hex_position:
			return {
				"action": "move",
				"target": mark_position,
				"reason": "mark_player"
			}

	return {"action": "none", "reason": "hold"}


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
	for u in all_units:
		occupied.append(u.hex_position)
	return occupied


static func _find_goalkeeper(units: Array[PlayerUnit]) -> PlayerUnit:
	for unit in units:
		if unit.is_goalkeeper():
			return unit
	return null


static func _find_nearest_opponent(unit: PlayerUnit, opponents: Array[PlayerUnit]) -> PlayerUnit:
	var nearest: PlayerUnit = null
	var min_dist: int = 100

	for opp in opponents:
		var dist = HexUtils.hex_distance(unit.hex_position, opp.hex_position)
		if dist < min_dist:
			min_dist = dist
			nearest = opp

	return nearest


static func _get_blocking_units(from: Vector2i, to: Vector2i,
								 units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var line = HexUtils.get_hex_line(from, to)
	var blocking: Array[PlayerUnit] = []

	for unit in units:
		if unit.hex_position in line:
			blocking.append(unit)

	return blocking


static func _find_safe_pass(passer: PlayerUnit, teammates: Array[PlayerUnit],
							 opponents: Array[PlayerUnit]) -> Dictionary:
	var best: PlayerUnit = null
	var best_score: float = -1.0

	for tm in teammates:
		if tm.is_goalkeeper():
			continue

		var dist = HexUtils.hex_distance(passer.hex_position, tm.hex_position)
		if dist < 2 or dist > 8:
			continue

		var nearest_opp_dist = 100.0
		for opp in opponents:
			nearest_opp_dist = min(nearest_opp_dist, HexUtils.hex_distance(tm.hex_position, opp.hex_position))

		var score = nearest_opp_dist - dist * 0.2

		if score > best_score:
			best_score = score
			best = tm

	if best:
		return {"found": true, "target": best.hex_position, "receiver": best}
	return {"found": false}


static func _find_forward_pass(passer: PlayerUnit, teammates: Array[PlayerUnit],
								opponents: Array[PlayerUnit], attacking_right: bool) -> Dictionary:
	var forward_dir = 1 if attacking_right else -1
	var best: PlayerUnit = null
	var best_score: float = -1.0

	for tm in teammates:
		var x_diff = (tm.hex_position.x - passer.hex_position.x) * forward_dir
		if x_diff <= 0:
			continue

		var dist = HexUtils.hex_distance(passer.hex_position, tm.hex_position)
		if dist > 10:
			continue

		var openness = 100.0
		for opp in opponents:
			openness = min(openness, HexUtils.hex_distance(tm.hex_position, opp.hex_position))

		var score = x_diff * 0.5 + openness * 0.3 - dist * 0.1

		if score > best_score:
			best_score = score
			best = tm

	if best and best_score > 0:
		return {"found": true, "target": best.hex_position, "receiver": best}
	return {"found": false}


static func _find_through_ball(passer: PlayerUnit, teammates: Array[PlayerUnit],
								opponents: Array[PlayerUnit], attacking_right: bool) -> Dictionary:
	var forward_dir = 1 if attacking_right else -1
	var goal_hex = HexUtils.get_goal_hex(attacking_right)

	for tm in teammates:
		# Through ball target should be ahead of teammate
		var through_target = Vector2i(
			tm.hex_position.x + forward_dir * 3,
			tm.hex_position.y
		)

		if not HexUtils.is_valid_hex(through_target):
			continue

		var dist_to_goal = HexUtils.hex_distance(through_target, goal_hex)
		if dist_to_goal > 8:
			continue

		# Check if space is clear
		var clear = true
		for opp in opponents:
			if HexUtils.hex_distance(through_target, opp.hex_position) < 2:
				clear = false
				break

		if clear:
			return {"found": true, "target": through_target}

	return {"found": false}


static func _find_dribble_escape(unit: PlayerUnit, defender: PlayerUnit,
								  all_units: Array[PlayerUnit], attacking_right: bool) -> Vector2i:
	var forward_dir = 1 if attacking_right else -1
	var occupied = _get_occupied_hexes(all_units)
	occupied.erase(unit.hex_position)

	var neighbors = HexUtils.get_neighbors(unit.hex_position)
	var best_hex = unit.hex_position
	var best_score = -100.0

	for hex in neighbors:
		if hex in occupied:
			continue

		var away_from_defender = HexUtils.hex_distance(hex, defender.hex_position)
		var forward_progress = (hex.x - unit.hex_position.x) * forward_dir

		var score = away_from_defender + forward_progress * 0.5

		if score > best_score:
			best_score = score
			best_hex = hex

	return best_hex


static func _find_forward_space(unit: PlayerUnit, all_units: Array[PlayerUnit],
								 attacking_right: bool) -> Vector2i:
	var forward_dir = 1 if attacking_right else -1
	var occupied = _get_occupied_hexes(all_units)
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	var best_hex = unit.hex_position
	var best_forward = 0

	for hex in reachable:
		var forward = (hex.x - unit.hex_position.x) * forward_dir
		if forward > best_forward:
			best_forward = forward
			best_hex = hex

	return best_hex


static func _calculate_support_run(unit: PlayerUnit, ball_carrier: PlayerUnit,
									opponents: Array[PlayerUnit], occupied: Array[Vector2i],
									attacking_right: bool) -> Vector2i:
	var forward_dir = 1 if attacking_right else -1
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	var best_hex = unit.hex_position
	var best_score = -100.0

	for hex in reachable:
		var dist_to_carrier = HexUtils.hex_distance(hex, ball_carrier.hex_position)
		if dist_to_carrier < 3 or dist_to_carrier > 8:
			continue

		var forward = (hex.x - unit.hex_position.x) * forward_dir
		var openness = 100.0
		for opp in opponents:
			openness = min(openness, HexUtils.hex_distance(hex, opp.hex_position))

		var score = forward * 0.3 + openness * 0.5

		if score > best_score:
			best_score = score
			best_hex = hex

	return best_hex


static func _calculate_gk_position(ball_hex: Vector2i, goal_hex: Vector2i) -> Vector2i:
	# Position between ball and center of goal
	var ideal_x = goal_hex.x + sign(ball_hex.x - goal_hex.x)
	var ideal_y = clampi(ball_hex.y, goal_hex.y - 2, goal_hex.y + 2)
	return Vector2i(clampi(ideal_x, 0, HexUtils.GRID_WIDTH - 1), ideal_y)


static func _calculate_press_position(unit: PlayerUnit, ball_hex: Vector2i,
									   occupied: Array[Vector2i], own_goal: Vector2i) -> Vector2i:
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	var best_hex = unit.hex_position
	var best_dist = HexUtils.hex_distance(unit.hex_position, ball_hex)

	for hex in reachable:
		var dist = HexUtils.hex_distance(hex, ball_hex)
		if dist < best_dist:
			best_dist = dist
			best_hex = hex

	return best_hex


static func _calculate_defensive_position(unit: PlayerUnit, ball_hex: Vector2i,
										   own_goal: Vector2i, occupied: Array[Vector2i],
										   attacking_right: bool) -> Vector2i:
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	# Get between ball and goal
	var ball_to_goal = HexUtils.get_hex_line(ball_hex, own_goal)

	var best_hex = unit.hex_position
	var best_score = -100.0

	for hex in reachable:
		var on_line = hex in ball_to_goal
		var dist_to_goal = HexUtils.hex_distance(hex, own_goal)
		var dist_to_ball = HexUtils.hex_distance(hex, ball_hex)

		var score = 0.0
		if on_line:
			score += 5.0
		score -= dist_to_ball * 0.1
		score -= dist_to_goal * 0.05

		if score > best_score:
			best_score = score
			best_hex = hex

	return best_hex


static func _find_nearest_attacker_to_mark(unit: PlayerUnit, opponents: Array[PlayerUnit],
											all_units: Array[PlayerUnit]) -> PlayerUnit:
	# Find an attacker not already marked
	var marked_players: Array[Vector2i] = []

	for teammate in all_units:
		if teammate.is_home_team == unit.is_home_team and teammate != unit:
			# Check if this teammate is marking someone
			for opp in opponents:
				if HexUtils.hex_distance(teammate.hex_position, opp.hex_position) <= 2:
					marked_players.append(opp.hex_position)

	var nearest: PlayerUnit = null
	var min_dist = 100

	for opp in opponents:
		if opp.is_goalkeeper():
			continue
		if opp.hex_position in marked_players:
			continue

		var dist = HexUtils.hex_distance(unit.hex_position, opp.hex_position)
		if dist < min_dist:
			min_dist = dist
			nearest = opp

	return nearest


static func _calculate_marking_position(unit: PlayerUnit, target: PlayerUnit,
										 own_goal: Vector2i, occupied: Array[Vector2i]) -> Vector2i:
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	# Get between target and goal
	var best_hex = unit.hex_position
	var best_score = -100.0

	for hex in reachable:
		var dist_to_target = HexUtils.hex_distance(hex, target.hex_position)
		var target_to_goal = HexUtils.hex_distance(target.hex_position, own_goal)
		var hex_to_goal = HexUtils.hex_distance(hex, own_goal)

		# Good marking position is close to target and between them and goal
		var between_bonus = 0.0
		if hex_to_goal < target_to_goal:
			between_bonus = 3.0

		var score = 10.0 - dist_to_target + between_bonus

		if score > best_score:
			best_score = score
			best_hex = hex

	return best_hex
