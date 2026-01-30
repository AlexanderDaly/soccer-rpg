extends GutTest
## Unit tests for HexUtils


# =============================================================================
# Coordinate Conversion Tests
# =============================================================================

func test_hex_to_pixel_origin() -> void:
	var pixel = HexUtils.hex_to_pixel(Vector2i(0, 0))
	assert_eq(pixel, Vector2(0, 0), "Origin hex should be at pixel origin")


func test_hex_to_pixel_positive_q() -> void:
	var pixel = HexUtils.hex_to_pixel(Vector2i(1, 0))
	# x = 32 * (3/2 * 1) = 48
	# y = 32 * (sqrt(3)/2 * 1 + sqrt(3) * 0) = 32 * 0.866 = ~27.7
	assert_almost_eq(pixel.x, 48.0, 0.1, "X should be HEX_SIZE * 1.5")
	assert_almost_eq(pixel.y, 32.0 * sqrt(3.0) / 2.0, 0.1, "Y should follow hex formula")


func test_pixel_to_hex_origin() -> void:
	var hex = HexUtils.pixel_to_hex(Vector2(0, 0))
	assert_eq(hex, Vector2i(0, 0), "Pixel origin should be hex origin")


func test_pixel_to_hex_round_trip() -> void:
	var original = Vector2i(5, 3)
	var pixel = HexUtils.hex_to_pixel(original)
	var restored = HexUtils.pixel_to_hex(pixel)
	assert_eq(restored, original, "Hex -> pixel -> hex should preserve coordinates")


func test_axial_round_exact_values() -> void:
	var result = HexUtils.axial_round(Vector2(3.0, 5.0))
	assert_eq(result, Vector2i(3, 5), "Exact values should round to themselves")


func test_axial_round_fractional_values() -> void:
	var result = HexUtils.axial_round(Vector2(3.4, 5.6))
	# Should round to nearest valid hex
	assert_true(result.x >= 3 and result.x <= 4, "Q should be reasonable")
	assert_true(result.y >= 5 and result.y <= 6, "R should be reasonable")


# =============================================================================
# Hex Distance Tests
# =============================================================================

func test_hex_distance_same_hex() -> void:
	var dist = HexUtils.hex_distance(Vector2i(5, 5), Vector2i(5, 5))
	assert_eq(dist, 0, "Distance to same hex should be 0")


func test_hex_distance_adjacent() -> void:
	var center = Vector2i(5, 5)
	for direction in HexUtils.HEX_DIRECTIONS:
		var neighbor = center + direction
		var dist = HexUtils.hex_distance(center, neighbor)
		assert_eq(dist, 1, "Distance to adjacent hex should be 1")


func test_hex_distance_symmetric() -> void:
	var a = Vector2i(3, 7)
	var b = Vector2i(10, 2)
	var dist_ab = HexUtils.hex_distance(a, b)
	var dist_ba = HexUtils.hex_distance(b, a)
	assert_eq(dist_ab, dist_ba, "Distance should be symmetric")


func test_hex_distance_horizontal() -> void:
	var dist = HexUtils.hex_distance(Vector2i(0, 5), Vector2i(5, 5))
	assert_eq(dist, 5, "Horizontal distance should match q difference")


# =============================================================================
# Grid Bounds Tests
# =============================================================================

func test_is_valid_hex_within_bounds() -> void:
	assert_true(HexUtils.is_valid_hex(Vector2i(0, 0)), "Origin should be valid")
	assert_true(HexUtils.is_valid_hex(Vector2i(10, 7)), "Center should be valid")
	assert_true(HexUtils.is_valid_hex(Vector2i(20, 13)), "Corner should be valid")


func test_is_valid_hex_out_of_bounds() -> void:
	assert_false(HexUtils.is_valid_hex(Vector2i(-1, 0)), "Negative Q should be invalid")
	assert_false(HexUtils.is_valid_hex(Vector2i(0, -1)), "Negative R should be invalid")
	assert_false(HexUtils.is_valid_hex(Vector2i(21, 0)), "Q >= GRID_WIDTH should be invalid")
	assert_false(HexUtils.is_valid_hex(Vector2i(0, 14)), "R >= GRID_HEIGHT should be invalid")


