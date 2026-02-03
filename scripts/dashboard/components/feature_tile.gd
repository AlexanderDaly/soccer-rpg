extends PanelContainer
class_name FeatureTile
## FeatureTile - A selectable tile for the console dashboard navigation grid

signal pressed(tile_id: String)

@export var tile_id: String = ""
@export var tile_title: String = "Feature"
@export var tile_icon: Texture2D

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/IconRect
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel

var is_focused: bool = false
var base_scale: Vector2 = Vector2.ONE
var focus_scale: Vector2 = Vector2(1.05, 1.05)

# Style references
var style_normal: StyleBoxFlat
var style_hover: StyleBoxFlat
var style_focus: StyleBoxFlat
var style_pressed: StyleBoxFlat


func _ready() -> void:
	_setup_styles()
	_update_display()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func _setup_styles() -> void:
	# Create style variations for different states
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.12, 0.2, 0.9)
	style_normal.set_border_width_all(2)
	style_normal.border_color = Color(0.15, 0.25, 0.4, 1)
	style_normal.set_corner_radius_all(8)
	style_normal.set_content_margin_all(12)

	style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.1, 0.15, 0.25, 0.95)
	style_hover.set_border_width_all(2)
	style_hover.border_color = Color(0.2, 0.35, 0.5, 1)
	style_hover.set_corner_radius_all(8)
	style_hover.set_content_margin_all(12)

	style_focus = StyleBoxFlat.new()
	style_focus.bg_color = Color(0.1, 0.18, 0.3, 1)
	style_focus.set_border_width_all(3)
	style_focus.border_color = Color(0, 1, 0.5, 1)
	style_focus.set_corner_radius_all(8)
	style_focus.set_content_margin_all(12)
	style_focus.shadow_color = Color(0, 1, 0.5, 0.3)
	style_focus.shadow_size = 8

	style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.05, 0.1, 0.18, 1)
	style_pressed.set_border_width_all(3)
	style_pressed.border_color = Color(0, 0.8, 0.4, 1)
	style_pressed.set_corner_radius_all(8)
	style_pressed.set_content_margin_all(12)

	add_theme_stylebox_override("panel", style_normal)


func _update_display() -> void:
	if icon_rect and tile_icon:
		icon_rect.texture = tile_icon
	elif icon_rect:
		# Create placeholder icon
		icon_rect.custom_minimum_size = Vector2(48, 48)

	if title_label:
		title_label.text = tile_title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func setup(id: String, title: String, icon: Texture2D = null) -> void:
	tile_id = id
	tile_title = title
	tile_icon = icon
	if is_inside_tree():
		_update_display()


func set_focused(focused: bool) -> void:
	is_focused = focused

	if focused:
		add_theme_stylebox_override("panel", style_focus)
		_animate_scale(focus_scale)
		grab_focus()
	else:
		add_theme_stylebox_override("panel", style_normal)
		_animate_scale(base_scale)


func _animate_scale(target_scale: Vector2) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", target_scale, 0.15)


func _on_mouse_entered() -> void:
	if not is_focused:
		add_theme_stylebox_override("panel", style_hover)


func _on_mouse_exited() -> void:
	if not is_focused:
		add_theme_stylebox_override("panel", style_normal)


func _on_focus_entered() -> void:
	set_focused(true)


func _on_focus_exited() -> void:
	set_focused(false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_activate()
	elif event.is_action_pressed("ui_accept"):
		_activate()


func _activate() -> void:
	AudioManager.play_ui_click()
	add_theme_stylebox_override("panel", style_pressed)

	# Brief press animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(self, "scale", focus_scale if is_focused else base_scale, 0.1)
	tween.tween_callback(func():
		add_theme_stylebox_override("panel", style_focus if is_focused else style_normal)
		pressed.emit(tile_id)
	)
