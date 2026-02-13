extends Node
## TacticalUIController - Handles UI interactions for the tactical match

const DribbleMoves = preload("res://scripts/match/tactical/dribble_moves.gd")

@onready var match_controller: MatchController = get_node("../../MatchController")

# UI elements
@onready var score_label: Label = get_node("../TopBar/HBoxContainer/ScoreLabel")
@onready var home_label: Label = get_node("../TopBar/HBoxContainer/HomeScore")
@onready var away_label: Label = get_node("../TopBar/HBoxContainer/AwayScore")
@onready var minute_label: Label = get_node("../TopBar/HBoxContainer/MinuteLabel")

@onready var turn_label: Label = get_node("../ActionPanel/VBoxContainer/TurnLabel")
@onready var ap_label: Label = get_node("../ActionPanel/VBoxContainer/APLabel")

@onready var move_btn: Button = get_node("../ActionPanel/VBoxContainer/ButtonGrid/MoveBtn")
@onready var pass_btn: Button = get_node("../ActionPanel/VBoxContainer/ButtonGrid/PassBtn")
@onready var shoot_btn: Button = get_node("../ActionPanel/VBoxContainer/ButtonGrid/ShootBtn")
@onready var dribble_btn: Button = get_node("../ActionPanel/VBoxContainer/ButtonGrid/DribbleBtn")
@onready var tackle_btn: Button = get_node("../ActionPanel/VBoxContainer/ButtonGrid/TackleBtn")
@onready var end_turn_btn: Button = get_node("../ActionPanel/VBoxContainer/ButtonGrid/EndTurnBtn")
@onready var substitute_btn: Button = get_node("../ActionPanel/VBoxContainer/ButtonGrid/SubstituteBtn")

@onready var dribble_move_panel: PanelContainer = get_node("../ActionPanel/VBoxContainer/DribbleMovePanel")
@onready var dribble_move_container: HBoxContainer = get_node("../ActionPanel/VBoxContainer/DribbleMovePanel/VBoxContainer/MoveButtons")

@onready var selected_label: Label = get_node("../InfoPanel/VBoxContainer/SelectedLabel")
@onready var position_label: Label = get_node("../InfoPanel/VBoxContainer/PositionLabel")
@onready var stamina_label: Label = get_node("../InfoPanel/VBoxContainer/StaminaLabel")
@onready var stats_label: Label = get_node("../InfoPanel/VBoxContainer/StatsLabel")

@onready var action_panel: PanelContainer = get_node("../ActionPanel")

var dribble_move_buttons: Dictionary = {}


func _ready() -> void:
	# Wait for match controller to initialize
	await get_tree().process_frame

	if match_controller:
		match_controller.turn_changed.connect(_on_turn_changed)
		match_controller.score_changed.connect(_on_score_changed)
		match_controller.match_minute_changed.connect(_on_minute_changed)
		match_controller.action_selected.connect(_on_action_selected)
		match_controller.dribble_move_changed.connect(_on_dribble_move_changed)

	# Set team names from match data
	if GameManager.current_match:
		home_label.text = GameManager.current_match.home_team.short_name if GameManager.current_match.home_team.short_name else GameManager.current_match.home_team.name.substr(0, 8)
		away_label.text = GameManager.current_match.away_team.short_name if GameManager.current_match.away_team.short_name else GameManager.current_match.away_team.name.substr(0, 8)

	_try_build_dribble_moves()
	_update_button_states()


func _process(_delta: float) -> void:
	_try_build_dribble_moves()
	if match_controller and match_controller.player_unit:
		_update_player_info()


func _on_turn_changed(phase: MatchController.TurnPhase, turn_number: int) -> void:
	match phase:
		MatchController.TurnPhase.PLAYER:
			turn_label.text = "YOUR TURN"
			action_panel.modulate = Color.WHITE
			_enable_buttons(true)
		MatchController.TurnPhase.TEAM:
			turn_label.text = "TEAM MOVING..."
			action_panel.modulate = Color(0.7, 0.7, 0.7)
			_enable_buttons(false)
		MatchController.TurnPhase.OPPONENT:
			turn_label.text = "OPPONENT TURN"
			action_panel.modulate = Color(0.7, 0.7, 0.7)
			_enable_buttons(false)

	_update_button_states()


func _on_score_changed(home: int, away: int) -> void:
	score_label.text = "%d - %d" % [home, away]


func _on_minute_changed(minute: int) -> void:
	minute_label.text = "%d'" % minute


