extends RefCounted
class_name TeammateAI
## TeammateAI - Intelligent friendly AI that supports the player character
##
## Design Philosophy:
## - Teammates exist to support YOUR story, not steal the spotlight
## - They should make smart decisions that create opportunities for YOU
## - Movement should feel like real soccer: triangles, runs, spacing
## - Context-aware decisions, not random rolls

#region Constants

## Run types that teammates can make
enum RunType {
	NONE,
	OVERLAP,        # Full back running past winger on the outside
	UNDERLAP,       # Running inside, behind the line
	DIAGONAL,       # Cutting across the defense diagonally
	CHECK_TO_BALL,  # Coming short toward the ball to receive
	CHANNEL_RUN,    # Straight run into space between defenders
	DRIFT_WIDE,     # Moving wide to stretch the play
	DROP_DEEP,      # Falling back to receive and recycle
}

## Minimum angle (degrees) between passing options for valid triangle
const MIN_TRIANGLE_ANGLE := 25.0

## Ideal distance range for passing support
const MIN_SUPPORT_DISTANCE := 3
const MAX_SUPPORT_DISTANCE := 8

## How much the formation shifts toward the ball (0.0 - 1.0)
const FORMATION_SHIFT_FACTOR := 0.3

## How much the formation compresses/expands with ball position
const FORMATION_COMPRESS_FACTOR := 0.2

## Distance threshold for "under pressure"
const PRESSURE_DISTANCE := 2

## Distance for "congested" area detection
const CONGESTION_RADIUS := 3
const CONGESTION_THRESHOLD := 4  # Units within radius to be "congested"

#endregion

#region Main Entry Point

## Determine and execute AI action for a teammate
## This is the main entry point called by MatchController
static func take_turn(unit: PlayerUnit, ball: BallController,
					   all_units: Array[PlayerUnit], match_data: MatchData,
					   attacking_right: bool) -> Dictionary:
	if unit.action_points <= 0:
		return {"action": "none", "reason": "no_ap"}
	
	# Find the player character for special support logic
	var player_unit = _find_player_unit(all_units)
	
	# Build rich context for decision making
	var context = _analyze_context(unit, ball, all_units, player_unit, attacking_right)
	
	# Branch based on game state
	if context.has_ball:
		return _decide_with_ball(unit, context)
	elif context.team_has_possession:
		return _decide_support_play(unit, context)
	else:
		return _decide_defensive_action(unit, context)

#endregion

#region Context Analysis

## Build comprehensive context for intelligent decision making
static func _analyze_context(unit: PlayerUnit, ball: BallController,
							  all_units: Array[PlayerUnit], player_unit: PlayerUnit,
							  attacking_right: bool) -> Dictionary:
	var teammates = _get_teammates(unit, all_units)
	var opponents = _get_opponents(unit, all_units)
	var occupied = _get_occupied_hexes(all_units)
	
	var forward_dir = 1 if attacking_right else -1
	var ball_carrier = ball.get_possessing_unit() if ball.is_possessed() else null
	var ball_hex = ball.hex_position
	
	var pitch_center_x = HexUtils.GRID_WIDTH / 2
	var pitch_center_y = HexUtils.GRID_HEIGHT / 2
	
	# Determine possession state
	var has_ball = unit.has_ball
	var team_has_possession = _team_has_possession(unit, ball, all_units)
	
	# Calculate ball progress (negative = own half, positive = attacking half)
	var ball_progress = (ball_hex.x - pitch_center_x) * forward_dir
	
	# Build the context dictionary
	var ctx = {
		# References
		"unit": unit,
		"ball": ball,
		"ball_carrier": ball_carrier,
		"player_unit": player_unit,
		"teammates": teammates,
		"opponents": opponents,
		"occupied": occupied,
		
		# Directional info
		"attacking_right": attacking_right,
		"forward_dir": forward_dir,
		"goal_hex": HexUtils.get_goal_hex(attacking_right),
		"own_goal_hex": HexUtils.get_goal_hex(not attacking_right),
		
		# Possession state
		"has_ball": has_ball,
		"team_has_possession": team_has_possession,
		"player_has_ball": ball_carrier and ball_carrier.is_player_controlled,
		
		# Spatial zones
		"ball_hex": ball_hex,
		"ball_progress": ball_progress,
		"ball_in_own_half": ball_progress < 0,
		"ball_in_middle_third": abs(ball_progress) < pitch_center_x * 0.33,
		"ball_in_final_third": ball_progress > pitch_center_x * 0.33,
		
		# Pitch geometry
		"pitch_center": Vector2i(pitch_center_x, pitch_center_y),
		"play_is_central": abs(ball_hex.y - pitch_center_y) < 3,
		"play_is_wide_left": ball_hex.y < pitch_center_y - 2,
		"play_is_wide_right": ball_hex.y > pitch_center_y + 2,
	}
	
	# Add computed analysis (these depend on the basic context)
	ctx["under_pressure"] = ball_carrier and _is_under_pressure(ball_carrier, opponents)
	ctx["space_ahead"] = _analyze_space_ahead(unit, opponents, attacking_right)
	ctx["midfield_congested"] = _is_area_congested(Vector2i(pitch_center_x, pitch_center_y), all_units)
	ctx["channel_space"] = _analyze_channel_space(unit, opponents, attacking_right)
	ctx["passing_options"] = _get_passing_options(ball_carrier, teammates, opponents) if ball_carrier else []
	ctx["has_triangle_support"] = len(ctx["passing_options"]) >= 2 and _has_valid_triangle(ball_carrier, ctx["passing_options"])
	ctx["unit_is_marked"] = _is_unit_marked(unit, opponents)
	ctx["nearest_opponent"] = _find_nearest_opponent(unit, opponents)
	ctx["distance_to_ball"] = HexUtils.hex_distance(unit.hex_position, ball_hex)
	
	return ctx

#endregion

#region With Ball Decisions

