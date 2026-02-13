extends Node2D
class_name MatchController
## MatchController - Main orchestrator for tactical match gameplay

signal turn_changed(phase: TurnPhase, turn_number: int)
signal match_minute_changed(minute: int)
signal score_changed(home: int, away: int)
signal action_selected(action_type: String)
signal dribble_move_changed(move_id: String)
signal match_ended(result: Dictionary)

enum TurnPhase {
	PLAYER,    # Human controls their character
	TEAM,      # AI moves teammates
	OPPONENT   # AI moves opponents
}

enum MatchPhase {
	KICKOFF,
	PLAYING,
	SET_PIECE,
	HALF_TIME,
	FULL_TIME
}

# Match state
var current_turn: int = 0
var current_phase: TurnPhase = TurnPhase.PLAYER
var match_phase: MatchPhase = MatchPhase.KICKOFF
var current_half: int = 1
var match_minute: int = 0
var home_score: int = 0
var away_score: int = 0

# Initiative order (player-level queue for this turn)
var initiative_order: Array[PlayerUnit] = []
var initiative_cursor: int = -1
var is_player_turn_active: bool = false

# Goal tracking for season awards
var home_goal_events: Array[Dictionary] = []
var away_goal_events: Array[Dictionary] = []
var last_passer: PlayerUnit = null  # Track who made the last pass for assist attribution
var last_shooter: PlayerUnit = null  # Track shooter for goal attribution (possession is cleared during flight)

# Turn settings
const TURNS_PER_HALF: int = 45
const MINUTES_PER_TURN: int = 1  # 45 turns * 1 minute = 45 min per half = 90 min total
const INITIATIVE_RANDOM_BONUS: int = 12

# Grid and units
var hex_grid: TileMapLayer
var all_units: Array[PlayerUnit] = []
var home_units: Array[PlayerUnit] = []
var away_units: Array[PlayerUnit] = []
var player_unit: PlayerUnit = null

# Ball
var ball: BallController

# Match data reference
var match_data: MatchData

# Current action state
var selected_unit: PlayerUnit = null
var current_action: String = ""
var valid_targets: Array[Vector2i] = []
var action_target_units: Array[PlayerUnit] = []
var current_dribble_move_id: String = "basic"

# Home team attacks right (toward away goal)
var home_attacks_right: bool = true

# UI references (will be set by scene)
var action_panel: Control
var turn_indicator: Label
var score_label: Label
var minute_label: Label

# Visual layers
var highlight_layer: Node2D
var units_layer: Node2D

const PLAYER_UNIT_SCENE = preload("res://scenes/match/tactical/player_unit.tscn")
const DribbleMoves = preload("res://scripts/match/tactical/dribble_moves.gd")


func _ready() -> void:
	_setup_visual_layers()
	_connect_signals()

	# Get match data from GameManager
	if GameManager.current_match:
		match_data = GameManager.current_match
		call_deferred("_initialize_match")


func _setup_visual_layers() -> void:
	# Highlight layer for movement/action ranges
	highlight_layer = Node2D.new()
	highlight_layer.name = "HighlightLayer"
	add_child(highlight_layer)

	# Units layer
	units_layer = Node2D.new()
	units_layer.name = "UnitsLayer"
	add_child(units_layer)


func _connect_signals() -> void:
	pass


func _exit_tree() -> void:
	# Clean up resources to prevent memory leaks
	_clear_highlights()

	# Clean up units
	for unit in all_units:
		if is_instance_valid(unit):
			unit.queue_free()
	all_units.clear()
	home_units.clear()
	away_units.clear()

	# Clean up ball
	if ball and is_instance_valid(ball):
		ball.queue_free()