func _on_action_selected(action_type: String) -> void:
	# Highlight the selected action button
	_reset_button_highlights()

	match action_type:
		"move":
			move_btn.modulate = Color(1.2, 1.2, 0.5)
		"pass":
			pass_btn.modulate = Color(1.2, 1.2, 0.5)
		"shoot":
			shoot_btn.modulate = Color(1.2, 1.2, 0.5)
		"dribble":
			dribble_btn.modulate = Color(1.2, 1.2, 0.5)
		"tackle":
			tackle_btn.modulate = Color(1.2, 1.2, 0.5)


func _update_player_info() -> void:
	var unit = match_controller.player_unit
	if not unit:
		return

	ap_label.text = "AP: %d/%d" % [unit.action_points, unit.max_action_points]

	if unit.is_selected:
		selected_label.text = "Selected: %s" % unit.unit_name
		position_label.text = "Position: %s" % unit.position_role
		stamina_label.text = "Stamina: %d%%" % unit.stamina
		stats_label.text = "SPD: %d TEC: %d\nPAS: %d SHO: %d" % [
			unit.get_stat("SPD"),
			unit.get_stat("TEC"),
			unit.get_stat("PAS"),
			unit.get_stat("SHO")
		]

	_update_button_states()


func _update_button_states() -> void:
	if not match_controller or not match_controller.player_unit:
		return

	if match_controller.current_phase != MatchController.TurnPhase.PLAYER:
		_enable_buttons(false)
		substitute_btn.text = "Substitute"
		_update_dribble_move_buttons_state()
		return

	var unit = match_controller.player_unit
	var ap = unit.action_points
	var has_ball = unit.has_ball

	# Move always available if has AP
	move_btn.disabled = ap < 1

	# Ball actions require possession
	pass_btn.disabled = ap < 1 or not has_ball
	shoot_btn.disabled = ap < 2 or not has_ball
	var dribble_move = DribbleMoves.get_move(match_controller.current_dribble_move_id)
	var dribble_stamina_cost = int(dribble_move.get("stamina_cost", 0))
	var dribble_unlocked = DribbleMoves.is_move_unlocked(unit, match_controller.current_dribble_move_id)
	dribble_btn.disabled = ap < 1 or not has_ball or unit.stamina < dribble_stamina_cost or not dribble_unlocked

	# Tackle requires adjacent opponent with ball
	var can_tackle = _can_tackle()
	tackle_btn.disabled = ap < 1 or not can_tackle

	end_turn_btn.disabled = false
	substitute_btn.disabled = not match_controller.can_player_substitute()
	var remaining_subs = match_controller.get_remaining_substitutions()
	substitute_btn.text = "Substitute (%d)" % remaining_subs
	_update_dribble_move_buttons_state()


func _can_tackle() -> bool:
	if not match_controller or not match_controller.player_unit:
		return false

	var unit = match_controller.player_unit
	var opponents = match_controller.away_units if unit.is_home_team else match_controller.home_units

	for opp in opponents:
		if opp.has_ball and HexUtils.hex_distance(unit.hex_position, opp.hex_position) <= 1:
			return true

	return false


func _enable_buttons(enabled: bool) -> void:
	move_btn.disabled = not enabled
	pass_btn.disabled = not enabled
	shoot_btn.disabled = not enabled
	dribble_btn.disabled = not enabled
	tackle_btn.disabled = not enabled
	end_turn_btn.disabled = not enabled
	substitute_btn.disabled = not enabled


func _reset_button_highlights() -> void:
	move_btn.modulate = Color.WHITE
	pass_btn.modulate = Color.WHITE
	shoot_btn.modulate = Color.WHITE
	dribble_btn.modulate = Color.WHITE
	tackle_btn.modulate = Color.WHITE
	substitute_btn.modulate = Color.WHITE


## Build dribble move buttons once the player unit is available.
func _try_build_dribble_moves() -> void:
	if dribble_move_buttons.size() > 0:
		return
	if not match_controller or not match_controller.player_unit:
		return

	_build_dribble_move_buttons()


