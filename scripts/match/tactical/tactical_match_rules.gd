extends RefCounted
class_name TacticalMatchRules
## TacticalMatchRules - Shared helpers for tactical match rules and availability.

const RESTART_NONE := "none"
const RESTART_FREE_KICK := "free_kick"
const RESTART_PENALTY := "penalty"
const RESTART_CORNER := "corner"
const RESTART_GOAL_KICK := "goal_kick"
const RESTART_THROW_IN := "throw_in"
const RESTART_OFFSIDE := "offside"

const SET_PIECE_OFFSIDE_EXEMPT := [
	RESTART_CORNER,
	RESTART_THROW_IN,
	RESTART_GOAL_KICK
]

const YELLOW_SUSPENSION_THRESHOLD := 3
const SUSPENSION_MATCHES := 1


static func build_competition_name(match_data: MatchData) -> String:
	if not match_data:
		return "Unknown Competition"
	if not str(match_data.competition_name).is_empty():
		return str(match_data.competition_name)
	if SeasonManager and SeasonManager.has_method("get_current_competition_name"):
		var season_name = str(SeasonManager.get_current_competition_name())
		if not season_name.is_empty():
			return season_name
	return _humanize_identifier(str(match_data.match_type))


static func build_competition_key(match_data: MatchData) -> String:
	if not match_data:
		return "unknown::unknown"
	var competition_name = build_competition_name(match_data)
	var match_type = str(match_data.match_type if not str(match_data.match_type).is_empty() else "match")
	return "%s::%s" % [match_type.to_lower(), _slugify(competition_name)]


static func is_receiver_offside(receiver: PlayerUnit, passer: PlayerUnit, defenders: Array[PlayerUnit], attacking_right: bool, restart_type: String = RESTART_NONE) -> bool:
	if not receiver or not passer:
		return false
	if restart_type in SET_PIECE_OFFSIDE_EXEMPT:
		return false

	var ball_hex = passer.hex_position
	var receiver_hex = receiver.hex_position
	if not _is_in_opponent_half(receiver_hex, attacking_right):
		return false

	var forward_dir = 1 if attacking_right else -1
	var receiver_progress = receiver_hex.x * forward_dir
	var ball_progress = ball_hex.x * forward_dir
	if receiver_progress <= ball_progress:
		return false

	var defender_progress = get_second_last_defender_progress(defenders, attacking_right)
	return receiver_progress > defender_progress


static func get_second_last_defender_progress(defenders: Array[PlayerUnit], attacking_right: bool) -> int:
	if defenders.is_empty():
		return 9999

	var forward_dir = 1 if attacking_right else -1
	var progresses: Array[int] = []
	for defender in defenders:
		if not defender or not defender.is_active_in_match():
			continue
		progresses.append(defender.hex_position.x * forward_dir)

	if progresses.is_empty():
		return 9999

	progresses.sort_custom(func(a: int, b: int) -> bool:
		return a > b
	)
	return progresses[min(1, progresses.size() - 1)]


static func get_default_through_ball_target(receiver: PlayerUnit, attacking_right: bool) -> Vector2i:
	if not receiver:
		return Vector2i.ZERO
	var forward_dir = 1 if attacking_right else -1
	var target = Vector2i(receiver.hex_position.x + forward_dir * 2, receiver.hex_position.y)
	if not HexUtils.is_valid_hex(target):
		target.x = clampi(target.x, 0, HexUtils.GRID_WIDTH - 1)
		target.y = clampi(target.y, 0, HexUtils.GRID_HEIGHT - 1)
	return target


static func classify_ball_exit(exit_hex: Vector2i, last_touch_is_home: bool) -> Dictionary:
	var exited_top = exit_hex.y < 0
	var exited_bottom = exit_hex.y >= HexUtils.GRID_HEIGHT
	var exited_left = exit_hex.x < 0
	var exited_right = exit_hex.x >= HexUtils.GRID_WIDTH

	if exited_top or exited_bottom:
		return {
			"restart_type": RESTART_THROW_IN,
			"restart_hex": Vector2i(clampi(exit_hex.x, 1, HexUtils.GRID_WIDTH - 2), 0 if exited_top else HexUtils.GRID_HEIGHT - 1),
			"is_home_team": not last_touch_is_home
		}

	if not exited_left and not exited_right:
		return {"restart_type": RESTART_NONE}

	var by_home_goal = exited_left
	var defending_home = by_home_goal
	var attacking_home = not defending_home
	var last_touch_was_attacker = last_touch_is_home == attacking_home
	var is_goal_kick = last_touch_was_attacker

	if is_goal_kick:
		return {
			"restart_type": RESTART_GOAL_KICK,
			"restart_hex": get_goal_kick_hex(defending_home),
			"is_home_team": defending_home
		}

	var corner_y = 0 if exit_hex.y < HexUtils.GRID_HEIGHT / 2 else HexUtils.GRID_HEIGHT - 1
	return {
		"restart_type": RESTART_CORNER,
		"restart_hex": Vector2i(0 if by_home_goal else HexUtils.GRID_WIDTH - 1, corner_y),
		"is_home_team": attacking_home
	}


static func get_goal_kick_hex(is_home_team: bool) -> Vector2i:
	return Vector2i(2, HexUtils.HOME_GOAL_HEX.y) if is_home_team else Vector2i(HexUtils.GRID_WIDTH - 3, HexUtils.AWAY_GOAL_HEX.y)