func _initialize_match() -> void:
	# Spawn all units
	_spawn_units()

	# Create ball
	ball = BallController.new()
	ball.name = "Ball"
	add_child(ball)
	ball.z_index = 10

	# Connect ball signals
	ball.goal_scored.connect(_on_goal_scored)
	ball.ball_arrived.connect(_on_ball_arrived)

	# Set initial ball position (center)
	ball.set_hex_position(HexUtils.get_center_hex())

	# Give ball to appropriate team for kickoff
	var kickoff_unit = _get_kickoff_unit(true)  # Home team starts
	if kickoff_unit:
		ball.give_possession(kickoff_unit)

	# Start the match
	match_phase = MatchPhase.PLAYING
	current_phase = TurnPhase.PLAYER
	_start_player_turn()


func _spawn_units() -> void:
	var home_team = match_data.home_team
	var away_team = match_data.away_team

	var home_formation = HexUtils.get_formation_positions(home_team.formation, true)
	var away_formation = HexUtils.get_formation_positions(away_team.formation, false)

	# Spawn home team
	var home_starting = home_team.get_starting_eleven()
	for i in range(mini(home_starting.size(), home_formation.size())):
		var player_data = home_starting[i]
		var formation_pos = home_formation[i]

		var unit = _create_unit(player_data, true, formation_pos.hex)
		home_units.append(unit)
		all_units.append(unit)

		if player_data.get("is_player", false):
			player_unit = unit

	# Spawn away team
	var away_starting = away_team.get_starting_eleven()
	for i in range(mini(away_starting.size(), away_formation.size())):
		var player_data = away_starting[i]
		var formation_pos = away_formation[i]

		var unit = _create_unit(player_data, false, formation_pos.hex)
		away_units.append(unit)
		all_units.append(unit)


func _create_unit(data: Dictionary, is_home: bool, hex_pos: Vector2i) -> PlayerUnit:
	var unit = PLAYER_UNIT_SCENE.instantiate() as PlayerUnit
	if not unit:
		unit = PlayerUnit.new()
	unit.name = "Unit_" + data.get("name", "Unknown").replace(" ", "_")
	units_layer.add_child(unit)

	unit.initialize(data, is_home, data.get("is_player", false))
	unit.set_hex_position(hex_pos)

	# Connect unit signals
	unit.move_completed.connect(_on_unit_move_completed.bind(unit))

	return unit


func _get_kickoff_unit(home_team: bool) -> PlayerUnit:
	var units = home_units if home_team else away_units
	for unit in units:
		if unit.position_role == "ST":
			return unit
		if unit.position_role == "CAM":
			return unit
		if unit.position_role == "CM":
			return unit
	return units[0] if units.size() > 0 else null


## Input handling
func _unhandled_input(event: InputEvent) -> void:
	if match_phase != MatchPhase.PLAYING:
		return

	if current_phase != TurnPhase.PLAYER:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_action()


func _handle_left_click(screen_pos: Vector2) -> void:
	# Convert screen position to hex
	var world_pos = get_global_mouse_position()
	var clicked_hex = HexUtils.pixel_to_hex(world_pos)

	if not HexUtils.is_valid_hex(clicked_hex):
		return

	# Check if we have an action selected
	if current_action != "":
		_execute_action_at_hex(clicked_hex)
		return

	# Check if clicking on a unit
	var clicked_unit = _get_unit_at_hex(clicked_hex)

	if clicked_unit and clicked_unit == player_unit:
		# Select player unit
		_select_unit(player_unit)
	elif selected_unit and clicked_hex in valid_targets:
		# Move to valid target
		_execute_move(clicked_hex)


func _select_unit(unit: PlayerUnit) -> void:
	if selected_unit:
		selected_unit.set_selected(false)

	selected_unit = unit
	unit.set_selected(true)

	# Show movement range
	_show_move_range(unit)


func _show_move_range(unit: PlayerUnit) -> void:
	_clear_highlights()

	var occupied = _get_all_occupied_hexes()
	var move_range = unit.get_move_range()
	valid_targets = HexUtils.get_reachable_hexes(unit.hex_position, move_range, occupied)

	for hex in valid_targets:
		_draw_hex_highlight(hex, Color(0, 0.5, 1, 0.3))  # Blue for movement


