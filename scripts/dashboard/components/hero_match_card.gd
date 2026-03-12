extends PanelContainer
class_name HeroMatchCard
## HeroMatchCard - Large card showing next match details with play button

signal play_match_pressed(match_data: Dictionary)

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var versus_container: HBoxContainer = $MarginContainer/VBoxContainer/VersusContainer
@onready var home_team_label: Label = $MarginContainer/VBoxContainer/VersusContainer/HomeTeamLabel
@onready var vs_label: Label = $MarginContainer/VBoxContainer/VersusContainer/VsLabel
@onready var away_team_label: Label = $MarginContainer/VBoxContainer/VersusContainer/AwayTeamLabel
@onready var match_info_label: Label = $MarginContainer/VBoxContainer/MatchInfoLabel
@onready var countdown_label: Label = $MarginContainer/VBoxContainer/CountdownLabel
@onready var play_button: Button = $MarginContainer/VBoxContainer/PlayButton
@onready var no_match_label: Label = $MarginContainer/VBoxContainer/NoMatchLabel

var current_match_data: Dictionary = {}
var season_schedule: Array[Dictionary] = []
var next_match_index: int = -1


func _ready() -> void:
	_setup_style()
	_setup_play_button()
	_generate_schedule()
	_refresh_display()


func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.15, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.2, 0.3, 0.5, 1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)


func _setup_play_button() -> void:
	if not play_button:
		return

	# Primary button style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0.6, 0.3, 1)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0, 0.8, 0.4, 1)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(16)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0, 0.7, 0.35, 1)
	hover_style.set_border_width_all(2)
	hover_style.border_color = Color(0, 1, 0.5, 1)
	hover_style.set_corner_radius_all(8)
	hover_style.set_content_margin_all(16)
	hover_style.shadow_color = Color(0, 1, 0.5, 0.3)
	hover_style.shadow_size = 6

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0, 0.5, 0.25, 1)
	pressed_style.set_border_width_all(2)
	pressed_style.border_color = Color(0, 0.6, 0.3, 1)
	pressed_style.set_corner_radius_all(8)
	pressed_style.set_content_margin_all(16)

	play_button.add_theme_stylebox_override("normal", normal_style)
	play_button.add_theme_stylebox_override("hover", hover_style)
	play_button.add_theme_stylebox_override("pressed", pressed_style)
	play_button.add_theme_stylebox_override("focus", hover_style)
	play_button.add_theme_font_size_override("font_size", 20)
	play_button.add_theme_color_override("font_color", Color(1, 1, 1))
	play_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	play_button.pressed.connect(_on_play_pressed)


func _generate_schedule() -> void:
	season_schedule = SeasonManager.get_upcoming_fixtures(-1, true)
	next_match_index = -1
	current_match_data = {}
	for i in range(season_schedule.size()):
		if not season_schedule[i].get("played", false):
			next_match_index = i
			current_match_data = season_schedule[i]
			break


func _get_matches_for_phase(phase: GameManager.CareerPhase) -> int:
	match phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			return 8
		GameManager.CareerPhase.YOUTH_ACADEMY:
			return 10
		GameManager.CareerPhase.U20_QUALIFIERS:
			return 6
		GameManager.CareerPhase.U20_WORLD_CUP:
			return 7
		GameManager.CareerPhase.PRO_CAREER:
			return 15
		_:
			return 8


func _generate_opponents(phase: GameManager.CareerPhase, count: int) -> Array[Dictionary]:
	var opponents: Array[Dictionary] = []
	var names = _get_opponent_names(phase)

	for i in range(count):
		var team = TeamData.new()
		team.name = names[i % names.size()]
		team.tier = _get_tier_for_phase(phase)
		team.formation = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"][randi() % 4]
		team.generate_teammates(10, phase)

		opponents.append({
			"name": team.name,
			"team_data": team
		})

	return opponents


func _get_opponent_names(phase: GameManager.CareerPhase) -> Array[String]:
	match phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			return [
				"Eastside Academy", "North High", "Central United",
				"South Academy", "West Technical", "Harbor High",
				"Mountain View HS", "Riverside Academy", "Valley High",
				"Metro Prep"
			]
		GameManager.CareerPhase.YOUTH_ACADEMY:
			return [
				"Capital Youth FC", "Metro Development", "Elite Academy",
				"Rising Stars FC", "Future Legends", "Youth United",
				"Phoenix Youth", "Crown Academy", "Royal Youth", "City Juniors"
			]
		GameManager.CareerPhase.U20_QUALIFIERS, GameManager.CareerPhase.U20_WORLD_CUP:
			return [
				"Brazil U20", "Germany U20", "Spain U20", "France U20",
				"Argentina U20", "England U20", "Italy U20", "Netherlands U20",
				"Portugal U20", "Mexico U20"
			]
		_:
			return [
				"City FC", "United Athletic", "Royal Sporting",
				"Metro Stars", "Crown FC", "Phoenix United"
			]


