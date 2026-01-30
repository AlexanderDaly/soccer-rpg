extends PanelBase
class_name PanelTournamentBracket
## PanelTournamentBracket - Displays knockout tournament bracket with visual connections

const MATCH_WIDTH = 180
const MATCH_HEIGHT = 60
const MATCH_SPACING_V = 20
const ROUND_SPACING_H = 80

const BG_COLOR = Color(0.05, 0.08, 0.12)
const PLAYED_COLOR = Color(0.08, 0.12, 0.18)
const PLAYER_MATCH_COLOR = Color(0.1, 0.2, 0.15)
const WINNER_COLOR = Color(0.2, 0.7, 0.2)
const LOSER_COLOR = Color(0.5, 0.5, 0.5)
const LINE_COLOR = Color(0.3, 0.4, 0.5)

@onready var tournament_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/TournamentHeader/TournamentLabel
@onready var stage_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/TournamentHeader/StageLabel
@onready var bracket_scroll: ScrollContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/BracketScroll
@onready var bracket_container: Control = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/BracketScroll/BracketContainer
@onready var player_status_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/PlayerStatus

var current_tournament: TournamentData = null


func _on_panel_ready() -> void:
	panel_title = "Tournament Bracket"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_refresh_display()


func _refresh_display() -> void:
	current_tournament = SeasonManager.get_current_tournament()

	if not current_tournament:
		_show_no_tournament_message()
		return

	# Update header
	if tournament_label:
		tournament_label.text = current_tournament.name
		tournament_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
		tournament_label.add_theme_font_size_override("font_size", 20)

	if stage_label:
		stage_label.text = current_tournament.get_current_stage_name()
		stage_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))

	# Update player status
	_update_player_status()

	# Build bracket display
	_build_bracket()


func _show_no_tournament_message() -> void:
	if bracket_container:
		for child in bracket_container.get_children():
			child.queue_free()

		var label = Label.new()
		label.text = "No active tournament.\nComplete the league to enter the Prefecture Qualifier."
		label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bracket_container.add_child(label)

	if player_status_label:
		player_status_label.text = ""


func _update_player_status() -> void:
	if not player_status_label or not current_tournament:
		return

	if current_tournament.is_complete:
		if current_tournament.player_won_tournament():
			player_status_label.text = "CHAMPION!"
			player_status_label.add_theme_color_override("font_color", Color(1, 0.84, 0))
		else:
			player_status_label.text = "Eliminated"
			player_status_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	elif current_tournament.player_eliminated:
		player_status_label.text = "Eliminated"
		player_status_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	else:
		var next_match = current_tournament.get_next_player_match()
		if not next_match.is_empty():
			var player_id = current_tournament.get_player_team_id()
			var opponent = next_match.team_b_name if next_match.team_a_id == player_id else next_match.team_a_name
			player_status_label.text = "Next: vs %s" % opponent
			player_status_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
		else:
			player_status_label.text = "Awaiting opponent..."
			player_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func _build_bracket() -> void:
	if not bracket_container:
		return

	for child in bracket_container.get_children():
		child.queue_free()

	# Determine which stages to show based on tournament type
	var stages_to_show: Array[TournamentData.Stage] = []

	match current_tournament.tournament_type:
		TournamentData.TournamentType.PREFECTURE_QUALIFIER:
			stages_to_show = [
				TournamentData.Stage.FIRST_ROUND,
				TournamentData.Stage.QUARTER_FINAL,
				TournamentData.Stage.SEMI_FINAL,
				TournamentData.Stage.FINAL
			]
		TournamentData.TournamentType.NATIONAL_CHAMPIONSHIP:
			stages_to_show = [
				TournamentData.Stage.FIRST_ROUND,
				TournamentData.Stage.SECOND_ROUND,
				TournamentData.Stage.ROUND_OF_16,
				TournamentData.Stage.QUARTER_FINAL,
				TournamentData.Stage.SEMI_FINAL,
				TournamentData.Stage.FINAL
			]

	# Calculate total width needed
	var total_width = stages_to_show.size() * (MATCH_WIDTH + ROUND_SPACING_H)
	bracket_container.custom_minimum_size = Vector2(total_width, 800)

	# Create each round column
	var x_offset = 20
	for stage in stages_to_show:
		var matches = current_tournament.get_matches_for_stage(stage)
		if matches.size() > 0:
			_create_round_column(stage, matches, x_offset)
		x_offset += MATCH_WIDTH + ROUND_SPACING_H