func _show_action_range(action: String) -> void:
	_clear_highlights()
	valid_targets.clear()
	action_target_units.clear()

	if not player_unit:
		return

	match action:
		"pass", "through_ball":
			# Highlight teammates as valid pass targets
			var team = home_units if player_unit.is_home_team else away_units
			for unit in team:
				if unit != player_unit:
					valid_targets.append(unit.hex_position)
					action_target_units.append(unit)
					_draw_hex_highlight(unit.hex_position, Color(0, 1, 0, 0.4))  # Green

		"shoot":
			# Highlight goal
			var goal_hex = HexUtils.get_goal_hex(player_unit.is_home_team == home_attacks_right)
			valid_targets.append(goal_hex)
			_draw_hex_highlight(goal_hex, Color(1, 0.5, 0, 0.5))  # Orange

		"tackle":
			# Highlight adjacent opponents with ball
			var opponents = away_units if player_unit.is_home_team else home_units
			for opp in opponents:
				if opp.has_ball and HexUtils.hex_distance(player_unit.hex_position, opp.hex_position) <= 1:
					valid_targets.append(opp.hex_position)
					action_target_units.append(opp)
					_draw_hex_highlight(opp.hex_position, Color(1, 0, 0, 0.4))  # Red

		"dribble":
			# Highlight dribble targets based on selected move range
			var move = DribbleMoves.get_move(current_dribble_move_id)
			var range_bonus = int(move.get("range_bonus", 0))
			var range = 1 + range_bonus
			var occupied = _get_all_occupied_hexes()
			valid_targets = HexUtils.get_reachable_hexes(player_unit.hex_position, range, occupied)
			for hex in valid_targets:
				_draw_hex_highlight(hex, Color(1, 1, 0, 0.4))  # Yellow


func _execute_action_at_hex(hex: Vector2i) -> void:
	if hex not in valid_targets:
		_cancel_action()
		return

	match current_action:
		"pass":
			_execute_pass(hex)
		"through_ball":
			_execute_through_ball(hex)
		"shoot":
			_execute_shot(hex)
		"tackle":
			_execute_tackle(hex)
		"dribble":
			_execute_dribble(hex)

	_cancel_action()


func _execute_move(target_hex: Vector2i) -> void:
	if not player_unit or not player_unit.can_act():
		return

	var occupied = _get_all_occupied_hexes()
	var result = ActionResolver.execute_move(player_unit, target_hex, occupied)

	if result.success:
		player_unit.move_to_hex(result.path)
		_clear_highlights()
		selected_unit = null


func _execute_pass(target_hex: Vector2i) -> void:
	if not player_unit or not player_unit.has_ball:
		return

	var receiver = _get_unit_at_hex(target_hex)
	var opponents = away_units if player_unit.is_home_team else home_units

	var result = ActionResolver.execute_pass(player_unit, target_hex, receiver, opponents, match_data)

	if result.success:
		# Track passer for potential assist
		last_passer = player_unit
		ball.start_pass(player_unit, target_hex)
		# Ball will be given to receiver when it arrives
	else:
		match result.reason:
			"inaccurate":
				ball.start_pass(player_unit, result.miss_hex)
			"intercepted":
				ball.start_pass(player_unit, result.interception_hex)
				# Interceptor will get ball when it arrives

	_clear_highlights()
	_check_turn_end()


func _execute_through_ball(target_hex: Vector2i) -> void:
	if not player_unit or not player_unit.has_ball:
		return

	var opponents = away_units if player_unit.is_home_team else home_units
	var result = ActionResolver.execute_through_ball(player_unit, target_hex, opponents, match_data)

	if result.success:
		last_passer = player_unit  # Track passer for potential assist
		ball.start_pass(player_unit, target_hex)
	else:
		match result.reason:
			"inaccurate":
				ball.start_pass(player_unit, result.miss_hex)
			"intercepted":
				ball.start_pass(player_unit, result.interception_hex)

	_clear_highlights()
	_check_turn_end()


