extends PanelBase
class_name PanelSettings
## PanelSettings - Game settings panel

@onready var settings_container: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/SettingsContainer

var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"vsync": true,
	"show_tutorials": true
}


func _on_panel_ready() -> void:
	panel_title = "Settings"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_load_settings()
	_build_settings_ui()


func _load_settings() -> void:
	# Load from AudioManager or config
	if AudioManager:
		settings.master_volume = AudioManager.get_master_volume() if AudioManager.has_method("get_master_volume") else 1.0
		settings.music_volume = AudioManager.get_music_volume() if AudioManager.has_method("get_music_volume") else 0.8
		settings.sfx_volume = AudioManager.get_sfx_volume() if AudioManager.has_method("get_sfx_volume") else 1.0

	settings.fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func _build_settings_ui() -> void:
	if not settings_container:
		return

	for child in settings_container.get_children():
		child.queue_free()

	# Audio section
	_add_section_header("Audio")
	_add_slider_setting("Master Volume", "master_volume", 0.0, 1.0)
	_add_slider_setting("Music Volume", "music_volume", 0.0, 1.0)
	_add_slider_setting("SFX Volume", "sfx_volume", 0.0, 1.0)

	_add_spacer()

	# Display section
	_add_section_header("Display")
	_add_toggle_setting("Fullscreen", "fullscreen")
	_add_toggle_setting("VSync", "vsync")

	_add_spacer()

	# Gameplay section
	_add_section_header("Gameplay")
	_add_toggle_setting("Show Tutorials", "show_tutorials")

	_add_spacer()

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var apply_btn = _create_button("Apply", Color(0, 0.5, 0.25))
	apply_btn.pressed.connect(_on_apply_pressed)
	btn_row.add_child(apply_btn)

	var reset_btn = _create_button("Reset to Defaults", Color(0.4, 0.2, 0.2))
	reset_btn.pressed.connect(_on_reset_pressed)
	btn_row.add_child(reset_btn)

	var quit_btn = _create_button("Quit to Menu", Color(0.3, 0.15, 0.15))
	quit_btn.pressed.connect(_on_quit_to_menu)
	btn_row.add_child(quit_btn)

	settings_container.add_child(btn_row)


func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0, 0.8, 0.4))
	settings_container.add_child(header)


func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	settings_container.add_child(spacer)


func _add_slider_setting(label_text: String, setting_key: String, min_val: float, max_val: float) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.05
	slider.value = settings.get(setting_key, 1.0)
	slider.custom_minimum_size = Vector2(200, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label = Label.new()
	value_label.text = "%d%%" % int(slider.value * 100)
	value_label.custom_minimum_size = Vector2(50, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))

	slider.value_changed.connect(func(val):
		settings[setting_key] = val
		value_label.text = "%d%%" % int(val * 100)
		_apply_audio_setting(setting_key, val)
	)

	hbox.add_child(label)
	hbox.add_child(slider)
	hbox.add_child(value_label)

	settings_container.add_child(hbox)


func _add_toggle_setting(label_text: String, setting_key: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

	var checkbox = CheckButton.new()
	checkbox.button_pressed = settings.get(setting_key, false)

	checkbox.toggled.connect(func(pressed):
		settings[setting_key] = pressed
		_apply_toggle_setting(setting_key, pressed)
	)

	hbox.add_child(label)
	hbox.add_child(checkbox)

	settings_container.add_child(hbox)


func _create_button(text: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 40)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = bg_color.lightened(0.2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = bg_color.lightened(0.15)
	hover_style.set_border_width_all(1)
	hover_style.border_color = bg_color.lightened(0.3)
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

	return btn


func _apply_audio_setting(key: String, value: float) -> void:
	if not AudioManager:
		return

	match key:
		"master_volume":
			if AudioManager.has_method("set_master_volume"):
				AudioManager.set_master_volume(value)
		"music_volume":
			if AudioManager.has_method("set_music_volume"):
				AudioManager.set_music_volume(value)
		"sfx_volume":
			if AudioManager.has_method("set_sfx_volume"):
				AudioManager.set_sfx_volume(value)


func _apply_toggle_setting(key: String, value: bool) -> void:
	match key:
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)


func _on_apply_pressed() -> void:
	AudioManager.play_ui_confirm()
	# Settings are applied immediately via callbacks
	DesktopManager.show_notification(
		"Settings Saved",
		"Your settings have been applied.",
		"",
		""
	)


func _on_reset_pressed() -> void:
	AudioManager.play_ui_click()
	settings = {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"fullscreen": false,
		"vsync": true,
		"show_tutorials": true
	}
	_build_settings_ui()
	_apply_all_settings()


func _apply_all_settings() -> void:
	_apply_audio_setting("master_volume", settings.master_volume)
	_apply_audio_setting("music_volume", settings.music_volume)
	_apply_audio_setting("sfx_volume", settings.sfx_volume)
	_apply_toggle_setting("fullscreen", settings.fullscreen)
	_apply_toggle_setting("vsync", settings.vsync)


func _on_quit_to_menu() -> void:
	AudioManager.play_ui_click()
	close()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