## Create dribble move UI buttons and set a default move.
func _build_dribble_move_buttons() -> void:
	if not dribble_move_container:
		return

	for child in dribble_move_container.get_children():
		child.queue_free()
	dribble_move_buttons.clear()

	var moves = DribbleMoves.get_move_entries(match_controller.player_unit)
	if moves.is_empty():
		dribble_move_panel.visible = false
		return

	dribble_move_panel.visible = true

	for move in moves:
		var move_id = move.get("id", "basic")
		var button = Button.new()
		button.text = move.get("name", "Move")
		button.custom_minimum_size = Vector2(90, 28)
		button.tooltip_text = _build_dribble_tooltip(move, move.get("lock_reasons", []))
		button.disabled = move.get("locked", false)
		button.pressed.connect(_on_dribble_move_pressed.bind(move_id))
		dribble_move_container.add_child(button)
		dribble_move_buttons[move_id] = button

	if not match_controller.current_dribble_move_id or match_controller.current_dribble_move_id == "" or not DribbleMoves.is_move_unlocked(match_controller.player_unit, match_controller.current_dribble_move_id):
		var default_move_id = "basic"
		for move in moves:
			if not move.get("locked", false):
				default_move_id = move.get("id", "basic")
				break
		match_controller.set_dribble_move(default_move_id)

	_highlight_dribble_move_button(match_controller.current_dribble_move_id)
	_update_dribble_move_buttons_state()


## Handle dribble move selection from UI.
func _on_dribble_move_pressed(move_id: String) -> void:
	AudioManager.play_ui_click()
	if not match_controller:
		return

	if not DribbleMoves.is_move_unlocked(match_controller.player_unit, move_id):
		return

	match_controller.set_dribble_move(move_id)
	if match_controller.current_action == "dribble":
		match_controller.select_action("dribble")


## Update UI when dribble move changes.
func _on_dribble_move_changed(move_id: String) -> void:
	_highlight_dribble_move_button(move_id)
	_update_dribble_move_buttons_state()
	_update_button_states()


## Visually highlight the active dribble move.
func _highlight_dribble_move_button(move_id: String) -> void:
	for id in dribble_move_buttons:
		var button: Button = dribble_move_buttons[id]
		if id == move_id and DribbleMoves.is_move_unlocked(match_controller.player_unit, id):
			button.modulate = Color(1.2, 1.2, 0.5)


## Enable or disable move buttons based on stamina and turn state.
func _update_dribble_move_buttons_state() -> void:
	if not match_controller or not match_controller.player_unit:
		return

	var unit = match_controller.player_unit
	var is_player_turn = match_controller.current_phase == MatchController.TurnPhase.PLAYER
	var has_ball = unit.has_ball
	var ap = unit.action_points
	for id in dribble_move_buttons:
		var move = DribbleMoves.get_move(id)
		var status = DribbleMoves.get_move_status(unit, id)
		var stamina_cost = int(move.get("stamina_cost", 0))
		var ap_cost = int(move.get("ap_cost", 1))
		var locked = status.locked
		var can_use = is_player_turn and ap >= ap_cost and unit.stamina >= stamina_cost and has_ball and not locked
		var button: Button = dribble_move_buttons[id]
		button.tooltip_text = _build_dribble_tooltip(move, status.reasons)
		button.disabled = not can_use
		if locked:
			button.modulate = Color(0.7, 0.7, 0.7)
		else:
			button.modulate = Color.WHITE

	_highlight_dribble_move_button(match_controller.current_dribble_move_id)


## Build tooltip text for dribble move buttons.
func _build_dribble_tooltip(move: Dictionary, lock_reasons: Array) -> String:
	var lines: Array[String] = []
	var desc = move.get("desc", "")
	if desc != "":
		lines.append(desc)
	lines.append("STA -%d | Bonus +%d" % [
		int(move.get("stamina_cost", 0)),
		int(move.get("dribble_bonus", 0))
	])
	if lock_reasons.size() > 0:
		lines.append("LOCKED: %s" % ", ".join(lock_reasons))
	return "\n".join(lines)
# Button handlers
func _on_move_btn_pressed() -> void:
	AudioManager.play_ui_click()
	# Move is handled by clicking on hex after selecting unit
	# This button just reminds cost


func _on_pass_btn_pressed() -> void:
	AudioManager.play_ui_click()
	if match_controller:
		match_controller.select_action("pass")


func _on_shoot_btn_pressed() -> void:
	AudioManager.play_ui_click()
	if match_controller:
		match_controller.select_action("shoot")


func _on_dribble_btn_pressed() -> void:
	AudioManager.play_ui_click()
	if match_controller:
		match_controller.select_action("dribble")


func _on_tackle_btn_pressed() -> void:
	AudioManager.play_ui_click()
	if match_controller:
		match_controller.select_action("tackle")


func _on_end_turn_btn_pressed() -> void:
	AudioManager.play_ui_click()
	if match_controller:
		match_controller.end_player_turn()


func _on_substitute_btn_pressed() -> void:
	AudioManager.play_ui_click()
	if match_controller and match_controller.can_player_substitute():
		match_controller.perform_substitution()
		_update_button_states()