func _execute_shot(target_hex: Vector2i) -> void:
	if not player_unit or not player_unit.has_ball:
		return

	var opponents = away_units if player_unit.is_home_team else home_units
	var goalkeeper = _find_goalkeeper(opponents)
	var blockers = _get_units_between(player_unit.hex_position, target_hex, opponents)

	var result = ActionResolver.execute_shot(player_unit, target_hex, goalkeeper, blockers, match_data)

	if result.success:
		last_shooter = player_unit
		ball.start_shot(player_unit, target_hex)
	else:
		match result.reason:
			"blocked":
				ball.make_loose(result.block_hex)
			"saved":
				# Ball saved - loose near goalkeeper
				var save_hex = _get_save_landing_hex(target_hex)
				ball.make_loose(save_hex)
			"off_target":
				# Ball goes out - misses the goal
				var miss_hex = _get_off_target_hex(target_hex)
				ball.make_loose(miss_hex)

	_clear_highlights()
	_check_turn_end()


func _execute_tackle(target_hex: Vector2i) -> void:
	if not player_unit:
		return

	var target = _get_unit_at_hex(target_hex)
	if not target:
		return

	var result = ActionResolver.execute_tackle(player_unit, target, match_data)

	if result.success:
		ball.give_possession(player_unit)
	elif result.reason == "foul":
		# Handle foul - give free kick
		ball.make_loose(target.hex_position)
		# For now, just continue play

	_clear_highlights()
	_check_turn_end()


func _execute_dribble(target_hex: Vector2i) -> void:
	if not player_unit or not player_unit.has_ball:
		return

	# Check if there's a defender to beat
	var opponents = away_units if player_unit.is_home_team else home_units
	var defender: PlayerUnit = null

	for opp in opponents:
		if HexUtils.hex_distance(player_unit.hex_position, opp.hex_position) == 1:
			if HexUtils.hex_distance(target_hex, opp.hex_position) <= 1:
				defender = opp
				break

	var result = ActionResolver.execute_dribble(player_unit, target_hex, defender, match_data, current_dribble_move_id)

	if result.success:
		var occupied = _get_all_occupied_hexes()
		occupied.erase(player_unit.hex_position)
		var path = HexUtils.find_path(player_unit.hex_position, target_hex, occupied)
		if path.is_empty():
			path = [player_unit.hex_position, target_hex]
		player_unit.move_to_hex(path)
	elif result.reason == "dispossessed" and defender:
		ball.give_possession(defender)

	_clear_highlights()
	_check_turn_end()


func _cancel_action() -> void:
	current_action = ""
	_clear_highlights()
	if player_unit and player_unit.is_selected:
		_show_move_range(player_unit)


## Action button handlers (called from UI)
## Set the current dribble move for player actions.
func set_dribble_move(move_id: String) -> void:
	if move_id == current_dribble_move_id:
		return

	if player_unit and not DribbleMoves.is_move_unlocked(player_unit, move_id):
		return

	current_dribble_move_id = move_id
	dribble_move_changed.emit(move_id)


func select_action(action: String) -> void:
	if current_phase != TurnPhase.PLAYER:
		return

	if not player_unit:
		return

	# Check AP cost
	var ap_cost = ActionResolver.AP_COST.get(action, 1)
	if action == "dribble":
		if not DribbleMoves.is_move_unlocked(player_unit, current_dribble_move_id):
			return
		var move = DribbleMoves.get_move(current_dribble_move_id)
		ap_cost = int(move.get("ap_cost", ap_cost))

	if player_unit.action_points < ap_cost:
		return

	# Check if player has ball (for ball actions)
	if action in ["pass", "through_ball", "shoot", "dribble"] and not player_unit.has_ball:
		return

	if action == "dribble":
		var stamina_cost = int(DribbleMoves.get_move(current_dribble_move_id).get("stamina_cost", 0))
		if player_unit.stamina < stamina_cost:
			return

	current_action = action
	action_selected.emit(action)
	_show_action_range(action)


func end_player_turn() -> void:
	if not is_player_turn_active:
		return

	is_player_turn_active = false
	_process_next_initiative_actor()