func test_grid_dimensions() -> void:
	assert_eq(HexUtils.GRID_WIDTH, 21, "Grid width should be 21")
	assert_eq(HexUtils.GRID_HEIGHT, 14, "Grid height should be 14")


# =============================================================================
# Neighbor Tests
# =============================================================================

func test_get_neighbors_center() -> void:
	var neighbors = HexUtils.get_neighbors(Vector2i(10, 7))
	assert_eq(neighbors.size(), 6, "Center hex should have 6 neighbors")


func test_get_neighbors_corner() -> void:
	var neighbors = HexUtils.get_neighbors(Vector2i(0, 0))
	# Corner should have fewer valid neighbors
	assert_lt(neighbors.size(), 6, "Corner hex should have fewer than 6 neighbors")
	for neighbor in neighbors:
		assert_true(HexUtils.is_valid_hex(neighbor), "All neighbors should be valid")


func test_get_neighbors_all_adjacent() -> void:
	var center = Vector2i(10, 7)
	var neighbors = HexUtils.get_neighbors(center)
	for neighbor in neighbors:
		var dist = HexUtils.hex_distance(center, neighbor)
		assert_eq(dist, 1, "All neighbors should be distance 1 from center")


# =============================================================================
# Range Tests
# =============================================================================

func test_get_hexes_in_range_zero() -> void:
	var hexes = HexUtils.get_hexes_in_range(Vector2i(10, 7), 0)
	assert_eq(hexes.size(), 0, "Range 0 should return no hexes (excludes center)")


func test_get_hexes_in_range_one() -> void:
	var hexes = HexUtils.get_hexes_in_range(Vector2i(10, 7), 1)
	assert_eq(hexes.size(), 6, "Range 1 from center should return 6 hexes")


func test_get_hexes_in_range_all_valid() -> void:
	var hexes = HexUtils.get_hexes_in_range(Vector2i(10, 7), 3)
	for hex in hexes:
		assert_true(HexUtils.is_valid_hex(hex), "All hexes in range should be valid")


func test_get_hexes_in_range_respects_grid_bounds() -> void:
	# Get hexes near edge - should be limited by bounds
	var hexes = HexUtils.get_hexes_in_range(Vector2i(0, 0), 5)
	for hex in hexes:
		assert_true(HexUtils.is_valid_hex(hex), "No out-of-bounds hexes should be returned")


# =============================================================================
# Movement Range Tests
# =============================================================================

func test_calculate_move_range_low_speed() -> void:
	var range_val = HexUtils.calculate_move_range(20)
	# 2 + int(20 / 20) = 2 + 1 = 3
	assert_eq(range_val, 3, "Low speed should give base movement + 1")


func test_calculate_move_range_high_speed() -> void:
	var range_val = HexUtils.calculate_move_range(80)
	# 2 + int(80 / 20) = 2 + 4 = 6
	assert_eq(range_val, 6, "High speed should give good movement range")


func test_calculate_move_range_max_speed() -> void:
	var range_val = HexUtils.calculate_move_range(99)
	# 2 + int(99 / 20) = 2 + 4 = 6
	assert_eq(range_val, 6, "Max speed should cap at reasonable range")


# =============================================================================
# Pathfinding Tests
# =============================================================================

func test_find_path_to_self() -> void:
	var path = HexUtils.find_path(Vector2i(10, 7), Vector2i(10, 7))
	assert_eq(path.size(), 1, "Path to self should have 1 element")
	assert_eq(path[0], Vector2i(10, 7), "Path should contain start position")


func test_find_path_adjacent() -> void:
	var start = Vector2i(10, 7)
	var goal = Vector2i(11, 7)
	var path = HexUtils.find_path(start, goal)

	assert_eq(path.size(), 2, "Path to adjacent should have 2 elements")
	assert_eq(path[0], start, "Path should start at start")
	assert_eq(path[-1], goal, "Path should end at goal")


func test_find_path_respects_obstacles() -> void:
	var start = Vector2i(10, 7)
	var goal = Vector2i(12, 7)
	var occupied: Array[Vector2i] = [Vector2i(11, 7)]  # Block direct path

	var path = HexUtils.find_path(start, goal, occupied)

	assert_gt(path.size(), 3, "Path should go around obstacle")
	assert_false(Vector2i(11, 7) in path, "Path should not include occupied hex")