static func get_penalty_hex(attacking_right: bool) -> Vector2i:
	return Vector2i(HexUtils.GRID_WIDTH - 3, HexUtils.AWAY_GOAL_HEX.y) if attacking_right else Vector2i(2, HexUtils.HOME_GOAL_HEX.y)


static func create_set_piece_context(restart_type: String, restart_hex: Vector2i, is_home_team: bool, attacking_right: bool, detail: Dictionary = {}) -> Dictionary:
	var ctx = detail.duplicate(true)
	ctx["restart_type"] = restart_type
	ctx["restart_hex"] = restart_hex
	ctx["is_home_team"] = is_home_team
	ctx["attacking_right"] = attacking_right
	return ctx


static func player_match_availability(match_data: MatchData) -> Dictionary:
	if not GameManager.player_data or not match_data:
		return {"eligible": true, "reason": "", "detail": ""}

	var player_team = match_data.get_player_team()
	if not player_team or not GameManager.current_team or player_team.id != GameManager.current_team.id:
		return {"eligible": true, "reason": "", "detail": ""}

	return GameManager.player_data.get_match_availability(match_data.competition_key)


static func serve_competition_suspensions(match_data: MatchData) -> void:
	if not match_data:
		return

	var competition_key = str(match_data.competition_key)
	if competition_key.is_empty():
		competition_key = build_competition_key(match_data)

	var player_team = match_data.get_player_team()
	if player_team and GameManager.player_data and GameManager.current_team and player_team.id == GameManager.current_team.id:
		GameManager.player_data.serve_suspension(competition_key)

	for team in [match_data.home_team, match_data.away_team]:
		if not team:
			continue
		for player in team.players:
			var player_id = str(player.get("id", ""))
			if player_id.is_empty() or not NpcRegistry.has_npc(player_id):
				continue
			NpcRegistry.serve_suspension(player_id, competition_key)


static func apply_result_discipline(match_data: MatchData, result: Dictionary) -> void:
	if not match_data:
		return

	var competition_key = str(match_data.competition_key)
	if competition_key.is_empty():
		competition_key = build_competition_key(match_data)

	for event in extract_card_events(result):
		var player_id = str(event.get("player_id", ""))
		if player_id.is_empty():
			continue

		var card_color = str(event.get("card_color", ""))
		var dismissal_reason = str(event.get("dismissal_reason", ""))
		if dismissal_reason == "second_yellow" and card_color == "yellow":
			continue
		var card_type = dismissal_reason if dismissal_reason in ["second_yellow", "red"] else card_color
		if card_type.is_empty():
			card_type = "red" if card_color == "red" else "yellow"

		if GameManager.player_data and player_id == GameManager.player_data.id:
			GameManager.player_data.record_competition_card(competition_key, card_type)
		elif NpcRegistry.has_npc(player_id):
			NpcRegistry.record_competition_card(player_id, competition_key, card_type)


static func apply_result_injuries(result: Dictionary) -> void:
	var injuries = result.get("injury_events", [])
	for injury in injuries:
		var player_id = str(injury.get("player_id", ""))
		if player_id.is_empty():
			continue

		if GameManager.player_data and player_id == GameManager.player_data.id:
			GameManager.player_data.apply_injury_report(injury)
		elif NpcRegistry.has_npc(player_id):
			NpcRegistry.apply_injury(
				player_id,
				str(injury.get("type", "minor")),
				int(injury.get("matches_out", 1)),
				str(injury.get("description", "injury")),
				str(injury.get("injury_type", ""))
			)


static func extract_card_events(result: Dictionary) -> Array[Dictionary]:
	var card_events: Array[Dictionary] = []
	for event in result.get("card_events", []):
		card_events.append(event.duplicate(true))
	return card_events


static func extract_tactical_card_events(match_data: MatchData) -> Array[Dictionary]:
	var card_events: Array[Dictionary] = []
	if not match_data:
		return card_events

	for event in match_data.events:
		var event_type = str(event.get("type", ""))
		if event_type not in ["yellow_card", "red_card"]:
			continue
		var data = event.get("data", {})
		card_events.append({
			"minute": int(event.get("minute", 0)),
			"team_id": str(data.get("team_id", "")),
			"team_name": str(data.get("team_name", "")),
			"player_id": str(data.get("player_id", "")),
			"player_name": str(data.get("player_name", "")),
			"card_color": "red" if event_type == "red_card" else "yellow",
			"dismissal_reason": str(data.get("dismissal_reason", ""))
		})
	return card_events


static func is_restart_exempt_from_offside(restart_type: String) -> bool:
	return restart_type in SET_PIECE_OFFSIDE_EXEMPT


static func _is_in_opponent_half(hex: Vector2i, attacking_right: bool) -> bool:
	var halfway = int(HexUtils.GRID_WIDTH / 2)
	return hex.x > halfway if attacking_right else hex.x < halfway


static func _slugify(value: String) -> String:
	var output = value.strip_edges().to_lower()
	output = output.replace("-", "_").replace(" ", "_")
	var cleaned := ""
	for i in range(output.length()):
		var chr = output.substr(i, 1)
		if "abcdefghijklmnopqrstuvwxyz0123456789_".find(chr) != -1:
			cleaned += chr
		elif chr == "/" or chr == ":":
			cleaned += "_"
	return cleaned.strip_edges().trim_suffix("_").trim_prefix("_")


static func _humanize_identifier(identifier: String) -> String:
	if identifier.is_empty():
		return ""
	var parts = identifier.replace("-", "_").split("_", false)
	var words: Array[String] = []
	for part in parts:
		var lowered = part.to_lower()
		words.append("U20" if lowered == "u20" else lowered.capitalize())
	return " ".join(words)
