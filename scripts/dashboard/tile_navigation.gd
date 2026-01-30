extends Node
class_name TileNavigation
## TileNavigation - Handles 2D grid navigation for dashboard tiles

signal tile_selected(tile_index: int)
signal tile_activated(tile_index: int)

@export var columns: int = 2
@export var wrap_navigation: bool = true

var tiles: Array[Control] = []
var current_index: int = 0
var navigation_enabled: bool = true


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not navigation_enabled or tiles.is_empty():
		return

	var direction := 0

	if event.is_action_pressed("ui_up"):
		direction = -columns
	elif event.is_action_pressed("ui_down"):
		direction = columns
	elif event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("ui_right"):
		direction = 1
	elif event.is_action_pressed("ui_accept"):
		_activate_current()
		get_viewport().set_input_as_handled()
		return

	if direction != 0:
		navigate(direction)
		get_viewport().set_input_as_handled()


func register_tiles(tile_array: Array) -> void:
	tiles.clear()
	for tile in tile_array:
		if tile is Control:
			tiles.append(tile)
			# Connect mouse hover to update selection
			if not tile.mouse_entered.is_connected(_on_tile_mouse_entered.bind(tiles.size() - 1)):
				tile.mouse_entered.connect(_on_tile_mouse_entered.bind(tiles.size() - 1))

	if not tiles.is_empty():
		set_selection(0)


func navigate(direction: int) -> void:
	if tiles.is_empty():
		return

	var new_index = current_index + direction

	# Handle wrapping
	if wrap_navigation:
		var row = current_index / columns
		var col = current_index % columns
		var new_row = new_index / columns
		var new_col = new_index % columns

		# Horizontal wrapping within row
		if direction == 1 and col == columns - 1:
			new_index = row * columns  # Wrap to start of row
		elif direction == -1 and col == 0:
			new_index = (row + 1) * columns - 1  # Wrap to end of row
			if new_index >= tiles.size():
				new_index = tiles.size() - 1

		# Vertical wrapping
		if direction == columns and new_index >= tiles.size():
			new_index = col  # Wrap to top
		elif direction == -columns and new_index < 0:
			# Find the bottom-most row that has this column
			var total_rows = ceili(float(tiles.size()) / columns)
			new_index = (total_rows - 1) * columns + col
			if new_index >= tiles.size():
				new_index = tiles.size() - 1
	else:
		new_index = clampi(new_index, 0, tiles.size() - 1)

	# Ensure valid index
	if new_index >= 0 and new_index < tiles.size() and new_index != current_index:
		set_selection(new_index)


func set_selection(index: int) -> void:
	if index < 0 or index >= tiles.size():
		return

	# Deselect current
	if current_index >= 0 and current_index < tiles.size():
		var current_tile = tiles[current_index]
		if current_tile.has_method("set_focused"):
			current_tile.set_focused(false)

	current_index = index

	# Select new
	var new_tile = tiles[current_index]
	if new_tile.has_method("set_focused"):
		new_tile.set_focused(true)

	AudioManager.play_ui_click()
	tile_selected.emit(current_index)


func _activate_current() -> void:
	if current_index >= 0 and current_index < tiles.size():
		tile_activated.emit(current_index)
		# The tile handles its own activation via pressed signal


func _on_tile_mouse_entered(tile_index: int) -> void:
	if tile_index != current_index:
		set_selection(tile_index)


func get_current_tile() -> Control:
	if current_index >= 0 and current_index < tiles.size():
		return tiles[current_index]
	return null


func set_navigation_enabled(enabled: bool) -> void:
	navigation_enabled = enabled


func get_tile_count() -> int:
	return tiles.size()