func test_find_path_invalid_start() -> void:
	var path = HexUtils.find_path(Vector2i(-1, 0), Vector2i(10, 7))
	assert_eq(path.size(), 0, "Invalid start should return empty path")


func test_find_path_invalid_goal() -> void:
	var path = HexUtils.find_path(Vector2i(10, 7), Vector2i(100, 100))
	assert_eq(path.size(), 0, "Invalid goal should return empty path")


func test_find_path_blocked_goal() -> void:
	var occupied: Array[Vector2i] = [Vector2i(10, 8)]
	var path = HexUtils.find_path(Vector2i(10, 7), Vector2i(10, 8), occupied)
	assert_eq(path.size(), 0, "Blocked goal should return empty path")


func test_find_path_is_continuous() -> void:
	var path = HexUtils.find_path(Vector2i(5, 5), Vector2i(15, 10))

	for i in range(path.size() - 1):
		var dist = HexUtils.hex_distance(path[i], path[i + 1])
		assert_eq(dist, 1, "Each step in path should be adjacent")


# =============================================================================
# Reachable Hexes Tests
# =============================================================================

func test_get_reachable_hexes_empty() -> void:
	var reachable = HexUtils.get_reachable_hexes(Vector2i(10, 7), 0)
	assert_eq(reachable.size(), 0, "Range 0 should return no reachable hexes")


func test_get_reachable_hexes_respects_range() -> void:
	var center = Vector2i(10, 7)
	var reachable = HexUtils.get_reachable_hexes(center, 2)

	for hex in reachable:
		var dist = HexUtils.hex_distance(center, hex)
		assert_lte(dist, 2, "All reachable hexes should be within range")


func test_get_reachable_hexes_excludes_occupied() -> void:
	var center = Vector2i(10, 7)
	var occupied: Array[Vector2i] = [Vector2i(11, 7), Vector2i(10, 8)]
	var reachable = HexUtils.get_reachable_hexes(center, 3, occupied)

	assert_false(Vector2i(11, 7) in reachable, "Occupied hexes should not be reachable")
	assert_false(Vector2i(10, 8) in reachable, "Occupied hexes should not be reachable")


func test_get_reachable_hexes_excludes_start() -> void:
	var center = Vector2i(10, 7)
	var reachable = HexUtils.get_reachable_hexes(center, 2)

	assert_false(center in reachable, "Start position should not be in reachable list")


# =============================================================================
# Hex Line Tests
# =============================================================================

func test_get_hex_line_same_hex() -> void:
	var line = HexUtils.get_hex_line(Vector2i(5, 5), Vector2i(5, 5))
	assert_eq(line.size(), 1, "Line to same hex should have 1 element")
	assert_eq(line[0], Vector2i(5, 5), "Line should contain the hex")


func test_get_hex_line_includes_endpoints() -> void:
	var start = Vector2i(5, 5)
	var end = Vector2i(10, 5)
	var line = HexUtils.get_hex_line(start, end)

	assert_eq(line[0], start, "Line should start at start")
	assert_eq(line[-1], end, "Line should end at end")


func test_get_hex_line_is_continuous() -> void:
	var line = HexUtils.get_hex_line(Vector2i(5, 5), Vector2i(10, 8))

	for i in range(line.size() - 1):
		var dist = HexUtils.hex_distance(line[i], line[i + 1])
		assert_lte(dist, 1, "Line should be continuous (adjacent hexes)")


# =============================================================================
# Formation Tests
# =============================================================================

func test_get_formation_positions_442_has_11_players() -> void:
	var positions = HexUtils.get_formation_positions("4-4-2", true)
	assert_eq(positions.size(), 11, "4-4-2 should have 11 positions")


func test_get_formation_positions_433_has_11_players() -> void:
	var positions = HexUtils.get_formation_positions("4-3-3", true)
	assert_eq(positions.size(), 11, "4-3-3 should have 11 positions")


func test_get_formation_positions_352_has_11_players() -> void:
	var positions = HexUtils.get_formation_positions("3-5-2", true)
	assert_eq(positions.size(), 11, "3-5-2 should have 11 positions")


