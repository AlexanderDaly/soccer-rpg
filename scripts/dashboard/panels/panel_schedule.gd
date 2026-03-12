extends PanelBase
class_name PanelSchedule
## PanelSchedule - Calendar panel for match schedule (season-aware)

@onready var month_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HeaderSection/MonthLabel
@onready var prev_button: Button = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HeaderSection/PrevButton
@onready var next_button: Button = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HeaderSection/NextButton
@onready var calendar_grid: GridContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/CalendarGrid
@onready var upcoming_list: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/UpcomingSection/UpcomingList

var season_schedule: Array[Dictionary] = []
var next_match_index: int = 0


func _on_panel_ready() -> void:
	panel_title = "Schedule"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	if prev_button:
		prev_button.pressed.connect(_on_prev_month)
	if next_button:
		next_button.pressed.connect(_on_next_month)

	_refresh_schedule()
	_setup_calendar()
	_setup_upcoming_matches()


func _refresh_schedule() -> void:
	season_schedule = SeasonManager.get_upcoming_fixtures(-1, true)
	next_match_index = -1
	for i in range(season_schedule.size()):
		if not season_schedule[i].get("played", false):
			next_match_index = i
			break


func _load_season_schedule() -> void:
	var season = SeasonManager.current_season
	if not season:
		return

	var competition = SeasonManager.get_current_competition_name()
	var match_type = SeasonManager.get_match_type()

	match season.current_phase:
		SeasonData.Phase.LEAGUE:
			_load_league_fixtures(season, competition, match_type)
		SeasonData.Phase.QUALIFIERS:
			_load_tournament_fixtures(season.prefecture_qualifier, competition, match_type)
		SeasonData.Phase.NATIONALS:
			_load_tournament_fixtures(season.national_championship, competition, match_type)


func _load_league_fixtures(season: SeasonData, competition: String, match_type: String) -> void:
	if not season.league:
		return

	var player_id = season.league.get_player_team_id()
	var all_fixtures = season.league.get_all_player_fixtures()

	for fixture in all_fixtures:
		var opponent_id: String
		var opponent_name: String
		var is_home: bool

		if fixture.home_id == player_id:
			opponent_id = fixture.away_id
			opponent_name = fixture.away_team_name
			is_home = true
		else:
			opponent_id = fixture.home_id
			opponent_name = fixture.home_team_name
			is_home = false

		var opponent_team = season.league.get_team_by_id(opponent_id)
		var match_date = fixture.get("match_date", {"year": 2024, "month": 4, "day": 1})

		season_schedule.append({
			"matchday": fixture.matchday,
			"match_date": match_date,
			"opponent": {
				"name": opponent_name,
				"team_data": opponent_team
			},
			"is_home": is_home,
			"type": match_type,
			"competition": competition,
			"played": fixture.played,
			"result": _get_fixture_result(fixture, player_id) if fixture.played else "",
			"from_season": true
		})


func _load_tournament_fixtures(tournament: TournamentData, competition: String, match_type: String) -> void:
	if not tournament:
		return

	var next_match = tournament.get_next_player_match()
	if next_match.is_empty():
		return

	var player_id = tournament.get_player_team_id()
	var opponent_name: String
	var opponent_team: TeamData

	if next_match.team_a_id == player_id:
		opponent_name = next_match.team_b_name
		opponent_team = tournament.get_team_by_id(next_match.team_b_id)
	else:
		opponent_name = next_match.team_a_name
		opponent_team = tournament.get_team_by_id(next_match.team_a_id)

	if opponent_team:
		season_schedule.append({
			"matchday": 0,
			"match_date": {"year": DesktopManager.game_date.year, "month": DesktopManager.game_date.month, "day": DesktopManager.game_date.day + 3},
			"opponent": {
				"name": opponent_name,
				"team_data": opponent_team
			},
			"is_home": true,
			"type": match_type,
			"competition": competition,
			"played": false,
			"result": "",
			"from_season": true
		})


func _get_fixture_result(fixture: Dictionary, player_id: String) -> String:
	var player_score: int
	var opponent_score: int

	if fixture.home_id == player_id:
		player_score = fixture.home_score
		opponent_score = fixture.away_score
	else:
		player_score = fixture.away_score
		opponent_score = fixture.home_score

	if player_score > opponent_score:
		return "W %d-%d" % [player_score, opponent_score]
	elif player_score < opponent_score:
		return "L %d-%d" % [player_score, opponent_score]
	else:
		return "D %d-%d" % [player_score, opponent_score]


