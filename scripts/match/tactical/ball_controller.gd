extends Node2D
class_name BallController
## BallController - Manages ball state and physics in tactical matches

signal possession_changed(unit: PlayerUnit)
signal ball_loose(hex: Vector2i)
signal ball_in_flight(from_hex: Vector2i, to_hex: Vector2i)
signal ball_arrived(hex: Vector2i)
signal goal_scored(is_home_goal: bool)

enum BallState {
	POSSESSED,    # Attached to a unit
	LOOSE,        # On the ground, can be contested
	IN_FLIGHT     # During a pass or shot
}

var current_state: BallState = BallState.LOOSE
var hex_position: Vector2i = Vector2i(10, 7)  # Start at center
var possessing_unit: PlayerUnit = null

# Flight state
var flight_origin: Vector2i = Vector2i.ZERO
var flight_target: Vector2i = Vector2i.ZERO
var flight_path: Array[Vector2i] = []
var flight_progress: float = 0.0
var flight_speed: float = 400.0  # Pixels per second
var is_shot: bool = false

# Visual
var ball_sprite: Sprite2D


func _ready() -> void:
	_setup_visuals()


func _process(delta: float) -> void:
	if current_state == BallState.IN_FLIGHT:
		_process_flight(delta)
	elif current_state == BallState.POSSESSED and possessing_unit:
		# Follow the possessing unit
		position = possessing_unit.position


func _setup_visuals() -> void:
	ball_sprite = Sprite2D.new()
	add_child(ball_sprite)

	# Create a simple ball texture (white circle with black outline)
	var image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	for x in range(16):
		for y in range(16):
			var dist = Vector2(x - 8, y - 8).length()
			if dist <= 5:
				image.set_pixel(x, y, Color.WHITE)
			elif dist <= 7:
				image.set_pixel(x, y, Color.BLACK)

	ball_sprite.texture = ImageTexture.create_from_image(image)


func set_hex_position(hex: Vector2i) -> void:
	hex_position = hex
	position = HexUtils.hex_to_pixel(hex)


func give_possession(unit: PlayerUnit) -> void:
	if possessing_unit:
		possessing_unit.set_has_ball(false)

	possessing_unit = unit
	current_state = BallState.POSSESSED

	if unit:
		unit.set_has_ball(true)
		hex_position = unit.hex_position
		possession_changed.emit(unit)


func make_loose(hex: Vector2i) -> void:
	if possessing_unit:
		possessing_unit.set_has_ball(false)
		possessing_unit = null

	current_state = BallState.LOOSE
	hex_position = hex
	position = HexUtils.hex_to_pixel(hex)
	ball_loose.emit(hex)


func start_pass(from_unit: PlayerUnit, target_hex: Vector2i) -> void:
	_start_flight(from_unit.hex_position, target_hex, false)


func start_shot(from_unit: PlayerUnit, target_hex: Vector2i) -> void:
	_start_flight(from_unit.hex_position, target_hex, true)


func _start_flight(from: Vector2i, to: Vector2i, shooting: bool) -> void:
	if possessing_unit:
		possessing_unit.set_has_ball(false)
		possessing_unit = null

	current_state = BallState.IN_FLIGHT
	flight_origin = from
	flight_target = to
	flight_path = HexUtils.get_hex_line(from, to)
	flight_progress = 0.0
	is_shot = shooting

	hex_position = from
	position = HexUtils.hex_to_pixel(from)

	ball_in_flight.emit(from, to)


func _process_flight(delta: float) -> void:
	if flight_path.is_empty():
		_complete_flight()
		return

	var origin_pixel = HexUtils.hex_to_pixel(flight_origin)
	var target_pixel = HexUtils.hex_to_pixel(flight_target)
	var total_distance = origin_pixel.distance_to(target_pixel)

	if total_distance < 1.0:
		_complete_flight()
		return

	flight_progress += (flight_speed * delta) / total_distance

	if flight_progress >= 1.0:
		_complete_flight()
	else:
		position = origin_pixel.lerp(target_pixel, flight_progress)

		# Update hex position based on current pixel position
		var current_hex = HexUtils.pixel_to_hex(position)
		if current_hex != hex_position:
			hex_position = current_hex


func _complete_flight() -> void:
	hex_position = flight_target
	position = HexUtils.hex_to_pixel(flight_target)

	# Check if this was a goal
	if is_shot:
		var scored := false
		if flight_target == HexUtils.HOME_GOAL_HEX:
			goal_scored.emit(true)  # Goal on home side (away team scored)
			scored = true
		elif flight_target == HexUtils.AWAY_GOAL_HEX:
			goal_scored.emit(false)  # Goal on away side (home team scored)
			scored = true

		if scored:
			# Don't emit ball_arrived after a goal - match controller handles
			# the reset and kickoff possession via _on_goal_scored
			current_state = BallState.LOOSE
			flight_path.clear()
			return

	current_state = BallState.LOOSE
	flight_path.clear()
	ball_arrived.emit(hex_position)


func get_flight_current_hex() -> Vector2i:
	return hex_position


func get_flight_path() -> Array[Vector2i]:
	return flight_path


func is_in_flight() -> bool:
	return current_state == BallState.IN_FLIGHT


func is_possessed() -> bool:
	return current_state == BallState.POSSESSED


func is_loose() -> bool:
	return current_state == BallState.LOOSE


func get_possessing_unit() -> PlayerUnit:
	return possessing_unit
