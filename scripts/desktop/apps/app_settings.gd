extends Control
## AppSettings - Audio and game settings

@onready var music_slider: HSlider = $VBoxContainer/AudioSection/MusicRow/MusicSlider
@onready var music_value: Label = $VBoxContainer/AudioSection/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $VBoxContainer/AudioSection/SFXRow/SFXSlider
@onready var sfx_value: Label = $VBoxContainer/AudioSection/SFXRow/SFXValue
@onready var mute_button: CheckButton = $VBoxContainer/AudioSection/MuteRow/MuteButton
@onready var auto_save_button: CheckButton = $VBoxContainer/GameSection/AutoSaveRow/AutoSaveButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	_load_settings()
	_connect_signals()


func _load_settings() -> void:
	music_slider.value = AudioManager.music_volume * 100
	sfx_slider.value = AudioManager.sfx_volume * 100
	mute_button.button_pressed = AudioManager.is_muted
	auto_save_button.button_pressed = SaveManager.auto_save_enabled

	_update_music_label()
	_update_sfx_label()


func _connect_signals() -> void:
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_button.toggled.connect(_on_mute_toggled)
	auto_save_button.toggled.connect(_on_auto_save_toggled)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_music_changed(value: float) -> void:
	AudioManager.set_music_volume(value / 100.0)
	_update_music_label()


func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	_update_sfx_label()
	AudioManager.play_ui_click()


func _on_mute_toggled(pressed: bool) -> void:
	AudioManager.set_muted(pressed)


func _on_auto_save_toggled(pressed: bool) -> void:
	SaveManager.auto_save_enabled = pressed
	if pressed:
		SaveManager.start_auto_save()
	else:
		SaveManager.stop_auto_save()


func _on_quit_pressed() -> void:
	AudioManager.play_ui_click()
	# Return to main menu
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


func _update_music_label() -> void:
	music_value.text = "%d%%" % roundi(music_slider.value)


func _update_sfx_label() -> void:
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)
