extends PanelContainer
class_name PlayerMiniCard
## PlayerMiniCard - Compact player info card for the dashboard

@onready var portrait_rect: TextureRect = $MarginContainer/HBoxContainer/PortraitContainer/PortraitRect
@onready var name_label: Label = $MarginContainer/HBoxContainer/InfoContainer/NameLabel
@onready var position_label: Label = $MarginContainer/HBoxContainer/InfoContainer/PositionRow/PositionLabel
@onready var overall_label: Label = $MarginContainer/HBoxContainer/InfoContainer/PositionRow/OverallLabel
@onready var form_indicator: ColorRect = $MarginContainer/HBoxContainer/InfoContainer/FormRow/FormIndicator
@onready var form_label: Label = $MarginContainer/HBoxContainer/InfoContainer/FormRow/FormLabel
@onready var stamina_bar: ProgressBar = $MarginContainer/HBoxContainer/InfoContainer/StaminaRow/StaminaBar
@onready var stamina_label: Label = $MarginContainer/HBoxContainer/InfoContainer/StaminaRow/StaminaLabel


func _ready() -> void:
	_setup_style()
	_refresh_display()
	_connect_signals()


func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.18, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.15, 0.25, 0.4, 1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	add_theme_stylebox_override("panel", style)


func _connect_signals() -> void:
	if StatSystem.stat_changed.is_connected(_on_stat_changed):
		return
	StatSystem.stat_changed.connect(_on_stat_changed)
	StatSystem.level_up.connect(_on_level_up)


func _on_stat_changed(_player_id: String, _stat_name: String, _old_value: int, _new_value: int) -> void:
	_refresh_display()


func _on_level_up(_player_id: String, _new_level: int) -> void:
	_refresh_display()


func _refresh_display() -> void:
	var player = GameManager.player_data
	if not player:
		_show_placeholder()
		return

	# Name
	if name_label:
		name_label.text = player.name if player.name else "Unknown Player"

	# Position
	if position_label:
		position_label.text = player.position
		position_label.add_theme_color_override("font_color", _get_position_color(player.position))

	# Overall rating
	if overall_label:
		var ovr = player.get_overall()
		overall_label.text = "OVR %d" % ovr
		overall_label.add_theme_color_override("font_color", _get_overall_color(ovr))

	# Form
	if form_indicator and form_label:
		var form_str = player.current_form if player.current_form else "average"
		form_indicator.color = _get_form_color_from_string(form_str)
		form_label.text = form_str.capitalize()

	# Stamina
	if stamina_bar and stamina_label:
		stamina_bar.value = player.stamina_current
		stamina_label.text = "%d%%" % player.stamina_current
		stamina_bar.modulate = _get_stamina_color(player.stamina_current)

	# Portrait (placeholder for now)
	if portrait_rect:
		portrait_rect.modulate = Color(0.8, 0.85, 0.9)


func _show_placeholder() -> void:
	if name_label:
		name_label.text = "No Player"
	if position_label:
		position_label.text = "---"
	if overall_label:
		overall_label.text = "OVR --"
	if form_label:
		form_label.text = "---"
	if stamina_bar:
		stamina_bar.value = 0
	if stamina_label:
		stamina_label.text = "--%"


func _get_position_color(pos: String) -> Color:
	match pos:
		"GK":
			return Color(1.0, 0.8, 0.2)  # Gold
		"CB", "LB", "RB", "LWB", "RWB":
			return Color(0.2, 0.6, 1.0)  # Blue
		"CDM", "CM", "CAM", "LM", "RM":
			return Color(0.2, 0.9, 0.4)  # Green
		"LW", "RW", "CF", "ST":
			return Color(1.0, 0.4, 0.4)  # Red
		_:
			return Color(0.8, 0.8, 0.8)


func _get_overall_color(ovr: int) -> Color:
	if ovr >= 85:
		return Color(1.0, 0.84, 0.0)  # Gold
	elif ovr >= 75:
		return Color(0.0, 0.9, 0.4)  # Green
	elif ovr >= 65:
		return Color(0.9, 0.9, 0.9)  # Silver
	elif ovr >= 55:
		return Color(0.8, 0.5, 0.2)  # Bronze
	else:
		return Color(0.6, 0.6, 0.6)  # Gray


func _get_form_color_from_string(form: String) -> Color:
	match form:
		"excellent":
			return Color(0.0, 1.0, 0.4)  # Bright green
		"good":
			return Color(0.4, 0.9, 0.4)  # Green
		"average":
			return Color(1.0, 0.8, 0.2)  # Yellow
		"poor":
			return Color(1.0, 0.5, 0.2)  # Orange
		"terrible":
			return Color(1.0, 0.3, 0.3)  # Red
		_:
			return Color(1.0, 0.8, 0.2)  # Default yellow


func _get_stamina_color(stamina: int) -> Color:
	if stamina >= 70:
		return Color(0.4, 1.0, 0.5)  # Green
	elif stamina >= 40:
		return Color(1.0, 0.9, 0.3)  # Yellow
	else:
		return Color(1.0, 0.4, 0.4)  # Red