## Decide action when this teammate has the ball
static func _decide_with_ball(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var distance_to_goal = HexUtils.hex_distance(unit.hex_position, ctx.goal_hex)
	
	# Priority 1: Shooting opportunity (close to goal, clear sight)
	if distance_to_goal <= 5 and unit.action_points >= 2:
		var blockers = _get_units_blocking_path(unit.hex_position, ctx.goal_hex, ctx.opponents)
		if blockers.size() <= 1:
			return {
				"action": "shoot",
				"target": ctx.goal_hex,
				"reason": "shooting_opportunity"
			}
	
	# Priority 2: Under pressure - release the ball quickly
	if ctx.under_pressure:
		# Look for the player character first if they're open
		if ctx.player_unit and not _is_unit_marked(ctx.player_unit, ctx.opponents):
			var dist_to_player = HexUtils.hex_distance(unit.hex_position, ctx.player_unit.hex_position)
			if dist_to_player >= 2 and dist_to_player <= 10:
				return {
					"action": "pass",
					"target": ctx.player_unit.hex_position,
					"receiver": ctx.player_unit,
					"reason": "pass_to_player_under_pressure"
				}
		
		# Otherwise find safest pass
		var safe_pass = _find_safest_pass(unit, ctx)
		if safe_pass.found:
			return {
				"action": "pass",
				"target": safe_pass.target,
				"receiver": safe_pass.receiver,
				"reason": "release_pressure"
			}
	
	# Priority 3: Look for through ball to player making a run
	if unit.action_points >= 2 and ctx.player_unit:
		var through_ball = _find_through_ball_to_player(unit, ctx)
		if through_ball.found:
			return {
				"action": "through_ball",
				"target": through_ball.target,
				"reason": "through_ball_to_player"
			}
	
	# Priority 4: Forward pass to progress play
	var forward_pass = _find_forward_pass(unit, ctx)
	if forward_pass.found:
		return {
			"action": "pass",
			"target": forward_pass.target,
			"receiver": forward_pass.receiver,
			"reason": "progress_play"
		}
	
	# Priority 5: Pass to player character if they're an option
	if ctx.player_unit and not ctx.player_unit.is_goalkeeper():
		var dist = HexUtils.hex_distance(unit.hex_position, ctx.player_unit.hex_position)
		if dist >= 2 and dist <= 12:
			var openness = _calculate_openness(ctx.player_unit, ctx.opponents)
			if openness > 0.2:
				return {
					"action": "pass",
					"target": ctx.player_unit.hex_position,
					"receiver": ctx.player_unit,
					"reason": "involve_player"
				}
	
	# Priority 6: Carry ball forward if space exists
	if ctx.space_ahead.has_space:
		var move_target = _find_carry_target(unit, ctx)
		if move_target != unit.hex_position:
			return {
				"action": "move",
				"target": move_target,
				"reason": "carry_forward"
			}
	
	# Priority 7: Keep possession with simple pass
	var simple_pass = _find_best_pass(unit, ctx)
	if simple_pass.found:
		return {
			"action": "pass",
			"target": simple_pass.target,
			"receiver": simple_pass.receiver,
			"reason": "keep_possession"
		}
	
	return {"action": "none", "reason": "no_good_option"}

#endregion

#region Support Play Decisions

## Decide movement when a teammate has the ball
static func _decide_support_play(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	if not ctx.ball_carrier:
		return {"action": "none", "reason": "no_ball_carrier"}
	
	# Goalkeepers have special logic
	if unit.is_goalkeeper():
		return _decide_goalkeeper_support(unit, ctx)
	
	# Priority 1: Player has the ball - actively support them
	if ctx.player_has_ball:
		return _support_player_character(unit, ctx)
	
	# Priority 2: We should make an attacking run
	var run_decision = _evaluate_attacking_run(unit, ctx)
	if run_decision.should_run:
		return _execute_run(unit, run_decision.run_type, ctx)
	
	# Priority 3: Team lacks passing triangle - create an angle
	if not ctx.has_triangle_support:
		var angle_move = _create_passing_angle(unit, ctx)
		if angle_move.found:
			return {
				"action": "move",
				"target": angle_move.target,
				"reason": "create_passing_angle"
			}
	
	# Priority 4: Already well positioned - hold
	if _is_well_positioned_for_support(unit, ctx):
		return {"action": "none", "reason": "good_position"}
	
	# Priority 5: Move to shifted formation position
	var formation_pos = _get_shifted_formation_position(unit, ctx)
	if formation_pos != unit.hex_position and formation_pos not in ctx.occupied:
		var path = HexUtils.find_path(unit.hex_position, formation_pos, ctx.occupied)
		if path.size() > 1:
			var move_range = unit.get_move_range()
			var target_idx = min(move_range, path.size() - 1)
			return {
				"action": "move",
				"target": path[target_idx],
				"reason": "formation_shape"
			}
	
	return {"action": "none", "reason": "holding_position"}


## Special support logic when the PLAYER has the ball
static func _support_player_character(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var player = ctx.player_unit
	var my_role = unit.position_role
	
	# Calculate relative position to player
	var am_ahead = _is_ahead_of(unit, player, ctx.attacking_right)
	var am_wide = abs(unit.hex_position.y - player.hex_position.y) > 3
	var dist_to_player = HexUtils.hex_distance(unit.hex_position, player.hex_position)
	
	# If I'm ahead and there's space, make a run for a through ball
	if am_ahead and _is_attacking_role(my_role):
		var run_target = _find_through_ball_run_target(unit, player, ctx)
		if run_target != unit.hex_position:
			return {
				"action": "move",
				"target": run_target,
				"reason": "through_ball_run_for_player"
			}
	
	# Full backs should overlap when player is a winger ahead of them
	if my_role == "FB" and not am_ahead:
		var overlap_target = _find_overlap_target(unit, player, ctx)
		if overlap_target != unit.hex_position:
			return {
				"action": "move",
				"target": overlap_target,
				"reason": "overlap_run_for_player"
			}
	
	# Midfielders should offer a safe outlet
	if my_role in ["CM", "CDM", "CAM"]:
		if dist_to_player > MAX_SUPPORT_DISTANCE or ctx.unit_is_marked:
			var outlet = _find_outlet_position(unit, player, ctx)
			if outlet != unit.hex_position:
				return {
					"action": "move",
					"target": outlet,
					"reason": "outlet_for_player"
				}
	
	# Strikers should create space or offer option
	if my_role == "ST":
		# If congested, drag a defender away
		if ctx.midfield_congested:
			var decoy_target = _find_decoy_run_target(unit, ctx)
			if decoy_target != unit.hex_position:
				return {
					"action": "move",
					"target": decoy_target,
					"reason": "create_space_for_player"
				}
	
	# Default: position myself as a passing option
	if not _is_valid_passing_option(unit, player, ctx):
		var option_pos = _find_passing_option_position(unit, player, ctx)
		if option_pos != unit.hex_position:
			return {
				"action": "move",
				"target": option_pos,
				"reason": "become_passing_option"
			}
	
	return {"action": "none", "reason": "already_supporting_player"}

#endregion

#region Defensive Decisions

## Decide action when opponent has possession
static func _decide_defensive_action(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	# Goalkeepers have special positioning
	if unit.is_goalkeeper():
		return _decide_goalkeeper_defense(unit, ctx)
	
	var ball_hex = ctx.ball_hex
	var dist_to_ball = ctx.distance_to_ball
	
	# Priority 1: Can we tackle? (adjacent to ball carrier)
	if ctx.ball_carrier:
		var dist_to_carrier = HexUtils.hex_distance(unit.hex_position, ctx.ball_carrier.hex_position)
		if dist_to_carrier == 1 and unit.action_points >= 1:
			return {
				"action": "tackle",
				"target": ctx.ball_carrier,
				"reason": "tackle_opportunity"
			}
	
	# Priority 2: Defenders should track dangerous runners, not just the ball
	if _is_defensive_role(unit.position_role):
		var danger_runner = _find_dangerous_runner(unit, ctx)
		if danger_runner:
			var mark_pos = _calculate_marking_position(unit, danger_runner, ctx)
			if mark_pos != unit.hex_position:
				return {
					"action": "move",
					"target": mark_pos,
					"reason": "track_runner"
				}
	
	# Priority 3: Press the ball if close enough
	if dist_to_ball <= 4:
		var press_target = _calculate_press_position(unit, ctx)
		if press_target != unit.hex_position:
			return {
				"action": "move",
				"target": press_target,
				"reason": "press_ball"
			}
	
	# Priority 4: Maintain defensive shape
	var defensive_pos = _get_defensive_position(unit, ctx)
	if defensive_pos != unit.hex_position and defensive_pos not in ctx.occupied:
		var path = HexUtils.find_path(unit.hex_position, defensive_pos, ctx.occupied)
		if path.size() > 1:
			var move_range = unit.get_move_range()
			var target_idx = min(move_range, path.size() - 1)
			return {
				"action": "move",
				"target": path[target_idx],
				"reason": "defensive_shape"
			}
	
	return {"action": "none", "reason": "holding_defensive_position"}


## Goalkeeper support positioning (when team has ball)
static func _decide_goalkeeper_support(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	# GK should position to receive back passes
	var ideal_pos = Vector2i(
		2 if ctx.attacking_right else HexUtils.GRID_WIDTH - 3,
		HexUtils.GRID_HEIGHT / 2
	)
	
	if unit.hex_position != ideal_pos and ideal_pos not in ctx.occupied:
		return {
			"action": "move",
			"target": ideal_pos,
			"reason": "gk_support_position"
		}
	
	return {"action": "none", "reason": "gk_positioned"}


## Goalkeeper defensive positioning
static func _decide_goalkeeper_defense(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var ball_hex = ctx.ball_hex
	var goal_hex = ctx.own_goal_hex
	
	# Position between ball and center of goal
	var ideal_x = goal_hex.x + (1 if ctx.attacking_right else -1)
	var ideal_y = clampi(
		int(lerp(float(goal_hex.y), float(ball_hex.y), 0.3)),
		goal_hex.y - 2,
		goal_hex.y + 2
	)
	var ideal_pos = Vector2i(ideal_x, ideal_y)
	
	if unit.hex_position != ideal_pos and ideal_pos not in ctx.occupied:
		return {
			"action": "move",
			"target": ideal_pos,
			"reason": "gk_positioning"
		}
	
	return {"action": "none", "reason": "gk_set"}

#endregion

#region Run Type Logic

## Evaluate whether this unit should make an attacking run
static func _evaluate_attacking_run(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var role = unit.position_role
	var result = {"should_run": false, "run_type": RunType.NONE}
	
	# Only certain roles make attacking runs
	if not _is_attacking_role(role) and role != "FB":
		return result
	
	# Don't run if already well ahead of the ball
	if _is_far_ahead_of(unit, ctx.ball_carrier, ctx.attacking_right):
		return result
	
	# Determine best run type based on role and context
	var run_type = _select_run_type(unit, ctx)
	
	if run_type != RunType.NONE:
		# Check if the run makes sense (space exists, etc.)
		if _validate_run(unit, run_type, ctx):
			result.should_run = true
			result.run_type = run_type
	
	return result


## Select the appropriate run type based on role and context
static func _select_run_type(unit: PlayerUnit, ctx: Dictionary) -> RunType:
	var role = unit.position_role
	var ball_carrier = ctx.ball_carrier
	
	# Full back overlap when winger has ball
	if role == "FB":
		if ball_carrier and ball_carrier.position_role == "WNG":
			if _is_behind(unit, ball_carrier, ctx.attacking_right):
				return RunType.OVERLAP
		return RunType.NONE
	
	# Wingers drift wide when play is central
	if role == "WNG":
		if ctx.play_is_central and not _is_unit_wide(unit, ctx):
			return RunType.DRIFT_WIDE
		if ctx.channel_space.has_space:
			return RunType.DIAGONAL
		return RunType.NONE
	
	# Strikers make runs into channels or check to ball
	if role == "ST":
		if ctx.ball_in_final_third:
			return RunType.CHANNEL_RUN
		if ctx.midfield_congested:
			return RunType.CHECK_TO_BALL
		return RunType.CHANNEL_RUN
	
	# Attacking mids make diagonal runs or support
	if role == "CAM":
		if ctx.channel_space.has_space:
			return RunType.DIAGONAL
		if ctx.ball_in_own_half:
			return RunType.DROP_DEEP
		return RunType.NONE
	
	# Central mids occasionally make late runs
	if role == "CM":
		if ctx.ball_in_final_third and not ctx.midfield_congested:
			return RunType.CHANNEL_RUN
		return RunType.NONE
	
	return RunType.NONE


## Validate that a run makes tactical sense
static func _validate_run(unit: PlayerUnit, run_type: RunType, ctx: Dictionary) -> bool:
	match run_type:
		RunType.OVERLAP:
			return _has_overlap_space(unit, ctx)
		RunType.DIAGONAL:
			return ctx.channel_space.has_space
		RunType.CHANNEL_RUN:
			return _has_channel_space(unit, ctx)
		RunType.DRIFT_WIDE:
			return not _is_unit_wide(unit, ctx)
		RunType.CHECK_TO_BALL:
			return ctx.distance_to_ball > MIN_SUPPORT_DISTANCE
		RunType.DROP_DEEP:
			return ctx.distance_to_ball > MAX_SUPPORT_DISTANCE
		_:
			return false


## Execute the chosen run type
static func _execute_run(unit: PlayerUnit, run_type: RunType, ctx: Dictionary) -> Dictionary:
	var target = unit.hex_position
	var reason = "run"
	
	match run_type:
		RunType.OVERLAP:
			target = _calculate_overlap_target(unit, ctx)
			reason = "overlap_run"
		RunType.DIAGONAL:
			target = _calculate_diagonal_run_target(unit, ctx)
			reason = "diagonal_run"
		RunType.CHANNEL_RUN:
			target = _calculate_channel_run_target(unit, ctx)
			reason = "channel_run"
		RunType.DRIFT_WIDE:
			target = _calculate_wide_target(unit, ctx)
			reason = "drift_wide"
		RunType.CHECK_TO_BALL:
			target = _calculate_check_to_ball_target(unit, ctx)
			reason = "check_to_ball"
		RunType.DROP_DEEP:
			target = _calculate_drop_deep_target(unit, ctx)
			reason = "drop_deep"
	
	if target != unit.hex_position:
		return {"action": "move", "target": target, "reason": reason}
	
	return {"action": "none", "reason": "run_blocked"}

#endregion

#region Passing Triangle Logic

## Create a passing angle when the team lacks triangle support
static func _create_passing_angle(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	if not ctx.ball_carrier:
		return {"found": false}
	
	var ball_carrier = ctx.ball_carrier
	var existing_options = ctx.passing_options
	
	# Find angles already covered
	var covered_angles: Array[float] = []
	for option in existing_options:
		var angle = _get_angle_from_carrier(ball_carrier, option)
		covered_angles.append(angle)
	
	# Find a position that creates a new angle
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var dist = HexUtils.hex_distance(hex, ball_carrier.hex_position)
		if dist < MIN_SUPPORT_DISTANCE or dist > MAX_SUPPORT_DISTANCE:
			continue
		
		var angle = _get_angle_from_carrier_to_hex(ball_carrier, hex)
		var min_angle_diff = _get_min_angle_difference(angle, covered_angles)
		
		# Score based on angle difference and openness
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var score = min_angle_diff * 2.0 + openness
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	if best_hex != unit.hex_position and best_score > MIN_TRIANGLE_ANGLE:
		return {"found": true, "target": best_hex}
	
	return {"found": false}


## Check if the ball carrier has valid passing triangle
static func _has_valid_triangle(ball_carrier: PlayerUnit, options: Array) -> bool:
	if options.size() < 2:
		return false
	
	# Check if any two options have sufficient angle between them
	for i in range(options.size()):
		for j in range(i + 1, options.size()):
			var angle_i = _get_angle_from_carrier(ball_carrier, options[i])
			var angle_j = _get_angle_from_carrier(ball_carrier, options[j])
			var diff = abs(angle_i - angle_j)
			if diff > 180:
				diff = 360 - diff
			if diff >= MIN_TRIANGLE_ANGLE:
				return true
	
	return false

#endregion

#region Formation & Positioning

## Get formation position shifted based on ball location
static func _get_shifted_formation_position(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var base_pos = _get_base_formation_position(unit, ctx.attacking_right)
	
	var ball_hex = ctx.ball_hex
	var pitch_center = ctx.pitch_center
	
	# Horizontal shift: team shifts toward the ball's y position
	var ball_y_offset = ball_hex.y - pitch_center.y
	var y_shift = int(ball_y_offset * FORMATION_SHIFT_FACTOR)
	
	# Vertical shift: team pushes up/drops based on ball progress
	var x_shift = int(ctx.ball_progress * FORMATION_COMPRESS_FACTOR) * ctx.forward_dir
	
	var shifted = Vector2i(
		clampi(base_pos.x + x_shift, 2, HexUtils.GRID_WIDTH - 3),
		clampi(base_pos.y + y_shift, 1, HexUtils.GRID_HEIGHT - 2)
	)
	
	return shifted


## Get base formation position for a unit (before shifting)
static func _get_base_formation_position(unit: PlayerUnit, attacking_right: bool) -> Vector2i:
	# Use default 4-4-2 positions as base
	var positions = HexUtils.get_formation_positions("4-4-2", not attacking_right)
	
	for pos_data in positions:
		if pos_data.position == unit.position_role:
			return pos_data.hex
	
	# Fallback to current position
	return unit.hex_position


## Calculate defensive position based on ball and threats
static func _get_defensive_position(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var ball_hex = ctx.ball_hex
	var own_goal = ctx.own_goal_hex
	var role = unit.position_role
	
	# Get shifted base position (more conservative for defense)
	var base = _get_base_formation_position(unit, ctx.attacking_right)
	
	# Defenders position between ball and goal
	if _is_defensive_role(role):
		# Calculate point on line between ball and goal
		var ball_to_goal_dist = HexUtils.hex_distance(ball_hex, own_goal)
		var our_depth = 0.3 if role == "CB" else 0.4  # CBs stay deeper
		
		var target_x = int(lerp(float(own_goal.x), float(ball_hex.x), our_depth))
		var target_y = clampi(ball_hex.y, base.y - 2, base.y + 2)
		
		return Vector2i(target_x, target_y)
	
	# Midfielders split between supporting defense and staying available
	if role in ["CM", "CDM"]:
		var target_x = int(lerp(float(own_goal.x), float(ball_hex.x), 0.5))
		var target_y = base.y + int((ball_hex.y - ctx.pitch_center.y) * 0.3)
		
		return Vector2i(
			clampi(target_x, 3, HexUtils.GRID_WIDTH - 4),
			clampi(target_y, 2, HexUtils.GRID_HEIGHT - 3)
		)
	
	# Attackers stay higher but drop into midfield if needed
	return Vector2i(
		int(lerp(float(own_goal.x), float(ball_hex.x), 0.65)),
		base.y
	)

#endregion

#region Passing Helpers

## Find the safest pass option (maximum distance from opponents)
static func _find_safest_pass(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var best: PlayerUnit = null
	var best_safety: float = -1.0
	
	for tm in ctx.teammates:
		if tm.is_goalkeeper():
			continue
		
		var dist = HexUtils.hex_distance(unit.hex_position, tm.hex_position)
		if dist < 2 or dist > 10:
			continue
		
		# Check for interception risk along pass line
		var intercept_risk = _calculate_interception_risk(unit.hex_position, tm.hex_position, ctx.opponents)
		var openness = _calculate_openness(tm, ctx.opponents)
		
		var safety = openness - intercept_risk * 2.0
		
		if safety > best_safety:
			best_safety = safety
			best = tm
	
	if best:
		return {"found": true, "target": best.hex_position, "receiver": best}
	return {"found": false}


## Find a forward pass to progress play
static func _find_forward_pass(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var forward_dir = ctx.forward_dir
	var best: PlayerUnit = null
	var best_score: float = -1.0
	
	for tm in ctx.teammates:
		if tm.is_goalkeeper():
			continue
		
		var x_diff = (tm.hex_position.x - unit.hex_position.x) * forward_dir
		if x_diff <= 0:
			continue  # Not forward
		
		var dist = HexUtils.hex_distance(unit.hex_position, tm.hex_position)
		if dist < 2 or dist > 12:
			continue
		
		var openness = _calculate_openness(tm, ctx.opponents)
		var intercept_risk = _calculate_interception_risk(unit.hex_position, tm.hex_position, ctx.opponents)
		
		# Score: forward progress + openness - risk
		var score = x_diff * 0.3 + openness * 0.5 - intercept_risk * 0.4
		
		if score > best_score:
			best_score = score
			best = tm
	
	if best and best_score > 0.2:
		return {"found": true, "target": best.hex_position, "receiver": best}
	return {"found": false}


## Find the best general pass option
static func _find_best_pass(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var best: PlayerUnit = null
	var best_score: float = -1.0
	
	for tm in ctx.teammates:
		if tm.is_goalkeeper():
			continue
		
		var dist = HexUtils.hex_distance(unit.hex_position, tm.hex_position)
		if dist < 2 or dist > 10:
			continue
		
		var openness = _calculate_openness(tm, ctx.opponents)
		var intercept_risk = _calculate_interception_risk(unit.hex_position, tm.hex_position, ctx.opponents)
		
		# Bonus for passing to player character
		var player_bonus = 0.3 if tm.is_player_controlled else 0.0
		
		var score = openness - intercept_risk + player_bonus - dist * 0.05
		
		if score > best_score:
			best_score = score
			best = tm
	
	if best:
		return {"found": true, "target": best.hex_position, "receiver": best}
	return {"found": false}


## Find through ball opportunity to player character
static func _find_through_ball_to_player(unit: PlayerUnit, ctx: Dictionary) -> Dictionary:
	var player = ctx.player_unit
	if not player or player.is_goalkeeper():
		return {"found": false}
	
	var forward_dir = ctx.forward_dir
	
	# Check if player is making a run ahead
	if not _is_ahead_of(player, unit, ctx.attacking_right):
		return {"found": false}
	
	# Calculate through ball target (space ahead of player)
	var through_target = Vector2i(
		player.hex_position.x + forward_dir * 2,
		player.hex_position.y
	)
	
	if not HexUtils.is_valid_hex(through_target):
		return {"found": false}
	
	# Check if space is clear
	for opp in ctx.opponents:
		if HexUtils.hex_distance(through_target, opp.hex_position) < 2:
			return {"found": false}
	
	return {"found": true, "target": through_target}

#endregion

#region Run Target Calculations

## Calculate target for through ball run
static func _find_through_ball_run_target(unit: PlayerUnit, player: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var forward_dir = ctx.forward_dir
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		# Must be ahead of current position
		var forward_gain = (hex.x - unit.hex_position.x) * forward_dir
		if forward_gain <= 0:
			continue
		
		# Should be in a good receiving position
		var dist_to_goal = HexUtils.hex_distance(hex, ctx.goal_hex)
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		
		# Check we're not offside (simplified: not past last defender)
		# TODO: Implement proper offside check
		
		var score = forward_gain * 0.5 + openness * 0.5 - dist_to_goal * 0.1
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Calculate overlap run target
static func _find_overlap_target(unit: PlayerUnit, player: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var forward_dir = ctx.forward_dir
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	# Overlap should be wide and ahead
	var player_y = player.hex_position.y
	var wide_dir = 1 if player_y > ctx.pitch_center.y else -1
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var forward_gain = (hex.x - player.hex_position.x) * forward_dir
		var wide_gain = (hex.y - player.hex_position.y) * wide_dir
		
		if forward_gain <= 0 or wide_gain < 0:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var score = forward_gain * 0.4 + wide_gain * 0.3 + openness * 0.3
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Calculate target for checking to the ball
static func _calculate_check_to_ball_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var ball_carrier = ctx.ball_carrier
	if not ball_carrier:
		return unit.hex_position
	
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var dist_to_carrier = HexUtils.hex_distance(hex, ball_carrier.hex_position)
		
		# Want to be in passing range but not too close
		if dist_to_carrier < MIN_SUPPORT_DISTANCE or dist_to_carrier > MAX_SUPPORT_DISTANCE:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var came_toward = ctx.distance_to_ball - dist_to_carrier
		
		var score = openness * 0.6 + came_toward * 0.4
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Calculate target for dropping deep
static func _calculate_drop_deep_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var backward_dir = -ctx.forward_dir
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var backward_move = (hex.x - unit.hex_position.x) * backward_dir
		if backward_move <= 0:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var score = backward_move * 0.3 + openness * 0.7
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Calculate overlap run position
static func _calculate_overlap_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	if not ctx.ball_carrier:
		return unit.hex_position
	return _find_overlap_target(unit, ctx.ball_carrier, ctx)


## Calculate diagonal run position
static func _calculate_diagonal_run_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var forward_dir = ctx.forward_dir
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	# Diagonal toward goal
	var toward_center = 1 if unit.hex_position.y > ctx.pitch_center.y else -1
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var forward = (hex.x - unit.hex_position.x) * forward_dir
		var inward = (hex.y - unit.hex_position.y) * (-toward_center)
		
		if forward <= 0:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var score = forward * 0.4 + inward * 0.3 + openness * 0.3
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Calculate channel run position
static func _calculate_channel_run_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var forward_dir = ctx.forward_dir
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var forward = (hex.x - unit.hex_position.x) * forward_dir
		if forward <= 0:
			continue
		
		var dist_to_goal = HexUtils.hex_distance(hex, ctx.goal_hex)
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		
		var score = forward * 0.5 + openness * 0.3 - dist_to_goal * 0.1
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Calculate position to drift wide
static func _calculate_wide_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var wide_dir = 1 if unit.hex_position.y <= ctx.pitch_center.y else -1
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var wide_move = (hex.y - unit.hex_position.y) * wide_dir
		if wide_move <= 0:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var score = wide_move * 0.6 + openness * 0.4
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex

#endregion

#region Support Position Helpers

## Find outlet position to receive a pass under pressure
static func _find_outlet_position(unit: PlayerUnit, ball_carrier: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var dist_to_carrier = HexUtils.hex_distance(hex, ball_carrier.hex_position)
		if dist_to_carrier < MIN_SUPPORT_DISTANCE or dist_to_carrier > MAX_SUPPORT_DISTANCE:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var intercept_risk = _calculate_interception_risk(ball_carrier.hex_position, hex, ctx.opponents)
		
		# Slight preference for backward/sideways (safe outlet)
		var is_backward = (hex.x - ball_carrier.hex_position.x) * ctx.forward_dir < 0
		var safety_bonus = 0.2 if is_backward else 0.0
		
		var score = openness - intercept_risk + safety_bonus
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Find position to become a valid passing option
static func _find_passing_option_position(unit: PlayerUnit, ball_carrier: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var dist = HexUtils.hex_distance(hex, ball_carrier.hex_position)
		if dist < MIN_SUPPORT_DISTANCE or dist > MAX_SUPPORT_DISTANCE:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var angle_quality = _get_angle_quality(ball_carrier, hex, ctx.passing_options)
		
		var score = openness * 0.5 + angle_quality * 0.5
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Find a decoy run target to drag defenders away
static func _find_decoy_run_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	# Find direction that would drag the most defenders
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var defenders_pulled = 0
		for opp in ctx.opponents:
			if _is_defensive_role(opp.position_role):
				var current_dist = HexUtils.hex_distance(unit.hex_position, opp.hex_position)
				var new_dist = HexUtils.hex_distance(hex, opp.hex_position)
				if new_dist < current_dist and new_dist <= 3:
					defenders_pulled += 1
		
		var score = float(defenders_pulled)
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Find target to carry ball forward
static func _find_carry_target(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var forward_dir = ctx.forward_dir
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var forward = (hex.x - unit.hex_position.x) * forward_dir
		if forward <= 0:
			continue
		
		var openness = _calculate_openness_at_hex(hex, ctx.opponents)
		var score = forward * 0.5 + openness * 0.5
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex

#endregion

#region Defensive Helpers

## Find dangerous runners that need tracking
static func _find_dangerous_runner(unit: PlayerUnit, ctx: Dictionary) -> PlayerUnit:
	var own_goal = ctx.own_goal_hex
	var dangerous: PlayerUnit = null
	var highest_danger = -1.0
	
	for opp in ctx.opponents:
		if opp.is_goalkeeper():
			continue
		
		# Skip if already marked by another teammate
		if _is_marked_by_other(opp, unit, ctx.teammates):
			continue
		
		var dist_to_goal = HexUtils.hex_distance(opp.hex_position, own_goal)
		var dist_from_unit = HexUtils.hex_distance(unit.hex_position, opp.hex_position)
		
		# Danger = close to goal + close enough for us to track
		var danger = (15.0 - dist_to_goal) - dist_from_unit * 0.3
		
		if danger > highest_danger:
			highest_danger = danger
			dangerous = opp
	
	return dangerous if highest_danger > 5.0 else null


## Calculate marking position for a target
static func _calculate_marking_position(unit: PlayerUnit, target: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var own_goal = ctx.own_goal_hex
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_score = -1.0
	
	for hex in reachable:
		var dist_to_target = HexUtils.hex_distance(hex, target.hex_position)
		var our_dist_to_goal = HexUtils.hex_distance(hex, own_goal)
		var target_dist_to_goal = HexUtils.hex_distance(target.hex_position, own_goal)
		
		# Good mark: close to target, between them and goal
		var between_bonus = 2.0 if our_dist_to_goal < target_dist_to_goal else 0.0
		var closeness = max(0, 5.0 - dist_to_target)
		
		var score = closeness + between_bonus
		
		if score > best_score:
			best_score = score
			best_hex = hex
	
	return best_hex


## Calculate pressing position
static func _calculate_press_position(unit: PlayerUnit, ctx: Dictionary) -> Vector2i:
	var ball_hex = ctx.ball_hex
	var move_range = unit.get_move_range()
	var reachable = HexUtils.get_reachable_hexes(unit.hex_position, move_range, ctx.occupied)
	
	var best_hex = unit.hex_position
	var best_dist = HexUtils.hex_distance(unit.hex_position, ball_hex)
	
	for hex in reachable:
		var dist = HexUtils.hex_distance(hex, ball_hex)
		if dist < best_dist:
			best_dist = dist
			best_hex = hex
	
	return best_hex

#endregion

#region Utility Functions

## Check if team has possession
static func _team_has_possession(unit: PlayerUnit, ball: BallController,
								  all_units: Array[PlayerUnit]) -> bool:
	if ball.is_possessed():
		var possessor = ball.get_possessing_unit()
		return possessor and possessor.is_home_team == unit.is_home_team
	return false


## Get teammates (excluding self)
static func _get_teammates(unit: PlayerUnit, all_units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var teammates: Array[PlayerUnit] = []
	for other in all_units:
		if other != unit and other.is_home_team == unit.is_home_team:
			teammates.append(other)
	return teammates


## Get opponents
static func _get_opponents(unit: PlayerUnit, all_units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var opponents: Array[PlayerUnit] = []
	for other in all_units:
		if other.is_home_team != unit.is_home_team:
			opponents.append(other)
	return opponents


## Get all occupied hexes
static func _get_occupied_hexes(all_units: Array[PlayerUnit]) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for u in all_units:
		occupied.append(u.hex_position)
	return occupied


## Find the player character unit
static func _find_player_unit(all_units: Array[PlayerUnit]) -> PlayerUnit:
	for unit in all_units:
		if unit.is_player_controlled:
			return unit
	return null


## Find nearest opponent to a unit
static func _find_nearest_opponent(unit: PlayerUnit, opponents: Array[PlayerUnit]) -> PlayerUnit:
	var nearest: PlayerUnit = null
	var min_dist = 100
	
	for opp in opponents:
		var dist = HexUtils.hex_distance(unit.hex_position, opp.hex_position)
		if dist < min_dist:
			min_dist = dist
			nearest = opp
	
	return nearest


## Check if a unit is under pressure
static func _is_under_pressure(unit: PlayerUnit, opponents: Array[PlayerUnit]) -> bool:
	for opp in opponents:
		if HexUtils.hex_distance(unit.hex_position, opp.hex_position) <= PRESSURE_DISTANCE:
			return true
	return false


## Check if a unit is marked by opponents
static func _is_unit_marked(unit: PlayerUnit, opponents: Array[PlayerUnit]) -> bool:
	for opp in opponents:
		if HexUtils.hex_distance(unit.hex_position, opp.hex_position) <= 2:
			return true
	return false


## Check if target is marked by another teammate
static func _is_marked_by_other(target: PlayerUnit, self_unit: PlayerUnit, 
								 teammates: Array[PlayerUnit]) -> bool:
	for tm in teammates:
		if tm == self_unit:
			continue
		if HexUtils.hex_distance(tm.hex_position, target.hex_position) <= 2:
			return true
	return false


## Calculate openness of a unit (distance from nearest opponent)
static func _calculate_openness(unit: PlayerUnit, opponents: Array[PlayerUnit]) -> float:
	var min_dist = 100.0
	for opp in opponents:
		var dist = HexUtils.hex_distance(unit.hex_position, opp.hex_position)
		min_dist = min(min_dist, dist)
	return min_dist / 10.0


## Calculate openness at a specific hex
static func _calculate_openness_at_hex(hex: Vector2i, opponents: Array[PlayerUnit]) -> float:
	var min_dist = 100.0
	for opp in opponents:
		var dist = HexUtils.hex_distance(hex, opp.hex_position)
		min_dist = min(min_dist, dist)
	return min_dist / 10.0


## Calculate interception risk for a pass
static func _calculate_interception_risk(from: Vector2i, to: Vector2i, 
										  opponents: Array[PlayerUnit]) -> float:
	var pass_line = HexUtils.get_hex_line(from, to)
	var risk = 0.0
	
	for opp in opponents:
		for hex in pass_line:
			var dist = HexUtils.hex_distance(hex, opp.hex_position)
			if dist <= 1:
				risk += 0.5
			elif dist <= 2:
				risk += 0.2
	
	return min(risk, 1.0)


## Get units blocking a path
static func _get_units_blocking_path(from: Vector2i, to: Vector2i,
									  units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var line = HexUtils.get_hex_line(from, to)
	var blocking: Array[PlayerUnit] = []
	
	for unit in units:
		if unit.hex_position in line:
			blocking.append(unit)
	
	return blocking


## Get passing options for a ball carrier
static func _get_passing_options(carrier: PlayerUnit, teammates: Array[PlayerUnit],
								  opponents: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var options: Array[PlayerUnit] = []
	
	if not carrier:
		return options
	
	for tm in teammates:
		if tm.is_goalkeeper():
			continue
		
		var dist = HexUtils.hex_distance(carrier.hex_position, tm.hex_position)
		if dist >= MIN_SUPPORT_DISTANCE and dist <= MAX_SUPPORT_DISTANCE:
			var openness = _calculate_openness(tm, opponents)
			if openness > 0.2:
				options.append(tm)
	
	return options


## Check if unit is valid passing option
static func _is_valid_passing_option(unit: PlayerUnit, carrier: PlayerUnit, ctx: Dictionary) -> bool:
	var dist = HexUtils.hex_distance(unit.hex_position, carrier.hex_position)
	if dist < MIN_SUPPORT_DISTANCE or dist > MAX_SUPPORT_DISTANCE:
		return false
	
	var openness = _calculate_openness(unit, ctx.opponents)
	return openness > 0.2


## Check if role is attacking
static func _is_attacking_role(role: String) -> bool:
	return role in ["ST", "WNG", "CAM"]


## Check if role is defensive
static func _is_defensive_role(role: String) -> bool:
	return role in ["GK", "CB", "FB", "CDM"]


## Check if unit is ahead of another
static func _is_ahead_of(unit: PlayerUnit, other: PlayerUnit, attacking_right: bool) -> bool:
	var forward_dir = 1 if attacking_right else -1
	return (unit.hex_position.x - other.hex_position.x) * forward_dir > 0


## Check if unit is behind another
static func _is_behind(unit: PlayerUnit, other: PlayerUnit, attacking_right: bool) -> bool:
	return not _is_ahead_of(unit, other, attacking_right)


## Check if unit is far ahead of ball carrier
static func _is_far_ahead_of(unit: PlayerUnit, carrier: PlayerUnit, attacking_right: bool) -> bool:
	if not carrier:
		return false
	var forward_dir = 1 if attacking_right else -1
	var diff = (unit.hex_position.x - carrier.hex_position.x) * forward_dir
	return diff > 5


## Check if unit is wide
static func _is_unit_wide(unit: PlayerUnit, ctx: Dictionary) -> bool:
	return abs(unit.hex_position.y - ctx.pitch_center.y) > 4


## Analyze space ahead of unit
static func _analyze_space_ahead(unit: PlayerUnit, opponents: Array[PlayerUnit], 
								  attacking_right: bool) -> Dictionary:
	var forward_dir = 1 if attacking_right else -1
	var space_count = 0
	
	for dx in range(1, 4):
		var check_hex = Vector2i(unit.hex_position.x + dx * forward_dir, unit.hex_position.y)
		if not HexUtils.is_valid_hex(check_hex):
			break
		
		var blocked = false
		for opp in opponents:
			if HexUtils.hex_distance(check_hex, opp.hex_position) <= 1:
				blocked = true
				break
		
		if not blocked:
			space_count += 1
	
	return {"has_space": space_count >= 2, "depth": space_count}


## Check if area is congested
static func _is_area_congested(center: Vector2i, all_units: Array[PlayerUnit]) -> bool:
	var count = 0
	for unit in all_units:
		if HexUtils.hex_distance(unit.hex_position, center) <= CONGESTION_RADIUS:
			count += 1
	return count >= CONGESTION_THRESHOLD


## Analyze channel space
static func _analyze_channel_space(unit: PlayerUnit, opponents: Array[PlayerUnit],
									attacking_right: bool) -> Dictionary:
	# Check space between CBs/FBs
	var forward_dir = 1 if attacking_right else -1
	var channels_clear = 0
	
	for y_offset in [-2, 0, 2]:
		var check_y = unit.hex_position.y + y_offset
		var check_x = unit.hex_position.x + forward_dir * 3
		var check_hex = Vector2i(check_x, check_y)
		
		if not HexUtils.is_valid_hex(check_hex):
			continue
		
		var clear = true
		for opp in opponents:
			if HexUtils.hex_distance(check_hex, opp.hex_position) <= 2:
				clear = false
				break
		
		if clear:
			channels_clear += 1
	
	return {"has_space": channels_clear > 0, "count": channels_clear}


## Check space for overlap
static func _has_overlap_space(unit: PlayerUnit, ctx: Dictionary) -> bool:
	if not ctx.ball_carrier:
		return false
	
	var carrier = ctx.ball_carrier
	var forward_dir = ctx.forward_dir
	
	# Check if there's space wide and ahead of carrier
	var wide_dir = 1 if carrier.hex_position.y > ctx.pitch_center.y else -1
	var target = Vector2i(
		carrier.hex_position.x + forward_dir * 2,
		carrier.hex_position.y + wide_dir * 2
	)
	
	if not HexUtils.is_valid_hex(target):
		return false
	
	for opp in ctx.opponents:
		if HexUtils.hex_distance(target, opp.hex_position) <= 2:
			return false
	
	return true


## Check for channel run space
static func _has_channel_space(unit: PlayerUnit, ctx: Dictionary) -> bool:
	return ctx.channel_space.has_space


## Check if well positioned for support
static func _is_well_positioned_for_support(unit: PlayerUnit, ctx: Dictionary) -> bool:
	if not ctx.ball_carrier:
		return true
	
	var dist = HexUtils.hex_distance(unit.hex_position, ctx.ball_carrier.hex_position)
	if dist < MIN_SUPPORT_DISTANCE or dist > MAX_SUPPORT_DISTANCE:
		return false
	
	var openness = _calculate_openness(unit, ctx.opponents)
	return openness > 0.3


## Get angle from carrier to a unit
static func _get_angle_from_carrier(carrier: PlayerUnit, target: PlayerUnit) -> float:
	var diff = Vector2(target.hex_position - carrier.hex_position)
	return rad_to_deg(diff.angle())


## Get angle from carrier to a hex
static func _get_angle_from_carrier_to_hex(carrier: PlayerUnit, hex: Vector2i) -> float:
	var diff = Vector2(hex - carrier.hex_position)
	return rad_to_deg(diff.angle())


## Get minimum angle difference from a list
static func _get_min_angle_difference(angle: float, angles: Array[float]) -> float:
	if angles.is_empty():
		return 180.0
	
	var min_diff = 180.0
	for a in angles:
		var diff = abs(angle - a)
		if diff > 180:
			diff = 360 - diff
		min_diff = min(min_diff, diff)
	
	return min_diff


## Get angle quality (how much this adds to triangle)
static func _get_angle_quality(carrier: PlayerUnit, hex: Vector2i, 
								existing_options: Array) -> float:
	if existing_options.is_empty():
		return 1.0
	
	var angle = _get_angle_from_carrier_to_hex(carrier, hex)
	var angles: Array[float] = []
	for opt in existing_options:
		angles.append(_get_angle_from_carrier(carrier, opt))
	
	var min_diff = _get_min_angle_difference(angle, angles)
	return min_diff / 90.0  # Normalize to 0-1 range (90° is optimal)

#endregion
