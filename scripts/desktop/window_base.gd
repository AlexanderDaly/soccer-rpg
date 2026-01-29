extends PanelContainer
class_name WindowBase
## WindowBase - Draggable, resizable window frame for desktop apps

signal close_requested
signal minimize_requested
signal focused

@export var window_id: String = ""
@export var window_title: String = "Window"
@export var window_icon: Texture2D = null
@export var min_size: Vector2 = Vector2(200, 150)
@export var resizable: bool = true

var is_dragging: bool = false
var is_resizing: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var resize_start_size: Vector2 = Vector2.ZERO
var resize_start_mouse: Vector2 = Vector2.ZERO
var is_focused: bool = false

const RESIZE_MARGIN: int = 8
const TITLEBAR_HEIGHT: int = 24

@onready var title_bar: PanelContainer = $VBoxContainer/TitleBar
@onready var title_label: Label = $VBoxContainer/TitleBar/HBoxContainer/TitleLabel
@onready var icon_rect: TextureRect = $VBoxContainer/TitleBar/HBoxContainer/Icon
@onready var minimize_button: Button = $VBoxContainer/TitleBar/HBoxContainer/MinimizeButton
@onready var close_button: Button = $VBoxContainer/TitleBar/HBoxContainer/CloseButton
@onready var content_container: PanelContainer = $VBoxContainer/ContentContainer
@onready var resize_handle: Control = $ResizeHandle


func _ready() -> void:
	_setup_window()
	_connect_signals()
	custom_minimum_size = min_size


func _setup_window() -> void:
	title_label.text = window_title
	if window_icon:
		icon_rect.texture = window_icon
		icon_rect.visible = true
	else:
		icon_rect.visible = false

	resize_handle.visible = resizable
	_update_titlebar_style()


func _connect_signals() -> void:
	title_bar.gui_input.connect(_on_title_bar_input)
	minimize_button.pressed.connect(_on_minimize_pressed)
	close_button.pressed.connect(_on_close_pressed)
	resize_handle.gui_input.connect(_on_resize_handle_input)
	gui_input.connect(_on_window_input)


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_request_focus()


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			_request_focus()
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		var new_pos = get_global_mouse_position() - drag_offset
		# Clamp to screen bounds
		var screen_size = get_viewport_rect().size
		new_pos.x = clampf(new_pos.x, 0, screen_size.x - 100)
		new_pos.y = clampf(new_pos.y, 0, screen_size.y - TITLEBAR_HEIGHT)
		global_position = new_pos


func _on_resize_handle_input(event: InputEvent) -> void:
	if not resizable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_resizing = true
			resize_start_size = size
			resize_start_mouse = get_global_mouse_position()
			_request_focus()
		else:
			is_resizing = false
	elif event is InputEventMouseMotion and is_resizing:
		var delta = get_global_mouse_position() - resize_start_mouse
		var new_size = resize_start_size + delta
		new_size.x = maxf(new_size.x, min_size.x)
		new_size.y = maxf(new_size.y, min_size.y)
		size = new_size


func _on_minimize_pressed() -> void:
	AudioManager.play_ui_click()
	minimize_requested.emit()
	DesktopManager.minimize_window(window_id)


func _on_close_pressed() -> void:
	AudioManager.play_ui_click()
	close_requested.emit()
	DesktopManager.unregister_window(window_id)
	queue_free()


func _request_focus() -> void:
	if not is_focused:
		focused.emit()
		DesktopManager.focus_window(window_id)


func setup(id: String, title: String, icon_path: String = "", content_min_size: Vector2 = Vector2.ZERO) -> void:
	window_id = id
	window_title = title

	if title_label:
		title_label.text = title

	if icon_path != "" and ResourceLoader.exists(icon_path):
		window_icon = load(icon_path)
		if icon_rect:
			icon_rect.texture = window_icon
			icon_rect.visible = true

	if content_min_size != Vector2.ZERO:
		min_size = content_min_size + Vector2(8, TITLEBAR_HEIGHT + 8)
		custom_minimum_size = min_size


func set_content(content_node: Control) -> void:
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	content_container.add_child(content_node)
	content_node.set_anchors_preset(Control.PRESET_FULL_RECT)


func set_focused(focused_state: bool) -> void:
	is_focused = focused_state
	_update_titlebar_style()


func _update_titlebar_style() -> void:
	if not title_bar:
		return

	var style = StyleBoxFlat.new()
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	if is_focused:
		style.bg_color = Color(0.0, 0.0, 0.5)  # Navy blue
		title_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		style.bg_color = Color(0.5, 0.5, 0.5)  # Gray
		title_label.add_theme_color_override("font_color", Color.WHITE)

	title_bar.add_theme_stylebox_override("panel", style)


func get_content_container() -> PanelContainer:
	return content_container
