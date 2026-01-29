extends Control
## CharacterCreation - Player creation screen for new careers

signal character_created(player_name: String, position: String)

const POSITION_DESCRIPTIONS = {
	"GK": "Goalkeeper - Last line of defense. Commands the box and organizes the backline.",
	"CB": "Center Back - Defensive rock. Wins aerial duels and stops attackers.",
	"FB": "Full Back - Speedy defender. Supports attacks down the flanks.",
	"CDM": "Defensive Mid - Shield in front of defense. Breaks up play and distributes.",
	"CM": "Central Mid - Engine of the team. Links defense and attack.",
	"CAM": "Attacking Mid - Creative playmaker. Unlocks defenses with vision.",
	"WNG": "Winger - Pace merchant. Beats defenders and delivers crosses.",
	"ST": "Striker - Goal scorer. Clinical finisher in the box."
}

const POSITION_ORDER = ["GK", "CB", "FB", "CDM", "CM", "CAM", "WNG", "ST"]

@onready var name_input: LineEdit = $MainContainer/ContentContainer/LeftPanel/NameSection/NameInput
@onready var position_container: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/PositionSection/PositionList
@onready var position_description: Label = $MainContainer/ContentContainer/RightPanel/PositionDescription
@onready var stats_container: VBoxContainer = $MainContainer/ContentContainer/RightPanel/StatsPreview/StatsGrid
@onready var overall_label: Label = $MainContainer/ContentContainer/RightPanel/OverallRating
@onready var start_button: Button = $MainContainer/ButtonContainer/StartButton
@onready var back_button: Button = $MainContainer/ButtonContainer/BackButton

var selected_position: String = "CM"
var position_buttons: Dictionary = {}


func _ready() -> void:
	_create_position_buttons()
	_create_stat_labels()
	_update_position_selection("CM")
	_update_start_button()

	name_input.text_changed.connect(_on_name_changed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)

	name_input.grab_focus()


func _create_position_buttons() -> void:
	for pos in POSITION_ORDER:
		var button = Button.new()
		button.text = pos
		button.custom_minimum_size = Vector2(60, 40)
		button.toggle_mode = true
		button.button_group = _get_or_create_button_group()
		button.pressed.connect(_on_position_selected.bind(pos))
		position_container.add_child(button)
		position_buttons[pos] = button

	# Select CM by default
	position_buttons["CM"].button_pressed = true


func _get_or_create_button_group() -> ButtonGroup:
	if position_buttons.is_empty():
		return ButtonGroup.new()
	return position_buttons.values()[0].button_group


func _create_stat_labels() -> void:
	for stat_key in StatSystem.PRIMARY_STATS:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label = Label.new()
		name_label.text = StatSystem.PRIMARY_STATS[stat_key]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(100, 0)

		var value_label = Label.new()
		value_label.name = "Value_" + stat_key
		value_label.text = "50"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size = Vector2(30, 0)

		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(100, 16)
		bar_bg.color = Color(0.2, 0.25, 0.3)

		var bar_fill = ColorRect.new()
		bar_fill.name = "Bar_" + stat_key
		bar_fill.custom_minimum_size = Vector2(50, 16)
		bar_fill.color = _get_stat_color(50)

		var bar_container = Control.new()
		bar_container.custom_minimum_size = Vector2(100, 16)
		bar_container.add_child(bar_bg)
		bar_container.add_child(bar_fill)
		bar_bg.position = Vector2.ZERO
		bar_fill.position = Vector2.ZERO

		hbox.add_child(name_label)
		hbox.add_child(value_label)
		hbox.add_child(bar_container)

		stats_container.add_child(hbox)


func _get_stat_color(value: int) -> Color:
	if value >= 70:
		return Color(0.2, 0.8, 0.3)  # Green
	elif value >= 50:
		return Color(0.9, 0.8, 0.2)  # Yellow
	else:
		return Color(0.8, 0.3, 0.2)  # Red


func _on_position_selected(pos: String) -> void:
	AudioManager.play_ui_click()
	_update_position_selection(pos)


func _update_position_selection(pos: String) -> void:
	selected_position = pos

	# Update description
	position_description.text = POSITION_DESCRIPTIONS.get(pos, "")

	# Calculate and display preview stats
	var preview_stats = _calculate_preview_stats(pos)
	_update_stats_display(preview_stats)

	# Update overall rating
	var overall = StatSystem.calculate_overall(preview_stats, pos)
	overall_label.text = "Overall: %d" % overall


func _calculate_preview_stats(pos: String) -> Dictionary:
	var base = 45
	var weights = StatSystem.POSITION_WEIGHTS.get(pos, StatSystem.POSITION_WEIGHTS["CM"])
	var preview = {}

	for stat_key in StatSystem.PRIMARY_STATS:
		var weight = weights.get(stat_key, 0.5)
		var weighted_base = base + roundi((weight - 0.5) * 10)
		preview[stat_key] = clampi(weighted_base, 30, 65)

	return preview


func _update_stats_display(preview_stats: Dictionary) -> void:
	for stat_key in StatSystem.PRIMARY_STATS:
		var value = preview_stats.get(stat_key, 50)

		# Find the value label and bar
		for child in stats_container.get_children():
			if child is HBoxContainer:
				var value_label = child.get_node_or_null("Value_" + stat_key)
				if value_label:
					value_label.text = str(value)

				# Update bar width
				for subchild in child.get_children():
					if subchild is Control and not subchild is HBoxContainer:
						var bar = subchild.get_node_or_null("Bar_" + stat_key)
						if bar:
							bar.custom_minimum_size.x = value
							bar.color = _get_stat_color(value)


func _on_name_changed(_new_text: String) -> void:
	_update_start_button()


func _update_start_button() -> void:
	var name_valid = name_input.text.strip_edges().length() >= 2
	start_button.disabled = not name_valid


func _on_start_pressed() -> void:
	var player_name = name_input.text.strip_edges()

	if player_name.length() < 2:
		return

	AudioManager.play_ui_confirm()

	# Start the career
	GameManager.start_new_career(player_name, selected_position)

	# Transition to desktop shell
	get_tree().change_scene_to_file("res://scenes/desktop/desktop_shell.tscn")


func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
