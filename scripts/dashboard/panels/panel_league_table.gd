extends PanelBase
class_name PanelLeagueTable
## PanelLeagueTable - Displays league standings with player highlight

const ROW_HEIGHT = 40
const HEADER_COLOR = Color(0.15, 0.25, 0.4)
const PLAYER_ROW_COLOR = Color(0.1, 0.3, 0.15)
const EVEN_ROW_COLOR = Color(0.05, 0.08, 0.12)
const ODD_ROW_COLOR = Color(0.07, 0.1, 0.15)
const QUALIFYING_COLOR = Color(0.1, 0.25, 0.1)

@onready var standings_container: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/StandingsContainer
@onready var competition_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/CompetitionHeader/CompetitionLabel
@onready var matchday_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/CompetitionHeader/MatchdayLabel
@onready var next_match_container: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/NextMatchSection/NextMatchInfo
@onready var form_legend: HBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/FormLegend


func _on_panel_ready() -> void:
	panel_title = "League Table"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_refresh_display()


func _refresh_display() -> void:
	if not SeasonManager.has_active_season():
		_show_no_season_message()
		return

	var season = SeasonManager.current_season
	if not season or not season.league:
		_show_no_season_message()
		return

	# Update competition header
	if competition_label:
		competition_label.text = season.league.name
		competition_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		competition_label.add_theme_font_size_override("font_size", 20)

	if matchday_label:
		matchday_label.text = "Matchday %d" % season.league.current_matchday
		matchday_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))

	# Build standings table
	_build_standings_table(season.league)

	# Show next fixture
	_show_next_fixture(season.league)

	# Setup form legend
	_setup_form_legend()


func _show_no_season_message() -> void:
	if standings_container:
		for child in standings_container.get_children():
			child.queue_free()

		var label = Label.new()
		label.text = "No active season.\nStart a new career to begin your season."
		label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		standings_container.add_child(label)


func _build_standings_table(league: LeagueData) -> void:
	if not standings_container:
		return

	# Clear existing
	for child in standings_container.get_children():
		child.queue_free()

	# Create header row
	var header = _create_header_row()
	standings_container.add_child(header)

	# Get sorted standings
	var standings = league.get_sorted_standings()
	var player_team_id = league.get_player_team_id()

	# Create rows for each team
	for i in range(standings.size()):
		var team_stats = standings[i]
		var is_player = team_stats.team_id == player_team_id
		var is_qualifying = i < 2  # Top 2 qualify
		var row = _create_team_row(i + 1, team_stats, is_player, is_qualifying, i % 2 == 0)
		standings_container.add_child(row)


func _create_header_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var columns = [
		{"text": "#", "width": 40},
		{"text": "Team", "width": 200},
		{"text": "P", "width": 40},
		{"text": "W", "width": 40},
		{"text": "D", "width": 40},
		{"text": "L", "width": 40},
		{"text": "GF", "width": 45},
		{"text": "GA", "width": 45},
		{"text": "GD", "width": 50},
		{"text": "Pts", "width": 50},
		{"text": "Form", "width": 120}
	]

	for col in columns:
		var cell = _create_cell(col.text, col.width, HEADER_COLOR, true)
		row.add_child(cell)

	return row


