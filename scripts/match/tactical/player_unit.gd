extends Node2D
class_name PlayerUnit
## PlayerUnit - Represents a single player on the tactical pitch

signal action_points_changed(new_ap: int)
signal stamina_changed(new_stamina: int)
signal selected()
signal deselected()
signal move_completed()

# Unit identification
var unit_id: String = ""
var unit_name: String = ""
var position_role: String = ""  # GK, CB, FB, CDM, CM, CAM, WNG, ST
var is_player_controlled: bool = false
var is_home_team: bool = true
var dominant_foot: String = "right"

# Stats (copied from player/NPC data)
var stats: Dictionary = {}
var overall: int = 50
var live_injury: Dictionary = {
	"type": "",
	"injury_type": "",
	"matches_remaining": 0,
	"matches_total": 0,
	"description": ""
}
var sent_off_reason: String = ""

# Grid position
var hex_position: Vector2i = Vector2i.ZERO
var target_hex: Vector2i = Vector2i.ZERO

# Turn resources
var action_points: int = 3
var max_action_points: int = 3
var stamina: int = 100
var max_stamina: int = 100

# Ball state
var has_ball: bool = false

# Visual state
var is_selected: bool = false
var is_moving: bool = false
var move_path: Array[Vector2i] = []
var move_speed: float = 200.0  # Pixels per second

# Visual components
var sprite: Sprite2D
var selection_indicator: Node2D
var ap_label: Label
var name_label: Label

# Team colors
var team_color: Color = Color.BLUE

const MINOR_INJURY_STAT_PENALTIES: Dictionary = {
	"muscle_tightness": {"STA": 6, "SPD": 4, "TEC": 2},
	"light_bruising": {"PHY": 5, "DEF": 2, "MEN": 2},
	"ankle_niggle": {"SPD": 6, "TEC": 4, "PAS": 2},
	"minor_cramp": {"STA": 7, "SPD": 3, "PHY": 2},
	"ankle_sprain": {"SPD": 8, "TEC": 5, "PAS": 3},
	"hamstring_pull": {"STA": 9, "SPD": 8, "PHY": 4},
	"knee_twist": {"SPD": 7, "DEF": 4, "PHY": 5},
	"quadriceps_strain": {"STA": 8, "SPD": 6, "SHO": 3},
	"_default": {"STA": 4, "SPD": 2, "MEN": 1}
}

const ACTION_STAMINA_COSTS := {
	"move": 2,
	"sprint": 10,
	"pass": 3,
	"through_ball": 5,
	"shoot": 6,
	"dribble": 5,
	"tackle": 4
}


func _ready() -> void:
	_setup_visuals()


func _process(delta: float) -> void:
	if is_moving and move_path.size() > 0:
		_process_movement(delta)


func _setup_visuals() -> void:
	# Create player sprite placeholder (will be a circle with team color)
	sprite = Sprite2D.new()
	add_child(sprite)

	# Create a simple circle texture
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for x in range(32):
		for y in range(32):
			var dist = Vector2(x - 16, y - 16).length()
			if dist <= 14:
				image.set_pixel(x, y, team_color)
			elif dist <= 16:
				image.set_pixel(x, y, Color.WHITE)

	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

	# Selection indicator (ring around player)
	selection_indicator = Node2D.new()
	selection_indicator.visible = false
	add_child(selection_indicator)

	# Name label
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-30, -30)
	name_label.custom_minimum_size = Vector2(60, 20)
	name_label.add_theme_font_size_override("font_size", 10)
	add_child(name_label)

	# AP indicator (small label showing remaining AP)
	ap_label = Label.new()
	ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_label.position = Vector2(-10, 18)
	ap_label.custom_minimum_size = Vector2(20, 15)
	ap_label.add_theme_font_size_override("font_size", 9)
	add_child(ap_label)


