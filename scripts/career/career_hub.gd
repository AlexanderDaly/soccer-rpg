extends Control
## CareerHub - Central navigation hub for career mode (Placeholder)

@onready var player_name_label: Label = $MainContainer/PlayerCard/PlayerName
@onready var position_label: Label = $MainContainer/PlayerCard/Position
@onready var overall_label: Label = $MainContainer/PlayerCard/Overall
@onready var phase_label: Label = $MainContainer/PhaseLabel
@onready var back_button: Button = $MainContainer/BackButton


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.CAREER_HUB)
	if back_button:
		back_button.text = "Back to Dashboard"
	_update_display()


func _update_display() -> void:
	var player = GameManager.player_data
	if player:
		player_name_label.text = player.name
		position_label.text = player.position
		overall_label.text = "OVR: %d" % player.get_overall()

	phase_label.text = GameManager.get_career_phase_name()


func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")