## Turn management
func _start_player_turn() -> void:
	_clear_highlights()
	current_phase = TurnPhase.PLAYER

	# Reset all units for this turn.
	for unit in all_units:
		unit.reset_turn()

	# Build initiative order for this minute and start the queue.
	_build_initiative_order()
	initiative_cursor = -1
	is_player_turn_active = false
	_process_next_initiative_actor()


func _process_next_initiative_actor() -> void:
	var actor: PlayerUnit = _get_next_initiative_actor()

	# All actors completed
	if not actor:
		is_player_turn_active = false
		_end_turn()
		return

	# Clear any stale player selection/highlights between actor switches.
	selected_unit = null
	_clear_highlights()
	current_action = ""
	_update_active_player_selection(actor)

	if actor == player_unit:
		current_phase = TurnPhase.PLAYER
		is_player_turn_active = true
		turn_changed.emit(current_phase, current_turn)
		_select_unit(actor)
		return

	current_phase = TurnPhase.TEAM if _is_player_team_unit(actor) else TurnPhase.OPPONENT
	turn_changed.emit(current_phase, current_turn)

	await _process_ai_unit_turn(actor)
	_process_next_initiative_actor()


func _build_initiative_order() -> void:
	var initiative_entries: Array[Dictionary] = []

	for unit in all_units:
		if unit == null:
			continue

		initiative_entries.append({
			"unit": unit,
			"initiative": _calculate_unit_initiative(unit)
		})

	initiative_entries.sort_custom(_sort_initiative_entries)

	initiative_order.clear()
	for entry in initiative_entries:
		initiative_order.append(entry.get("unit", null))


func _get_next_initiative_actor() -> PlayerUnit:
	initiative_cursor += 1

	while initiative_cursor < initiative_order.size():
		var candidate = initiative_order[initiative_cursor]
		if candidate and candidate.action_points > 0:
			return candidate
		initiative_cursor += 1

	return null


func _calculate_unit_initiative(unit: PlayerUnit) -> int:
	var speed = unit.get_stat("SPD")
	var role_penalty = -3 if unit.is_goalkeeper() else 0
	var player_bonus = 2 if unit.is_player_controlled else 0
	return (speed * 2) + player_bonus + role_penalty + randi_range(0, INITIATIVE_RANDOM_BONUS)


func _sort_initiative_entries(a: Dictionary, b: Dictionary) -> bool:
	var a_initiative = int(a.get("initiative", 0))
	var b_initiative = int(b.get("initiative", 0))

	if a_initiative == b_initiative:
		var a_unit = a.get("unit", null)
		var b_unit = b.get("unit", null)
		if a_unit == null or b_unit == null:
			return false

		if a_unit.overall == b_unit.overall:
			return int(a_unit.get_stat("PAS")) > int(b_unit.get_stat("PAS"))
		return a_unit.overall > b_unit.overall

	return a_initiative > b_initiative


func _is_player_team_unit(unit: PlayerUnit) -> bool:
	return player_unit != null and unit.is_home_team == player_unit.is_home_team


func _update_active_player_selection(unit: PlayerUnit) -> void:
	if player_unit:
		player_unit.set_selected(false)
	
	if unit == player_unit and unit:
		player_unit.set_selected(true)


func _process_ai_unit_turn(unit: PlayerUnit) -> void:
	var actions_per_turn = mini(unit.max_action_points, 3)
	var is_player_team = _is_player_team_unit(unit)
	var attacking_right = home_attacks_right if unit.is_home_team else not home_attacks_right
	var tactics = match_data.home_team.tactics if unit.is_home_team else match_data.away_team.tactics

	for _i in range(actions_per_turn):
		if unit.action_points <= 0:
			break

		var decision: Dictionary = {}
		if is_player_team:
			decision = TeammateAI.take_turn(unit, ball, all_units, match_data, attacking_right)
		else:
			decision = OpponentAI.take_turn(unit, ball, all_units, match_data, tactics, attacking_right)

		await _execute_ai_decision(unit, decision)

		# Small delay for visibility
		await get_tree().create_timer(0.1).timeout


