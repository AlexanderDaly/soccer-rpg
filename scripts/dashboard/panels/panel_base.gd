extends Control
class_name PanelBase
## PanelBase - Base class for full-screen overlay panels

signal panel_closed()
signal panel_opened()

@export var panel_title: String = "Panel"
@export var show_back_button: bool = true

@onready var background: ColorRect = $Background
@onready var content_container: PanelContainer = $ContentContainer
@onready var header: HBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/Header
@onready var title_label: Label = $ContentContainer/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var back_button: Button = $ContentContainer/MarginContainer/VBoxContainer/Header/BackButton
@onready var content_area: Control = $ContentContainer/MarginContainer/VBoxContainer/ContentArea

var is_open: bool = false


func _ready() -> void:
	_setup_style()
	_setup_back_button()

	# Start invisible
	modulate.a = 0
	visible = false

	# Allow subclasses to initialize
	_on_panel_ready()


func _setup_style() -> void:
	if background:
		background.color = Color(0, 0, 0, 0.85)

	if content_container:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.039, 0.086, 0.157, 0.98)
		style.set_border_width_all(2)
		style.border_color = Color(0.15, 0.25, 0.4, 1)
		style.set_content_margin_all(0)
		content_container.add_theme_stylebox_override("panel", style)

	if title_label:
		title_label.text = panel_title
		title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		title_label.add_theme_font_size_override("font_size", 24)


func _setup_back_button() -> void:
	if not back_button:
		return

	back_button.visible = show_back_button

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.15, 0.25, 0.9)
	normal_style.set_border_width_all(1)
	normal_style.border_color = Color(0.3, 0.4, 0.6, 1)
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(8)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.15, 0.2, 0.3, 0.95)
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color(0.4, 0.5, 0.7, 1)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(8)

	back_button.add_theme_stylebox_override("normal", normal_style)
	back_button.add_theme_stylebox_override("hover", hover_style)
	back_button.add_theme_stylebox_override("pressed", normal_style)
	back_button.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	back_button.pressed.connect(_on_back_pressed)


func _input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return

	is_open = true
	visible = true

	_on_panel_opening()

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_callback(func():
		panel_opened.emit()
		_on_panel_opened()
	)


func close() -> void:
	if not is_open:
		return

	is_open = false
	AudioManager.play_ui_click()

	_on_panel_closing()

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
		panel_closed.emit()
		_on_panel_closed()
	)


func _on_back_pressed() -> void:
	close()


# Virtual methods for subclasses to override
func _on_panel_ready() -> void:
	pass


func _on_panel_opening() -> void:
	pass


func _on_panel_opened() -> void:
	pass


func _on_panel_closing() -> void:
	pass


func _on_panel_closed() -> void:
	pass


func get_content_area() -> Control:
	return content_area


func set_title(new_title: String) -> void:
	panel_title = new_title
	if title_label:
		title_label.text = new_title
