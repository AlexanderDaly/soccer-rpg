extends PanelBase
class_name PanelSeasonAwards
## PanelSeasonAwards - Displays season awards and leaderboards

const ROW_HEIGHT = 36
const HEADER_COLOR = Color(0.15, 0.25, 0.4)
const PLAYER_ROW_COLOR = Color(0.1, 0.3, 0.15)
const EVEN_ROW_COLOR = Color(0.05, 0.08, 0.12)
const ODD_ROW_COLOR = Color(0.07, 0.1, 0.15)
const GOLD_COLOR = Color(0.85, 0.7, 0.2)
const SILVER_COLOR = Color(0.75, 0.75, 0.8)
const BRONZE_COLOR = Color(0.8, 0.5, 0.2)

@onready var awards_container: HBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/AwardsSection
@onready var leaderboards_container: HBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/LeaderboardsSection
@onready var season_header_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/SeasonHeader


func _on_panel_ready() -> void:
	panel_title = "Season Awards"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_refresh_display()


func _refresh_display() -> void:
	if not SeasonManager.has_active_season():
		_show_no_awards_message()
		return

	var season = SeasonManager.current_season
	if not season or not season.league:
		_show_no_awards_message()
		return

	# Update header
	if season_header_label:
		season_header_label.text = "%s %d Season" % [season.prefecture, season.year]
		season_header_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		season_header_label.add_theme_font_size_override("font_size", 20)

	# Display awards
	_build_awards_section(season.league)

	# Display leaderboards
	_build_leaderboards_section(season.league)


func _show_no_awards_message() -> void:
	if awards_container:
		for child in awards_container.get_children():
			child.queue_free()

		var label = Label.new()
		label.text = "No season data available.\nComplete a league season to see awards."
		label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		awards_container.add_child(label)


func _build_awards_section(league: LeagueData) -> void:
	if not awards_container:
		return

	for child in awards_container.get_children():
		child.queue_free()

	var awards = league.league_awards
	if awards.is_empty() and league.player_stats:
		# Compute awards if not stored yet
		var total_matches = league.player_stats.get_total_matches_in_league(league.teams.size())
		awards = league.player_stats.get_all_awards(total_matches)

	# Golden Boot
	var golden_boot = awards.get("golden_boot", {})
	var boot_card = _create_award_card("Golden Boot", "Top Scorer", golden_boot, "goals")
	awards_container.add_child(boot_card)

	# Top Assister
	var top_assister = awards.get("top_assister", {})
	var assist_card = _create_award_card("Playmaker Award", "Top Assister", top_assister, "assists")
	awards_container.add_child(assist_card)

	# Golden Glove
	var golden_glove = awards.get("golden_glove", {})
	var glove_card = _create_award_card("Golden Glove", "Best Goalkeeper", golden_glove, "clean_sheets")
	awards_container.add_child(glove_card)


func _create_award_card(award_name: String, subtitle: String, winner: Dictionary, stat_key: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 160)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.16)
	style.set_border_width_all(2)
	style.border_color = GOLD_COLOR if not winner.is_empty() else Color(0.2, 0.25, 0.35)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	# Award title
	var title_lbl = Label.new()
	title_lbl.text = award_name
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", GOLD_COLOR)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	# Subtitle
	var sub_lbl = Label.new()
	sub_lbl.text = subtitle
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	if winner.is_empty():
		var no_winner = Label.new()
		no_winner.text = "No winner yet"
		no_winner.add_theme_font_size_override("font_size", 14)
		no_winner.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		no_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_winner)
	else:
		# Winner name
		var name_lbl = Label.new()
		name_lbl.text = winner.get("name", "Unknown")
		name_lbl.add_theme_font_size_override("font_size", 16)

		# Highlight if player
		var player_id = ""
		if GameManager.player_data:
			player_id = GameManager.player_data.id
		var is_player_winner = winner.get("player_id", "") == player_id
		name_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if is_player_winner else Color(0.9, 0.95, 1))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		# Stat value
		var stat_val = winner.get(stat_key, 0)
		var stat_lbl = Label.new()
		stat_lbl.text = "%d %s" % [stat_val, stat_key.replace("_", " ")]
		stat_lbl.add_theme_font_size_override("font_size", 14)
		stat_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stat_lbl)

	return card


func _build_leaderboards_section(league: LeagueData) -> void:
	if not leaderboards_container:
		return

	for child in leaderboards_container.get_children():
		child.queue_free()

	if not league.player_stats:
		return

	var total_matches = league.player_stats.get_total_matches_in_league(league.teams.size())

	# Top Scorers
	var scorers = league.player_stats.get_top_scorers(5, total_matches)
	var scorers_table = _create_leaderboard("Top Scorers", scorers, "goals", "assists")
	leaderboards_container.add_child(scorers_table)

	# Top Assisters
	var assisters = league.player_stats.get_top_assisters(5, total_matches)
	var assisters_table = _create_leaderboard("Top Assisters", assisters, "assists", "goals")
	leaderboards_container.add_child(assisters_table)


func _create_leaderboard(title: String, players: Array, primary_stat: String, secondary_stat: String) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Title
	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	container.add_child(title_lbl)

	# Header row
	var header = _create_leaderboard_row("#", "Player", primary_stat.capitalize(), secondary_stat.capitalize(), HEADER_COLOR, true)
	container.add_child(header)

	# Player rows
	var player_id = ""
	if GameManager.player_data:
		player_id = GameManager.player_data.id

	for i in range(players.size()):
		var p = players[i]
		var is_player = p.get("player_id", "") == player_id
		var bg_color: Color
		if is_player:
			bg_color = PLAYER_ROW_COLOR
		elif i % 2 == 0:
			bg_color = EVEN_ROW_COLOR
		else:
			bg_color = ODD_ROW_COLOR

		var row = _create_leaderboard_row(
			str(i + 1),
			p.get("name", "Unknown"),
			str(p.get(primary_stat, 0)),
			str(p.get(secondary_stat, 0)),
			bg_color,
			false,
			i < 3  # Highlight top 3
		)
		container.add_child(row)

	if players.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No data available"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		container.add_child(empty_lbl)

	return container


func _create_leaderboard_row(pos: String, name: String, primary: String, secondary: String, bg_color: Color, is_header: bool, highlight: bool = false) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	# Position
	var pos_panel = _create_cell(pos, 30, bg_color, is_header)
	if highlight and not is_header:
		var medal_color: Color
		match pos:
			"1":
				medal_color = GOLD_COLOR
			"2":
				medal_color = SILVER_COLOR
			"3":
				medal_color = BRONZE_COLOR
			_:
				medal_color = Color(0.85, 0.9, 0.95)
		pos_panel.get_child(0).add_theme_color_override("font_color", medal_color)
	row.add_child(pos_panel)

	# Name
	row.add_child(_create_cell(name, 180, bg_color, is_header, HORIZONTAL_ALIGNMENT_LEFT))

	# Primary stat
	row.add_child(_create_cell(primary, 50, bg_color, is_header))

	# Secondary stat
	row.add_child(_create_cell(secondary, 50, bg_color, false))

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
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

	if bold:
		label.add_theme_color_override("font_color", Color(1, 1, 1))

	panel.add_child(label)
	return panel