func _end_turn() -> void:
	current_turn += 1
	match_minute += MINUTES_PER_TURN
	match_minute_changed.emit(match_minute)

	# Update match data
	if match_data:
		match_data.current_minute = match_minute

	# Check for half/full time
	if current_turn >= TURNS_PER_HALF and current_half == 1:
		_start_half_time()
	elif current_turn >= TURNS_PER_HALF * 2:
		_end_match()
	else:
		_start_player_turn()


func _start_half_time() -> void:
	match_phase = MatchPhase.HALF_TIME
	current_half = 2

	# Switch sides
	home_attacks_right = not home_attacks_right
	_reset_positions()

	# Give ball to away team for second half kickoff
	var kickoff_unit = _get_kickoff_unit(false)
	if kickoff_unit:
		ball.give_possession(kickoff_unit)
	elif away_units.size() > 0:
		# Fallback if no kickoff unit found
		ball.give_possession(away_units[0])
	elif home_units.size() > 0:
		# Last resort fallback
		ball.give_possession(home_units[0])

	match_phase = MatchPhase.PLAYING
	_start_player_turn()


func _end_match() -> void:
	match_phase = MatchPhase.FULL_TIME

	# Update match data scores
	if match_data:
		match_data.home_score = home_score
		match_data.away_score = away_score

	# Generate result and transition
	var result: Dictionary
	if match_data:
		result = match_data.generate_result()
	else:
		# Fallback result when match_data is null
		push_warning("[MatchController] match_data is null, generating fallback result")
		result = _generate_fallback_result()

	# Add goal events for season tracking
	result["home_goal_events"] = home_goal_events
	result["away_goal_events"] = away_goal_events

	match_ended.emit(result)

	GameManager.end_match(result)
	get_tree().change_scene_to_file("res://scenes/match/post_match.tscn")


func _generate_fallback_result() -> Dictionary:
	# Create minimal result when match_data is unavailable
	var player_is_home = player_unit and player_unit.is_home_team
	var player_score = home_score if player_is_home else away_score
	var opponent_score = away_score if player_is_home else home_score

	return {
		"match_id": "unknown",
		"match_type": "unknown",
		"importance": 1.0,
		"opponent_name": "Opponent",
		"won": player_score > opponent_score,
		"lost": player_score < opponent_score,
		"draw": player_score == opponent_score,
		"player_score": player_score,
		"opponent_score": opponent_score,
		"goals": 0,
		"assists": 0,
		"rating": 6.0,
		"man_of_match": false,
		"clean_sheet": opponent_score == 0,
		"shots": 0,
		"shots_on_target": 0,
		"successful_passes": 0,
		"successful_tackles": 0,
		"successful_dribbles": 0,
		"distance_covered": 0,
		"yellow_cards": 0,
		"red_card": false,
		"key_events": []
	}


func _reset_positions() -> void:
	# Reset all units to formation positions
	var home_formation = HexUtils.get_formation_positions(match_data.home_team.formation, home_attacks_right)
	var away_formation = HexUtils.get_formation_positions(match_data.away_team.formation, not home_attacks_right)

	for i in range(mini(home_units.size(), home_formation.size())):
		home_units[i].set_hex_position(home_formation[i].hex)
		home_units[i].reset_turn()

	for i in range(mini(away_units.size(), away_formation.size())):
		away_units[i].set_hex_position(away_formation[i].hex)
		away_units[i].reset_turn()

	ball.set_hex_position(HexUtils.get_center_hex())