func test_get_formation_positions_4231_has_11_players() -> void:
	var positions = HexUtils.get_formation_positions("4-2-3-1", true)
	assert_eq(positions.size(), 11, "4-2-3-1 should have 11 positions")


func test_get_formation_positions_unknown_defaults_to_442() -> void:
	var unknown = HexUtils.get_formation_positions("unknown", true)
	var default = HexUtils.get_formation_positions("4-4-2", true)
	assert_eq(unknown.size(), default.size(), "Unknown formation should default to 4-4-2")


func test_get_formation_positions_away_mirrored() -> void:
	var home = HexUtils.get_formation_positions("4-4-2", true)
	var away = HexUtils.get_formation_positions("4-4-2", false)

	# Away GK should be on opposite side
	var home_gk_x = home[0].hex.x
	var away_gk_x = away[0].hex.x

	assert_lt(home_gk_x, 5, "Home GK should be on left side")
	assert_gt(away_gk_x, 15, "Away GK should be on right side")


func test_get_formation_all_positions_valid() -> void:
	var positions = HexUtils.get_formation_positions("4-4-2", true)

	for pos_data in positions:
		assert_true(HexUtils.is_valid_hex(pos_data.hex),
			"Position %s should be valid" % pos_data.position)


# =============================================================================
# Goal and Penalty Area Tests
# =============================================================================

func test_goal_hex_positions() -> void:
	assert_eq(HexUtils.HOME_GOAL_HEX, Vector2i(0, 7), "Home goal should be at (0, 7)")
	assert_eq(HexUtils.AWAY_GOAL_HEX, Vector2i(20, 7), "Away goal should be at (20, 7)")


func test_get_goal_hex() -> void:
	var right = HexUtils.get_goal_hex(true)
	var left = HexUtils.get_goal_hex(false)

	assert_eq(right, HexUtils.AWAY_GOAL_HEX, "Attacking right should target away goal")
	assert_eq(left, HexUtils.HOME_GOAL_HEX, "Attacking left should target home goal")


func test_get_center_hex() -> void:
	var center = HexUtils.get_center_hex()
	assert_eq(center, Vector2i(10, 7), "Center hex should be (10, 7)")


func test_is_in_penalty_area_home() -> void:
	assert_true(HexUtils.is_in_penalty_area(Vector2i(2, 7), true), "Near home goal should be in penalty area")
	assert_false(HexUtils.is_in_penalty_area(Vector2i(10, 7), true), "Center should not be in penalty area")


func test_is_in_penalty_area_away() -> void:
	assert_true(HexUtils.is_in_penalty_area(Vector2i(18, 7), false), "Near away goal should be in penalty area")
	assert_false(HexUtils.is_in_penalty_area(Vector2i(10, 7), false), "Center should not be in penalty area")


# =============================================================================
# Shot Difficulty Tests
# =============================================================================

func test_calculate_shot_difficulty_close_range() -> void:
	var difficulty = HexUtils.calculate_shot_difficulty(Vector2i(18, 7), HexUtils.AWAY_GOAL_HEX)
	assert_lt(difficulty, 0.5, "Close-range shot should be easier")


func test_calculate_shot_difficulty_long_range() -> void:
	var difficulty = HexUtils.calculate_shot_difficulty(Vector2i(10, 7), HexUtils.AWAY_GOAL_HEX)
	assert_gt(difficulty, 0.5, "Long-range shot should be harder")


func test_calculate_shot_difficulty_angle_penalty() -> void:
	var straight = HexUtils.calculate_shot_difficulty(Vector2i(15, 7), HexUtils.AWAY_GOAL_HEX)
	var angled = HexUtils.calculate_shot_difficulty(Vector2i(15, 3), HexUtils.AWAY_GOAL_HEX)

	assert_lt(straight, angled, "Straight shot should be easier than angled shot")


func test_calculate_shot_difficulty_clamped() -> void:
	var very_close = HexUtils.calculate_shot_difficulty(Vector2i(19, 7), HexUtils.AWAY_GOAL_HEX)
	var very_far = HexUtils.calculate_shot_difficulty(Vector2i(0, 0), HexUtils.AWAY_GOAL_HEX)

	assert_gte(very_close, 0.2, "Difficulty should not go below 0.2")
	assert_lte(very_far, 0.9, "Difficulty should not exceed 0.9")
