extends PanelBase
class_name PanelSaveLoad
## PanelSaveLoad - Save/Load game panel

@onready var slots_container: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/SlotsContainer
@onready var status_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/StatusLabel

const MAX_SAVE_SLOTS = 5


func _on_panel_ready() -> void:
	panel_title = "Save Manager"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_refresh_slots()


func _refresh_slots() -> void:
	if not slots_container:
		return

	for child in slots_container.get_children():
		child.queue_free()

	var save_info_list = SaveManager.get_all_save_info()

	for i in range(MAX_SAVE_SLOTS):
		var save_info = save_info_list[i] if i < save_info_list.size() else {"exists": false}
		_add_slot_panel(i, save_info)


func _add_slot_panel(slot_index: int, save_info: Dictionary) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.18, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.15, 0.25, 0.4)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	# Slot info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)

	var slot_label = Label.new()
	slot_label.text = "Slot %d" % (slot_index + 1)
	slot_label.add_theme_font_size_override("font_size", 18)
	slot_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))

	var details_label = Label.new()
	if save_info.get("exists", false):
		var player_name = save_info.get("player_name", "Unknown")
		var save_date = save_info.get("save_date", "Unknown")
		var game_day = save_info.get("game_day", 0)
		details_label.text = "%s - Day %d\nSaved: %s" % [player_name, game_day, save_date]
	else:
		details_label.text = "Empty Slot"
	details_label.add_theme_font_size_override("font_size", 13)
	details_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))

	info_vbox.add_child(slot_label)
	info_vbox.add_child(details_label)

	# Buttons
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)

	# Save button
	var save_btn = _create_button("Save", Color(0, 0.5, 0.25))
	save_btn.pressed.connect(_on_save_pressed.bind(slot_index))
	btn_vbox.add_child(save_btn)

	# Load button (only if save exists)
	if save_info.get("exists", false):
		var load_btn = _create_button("Load", Color(0.2, 0.4, 0.6))
		load_btn.pressed.connect(_on_load_pressed.bind(slot_index))
		btn_vbox.add_child(load_btn)

		var delete_btn = _create_button("Delete", Color(0.5, 0.15, 0.15))
		delete_btn.pressed.connect(_on_delete_pressed.bind(slot_index))
		btn_vbox.add_child(delete_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(btn_vbox)

	panel.add_child(hbox)
	slots_container.add_child(panel)


func _create_button(text: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 32)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = bg_color.lightened(0.2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = bg_color.lightened(0.15)
	hover_style.set_border_width_all(1)
	hover_style.border_color = bg_color.lightened(0.3)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

	return btn


func _on_save_pressed(slot_index: int) -> void:
	AudioManager.play_ui_click()
	if status_label:
		status_label.text = "Saving to Slot %d..." % (slot_index + 1)
		status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	var success = SaveManager.save_game(slot_index)

	if success:
		if status_label:
			status_label.text = "Game saved to Slot %d!" % (slot_index + 1)
			status_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		_refresh_slots()
	else:
		if status_label:
			status_label.text = "Failed to save game."
			status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))


func _on_load_pressed(slot_index: int) -> void:
	AudioManager.play_ui_click()
	if status_label:
		status_label.text = "Loading Slot %d..." % (slot_index + 1)
		status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	var success = SaveManager.load_game(slot_index)

	if success:
		close()
		# Reload the dashboard to reflect loaded game state
		get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")
	else:
		if status_label:
			status_label.text = "Failed to load game."
			status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))


func _on_delete_pressed(slot_index: int) -> void:
	AudioManager.play_ui_click()

	var success = SaveManager.delete_save(slot_index)

	if success:
		if status_label:
			status_label.text = "Slot %d deleted." % (slot_index + 1)
			status_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		_refresh_slots()
	else:
		if status_label:
			status_label.text = "Failed to delete save."
			status_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