## AI Processing
func _execute_ai_decision(unit: PlayerUnit, decision: Dictionary) -> void:
	var action = decision.get("action", "none")

	match action:
		"move":
			var target = decision.get("target", unit.hex_position)
			var occupied = _get_all_occupied_hexes()
			var result = ActionResolver.execute_move(unit, target, occupied)
			if result.success:
				unit.move_to_hex(result.path)
				await unit.move_completed

		"pass":
			if unit.has_ball:
				var target = decision.get("target", unit.hex_position)
				var receiver = decision.get("receiver")
				var opponents = away_units if unit.is_home_team else home_units
				var result = ActionResolver.execute_pass(unit, target, receiver, opponents, match_data)

				if result.success:
					# Track passer for potential assist
					last_passer = unit
					ball.start_pass(unit, target)
				else:
					var miss_hex = result.get("miss_hex", result.get("interception_hex", target))
					ball.start_pass(unit, miss_hex)

				await ball.ball_arrived

		"through_ball":
			if unit.has_ball:
				var target = decision.get("target")
				var opponents = away_units if unit.is_home_team else home_units
				var result = ActionResolver.execute_through_ball(unit, target, opponents, match_data)

				var final_target = target
				if not result.success:
					final_target = result.get("miss_hex", result.get("interception_hex", target))

				# Track passer for potential assist
				last_passer = unit
				ball.start_pass(unit, final_target)
				await ball.ball_arrived

		"shoot":
			if unit.has_ball:
				var attacking_right = home_attacks_right if unit.is_home_team else not home_attacks_right
				var target = decision.get("target", HexUtils.get_goal_hex(attacking_right))
				var opponents = away_units if unit.is_home_team else home_units
				var goalkeeper = _find_goalkeeper(opponents)
				var blockers = _get_units_between(unit.hex_position, target, opponents)
				var result = ActionResolver.execute_shot(unit, target, goalkeeper, blockers, match_data)

				if result.success:
					last_shooter = unit
					ball.start_shot(unit, target)
				else:
					if result.reason == "blocked":
						ball.make_loose(result.block_hex)
					elif result.reason == "saved":
						ball.make_loose(_get_save_landing_hex(target))
					else:  # off_target
						var miss_hex = _get_off_target_hex(target)
						ball.make_loose(miss_hex)

				await get_tree().create_timer(0.3).timeout

		"tackle":
			var target = decision.get("target")
			if target:
				var result = ActionResolver.execute_tackle(unit, target, match_data)
				if result.success:
					ball.give_possession(unit)

		"dribble":
			if unit.has_ball:
				var target = decision.get("target")
				var defender = decision.get("defender")
				var move_id = decision.get("move_id", "basic")
				var result = ActionResolver.execute_dribble(unit, target, defender, match_data, move_id)
				if result.success:
					var occupied = _get_all_occupied_hexes()
					occupied.erase(unit.hex_position)
					var path = HexUtils.find_path(unit.hex_position, target, occupied)
					if path.is_empty():
						path = [unit.hex_position, target]
					unit.move_to_hex(path)
					await unit.move_completed
				elif result.reason == "dispossessed" and defender:
					ball.give_possession(defender)


## Event handlers
func _on_goal_scored(is_home_goal: bool) -> void:
	# is_home_goal means the ball entered the home team's goal (away team scored)
	if is_home_goal:
		away_score += 1
	else:
		home_score += 1

	# Possession is cleared while the ball is in flight, so track the shooter explicitly.
	var scorer = last_shooter if last_shooter else ball.get_possessing_unit()

	# Create goal event for season tracking
	var goal_event: Dictionary = {}
	if scorer:
		goal_event["scorer_id"] = scorer.unit_id
		goal_event["scorer_name"] = scorer.unit_name
		goal_event["minute"] = max(match_minute, 1)

		# Add assist if last passer was from the same team and different from scorer
		if last_passer and last_passer != scorer and last_passer.is_home_team == scorer.is_home_team:
			goal_event["assister_id"] = last_passer.unit_id
			goal_event["assister_name"] = last_passer.unit_name
			# Record assist in match_data for player career stats and rating
			if last_passer.is_player_controlled and match_data:
				match_data.record_event("assist", {"is_player": true})

	# Store goal event for season tracking
	if is_home_goal:
		# Away team scored
		if match_data and match_data.away_team:
			goal_event["team_id"] = match_data.away_team.id
			goal_event["team_name"] = match_data.away_team.name
		away_goal_events.append(goal_event)
	else:
		# Home team scored
		if match_data and match_data.home_team:
			goal_event["team_id"] = match_data.home_team.id
			goal_event["team_name"] = match_data.home_team.name
		home_goal_events.append(goal_event)

	# Reset last passer after goal
	last_passer = null
	last_shooter = null

	# Update match data
	if match_data:
		match_data.home_score = home_score
		match_data.away_score = away_score

	score_changed.emit(home_score, away_score)

	# Reset for kickoff
	_reset_for_kickoff(is_home_goal)