func _create_round_column(stage: TournamentData.Stage, matches: Array[Dictionary], x_offset: int) -> void:
	# Round header
	var header = Label.new()
	header.text = current_tournament.get_stage_name(stage)
	header.position = Vector2(x_offset, 10)
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	bracket_container.add_child(header)

	# Calculate vertical spacing based on number of matches
	var y_start = 50
	var total_height = 700
	var spacing = total_height / maxf(matches.size(), 1)

	for i in range(matches.size()):
		var match_data = matches[i]
		var y_pos = y_start + (i * spacing)
		var match_card = _create_match_card(match_data)
		match_card.position = Vector2(x_offset, y_pos)
		bracket_container.add_child(match_card)


func _create_match_card(match_data: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(MATCH_WIDTH, MATCH_HEIGHT)

	# Determine background color
	var bg_color: Color
	var player_id = current_tournament.get_player_team_id()
	var is_player_match = match_data.team_a_id == player_id or match_data.team_b_id == player_id

	if is_player_match:
		bg_color = PLAYER_MATCH_COLOR
	elif match_data.played:
		bg_color = PLAYED_COLOR
	else:
		bg_color = BG_COLOR

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = LINE_COLOR
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	# Team A
	var team_a_row = _create_team_row(
		match_data.team_a_name,
		match_data.team_a_score if match_data.played else -1,
		match_data.winner_id == match_data.team_a_id,
		match_data.played and match_data.winner_id != match_data.team_a_id,
		match_data.team_a_id == player_id
	)
	vbox.add_child(team_a_row)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	vbox.add_child(sep)

	# Team B
	var team_b_row = _create_team_row(
		match_data.team_b_name,
		match_data.team_b_score if match_data.played else -1,
		match_data.winner_id == match_data.team_b_id,
		match_data.played and match_data.winner_id != match_data.team_b_id,
		match_data.team_b_id == player_id
	)
	vbox.add_child(team_b_row)

	# Penalties indicator
	if match_data.penalties:
		var pen_label = Label.new()
		pen_label.text = "(%d-%d pen)" % [match_data.penalty_score_a, match_data.penalty_score_b]
		pen_label.add_theme_font_size_override("font_size", 10)
		pen_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		pen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(pen_label)
	elif match_data.extra_time:
		var et_label = Label.new()
		et_label.text = "(AET)"
		et_label.add_theme_font_size_override("font_size", 10)
		et_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		et_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(et_label)

	panel.add_child(vbox)
	return panel


func _create_team_row(team_name: String, score: int, is_winner: bool, is_loser: bool, is_player: bool) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	# Team name
	var name_label = Label.new()
	name_label.text = team_name if team_name != "" else "TBD"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(130, 0)

	# Color based on status
	if is_winner:
		name_label.add_theme_color_override("font_color", WINNER_COLOR)
	elif is_loser:
		name_label.add_theme_color_override("font_color", LOSER_COLOR)
	elif is_player:
		name_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.5))
	else:
		name_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	hbox.add_child(name_label)

	# Score
	var score_label = Label.new()
	if score >= 0:
		score_label.text = str(score)
	else:
		score_label.text = "-"
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.custom_minimum_size = Vector2(25, 0)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if is_winner:
		score_label.add_theme_color_override("font_color", WINNER_COLOR)
	elif is_loser:
		score_label.add_theme_color_override("font_color", LOSER_COLOR)
	else:
		score_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))

	hbox.add_child(score_label)

	return hbox
