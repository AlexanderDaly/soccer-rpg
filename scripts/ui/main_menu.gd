extends Control
## MainMenu - Main menu UI and navigation

@onready var new_game_button: Button = $VBoxContainer/NewGameButton
@onready var load_game_button: Button = $VBoxContainer/LoadGameButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
	AudioManager.play_music("menu")
	
	# Check for existing saves
	_update_load_button()
	
	# Focus first button
	new_game_button.grab_focus()


func _update_load_button() -> void:
	var has_saves = false
	for save_info in SaveManager.get_all_save_info():
		if save_info.get("exists", false):
			has_saves = true
			break
	
	load_game_button.disabled = not has_saves


func _on_new_game_pressed() -> void:
	AudioManager.play_ui_confirm()
	# Transition to character creation
	get_tree().change_scene_to_file("res://scenes/menus/character_creation.tscn")


func _on_load_game_pressed() -> void:
	AudioManager.play_ui_confirm()
	# Open save slot selection
	get_tree().change_scene_to_file("res://scenes/menus/load_game.tscn")


func _on_settings_pressed() -> void:
	AudioManager.play_ui_click()
	# Open settings menu
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")


func _on_quit_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().quit()


func _input(event: InputEvent) -> void:
	# Handle button hover sounds
	pass
