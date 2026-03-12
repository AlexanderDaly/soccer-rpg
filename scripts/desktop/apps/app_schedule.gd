extends Control
## AppSchedule - Calendar app for match schedule

@onready var month_label: Label = $VBoxContainer/HeaderSection/MonthLabel
@onready var prev_button: Button = $VBoxContainer/HeaderSection/PrevButton
@onready var next_button: Button = $VBoxContainer/HeaderSection/NextButton
@onready var calendar_grid: GridContainer = $VBoxContainer/CalendarGrid
@onready var upcoming_list: VBoxContainer = $VBoxContainer/UpcomingSection/UpcomingList

# Track generated schedule
var season_schedule: Array[Dictionary] = []
var next_match_index: int = 0


func _ready() -> void:
	prev_button.pressed.connect(_on_prev_month)
	next_button.pressed.connect(_on_next_month)

	_generate_season_schedule()
	_setup_calendar()
	_setup_upcoming_matches()


func _generate_season_schedule() -> void:
	season_schedule = SeasonManager.get_upcoming_fixtures(-1, true)
	next_match_index = -1
	for i in range(season_schedule.size()):
		if not season_schedule[i].get("played", false):
			next_match_index = i
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
				return "cup"  # Finals
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


func _setup_calendar() -> void:
	month_label.text = _get_current_month()

	# Clear and rebuild calendar
	for child in calendar_grid.get_children():
		child.queue_free()

	# Get match days
	var match_days: Array[int] = []
	for match_info in season_schedule:
		if not match_info.get("played", false):
			var match_date = match_info.get("match_date", {})
			if int(match_date.get("month", 0)) == DesktopManager.game_date.month and int(match_date.get("year", 0)) == DesktopManager.game_date.year:
				match_days.append(int(match_date.get("day", 0)))

	# Add day numbers
	var current_day = DesktopManager.game_date.day
	for i in range(1, 31):
		var day_btn = Button.new()
		day_btn.text = str(i)
		day_btn.custom_minimum_size = Vector2(40, 40)

		# Current day highlight
		if i == current_day:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.5, 0.8)
			style.set_content_margin_all(4)
			day_btn.add_theme_stylebox_override("normal", style)

		# Match day indicator
		if i in match_days:
			day_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			day_btn.tooltip_text = "Match Day!"

		calendar_grid.add_child(day_btn)


func _setup_upcoming_matches() -> void:
	# Clear existing
	for child in upcoming_list.get_children():
		child.queue_free()

	# Find next unplayed matches
	var upcoming_count = 0
	for i in range(season_schedule.size()):
		var match_info = season_schedule[i]
		if match_info.played:
			continue

		upcoming_count += 1
		if upcoming_count > 4:
			break

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var date_label = Label.new()
		var match_date = match_info.get("match_date", {})
		date_label.text = "%s %d" % [_month_short(int(match_date.get("month", 1))), int(match_date.get("day", 1))]
		date_label.custom_minimum_size = Vector2(60, 0)
		date_label.add_theme_font_size_override("font_size", 14)

		var opponent_label = Label.new()
		opponent_label.text = "vs %s" % match_info.opponent.name
		opponent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opponent_label.add_theme_font_size_override("font_size", 14)

		var type_label = Label.new()
		type_label.text = "%s | %s" % [match_info.get("competition", ""), _get_match_type_display(match_info.type)]
		type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		type_label.add_theme_font_size_override("font_size", 12)

		hbox.add_child(date_label)
		hbox.add_child(opponent_label)
		hbox.add_child(type_label)

		# Add play button for the next match
		if upcoming_count == 1:
			var play_btn = Button.new()
			play_btn.text = "PLAY"
			play_btn.custom_minimum_size = Vector2(60, 30)
			play_btn.pressed.connect(_on_play_match.bind(i))
			hbox.add_child(play_btn)

			# Mark this as the next match
			next_match_index = i

		upcoming_list.add_child(hbox)

	# No matches message
	if upcoming_count == 0:
		var no_matches = Label.new()
		no_matches.text = "No upcoming matches.\nSeason complete!"
		no_matches.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		upcoming_list.add_child(no_matches)


func _get_match_type_display(match_type: String) -> String:
	match match_type:
		"league":
			return "League"
		"cup":
			return "Cup"
		"qualifier":
			return "Qualifier"
		"world_cup":
			return "World Cup"
		"world_cup_final":
			return "WC Final"
		_:
			return match_type.capitalize()


func _on_play_match(match_index: int) -> void:
	AudioManager.play_ui_click()

	var match_info = season_schedule[match_index]
	var opponent_team = match_info.opponent.team_data

	# Start the match via GameManager
	GameManager.start_match(opponent_team, match_info.type, match_info.get("is_home", true), match_info.get("player_team", null))

	# Mark as played
	season_schedule[match_index].played = true

	# Transition to pre-match screen
	get_tree().change_scene_to_file("res://scenes/match/pre_match.tscn")


func _on_prev_month() -> void:
	AudioManager.play_ui_click()
	# Month navigation (simplified - just visual)
	pass


func _on_next_month() -> void:
	AudioManager.play_ui_click()
	# Month navigation (simplified - just visual)
	pass


func _get_current_month() -> String:
	var months = ["January", "February", "March", "April", "May", "June",
				  "July", "August", "September", "October", "November", "December"]
	var month_idx = DesktopManager.game_date.month - 1
	return "%s %d" % [months[month_idx], DesktopManager.game_date.year]


func _month_short(month: int) -> String:
	var months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return months[clampi(month, 1, 12)]
