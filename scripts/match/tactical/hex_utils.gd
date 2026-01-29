extends RefCounted
class_name HexUtils
## HexUtils - Hex grid math and pathfinding utilities
## Uses axial coordinates (q, r) for hex grid representation
## Flat-top hexagon orientation

# Grid constants
const GRID_WIDTH: int = 21
const GRID_HEIGHT: int = 14
const HEX_SIZE: float = 32.0  # Pixels from center to corner

# Hex directions for flat-top hexagons (6 neighbors)
const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),   # East
	Vector2i(1, -1),  # Northeast
	Vector2i(0, -1),  # Northwest
	Vector2i(-1, 0),  # West
	Vector2i(-1, 1),  # Southwest
	Vector2i(0, 1)    # Southeast
]

# Goal positions
const HOME_GOAL_HEX := Vector2i(0, 7)
const AWAY_GOAL_HEX := Vector2i(20, 7)

# Pitch zones for formation positioning
const ZONES = {
	"GK": Vector2i(1, 7),
	"DEF_LEFT": Vector2i(4, 3),
	"DEF_CENTER_LEFT": Vector2i(4, 5),
	"DEF_CENTER": Vector2i(4, 7),
	"DEF_CENTER_RIGHT": Vector2i(4, 9),
	"DEF_RIGHT": Vector2i(4, 11),
	"MID_LEFT": Vector2i(10, 2),
	"MID_CENTER_LEFT": Vector2i(10, 5),
	"MID_CENTER": Vector2i(10, 7),
	"MID_CENTER_RIGHT": Vector2i(10, 9),
	"MID_RIGHT": Vector2i(10, 12),
	"ATT_LEFT": Vector2i(16, 3),
	"ATT_CENTER_LEFT": Vector2i(16, 5),
	"ATT_CENTER": Vector2i(16, 7),
	"ATT_CENTER_RIGHT": Vector2i(16, 9),
	"ATT_RIGHT": Vector2i(16, 11),
}


## Convert axial hex coordinates to pixel position
static func hex_to_pixel(hex: Vector2i) -> Vector2:
	var x = HEX_SIZE * (3.0 / 2.0 * hex.x)
	var y = HEX_SIZE * (sqrt(3.0) / 2.0 * hex.x + sqrt(3.0) * hex.y)
	return Vector2(x, y)


## Convert pixel position to axial hex coordinates
static func pixel_to_hex(pixel: Vector2) -> Vector2i:
	var q = (2.0 / 3.0 * pixel.x) / HEX_SIZE
	var r = (-1.0 / 3.0 * pixel.x + sqrt(3.0) / 3.0 * pixel.y) / HEX_SIZE
	return axial_round(Vector2(q, r))


## Round fractional hex coordinates to nearest hex
static func axial_round(hex: Vector2) -> Vector2i:
	var q = hex.x
	var r = hex.y
	var s = -q - r

	var rq = round(q)
	var rr = round(r)
	var rs = round(s)

	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)

	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs

	return Vector2i(int(rq), int(rr))


## Calculate hex distance between two hexes
static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2


