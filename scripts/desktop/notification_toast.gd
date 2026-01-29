extends PanelContainer
## NotificationToast - Popup notification that appears and fades out

signal clicked

@export var display_duration: float = 5.0
@export var fade_duration: float = 0.5

@onready var icon_rect: TextureRect = $HBoxContainer/IconRect
@onready var title_label: Label = $HBoxContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $HBoxContainer/VBoxContainer/MessageLabel

var fade_timer: Timer
var is_hovered: bool = false


func _ready() -> void:
	_setup_style()
	_setup_timer()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	# Animate in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.75, 0.75, 0.75)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.3, 0.3, 0.3, 0.5)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	add_theme_stylebox_override("panel", style)

	custom_minimum_size = Vector2(300, 70)


func _setup_timer() -> void:
	fade_timer = Timer.new()
	fade_timer.wait_time = display_duration
	fade_timer.one_shot = true
	fade_timer.timeout.connect(_start_fade_out)
	add_child(fade_timer)
	fade_timer.start()


func setup(title: String, message: String, icon_path: String = "") -> void:
	if title_label:
		title_label.text = title

	if message_label:
		message_label.text = message

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var texture = load(icon_path)
		if icon_rect:
			icon_rect.texture = texture
			icon_rect.visible = true
	elif icon_rect:
		icon_rect.visible = false


func _on_mouse_entered() -> void:
	is_hovered = true
	fade_timer.paused = true
	modulate = Color(1.1, 1.1, 1.1)


func _on_mouse_exited() -> void:
	is_hovered = false
	fade_timer.paused = false
	modulate = Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit()
			_dismiss()


func _start_fade_out() -> void:
	if is_hovered:
		# Wait for mouse to leave
		fade_timer.start()
		return

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)


func _dismiss() -> void:
	fade_timer.stop()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