func _get_tier_for_phase(phase: GameManager.CareerPhase) -> int:
	match phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			return 1
		GameManager.CareerPhase.YOUTH_ACADEMY:
			return 2
		GameManager.CareerPhase.U20_QUALIFIERS, GameManager.CareerPhase.U20_WORLD_CUP:
			return 3
		GameManager.CareerPhase.PRO_CAREER:
			return randi_range(2, 4)
		_:
			return 1


func _get_match_type(phase: GameManager.CareerPhase, index: int, total: int) -> String:
	match phase:
		GameManager.CareerPhase.HIGH_SCHOOL:
			if index == total - 1:
				return "cup"
			return "league"
		GameManager.CareerPhase.U20_QUALIFIERS:
			return "qualifier"
		GameManager.CareerPhase.U20_WORLD_CUP:
			if index == total - 1:
				return "world_cup_final"
			return "world_cup"
		_:
			if index % 5 == 4:
				return "cup"
			return "league"


func _refresh_display() -> void:
	if current_match_data.is_empty():
		_show_no_match()
		return

	# Show match info
	if no_match_label:
		no_match_label.visible = false
	if versus_container:
		versus_container.visible = true
	if match_info_label:
		match_info_label.visible = true
	if countdown_label:
		countdown_label.visible = true
	if play_button:
		play_button.visible = true

	# Title
	if title_label:
		title_label.text = "NEXT MATCH"
		title_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		title_label.add_theme_font_size_override("font_size", 14)

	# Team names
	var player_team = GameManager.current_team
	var team_name = player_team.name if player_team else "Your Team"

	if home_team_label:
		home_team_label.text = team_name
		home_team_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
		home_team_label.add_theme_font_size_override("font_size", 24)

	if vs_label:
		vs_label.text = "vs"
		vs_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		vs_label.add_theme_font_size_override("font_size", 18)

	if away_team_label:
		away_team_label.text = current_match_data.opponent.name
		away_team_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		away_team_label.add_theme_font_size_override("font_size", 24)

	# Match info
	if match_info_label:
		var match_type_text = _get_match_type_display(current_match_data.type)
		match_info_label.text = "%s - %s" % [current_match_data.opponent.name, match_type_text]
		match_info_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		match_info_label.add_theme_font_size_override("font_size", 16)

	# Countdown
	if countdown_label:
		var match_date = current_match_data.get("match_date", {})
		var days_until = int(match_date.get("day", DesktopManager.game_date.day)) - DesktopManager.game_date.day
		if int(match_date.get("month", DesktopManager.game_date.month)) != DesktopManager.game_date.month:
			days_until += 30
		var countdown_text = "%s %d" % [_month_short(int(match_date.get("month", 1))), int(match_date.get("day", 1))]
		if days_until == 0:
			countdown_text += " - TODAY!"
		elif days_until == 1:
			countdown_text += " - Tomorrow"
		else:
			countdown_text += " - %d days away" % days_until
		countdown_label.text = countdown_text
		countdown_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		countdown_label.add_theme_font_size_override("font_size", 14)

	# Play button
	if play_button:
		play_button.text = "PLAY MATCH"


func _show_no_match() -> void:
	if title_label:
		title_label.text = "NO UPCOMING MATCHES"
	if versus_container:
		versus_container.visible = false
	if match_info_label:
		match_info_label.visible = false
	if countdown_label:
		countdown_label.visible = false
	if play_button:
		play_button.visible = false
	if no_match_label:
		no_match_label.visible = true
		no_match_label.text = "Season complete!\nCheck schedule for details."


func _get_match_type_display(match_type: String) -> String:
	match match_type:
		"league":
			return "League Match"
		"cup":
			return "Cup Match"
		"qualifier":
			return "Qualifier"
		"world_cup":
			return "World Cup"
		"world_cup_final":
			return "World Cup Final"
		_:
			return match_type.capitalize()


func _on_play_pressed() -> void:
	if current_match_data.is_empty():
		return

	AudioManager.play_ui_confirm()

	# Mark match as played
	if next_match_index >= 0:
		season_schedule[next_match_index].played = true

	# Start match
	var opponent_team = current_match_data.opponent.team_data
	GameManager.start_match(opponent_team, current_match_data.type, current_match_data.get("is_home", true), current_match_data.get("player_team", null))

	# Emit signal for dashboard to handle
	play_match_pressed.emit(current_match_data)

	# Transition to pre-match screen
	get_tree().change_scene_to_file("res://scenes/match/pre_match.tscn")


func get_schedule() -> Array[Dictionary]:
	return season_schedule


func get_next_match_index() -> int:
	return next_match_index


func _month_short(month: int) -> String:
	var months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return months[clampi(month, 1, 12)]