func _reset_for_kickoff(home_conceded: bool) -> void:
	_reset_positions()

	# Team that conceded kicks off
	var kickoff_unit = _get_kickoff_unit(home_conceded)
	if kickoff_unit:
		ball.give_possession(kickoff_unit)


func _on_ball_arrived(hex: Vector2i) -> void:
	# Check if any unit can pick up the ball
	var unit_at_hex = _get_unit_at_hex(hex)
	if unit_at_hex:
		ball.give_possession(unit_at_hex)
	else:
		# Ball is loose - nearest unit should contest
		ball.make_loose(hex)


func _on_unit_move_completed(unit: PlayerUnit) -> void:
	# If unit has ball, ball moves with them
	if unit.has_ball:
		ball.hex_position = unit.hex_position


func _check_turn_end() -> void:
	if not is_player_turn_active or not player_unit:
		return

	if player_unit.action_points <= 0:
		# Auto-advance when out of AP
		call_deferred("end_player_turn")


## Helper functions
func _get_unit_at_hex(hex: Vector2i) -> PlayerUnit:
	for unit in all_units:
		if unit.hex_position == hex:
			return unit
	return null


func _get_all_occupied_hexes() -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for unit in all_units:
		occupied.append(unit.hex_position)
	return occupied


func _find_goalkeeper(team: Array[PlayerUnit]) -> PlayerUnit:
	for unit in team:
		if unit.is_goalkeeper():
			return unit
	return null


func _get_units_between(from: Vector2i, to: Vector2i, units: Array[PlayerUnit]) -> Array[PlayerUnit]:
	var line = HexUtils.get_hex_line(from, to)
	var between: Array[PlayerUnit] = []

	for unit in units:
		if unit.hex_position in line and unit.hex_position != from and unit.hex_position != to:
			between.append(unit)

	return between


func _get_save_landing_hex(goal_hex: Vector2i) -> Vector2i:
	# Ball lands near goal after save
	var offset_x = 2 if goal_hex.x < HexUtils.GRID_WIDTH / 2 else -2
	var offset_y = randi_range(-2, 2)
	return Vector2i(
		clampi(goal_hex.x + offset_x, 0, HexUtils.GRID_WIDTH - 1),
		clampi(goal_hex.y + offset_y, 0, HexUtils.GRID_HEIGHT - 1)
	)


func _get_off_target_hex(goal_hex: Vector2i) -> Vector2i:
	# Ball goes wide or over - lands near goal but not on it
	var offset_x = 1 if goal_hex.x < HexUtils.GRID_WIDTH / 2 else -1
	var offset_y = randi_range(-3, 3)
	if offset_y == 0:
		offset_y = 1 if randf() > 0.5 else -1  # Ensure it's not on the goal line
	return Vector2i(
		clampi(goal_hex.x + offset_x, 0, HexUtils.GRID_WIDTH - 1),
		clampi(goal_hex.y + offset_y, 0, HexUtils.GRID_HEIGHT - 1)
	)


## Visual helpers
func _draw_hex_highlight(hex: Vector2i, color: Color) -> void:
	var highlight = ColorRect.new()
	highlight.color = color
	highlight.size = Vector2(HexUtils.HEX_SIZE * 1.5, HexUtils.HEX_SIZE * 1.5)
	highlight.position = HexUtils.hex_to_pixel(hex) - highlight.size / 2
	highlight_layer.add_child(highlight)


func _clear_highlights() -> void:
	for child in highlight_layer.get_children():
		child.queue_free()
	valid_targets.clear()
	action_target_units.clear()
