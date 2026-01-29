extends Control
## AppSaveLoad - Save and load game progress

@onready var slots_container: VBoxContainer = $VBoxContainer/ScrollContainer/SlotsContainer
@onready var status_label: Label = $VBoxContainer/StatusLabel

var selected_slot: int = -1


func _ready() -> void:
	_refresh_slots()
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)


func _refresh_slots() -> void:
	# Clear existing
	for child in slots_container.get_children():
		child.queue_free()

	# Create slot entries
	var saves = SaveManager.get_all_save_info()
	for i in range(saves.size()):
		_create_slot_entry(i, saves[i])


func _create_slot_entry(slot: int, info: Dictionary) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)

	var hbox = HBoxContainer.new()

	# Slot info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var slot_label = Label.new()
	slot_label.text = "Slot %d" % (slot + 1)
	slot_label.add_theme_font_size_override("font_size", 18)

	var details_label = Label.new()
	if info.get("exists", false):
		details_label.text = "%s - %s\n%s" % [
			info.get("player_name", "Unknown"),
			info.get("career_phase", "Unknown"),
			info.get("save_date", "")
		]
	else:
		details_label.text = "Empty Slot"
		details_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	info_vbox.add_child(slot_label)
	info_vbox.add_child(details_label)

	# Buttons
	var buttons_vbox = VBoxContainer.new()

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(80, 28)
	save_btn.pressed.connect(_on_save_pressed.bind(slot))

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(80, 28)
	load_btn.disabled = not info.get("exists", false)
	load_btn.pressed.connect(_on_load_pressed.bind(slot))

	var delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.custom_minimum_size = Vector2(80, 28)
	delete_btn.disabled = not info.get("exists", false)
	delete_btn.pressed.connect(_on_delete_pressed.bind(slot))

	buttons_vbox.add_child(save_btn)
	buttons_vbox.add_child(load_btn)
	buttons_vbox.add_child(delete_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(buttons_vbox)

	panel.add_child(hbox)
	slots_container.add_child(panel)


func _on_save_pressed(slot: int) -> void:
	AudioManager.play_ui_click()
	status_label.text = "Saving to slot %d..." % (slot + 1)
	SaveManager.save_game(slot)


func _on_load_pressed(slot: int) -> void:
	AudioManager.play_ui_click()
	status_label.text = "Loading slot %d..." % (slot + 1)
	SaveManager.load_game(slot)


func _on_delete_pressed(slot: int) -> void:
	AudioManager.play_ui_click()
	if SaveManager.delete_save(slot):
		status_label.text = "Slot %d deleted" % (slot + 1)
		_refresh_slots()
	else:
		status_label.text = "Failed to delete slot %d" % (slot + 1)


func _on_save_completed(slot: int, success: bool) -> void:
	if success:
		status_label.text = "Saved to slot %d" % (slot + 1)
	else:
		status_label.text = "Save failed!"
	_refresh_slots()


func _on_load_completed(slot: int, success: bool) -> void:
	if success:
		status_label.text = "Loaded from slot %d" % (slot + 1)
		# Refresh desktop after loading
		get_tree().change_scene_to_file("res://scenes/desktop/desktop_shell.tscn")
	else:
		status_label.text = "Load failed!"
