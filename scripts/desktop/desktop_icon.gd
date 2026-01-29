extends Control
## DesktopIcon - Desktop shortcut that launches apps on double-click

signal icon_double_clicked(app_id: String)

@export var app_id: String = ""
@export var icon_label: String = "App"
@export var icon_texture: Texture2D = null

var last_click_time: float = 0.0
const DOUBLE_CLICK_TIME: float = 0.4

var is_selected: bool = false

@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var name_label: Label = $VBoxContainer/NameLabel


func _ready() -> void:
	_setup_visuals()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _setup_visuals() -> void:
	if icon_texture:
		icon_rect.texture = icon_texture
	name_label.text = icon_label


func setup(id: String, label: String, icon_path: String = "") -> void:
	app_id = id
	icon_label = label

	if name_label:
		name_label.text = label

	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path)
		if icon_rect:
			icon_rect.texture = icon_texture
	else:
		# Create a default colored rectangle as placeholder icon
		_create_placeholder_icon()


func _create_placeholder_icon() -> void:
	if not icon_rect:
		return

	# Generate a color based on app_id hash for variety
	var hash_val = app_id.hash()
	var hue = fmod(abs(float(hash_val)) / 1000000.0, 1.0)
	var icon_color = Color.from_hsv(hue, 0.6, 0.8)

	var img = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(icon_color)

	# Add a simple border
	for x in range(48):
		for y in range(48):
			if x < 2 or x >= 46 or y < 2 or y >= 46:
				img.set_pixel(x, y, icon_color.darkened(0.3))

	icon_rect.texture = ImageTexture.create_from_image(img)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var current_time = Time.get_ticks_msec() / 1000.0

			if current_time - last_click_time < DOUBLE_CLICK_TIME:
				# Double click
				_on_double_click()
			else:
				# Single click - select
				_on_single_click()

			last_click_time = current_time


func _on_single_click() -> void:
	AudioManager.play_ui_click()
	is_selected = true
	_update_selection_visual()


func _on_double_click() -> void:
	AudioManager.play_ui_confirm()
	icon_double_clicked.emit(app_id)


func _on_mouse_entered() -> void:
	modulate = Color(1.1, 1.1, 1.1)


func _on_mouse_exited() -> void:
	if not is_selected:
		modulate = Color.WHITE
	_update_selection_visual()


func _update_selection_visual() -> void:
	if is_selected:
		name_label.add_theme_color_override("font_color", Color.WHITE)
		# Add selection background
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.0, 0.0, 0.5, 0.8)
		name_label.add_theme_stylebox_override("normal", style)
	else:
		name_label.remove_theme_color_override("font_color")
		name_label.remove_theme_stylebox_override("normal")


func deselect() -> void:
	is_selected = false
	modulate = Color.WHITE
	_update_selection_visual()