func _create_team_row(position: int, stats: Dictionary, is_player: bool, is_qualifying: bool, is_even: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var bg_color: Color
	if is_player:
		bg_color = PLAYER_ROW_COLOR
	elif is_qualifying:
		bg_color = QUALIFYING_COLOR
	elif is_even:
		bg_color = EVEN_ROW_COLOR
	else:
		bg_color = ODD_ROW_COLOR

	# Position
	row.add_child(_create_cell(str(position), 40, bg_color))

	# Team name (highlight player)
	var team_name = stats.team_name
	if is_player:
		team_name = ">>> " + team_name
	row.add_child(_create_cell(team_name, 200, bg_color, false, HORIZONTAL_ALIGNMENT_LEFT))

	# Stats
	row.add_child(_create_cell(str(stats.played), 40, bg_color))
	row.add_child(_create_cell(str(stats.won), 40, bg_color))
	row.add_child(_create_cell(str(stats.drawn), 40, bg_color))
	row.add_child(_create_cell(str(stats.lost), 40, bg_color))
	row.add_child(_create_cell(str(stats.gf), 45, bg_color))
	row.add_child(_create_cell(str(stats.ga), 45, bg_color))

	# Goal difference with color
	var gd_str = str(stats.gd) if stats.gd <= 0 else "+%d" % stats.gd
	var gd_cell = _create_cell(gd_str, 50, bg_color)
	if stats.gd > 0:
		gd_cell.get_child(0).add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	elif stats.gd < 0:
		gd_cell.get_child(0).add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	row.add_child(gd_cell)

	# Points (bold)
	var pts_cell = _create_cell(str(stats.points), 50, bg_color, true)
	row.add_child(pts_cell)

	# Form
	var form_cell = _create_form_cell(stats.form, bg_color)
	row.add_child(form_cell)

	return row


func _create_cell(text: String, width: int, bg_color: Color, bold: bool = false, alignment: int = HORIZONTAL_ALIGNMENT_CENTER) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, ROW_HEIGHT)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.25, 0.35)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

	if bold:
		# Make text appear bolder via color
		label.add_theme_color_override("font_color", Color(1, 1, 1))

	panel.add_child(label)
	return panel


func _create_form_cell(form: Array, bg_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, ROW_HEIGHT)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.25, 0.35)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)

	# Show last 5 results
	for i in range(mini(form.size(), 5)):
		var result = form[form.size() - 1 - i]  # Most recent first
		var badge = ColorRect.new()
		badge.custom_minimum_size = Vector2(18, 18)

		match result:
			"W":
				badge.color = Color(0.2, 0.7, 0.2)
			"D":
				badge.color = Color(0.7, 0.7, 0.2)
			"L":
				badge.color = Color(0.7, 0.2, 0.2)

		hbox.add_child(badge)

	panel.add_child(hbox)
	return panel


func _show_next_fixture(league: LeagueData) -> void:
	if not next_match_container:
		return

	for child in next_match_container.get_children():
		child.queue_free()

	var next_fixture = league.get_next_player_fixture()
	if next_fixture.is_empty():
		var label = Label.new()
		label.text = "Season complete"
		label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		next_match_container.add_child(label)
		return

	# Create next match display
	var player_id = league.get_player_team_id()
	var is_home = next_fixture.home_id == player_id

	var opponent_name = next_fixture.away_team_name if is_home else next_fixture.home_team_name
	var venue = "HOME" if is_home else "AWAY"

	var match_label = Label.new()
	match_label.text = "vs %s (%s)" % [opponent_name, venue]
	match_label.add_theme_font_size_override("font_size", 16)
	match_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	next_match_container.add_child(match_label)

	var matchday_info = Label.new()
	matchday_info.text = "Matchday %d" % next_fixture.matchday
	matchday_info.add_theme_font_size_override("font_size", 14)
	matchday_info.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	next_match_container.add_child(matchday_info)


func _setup_form_legend() -> void:
	if not form_legend:
		return

	for child in form_legend.get_children():
		child.queue_free()

	var legend_items = [
		{"color": Color(0.2, 0.7, 0.2), "text": "Win"},
		{"color": Color(0.7, 0.7, 0.2), "text": "Draw"},
		{"color": Color(0.7, 0.2, 0.2), "text": "Loss"}
	]

	for item in legend_items:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var badge = ColorRect.new()
		badge.custom_minimum_size = Vector2(14, 14)
		badge.color = item.color
		hbox.add_child(badge)

		var label = Label.new()
		label.text = item.text
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		hbox.add_child(label)

		form_legend.add_child(hbox)

		# Add spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(20, 0)
		form_legend.add_child(spacer)

	# Qualifying position note
	var qual_note = Label.new()
	qual_note.text = "| Top 2 qualify for Prefecture Qualifier"
	qual_note.add_theme_font_size_override("font_size", 12)
	qual_note.add_theme_color_override("font_color", Color(0.4, 0.6, 0.4))
	form_legend.add_child(qual_note)