func _generate_legacy_schedule() -> void:
	var phase = GameManager.current_career_phase
	var num_matches = _get_matches_for_phase(phase)
	var opponents = _generate_opponents(phase, num_matches)

	var current_year = DesktopManager.game_date.year
	var current_month = DesktopManager.game_date.month
	var current_day = DesktopManager.game_date.day
	var match_day = current_day + 3
	var match_month = current_month

	for i in range(num_matches):
		var match_type = _get_match_type(phase, i, num_matches)

		# Handle month overflow
		if match_day > 30:
			match_day = match_day - 30
			match_month += 1
			if match_month > 12:
				match_month = 1
				current_year += 1

		season_schedule.append({
			"matchday": i + 1,
			"match_date": {"year": current_year, "month": match_month, "day": match_day},
			"opponent": opponents[i],
			"is_home": randf() > 0.5,
			"type": match_type,
			"played": false,
			"result": "",
			"from_season": false
		})

		match_day += randi_range(5, 8)


func _get_matches_for_phase(phase: GameManager.CareerPhase) -> int:
	match phase:
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
	if month_label:
		month_label.text = _get_current_month()
		month_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		month_label.add_theme_font_size_override("font_size", 18)

	if not calendar_grid:
		return

	# Clear and rebuild calendar
	for child in calendar_grid.get_children():
		child.queue_free()

	# Get match days for current month
	var current_month = DesktopManager.game_date.month
	var current_year = DesktopManager.game_date.year
	var match_days: Array[int] = []
	var played_days: Array[int] = []

	for match_info in season_schedule:
		var match_date = match_info.get("match_date", {})
		if match_date.get("month", 0) == current_month and match_date.get("year", 0) == current_year:
			if match_info.played:
				played_days.append(match_date.day)
			else:
				match_days.append(match_date.day)

	# Add day numbers
	var current_day = DesktopManager.game_date.day
	for i in range(1, 31):
		var day_btn = Button.new()
		day_btn.text = str(i)
		day_btn.custom_minimum_size = Vector2(40, 40)

		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(4)
		style.set_content_margin_all(4)

		if i == current_day:
			style.bg_color = Color(0, 0.5, 0.25)
			style.border_color = Color(0, 0.8, 0.4)
			style.set_border_width_all(2)
		elif i in match_days:
			style.bg_color = Color(0.4, 0.1, 0.1)
			day_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
			day_btn.tooltip_text = "Match Day!"
		elif i in played_days:
			style.bg_color = Color(0.15, 0.2, 0.15)
			day_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
			day_btn.tooltip_text = "Played"
		else:
			style.bg_color = Color(0.08, 0.12, 0.2)

		day_btn.add_theme_stylebox_override("normal", style)
		day_btn.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

		calendar_grid.add_child(day_btn)


func _setup_upcoming_matches() -> void:
	if not upcoming_list:
		return

	# Clear existing
	for child in upcoming_list.get_children():
		child.queue_free()

	# Add competition header if using season system
	if season_schedule.size() > 0 and season_schedule[0].get("from_season", false):
		var competition = season_schedule[0].get("competition", "")
		if competition != "":
			var comp_label = Label.new()
			comp_label.text = competition
			comp_label.add_theme_font_size_override("font_size", 16)
			comp_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5))
			upcoming_list.add_child(comp_label)

			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 8)
			upcoming_list.add_child(spacer)

	# Show recent results first (last 2 played matches)
	var played_matches: Array[Dictionary] = []
	for match_info in season_schedule:
		if match_info.played:
			played_matches.append(match_info)

	if played_matches.size() > 0:
		var results_label = Label.new()
		results_label.text = "Recent Results"
		results_label.add_theme_font_size_override("font_size", 12)
		results_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		upcoming_list.add_child(results_label)

		var start_idx = maxi(0, played_matches.size() - 2)
		for i in range(start_idx, played_matches.size()):
			var match_info = played_matches[i]
			var result_row = _create_result_row(match_info)
			upcoming_list.add_child(result_row)

		var divider = HSeparator.new()
		divider.add_theme_constant_override("separation", 8)
		upcoming_list.add_child(divider)

	# Show upcoming matches
	var upcoming_label = Label.new()
	upcoming_label.text = "Upcoming Fixtures"
	upcoming_label.add_theme_font_size_override("font_size", 12)
	upcoming_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	upcoming_list.add_child(upcoming_label)

	var upcoming_count = 0
	for i in range(season_schedule.size()):
		var match_info = season_schedule[i]
		if match_info.played:
			continue

		upcoming_count += 1
		if upcoming_count > 5:
			break

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		# Date label
		var date_label = Label.new()
		var match_date = match_info.get("match_date", {})
		date_label.text = _format_date(match_date)
		date_label.custom_minimum_size = Vector2(55, 0)
		date_label.add_theme_font_size_override("font_size", 13)
		date_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))

		# Matchday label
		var md_label = Label.new()
		var matchday = match_info.get("matchday", 0)
		if matchday > 0:
			md_label.text = "MD%d" % matchday
		else:
			md_label.text = ""
		md_label.custom_minimum_size = Vector2(35, 0)
		md_label.add_theme_font_size_override("font_size", 11)
		md_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

		# Home/Away indicator
		var venue_label = Label.new()
		venue_label.text = "(H)" if match_info.get("is_home", true) else "(A)"
		venue_label.custom_minimum_size = Vector2(25, 0)
		venue_label.add_theme_font_size_override("font_size", 12)
		venue_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))

		# Opponent name
		var opponent_label = Label.new()
		opponent_label.text = match_info.opponent.name
		opponent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opponent_label.add_theme_font_size_override("font_size", 14)
		opponent_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		opponent_label.clip_text = true

		hbox.add_child(date_label)
		hbox.add_child(md_label)
		hbox.add_child(venue_label)
		hbox.add_child(opponent_label)

		# Play button for next match
		if upcoming_count == 1:
			var play_btn = Button.new()
			play_btn.text = "PLAY"
			play_btn.custom_minimum_size = Vector2(55, 28)
			play_btn.pressed.connect(_on_play_match.bind(i))

			var style = StyleBoxFlat.new()
			style.bg_color = Color(0, 0.6, 0.3)
			style.set_border_width_all(1)
			style.border_color = Color(0, 0.8, 0.4)
			style.set_corner_radius_all(4)
			play_btn.add_theme_stylebox_override("normal", style)
			play_btn.add_theme_color_override("font_color", Color(1, 1, 1))

			hbox.add_child(play_btn)
			next_match_index = i

		upcoming_list.add_child(hbox)

	if upcoming_count == 0:
		var no_matches = Label.new()
		if SeasonManager.has_active_season():
			var season = SeasonManager.current_season
			if season.current_phase == SeasonData.Phase.POST_SEASON:
				no_matches.text = "Season complete!\nCheck your milestones."
			else:
				no_matches.text = "No upcoming matches."
		else:
			no_matches.text = "No upcoming matches.\nSeason complete!"
		no_matches.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		upcoming_list.add_child(no_matches)