## Get all hexes within a given range from center
static func get_hexes_in_range(center: Vector2i, range_val: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []

	for q in range(-range_val, range_val + 1):
		for r in range(max(-range_val, -q - range_val), min(range_val, -q + range_val) + 1):
			var hex = Vector2i(center.x + q, center.y + r)
			if is_valid_hex(hex):
				results.append(hex)

	return results


## Check if hex is within grid bounds
static func is_valid_hex(hex: Vector2i) -> bool:
	return hex.x >= 0 and hex.x < GRID_WIDTH and hex.y >= 0 and hex.y < GRID_HEIGHT


## Get neighboring hexes
static func get_neighbors(hex: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction in HEX_DIRECTIONS:
		var neighbor = hex + direction
		if is_valid_hex(neighbor):
			neighbors.append(neighbor)
	return neighbors


## Calculate movement range based on SPD stat
static func calculate_move_range(spd: int) -> int:
	return 2 + int(spd / 20.0)


## Get hexes reachable with given movement points (for movement highlighting)
static func get_reachable_hexes(start: Vector2i, move_range: int, occupied: Array[Vector2i] = []) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []
	var frontier: Array[Dictionary] = [{"hex": start, "cost": 0}]
	var visited: Dictionary = {start: 0}

	while frontier.size() > 0:
		var current = frontier.pop_front()
		var current_hex: Vector2i = current.hex
		var current_cost: int = current.cost

		if current_cost > 0:
			reachable.append(current_hex)

		if current_cost >= move_range:
			continue

		for neighbor in get_neighbors(current_hex):
			if neighbor in occupied:
				continue

			var new_cost = current_cost + 1
			if neighbor not in visited or visited[neighbor] > new_cost:
				visited[neighbor] = new_cost
				frontier.append({"hex": neighbor, "cost": new_cost})

	return reachable


## A* pathfinding between two hexes
static func find_path(start: Vector2i, goal: Vector2i, occupied: Array[Vector2i] = []) -> Array[Vector2i]:
	if not is_valid_hex(start) or not is_valid_hex(goal):
		return []

	if goal in occupied:
		return []

	var open_set: Array[Vector2i] = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: hex_distance(start, goal)}

	while open_set.size() > 0:
		# Get node with lowest f_score
		var current = open_set[0]
		var lowest_f = f_score.get(current, INF)
		for node in open_set:
			var f = f_score.get(node, INF)
			if f < lowest_f:
				lowest_f = f
				current = node

		if current == goal:
			# Reconstruct path
			var path: Array[Vector2i] = [current]
			while current in came_from:
				current = came_from[current]
				path.push_front(current)
			return path

		open_set.erase(current)

		for neighbor in get_neighbors(current):
			if neighbor in occupied and neighbor != goal:
				continue

			var tentative_g = g_score.get(current, INF) + 1

			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + hex_distance(neighbor, goal)

				if neighbor not in open_set:
					open_set.append(neighbor)

	return []  # No path found


## Get line of hexes between two points (for passes/shots)
static func get_hex_line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var n = hex_distance(start, end)
	if n == 0:
		return [start]

	var results: Array[Vector2i] = []
	var start_pixel = hex_to_pixel(start)
	var end_pixel = hex_to_pixel(end)

	for i in range(n + 1):
		var t = float(i) / float(n)
		var lerped = start_pixel.lerp(end_pixel, t)
		var hex = pixel_to_hex(lerped)
		if results.is_empty() or results[-1] != hex:
			results.append(hex)

	return results


## Get formation positions for a team
static func get_formation_positions(formation: String, is_home: bool) -> Array[Dictionary]:
	var positions: Array[Dictionary] = []

	# Base positions for home team (attacking right)
	var base_positions: Array[Dictionary] = []

	match formation:
		"4-4-2":
			base_positions = [
				{"position": "GK", "hex": Vector2i(1, 7)},
				{"position": "FB", "hex": Vector2i(4, 2)},
				{"position": "CB", "hex": Vector2i(4, 5)},
				{"position": "CB", "hex": Vector2i(4, 9)},
				{"position": "FB", "hex": Vector2i(4, 12)},
				{"position": "WNG", "hex": Vector2i(9, 2)},
				{"position": "CM", "hex": Vector2i(9, 5)},
				{"position": "CM", "hex": Vector2i(9, 9)},
				{"position": "WNG", "hex": Vector2i(9, 12)},
				{"position": "ST", "hex": Vector2i(14, 5)},
				{"position": "ST", "hex": Vector2i(14, 9)},
			]
		"4-3-3":
			base_positions = [
				{"position": "GK", "hex": Vector2i(1, 7)},
				{"position": "FB", "hex": Vector2i(4, 2)},
				{"position": "CB", "hex": Vector2i(4, 5)},
				{"position": "CB", "hex": Vector2i(4, 9)},
				{"position": "FB", "hex": Vector2i(4, 12)},
				{"position": "CDM", "hex": Vector2i(8, 7)},
				{"position": "CM", "hex": Vector2i(9, 4)},
				{"position": "CM", "hex": Vector2i(9, 10)},
				{"position": "WNG", "hex": Vector2i(14, 2)},
				{"position": "ST", "hex": Vector2i(15, 7)},
				{"position": "WNG", "hex": Vector2i(14, 12)},
			]
		"3-5-2":
			base_positions = [
				{"position": "GK", "hex": Vector2i(1, 7)},
				{"position": "CB", "hex": Vector2i(4, 4)},
				{"position": "CB", "hex": Vector2i(4, 7)},
				{"position": "CB", "hex": Vector2i(4, 10)},
				{"position": "FB", "hex": Vector2i(8, 1)},
				{"position": "CM", "hex": Vector2i(8, 5)},
				{"position": "CDM", "hex": Vector2i(8, 7)},
				{"position": "CM", "hex": Vector2i(8, 9)},
				{"position": "FB", "hex": Vector2i(8, 13)},
				{"position": "ST", "hex": Vector2i(14, 5)},
				{"position": "ST", "hex": Vector2i(14, 9)},
			]
		"4-2-3-1":
			base_positions = [
				{"position": "GK", "hex": Vector2i(1, 7)},
				{"position": "FB", "hex": Vector2i(4, 2)},
				{"position": "CB", "hex": Vector2i(4, 5)},
				{"position": "CB", "hex": Vector2i(4, 9)},
				{"position": "FB", "hex": Vector2i(4, 12)},
				{"position": "CDM", "hex": Vector2i(7, 5)},
				{"position": "CDM", "hex": Vector2i(7, 9)},
				{"position": "WNG", "hex": Vector2i(11, 2)},
				{"position": "CAM", "hex": Vector2i(11, 7)},
				{"position": "WNG", "hex": Vector2i(11, 12)},
				{"position": "ST", "hex": Vector2i(15, 7)},
			]
		_:
			# Default to 4-4-2
			return get_formation_positions("4-4-2", is_home)

	# Mirror positions for away team (attacking left)
	if is_home:
		positions = base_positions
	else:
		for pos_data in base_positions:
			positions.append({
				"position": pos_data.position,
				"hex": Vector2i(GRID_WIDTH - 1 - pos_data.hex.x, pos_data.hex.y)
			})

	return positions


## Get center hex of the pitch
static func get_center_hex() -> Vector2i:
	return Vector2i(10, 7)


## Check if a hex is in the penalty area
static func is_in_penalty_area(hex: Vector2i, is_home_goal: bool) -> bool:
	if is_home_goal:
		return hex.x <= 3 and hex.y >= 4 and hex.y <= 10
	else:
		return hex.x >= 17 and hex.y >= 4 and hex.y <= 10


## Get the goal hex for a team
static func get_goal_hex(attacking_right: bool) -> Vector2i:
	return AWAY_GOAL_HEX if attacking_right else HOME_GOAL_HEX


## Calculate shot difficulty based on distance and angle
static func calculate_shot_difficulty(shooter_hex: Vector2i, goal_hex: Vector2i) -> float:
	var distance = hex_distance(shooter_hex, goal_hex)
	var angle_penalty = abs(shooter_hex.y - goal_hex.y) * 0.05

	# Base difficulty increases with distance
	var difficulty = 0.3 + (distance * 0.05) + angle_penalty
	return clampf(difficulty, 0.2, 0.9)


## Get hexes in a cone (for through ball targeting)
static func get_hexes_in_cone(origin: Vector2i, direction: Vector2i, length: int, width: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	var dir_normalized = Vector2(direction.x, direction.y).normalized()

	for i in range(1, length + 1):
		var center = Vector2(origin.x, origin.y) + dir_normalized * i
		var center_hex = Vector2i(roundi(center.x), roundi(center.y))

		# Add hexes around the center based on width
		var spread = int(width * (float(i) / length))
		for w in range(-spread, spread + 1):
			var perpendicular = Vector2(-dir_normalized.y, dir_normalized.x) * w
			var hex = Vector2i(roundi(center.x + perpendicular.x), roundi(center.y + perpendicular.y))
			if is_valid_hex(hex) and hex not in results:
				results.append(hex)

	return results