func initialize(data: Dictionary, home_team: bool, player_char: bool = false) -> void:
	unit_id = data.get("id", "unit_%d" % randi())
	unit_name = data.get("name", "Player")
	position_role = data.get("position", "CM")
	stats = data.get("base_stats", data.get("stats", {})).duplicate(true)
	overall = int(data.get("base_overall", data.get("overall", 50)))
	is_home_team = home_team
	is_player_controlled = player_char
	dominant_foot = data.get("dominant_foot", "right")
	stamina = clampi(int(data.get("stamina_current", max_stamina)), 0, max_stamina)
	live_injury = _normalize_injury_record(data.get("injury", {}))

	# Set visual representation
	team_color = Color(0.2, 0.4, 0.8) if is_home_team else Color(0.8, 0.2, 0.2)
	if is_player_controlled:
		team_color = Color(1.0, 0.8, 0.2)  # Gold for player

	_update_sprite_color()
	_update_labels()


func _update_sprite_color() -> void:
	if not sprite:
		return

	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	for x in range(32):
		for y in range(32):
			var dist = Vector2(x - 16, y - 16).length()
			if dist <= 12:
				image.set_pixel(x, y, team_color)
			elif dist <= 14:
				image.set_pixel(x, y, Color.WHITE)
			elif is_player_controlled and dist <= 16:
				image.set_pixel(x, y, Color.GOLD)

	sprite.texture = ImageTexture.create_from_image(image)


func _update_labels() -> void:
	if name_label:
		var short_name = unit_name.split(" ")[-1] if " " in unit_name else unit_name
		name_label.text = short_name.substr(0, 8)
		if is_player_controlled:
			name_label.add_theme_color_override("font_color", Color.GOLD)

	if ap_label:
		ap_label.text = str(action_points) if action_points > 0 else ""


func set_hex_position(hex: Vector2i, instant: bool = true) -> void:
	hex_position = hex
	var pixel_pos = HexUtils.hex_to_pixel(hex)

	if instant:
		position = pixel_pos
	else:
		target_hex = hex