func _create_result_row(match_info: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Date
	var date_label = Label.new()
	var match_date = match_info.get("match_date", {})
	date_label.text = _format_date(match_date)
	date_label.custom_minimum_size = Vector2(55, 0)
	date_label.add_theme_font_size_override("font_size", 12)
	date_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

	# Venue
	var venue_label = Label.new()
	venue_label.text = "(H)" if match_info.get("is_home", true) else "(A)"
	venue_label.custom_minimum_size = Vector2(25, 0)
	venue_label.add_theme_font_size_override("font_size", 11)
	venue_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))

	# Opponent
	var opponent_label = Label.new()
	opponent_label.text = match_info.opponent.name
	opponent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opponent_label.add_theme_font_size_override("font_size", 13)
	opponent_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	opponent_label.clip_text = true

	# Result
	var result_label = Label.new()
	var result = match_info.get("result", "")
	result_label.text = result
	result_label.custom_minimum_size = Vector2(50, 0)
	result_label.add_theme_font_size_override("font_size", 13)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if result.begins_with("W"):
		result_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	elif result.begins_with("L"):
		result_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	else:
		result_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.3))

	hbox.add_child(date_label)
	hbox.add_child(venue_label)
	hbox.add_child(opponent_label)
	hbox.add_child(result_label)

	return hbox


func _format_date(date: Dictionary) -> String:
	if date.is_empty():
		return "TBD"
	var months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month = date.get("month", 1)
	var day = date.get("day", 1)
	return "%s %d" % [months[month], day]


func _get_match_type_display(match_type: String) -> String:
	match match_type:
		"league":
			return "League"
		"cup":
			return "Cup"
		"qualifier":
			return "Qualifier"
		"prefecture_qualifier":
			return "Pref. Qualifier"
		"national_championship":
			return "Nationals"
		"world_cup":
			return "World Cup"
		"world_cup_final":
			return "WC Final"
		_:
			return match_type.replace("_", " ").capitalize()


func _on_play_match(match_index: int) -> void:
	AudioManager.play_ui_confirm()

	var match_info = season_schedule[match_index]
	var opponent_team = match_info.opponent.team_data
	var is_home = match_info.get("is_home", true)

	GameManager.start_match(opponent_team, match_info.type, is_home, match_info.get("player_team", null))
	season_schedule[match_index].played = true

	close()
	get_tree().change_scene_to_file("res://scenes/match/pre_match.tscn")


func _on_prev_month() -> void:
	AudioManager.play_ui_click()


func _on_next_month() -> void:
	AudioManager.play_ui_click()


func _get_current_month() -> String:
	var months = ["January", "February", "March", "April", "May", "June",
				  "July", "August", "September", "October", "November", "December"]
	var month_idx = DesktopManager.game_date.month - 1
	return "%s %d" % [months[month_idx], DesktopManager.game_date.year]
