extends Control
## Settings - Audio and game settings UI

@onready var music_slider: HSlider = $VBoxContainer/SettingsContainer/MusicContainer/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SettingsContainer/SFXContainer/SFXSlider
@onready var auto_save_check: CheckBox = $VBoxContainer/SettingsContainer/AutoSaveCheck
@onready var back_button: Button = $VBoxContainer/BackButton

@onready var music_value_label: Label = $VBoxContainer/SettingsContainer/MusicContainer/MusicValueLabel
@onready var sfx_value_label: Label = $VBoxContainer/SettingsContainer/SFXContainer/SFXValueLabel


func _ready() -> void:
	# Initialize values from managers
	music_slider.value = AudioManager.music_volume * 100
	sfx_slider.value = AudioManager.sfx_volume * 100
	auto_save_check.button_pressed = SaveManager.auto_save_enabled

	# Update value labels
	_update_music_label(music_slider.value)
	_update_sfx_label(sfx_slider.value)

	# Connect signals
	music_slider.value_changed.connect(_on_music_slider_value_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)
	auto_save_check.toggled.connect(_on_auto_save_toggled)
	back_button.pressed.connect(_on_back_pressed)

	back_button.grab_focus()


func _update_music_label(value: float) -> void:
	music_value_label.text = "%d%%" % int(value)


func _update_sfx_label(value: float) -> void:
	sfx_value_label.text = "%d%%" % int(value)


func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)
	_update_music_label(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	_update_sfx_label(value)


func _on_auto_save_toggled(toggled: bool) -> void:
	AudioManager.play_ui_click()
	SaveManager.auto_save_enabled = toggled


func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
