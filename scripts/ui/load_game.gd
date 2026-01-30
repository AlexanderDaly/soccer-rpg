extends Control
## LoadGame - Save slot selection and loading UI

@onready var slot_container: VBoxContainer = $VBoxContainer/SlotContainer
@onready var back_button: Button = $VBoxContainer/BackButton

var selected_slot: int = -1
var _confirmation_dialog: ConfirmationDialog


func _ready() -> void:
	_setup_confirmation_dialog()
	_populate_save_slots()
	back_button.pressed.connect(_on_back_pressed)
	back_button.grab_focus()


func _setup_confirmation_dialog() -> void:
	_confirmation_dialog = ConfirmationDialog.new()
	_confirmation_dialog.title = "Delete Save"
	_confirmation_dialog.dialog_text = "Are you sure you want to delete this save?"
	_confirmation_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_confirmation_dialog)


func _populate_save_slots() -> void:
	# Clear existing slots
	for child in slot_container.get_children():
		child.queue_free()

	var saves = SaveManager.get_all_save_info()
	for i in range(saves.size()):
		_create_slot_ui(i, saves[i])


func _create_slot_ui(slot: int, info: Dictionary) -> void:
	var slot_panel = PanelContainer.new()
	slot_panel.custom_minimum_size = Vector2(0, 80)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	slot_panel.add_child(hbox)

	# Slot info container
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Slot header
	var slot_label = Label.new()
	slot_label.add_theme_font_size_override("font_size", 20)
	info_vbox.add_child(slot_label)

	# Details label
	var details_label = Label.new()
	details_label.add_theme_font_size_override("font_size", 14)
	details_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(details_label)

	var has_save = info.get("exists", false)

	if has_save:
		var player_name = info.get("player_name", "Unknown")
		var career_phase = info.get("career_phase", "Unknown")
		var save_date = info.get("save_date", "")

		slot_label.text = "Slot %d: %s" % [slot + 1, player_name]
		details_label.text = "%s | %s" % [career_phase, _format_date(save_date)]
	else:
		slot_label.text = "Slot %d: Empty" % [slot + 1]
		details_label.text = "No save data"

	# Button container
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	hbox.add_child(button_hbox)

	# Load button
	var load_button = Button.new()
	load_button.text = "Load"
	load_button.custom_minimum_size = Vector2(80, 40)
	load_button.disabled = not has_save
	load_button.pressed.connect(_on_load_pressed.bind(slot))
	button_hbox.add_child(load_button)

	# Delete button
	var delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 40)
	delete_button.disabled = not has_save
	delete_button.pressed.connect(_on_delete_pressed.bind(slot))
	button_hbox.add_child(delete_button)

	slot_container.add_child(slot_panel)


func _format_date(date_string: String) -> String:
	if date_string.is_empty():
		return "Unknown date"
	# Format: YYYY-MM-DDTHH:MM:SS -> MM/DD/YYYY HH:MM
	if date_string.length() >= 16:
		var date_part = date_string.substr(0, 10)
		var time_part = date_string.substr(11, 5)
		var parts = date_part.split("-")
		if parts.size() == 3:
			return "%s/%s/%s %s" % [parts[1], parts[2], parts[0], time_part]
	return date_string


func _on_load_pressed(slot: int) -> void:
	AudioManager.play_ui_confirm()
	if SaveManager.load_game(slot):
		get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")


func _on_delete_pressed(slot: int) -> void:
	AudioManager.play_ui_click()
	selected_slot = slot
	_confirmation_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if selected_slot >= 0:
		SaveManager.delete_save(selected_slot)
		_populate_save_slots()
		selected_slot = -1


func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