func move_to_hex(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return

	move_path = path
	is_moving = true


func _process_movement(delta: float) -> void:
	if move_path.is_empty():
		is_moving = false
		move_completed.emit()
		return

	var target_pixel = HexUtils.hex_to_pixel(move_path[0])
	var direction = (target_pixel - position).normalized()
	var distance = position.distance_to(target_pixel)

	if distance < move_speed * delta:
		position = target_pixel
		hex_position = move_path[0]
		move_path.remove_at(0)

		if move_path.is_empty():
			is_moving = false
			move_completed.emit()
	else:
		position += direction * move_speed * delta


func get_move_range() -> int:
	var spd = get_effective_stat("SPD")
	return maxi(1, HexUtils.calculate_move_range(spd))


func get_stat(stat_name: String) -> int:
	return get_effective_stat(stat_name)


func get_raw_stat(stat_name: String) -> int:
	return int(stats.get(stat_name, 50))


func spend_ap(amount: int) -> bool:
	if action_points < amount:
		return false

	action_points -= amount
	_update_labels()
	action_points_changed.emit(action_points)
	return true


func spend_stamina(amount: int) -> void:
	stamina = max(0, stamina - amount)
	stamina_changed.emit(stamina)


func reset_turn() -> void:
	action_points = 0 if sent_off_reason != "" else max_action_points
	_update_labels()
	action_points_changed.emit(action_points)


func set_selected(value: bool) -> void:
	is_selected = value
	selection_indicator.visible = value

	if value:
		selected.emit()
		# Visual feedback - add glow/scale
		sprite.modulate = Color(1.2, 1.2, 1.2)
	else:
		deselected.emit()
		sprite.modulate = Color.WHITE


func set_has_ball(value: bool) -> void:
	has_ball = value
	# Visual indicator could be added here


func can_act() -> bool:
	return action_points > 0 and not is_moving and sent_off_reason == ""


func is_goalkeeper() -> bool:
	return position_role == "GK"


func is_active_in_match() -> bool:
	return sent_off_reason == ""


func mark_sent_off(reason: String = "red") -> void:
	sent_off_reason = reason
	action_points = 0
	has_ball = false
	modulate = Color(0.55, 0.55, 0.55, 0.65)
	_update_labels()
	action_points_changed.emit(action_points)


func get_tackling_stat() -> int:
	var def = get_effective_stat("DEF")
	var phy = get_effective_stat("PHY")
	return int(def * 0.7 + phy * 0.3)


func get_dribbling_stat() -> int:
	return get_effective_stat("TEC")


func get_passing_stat() -> int:
	return get_effective_stat("PAS")


func get_shooting_stat() -> int:
	return get_effective_stat("SHO")


func get_goalkeeping_stat() -> int:
	var def = get_effective_stat("DEF")
	var men = get_effective_stat("MEN")
	var reflexes = int(def * 0.5 + men * 0.5)
	return reflexes


func get_effective_stat(stat_name: String) -> int:
	var base_stat = get_raw_stat(stat_name)
	base_stat -= _get_stamina_penalty()
	base_stat -= _get_injury_penalty_for_stat(stat_name)
	return clampi(base_stat, 1, 99)


func apply_live_injury(injury_report: Dictionary) -> void:
	live_injury = _normalize_injury_record(injury_report)


func apply_minute_fatigue(minutes: int = 1) -> void:
	if sent_off_reason != "":
		return
	var passive_cost = maxi(1, minutes)
	if position_role in ["WNG", "FB", "CM", "CAM", "ST"]:
		passive_cost += 1
	spend_stamina(passive_cost)


func apply_action_fatigue(action_type: String, distance: int = 0) -> void:
	if sent_off_reason != "":
		return
	var base_cost = int(ACTION_STAMINA_COSTS.get(action_type, 0))
	if action_type == "move":
		base_cost += maxi(distance - 1, 0)
	spend_stamina(base_cost)


func get_channel_side(target_hex: Vector2i = Vector2i(-999, -999)) -> String:
	var sample_hex = hex_position
	if target_hex.x != -999:
		sample_hex = Vector2i(
			int(round((hex_position.x + target_hex.x) / 2.0)),
			int(round((hex_position.y + target_hex.y) / 2.0))
		)

	var center_line = int(HexUtils.GRID_HEIGHT / 2)
	if sample_hex.y < center_line:
		return "left"
	if sample_hex.y > center_line:
		return "right"
	return "center"


func _get_stamina_penalty() -> int:
	if stamina >= 75:
		return 0
	if stamina >= 55:
		return 3
	if stamina >= 35:
		return 6
	if stamina >= 20:
		return 10
	return 14


func _get_injury_penalty_for_stat(stat_name: String) -> int:
	var severity = str(live_injury.get("type", ""))
	var matches_remaining = int(live_injury.get("matches_remaining", 0))
	if severity == "" and str(live_injury.get("description", "")).is_empty():
		return 0
	if matches_remaining <= 0 and severity != "live":
		return 0

	var injury_type = str(live_injury.get("injury_type", ""))
	var penalties: Dictionary = MINOR_INJURY_STAT_PENALTIES.get(
		injury_type,
		MINOR_INJURY_STAT_PENALTIES["_default"]
	)
	var penalty = int(penalties.get(stat_name, 0))
	if severity == "moderate":
		penalty = roundi(float(penalty) * 1.6)
	return penalty


func _normalize_injury_record(data: Dictionary) -> Dictionary:
	return {
		"type": str(data.get("type", "")),
		"injury_type": str(data.get("injury_type", "")),
		"matches_remaining": max(int(data.get("matches_remaining", data.get("matches_out", 0))), 0),
		"matches_total": max(int(data.get("matches_total", data.get("matches_remaining", data.get("matches_out", 0)))), 0),
		"description": str(data.get("description", ""))
	}
