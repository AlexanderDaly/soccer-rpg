extends Control
## CharacterCreation - Player creation screen for new careers

signal character_created(player_name: String, position: String)

const NATIONALITIES = {
	# Major soccer nations - alphabetical by name
	"ALG": "Algeria", "ARG": "Argentina", "AUS": "Australia",
	"AUT": "Austria", "BEL": "Belgium", "BRA": "Brazil",
	"CMR": "Cameroon", "CAN": "Canada", "CHI": "Chile",
	"CHN": "China", "COL": "Colombia", "CRC": "Costa Rica",
	"CRO": "Croatia", "CZE": "Czech Republic", "DEN": "Denmark",
	"ECU": "Ecuador", "EGY": "Egypt", "ENG": "England",
	"FIN": "Finland", "FRA": "France", "GER": "Germany",
	"GHA": "Ghana", "GRE": "Greece", "HUN": "Hungary",
	"ISL": "Iceland", "IND": "India", "IDN": "Indonesia",
	"IRN": "Iran", "IRQ": "Iraq", "IRL": "Ireland",
	"ISR": "Israel", "ITA": "Italy", "CIV": "Ivory Coast",
	"JAM": "Jamaica", "JPN": "Japan", "KEN": "Kenya",
	"KOR": "Korea Republic", "MEX": "Mexico", "MAR": "Morocco",
	"NED": "Netherlands", "NZL": "New Zealand", "NGA": "Nigeria",
	"NIR": "Northern Ireland", "NOR": "Norway", "PAN": "Panama",
	"PAR": "Paraguay", "PER": "Peru", "PHI": "Philippines",
	"POL": "Poland", "POR": "Portugal", "QAT": "Qatar",
	"ROU": "Romania", "RUS": "Russia", "KSA": "Saudi Arabia",
	"SCO": "Scotland", "SEN": "Senegal", "SRB": "Serbia",
	"SVK": "Slovakia", "SVN": "Slovenia", "RSA": "South Africa",
	"ESP": "Spain", "SWE": "Sweden", "SUI": "Switzerland",
	"THA": "Thailand", "TUN": "Tunisia", "TUR": "Turkey",
	"UKR": "Ukraine", "UAE": "United Arab Emirates", "USA": "United States",
	"URU": "Uruguay", "VEN": "Venezuela", "VNM": "Vietnam",
	"WAL": "Wales"
}

# Reverse lookup: name -> code
var _nationalities_by_name: Dictionary = {}

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

# Position zones on field (normalized 0-1 coordinates, origin top-left)
# Format: {"center": Vector2, "size": Vector2}
const POSITION_ZONES = {
	"GK": {"center": Vector2(0.5, 0.92), "size": Vector2(0.2, 0.12)},
	"CB": {"center": Vector2(0.5, 0.78), "size": Vector2(0.35, 0.12)},
	"FB": {"center": Vector2(0.15, 0.70), "size": Vector2(0.18, 0.15)},  # Shows both sides
	"CDM": {"center": Vector2(0.5, 0.60), "size": Vector2(0.3, 0.12)},
	"CM": {"center": Vector2(0.5, 0.48), "size": Vector2(0.35, 0.14)},
	"CAM": {"center": Vector2(0.5, 0.35), "size": Vector2(0.3, 0.12)},
	"WNG": {"center": Vector2(0.12, 0.28), "size": Vector2(0.16, 0.18)},  # Shows both sides
	"ST": {"center": Vector2(0.5, 0.15), "size": Vector2(0.25, 0.14)}
}

# Stat tooltips explaining what each stat affects
const STAT_TOOLTIPS = {
	"SPD": "Pace - Affects sprint speed and acceleration. Essential for wingers and fullbacks.",
	"STA": "Stamina - Determines how long you can maintain high performance. Key for midfielders.",
	"TEC": "Technical - Ball control, first touch, and dribbling ability.",
	"PAS": "Passing - Pass accuracy, weight, and vision for through balls.",
	"SHO": "Shooting - Shot power, accuracy, and finishing ability.",
	"DEF": "Defending - Tackling, interceptions, and marking ability.",
	"PHY": "Physical - Strength in challenges, aerial duels, and holding off opponents.",
	"MEN": "Mental - Composure, decision-making, and performance under pressure."
}

const APPEARANCE_OPTIONS = {
	"hair_color": ["Black", "Brown", "Blonde", "Red", "Blue", "White", "Green"],
	"hair_style": ["Short", "Medium", "Long", "Spiky", "Slicked", "Messy", "Braided"],
	"eye_color": ["Brown", "Blue", "Green", "Hazel", "Gray", "Amber", "Red"],
	"skin_tone": ["Fair", "Light", "Medium", "Tan", "Dark", "Deep"],
	"height": ["Short", "Average", "Tall"],
	"build": ["Lean", "Athletic", "Muscular", "Stocky"]
}

const PERSONALITY_TRAITS = {
	"leader": "Natural captain who boosts team morale",
	"hot_headed": "Plays with passion but may pick up cards",
	"professional": "Steady performer, rarely affected by pressure",
	"fan_favorite": "Loved by supporters, boosted by home crowds",
	"introvert": "Quiet but focused, excels in training",
	"showboat": "Loves flair, attempts risky plays",
	"workhorse": "High stamina, never stops running",
	"clinical": "Composed in big moments, clutch performer",
	"ambitious": "Driven to succeed, pushes for bigger clubs",
	"loyal": "Values team bonds, resists transfers"
}

const MAX_TRAITS = 2

@onready var name_input: LineEdit = $MainContainer/ContentContainer/LeftPanel/NameSection/NameInput
@onready var name_hint: Label = $MainContainer/ContentContainer/LeftPanel/NameSection/NameHint
@onready var nationality_section: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/NationalitySection
@onready var foot_container: HBoxContainer = $MainContainer/ContentContainer/LeftPanel/DominantFootSection/DominantFootContainer
@onready var traits_container: VBoxContainer = $MainContainer/ContentContainer/CenterPanel/TraitsSection/TraitsScroll/TraitsList
@onready var traits_hint: Label = $MainContainer/ContentContainer/CenterPanel/TraitsSection/TraitsHint
@onready var position_container: VBoxContainer = $MainContainer/ContentContainer/LeftPanel/PositionSection/PositionList
@onready var appearance_grid: GridContainer = $MainContainer/ContentContainer/CenterPanel/AppearanceGrid
@onready var position_description: Label = $MainContainer/ContentContainer/RightPanel/PositionDescription
@onready var stats_container: VBoxContainer = $MainContainer/ContentContainer/RightPanel/StatsPreview/StatsGrid
@onready var overall_label: Label = $MainContainer/ContentContainer/RightPanel/OverallRating
@onready var start_button: Button = $MainContainer/ButtonContainer/StartButton
@onready var back_button: Button = $MainContainer/ButtonContainer/BackButton
@onready var randomize_button: Button = $MainContainer/ContentContainer/CenterPanel/AppearanceHeader/RandomizeButton

# Confirmation dialog nodes (created dynamically)
var confirmation_dialog: Control
var confirm_button: Button
var cancel_button: Button
var summary_container: VBoxContainer

# Stat bar references for animation
var stat_bars: Dictionary = {}  # stat_key -> ColorRect
var stat_value_labels: Dictionary = {}  # stat_key -> Label

# Position field diagram
var field_diagram: Control
var position_highlight: ColorRect
var position_highlight_mirror: ColorRect  # For FB/WNG showing both sides

# Keyboard navigation
var current_section: int = 0  # 0=Name, 1=Position, 2=Appearance, 3=Traits
const SECTION_COUNT = 4

var selected_position: String = "CM"
var selected_nationality: String = "USA"
var selected_dominant_foot: String = "right"
var selected_traits: Array[String] = []
var position_buttons: Dictionary = {}
var appearance_buttons: Dictionary = {}
var foot_buttons: Dictionary = {}
var trait_checkboxes: Dictionary = {}
var nationality_input: LineEdit
var nationality_list: ItemList
var nationality_flag: TextureRect
var flag_textures: Dictionary = {}  # code -> Texture2D
var selected_appearance: Dictionary = {
	"hair_color": "black",
	"hair_style": "short",
	"eye_color": "brown",
	"skin_tone": "medium",
	"height": "average",
	"build": "athletic"
}


func _ready() -> void:
	_init_nationality_lookup()
	_create_nationality_selector()
	_setup_foot_buttons()
	_create_position_buttons()
	_create_appearance_selectors()
	_create_trait_selectors()
	_create_stat_labels()
	_create_field_diagram()
	_create_confirmation_dialog()
	_update_position_selection("CM")
	_update_name_validation()

	name_input.text_changed.connect(_on_name_changed)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	randomize_button.pressed.connect(_on_randomize_pressed)

	name_input.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# Don't handle shortcuts when confirmation dialog is open
	if confirmation_dialog and confirmation_dialog.visible:
		if event.keycode == KEY_ESCAPE:
			_on_cancel_confirmation()
			get_viewport().set_input_as_handled()
		return

	match event.keycode:
		KEY_ESCAPE:
			_on_back_pressed()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if not start_button.disabled:
				_on_start_pressed()
				get_viewport().set_input_as_handled()
		KEY_TAB:
			if event.shift_pressed:
				_navigate_section(-1)
			else:
				_navigate_section(1)
			get_viewport().set_input_as_handled()
		KEY_UP:
			if _is_position_focused():
				_navigate_position(-1)
				get_viewport().set_input_as_handled()
		KEY_DOWN:
			if _is_position_focused():
				_navigate_position(1)
				get_viewport().set_input_as_handled()


func _is_position_focused() -> bool:
	var focused = get_viewport().gui_get_focus_owner()
	return focused in position_buttons.values()


func _navigate_section(direction: int) -> void:
	current_section = wrapi(current_section + direction, 0, SECTION_COUNT)
	match current_section:
		0:
			name_input.grab_focus()
		1:
			position_buttons[selected_position].grab_focus()
		2:
			appearance_buttons.values()[0].grab_focus()
		3:
			trait_checkboxes.values()[0].grab_focus()


func _navigate_position(direction: int) -> void:
	var current_index = POSITION_ORDER.find(selected_position)
	var new_index = wrapi(current_index + direction, 0, POSITION_ORDER.size())
	var new_position = POSITION_ORDER[new_index]
	position_buttons[new_position].button_pressed = true
	position_buttons[new_position].grab_focus()
	_on_position_selected(new_position)


func _init_nationality_lookup() -> void:
	for code in NATIONALITIES:
		_nationalities_by_name[NATIONALITIES[code]] = code
	_preload_flag_textures()


func _preload_flag_textures() -> void:
	for code in NATIONALITIES:
		var flag_path = "res://assets/flags/%s.svg" % code
		if ResourceLoader.exists(flag_path):
			flag_textures[code] = load(flag_path)


func _get_flag_texture(code: String) -> Texture2D:
	if code in flag_textures:
		return flag_textures[code]
	return null


func _create_nationality_selector() -> void:
	# Create HBox container for flag + input
	var hbox = HBoxContainer.new()
	hbox.name = "NationalityHBox"
	hbox.add_theme_constant_override("separation", 10)
	nationality_section.add_child(hbox)

	# Create flag display
	nationality_flag = TextureRect.new()
	nationality_flag.name = "NationalityFlag"
	nationality_flag.custom_minimum_size = Vector2(45, 30)
	nationality_flag.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	nationality_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var initial_flag = _get_flag_texture(selected_nationality)
	if initial_flag:
		nationality_flag.texture = initial_flag
	hbox.add_child(nationality_flag)

	# Create LineEdit for typing/searching
	nationality_input = LineEdit.new()
	nationality_input.name = "NationalityInput"
	nationality_input.custom_minimum_size = Vector2(0, 45)
	nationality_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nationality_input.placeholder_text = "Search country..."
	nationality_input.text = "%s (%s)" % [NATIONALITIES[selected_nationality], selected_nationality]
	hbox.add_child(nationality_input)

	# Create ItemList for dropdown with icons
	nationality_list = ItemList.new()
	nationality_list.name = "NationalityList"
	nationality_list.custom_minimum_size = Vector2(0, 200)
	nationality_list.max_text_lines = 1
	nationality_list.visible = false
	nationality_list.z_index = 10
	nationality_list.icon_mode = ItemList.ICON_MODE_LEFT
	nationality_list.fixed_icon_size = Vector2(32, 24)
	nationality_section.add_child(nationality_list)

	# Connect signals
	nationality_input.text_changed.connect(_on_nationality_search_changed)
	nationality_input.focus_entered.connect(_on_nationality_focus_entered)
	nationality_input.focus_exited.connect(_on_nationality_focus_exited)
	nationality_list.item_selected.connect(_on_nationality_item_selected)

	# Populate full list initially
	_populate_nationality_list("")


func _populate_nationality_list(search_text: String) -> void:
	nationality_list.clear()

	# Get sorted country names
	var country_names = _nationalities_by_name.keys()
	country_names.sort()

	var search_lower = search_text.to_lower()

	for country_name in country_names:
		var code = _nationalities_by_name[country_name]
		var display_text = "%s (%s)" % [country_name, code]

		# Filter by search text
		if search_lower.is_empty() or country_name.to_lower().contains(search_lower) or code.to_lower().contains(search_lower):
			var flag_icon = _get_flag_texture(code)
			if flag_icon:
				nationality_list.add_item(display_text, flag_icon)
			else:
				nationality_list.add_item(display_text)


func _on_nationality_search_changed(new_text: String) -> void:
	_populate_nationality_list(new_text)
	nationality_list.visible = true


func _on_nationality_focus_entered() -> void:
	nationality_list.visible = true
	# Select all text for easy replacement
	nationality_input.select_all()


func _on_nationality_focus_exited() -> void:
	# Delay hiding to allow click on list to register
	await get_tree().create_timer(0.15).timeout
	nationality_list.visible = false
	# Validate and reset to current selection
	_validate_nationality_selection()


func _validate_nationality_selection() -> void:
	# Reset input to show current valid selection
	nationality_input.text = "%s (%s)" % [NATIONALITIES[selected_nationality], selected_nationality]
	_update_nationality_flag()


func _on_nationality_item_selected(index: int) -> void:
	var item_text = nationality_list.get_item_text(index)
	# Parse "Country Name (CODE)" format
	var parts = item_text.rsplit(" (", true, 1)
	if parts.size() == 2:
		var country_name = parts[0]
		var code = parts[1].trim_suffix(")")
		if code in NATIONALITIES:
			selected_nationality = code
			nationality_input.text = item_text
			_update_nationality_flag()
			AudioManager.play_ui_click()

	nationality_list.visible = false
	nationality_input.release_focus()


func _update_nationality_flag() -> void:
	if nationality_flag:
		var flag_texture = _get_flag_texture(selected_nationality)
		if flag_texture:
			nationality_flag.texture = flag_texture


func _setup_foot_buttons() -> void:
	var button_group = ButtonGroup.new()
	var foot_options = ["left", "right", "both"]

	for i in foot_container.get_child_count():
		var button = foot_container.get_child(i) as Button
		if button:
			button.button_group = button_group
			var foot_value = foot_options[i]
			foot_buttons[foot_value] = button
			button.pressed.connect(_on_foot_selected.bind(foot_value))


func _on_foot_selected(foot: String) -> void:
	selected_dominant_foot = foot
	AudioManager.play_ui_click()


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


func _create_appearance_selectors() -> void:
	for category in APPEARANCE_OPTIONS:
		# Create label
		var label = Label.new()
		label.text = category.replace("_", " ").capitalize()
		label.add_theme_font_size_override("font_size", 16)
		appearance_grid.add_child(label)

		# Create dropdown
		var option_button = OptionButton.new()
		option_button.custom_minimum_size = Vector2(120, 35)
		option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var options = APPEARANCE_OPTIONS[category]
		for i in options.size():
			option_button.add_item(options[i], i)

		# Set default selection
		var default_value = selected_appearance[category]
		for i in options.size():
			if options[i].to_lower() == default_value:
				option_button.select(i)
				break

		option_button.item_selected.connect(_on_appearance_changed.bind(category, options))
		appearance_grid.add_child(option_button)
		appearance_buttons[category] = option_button


func _on_appearance_changed(index: int, category: String, options: Array) -> void:
	selected_appearance[category] = options[index].to_lower()
	AudioManager.play_ui_click()


func _create_trait_selectors() -> void:
	for trait_id in PERSONALITY_TRAITS:
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var checkbox = CheckBox.new()
		checkbox.name = "Check_" + trait_id
		checkbox.toggled.connect(_on_trait_toggled.bind(trait_id))
		trait_checkboxes[trait_id] = checkbox
		hbox.add_child(checkbox)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label = Label.new()
		name_label.text = trait_id.replace("_", " ").capitalize()
		name_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = PERSONALITY_TRAITS[trait_id]
		desc_label.add_theme_font_size_override("font_size", 12)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(desc_label)

		hbox.add_child(vbox)
		traits_container.add_child(hbox)

	_update_traits_hint()


func _on_trait_toggled(toggled_on: bool, trait_id: String) -> void:
	AudioManager.play_ui_click()

	if toggled_on:
		if selected_traits.size() < MAX_TRAITS:
			selected_traits.append(trait_id)
		else:
			# Already at max, revert the checkbox
			trait_checkboxes[trait_id].set_pressed_no_signal(false)
	else:
		selected_traits.erase(trait_id)

	_update_traits_hint()


func _update_traits_hint() -> void:
	var remaining = MAX_TRAITS - selected_traits.size()
	if remaining == MAX_TRAITS:
		traits_hint.text = "Select up to %d traits (optional)" % MAX_TRAITS
		traits_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif remaining > 0:
		traits_hint.text = "%d trait%s remaining" % [remaining, "s" if remaining > 1 else ""]
		traits_hint.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	else:
		traits_hint.text = "Maximum traits selected"
		traits_hint.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))


func _create_stat_labels() -> void:
	for stat_key in StatSystem.PRIMARY_STATS:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Add tooltip to entire row
		hbox.tooltip_text = STAT_TOOLTIPS.get(stat_key, "")
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS

		var name_label = Label.new()
		name_label.text = StatSystem.PRIMARY_STATS[stat_key]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS

		var value_label = Label.new()
		value_label.name = "Value_" + stat_key
		value_label.text = "50"
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size = Vector2(30, 0)
		stat_value_labels[stat_key] = value_label

		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(100, 16)
		bar_bg.color = Color(0.2, 0.25, 0.3)

		var bar_fill = ColorRect.new()
		bar_fill.name = "Bar_" + stat_key
		bar_fill.custom_minimum_size = Vector2(50, 16)
		bar_fill.color = _get_stat_color(50)
		stat_bars[stat_key] = bar_fill

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


func _create_field_diagram() -> void:
	# Create container for the field diagram
	field_diagram = Control.new()
	field_diagram.name = "FieldDiagram"
	field_diagram.custom_minimum_size = Vector2(140, 180)
	field_diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Insert after position description, before stats label
	var right_panel = $MainContainer/ContentContainer/RightPanel
	var stats_label_index = right_panel.get_node("StatsLabel").get_index()
	right_panel.add_child(field_diagram)
	right_panel.move_child(field_diagram, stats_label_index)

	# Draw field background
	var field_bg = ColorRect.new()
	field_bg.name = "FieldBackground"
	field_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	field_bg.color = Color(0.15, 0.4, 0.15)  # Dark green
	field_diagram.add_child(field_bg)

	# Field lines will be drawn using _draw override
	var field_lines = Control.new()
	field_lines.name = "FieldLines"
	field_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://scripts/ui/field_lines_drawer.gd"):
		field_lines.set_script(load("res://scripts/ui/field_lines_drawer.gd"))
	field_diagram.add_child(field_lines)

	# Create custom drawing for field lines
	_draw_field_lines(field_lines)

	# Position highlight (main)
	position_highlight = ColorRect.new()
	position_highlight.name = "PositionHighlight"
	position_highlight.color = Color(1.0, 0.8, 0.2, 0.5)  # Yellow highlight
	position_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Initialize at CM position
	var cm_zone = POSITION_ZONES["CM"]
	position_highlight.position = cm_zone.center * field_diagram.custom_minimum_size - (cm_zone.size * field_diagram.custom_minimum_size) / 2
	position_highlight.size = cm_zone.size * field_diagram.custom_minimum_size
	field_diagram.add_child(position_highlight)

	# Position highlight mirror (for FB/WNG on opposite side)
	position_highlight_mirror = ColorRect.new()
	position_highlight_mirror.name = "PositionHighlightMirror"
	position_highlight_mirror.color = Color(1.0, 0.8, 0.2, 0.5)
	position_highlight_mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	position_highlight_mirror.visible = false
	position_highlight_mirror.size = Vector2(20, 20)  # Default size
	field_diagram.add_child(position_highlight_mirror)


func _draw_field_lines(container: Control) -> void:
	# We'll use a simple approach with ColorRects for lines
	var line_color = Color(1, 1, 1, 0.6)
	var line_width = 2

	# Get field size
	var field_size = field_diagram.custom_minimum_size

	# Outer boundary
	_add_line_rect(container, Vector2(0, 0), Vector2(field_size.x, line_width), line_color)  # Top
	_add_line_rect(container, Vector2(0, field_size.y - line_width), Vector2(field_size.x, line_width), line_color)  # Bottom
	_add_line_rect(container, Vector2(0, 0), Vector2(line_width, field_size.y), line_color)  # Left
	_add_line_rect(container, Vector2(field_size.x - line_width, 0), Vector2(line_width, field_size.y), line_color)  # Right

	# Center line
	_add_line_rect(container, Vector2(0, field_size.y / 2 - 1), Vector2(field_size.x, line_width), line_color)

	# Center circle (approximate with small square for simplicity)
	var center_size = 20
	_add_line_rect(container, Vector2(field_size.x / 2 - center_size / 2, field_size.y / 2 - center_size / 2), Vector2(center_size, line_width), line_color)  # Top
	_add_line_rect(container, Vector2(field_size.x / 2 - center_size / 2, field_size.y / 2 + center_size / 2 - line_width), Vector2(center_size, line_width), line_color)  # Bottom
	_add_line_rect(container, Vector2(field_size.x / 2 - center_size / 2, field_size.y / 2 - center_size / 2), Vector2(line_width, center_size), line_color)  # Left
	_add_line_rect(container, Vector2(field_size.x / 2 + center_size / 2 - line_width, field_size.y / 2 - center_size / 2), Vector2(line_width, center_size), line_color)  # Right

	# Penalty areas
	var penalty_width = field_size.x * 0.6
	var penalty_height = field_size.y * 0.15
	var penalty_x = (field_size.x - penalty_width) / 2

	# Top penalty area (attacking)
	_add_line_rect(container, Vector2(penalty_x, 0), Vector2(line_width, penalty_height), line_color)  # Left
	_add_line_rect(container, Vector2(penalty_x + penalty_width - line_width, 0), Vector2(line_width, penalty_height), line_color)  # Right
	_add_line_rect(container, Vector2(penalty_x, penalty_height - line_width), Vector2(penalty_width, line_width), line_color)  # Bottom

	# Bottom penalty area (defending)
	_add_line_rect(container, Vector2(penalty_x, field_size.y - penalty_height), Vector2(line_width, penalty_height), line_color)  # Left
	_add_line_rect(container, Vector2(penalty_x + penalty_width - line_width, field_size.y - penalty_height), Vector2(line_width, penalty_height), line_color)  # Right
	_add_line_rect(container, Vector2(penalty_x, field_size.y - penalty_height), Vector2(penalty_width, line_width), line_color)  # Top


func _add_line_rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var rect = ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)


func _create_confirmation_dialog() -> void:
	# Create dark overlay
	confirmation_dialog = Control.new()
	confirmation_dialog.name = "ConfirmationDialog"
	confirmation_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirmation_dialog.visible = false
	add_child(confirmation_dialog)

	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	confirmation_dialog.add_child(overlay)

	# Create centered panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 350)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	confirmation_dialog.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.name = "DialogTitle"
	title.text = "Confirm Your Player"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Summary container
	summary_container = VBoxContainer.new()
	summary_container.name = "SummaryContainer"
	summary_container.add_theme_constant_override("separation", 8)
	summary_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(summary_container)

	# Button container
	var button_box = HBoxContainer.new()
	button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	button_box.add_theme_constant_override("separation", 30)
	vbox.add_child(button_box)

	cancel_button = Button.new()
	cancel_button.text = "Go Back"
	cancel_button.custom_minimum_size = Vector2(120, 45)
	cancel_button.pressed.connect(_on_cancel_confirmation)
	button_box.add_child(cancel_button)

	confirm_button = Button.new()
	confirm_button.text = "Start Career"
	confirm_button.custom_minimum_size = Vector2(150, 45)
	confirm_button.pressed.connect(_on_confirm_career)
	button_box.add_child(confirm_button)


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

	# Update field diagram highlight
	_update_field_highlight(pos)

	# Calculate and display preview stats
	var preview_stats = _calculate_preview_stats(pos)
	_update_stats_display(preview_stats)

	# Update overall rating
	var overall = StatSystem.calculate_overall(preview_stats, pos)
	overall_label.text = "Overall: %d" % overall


func _update_field_highlight(pos: String) -> void:
	if not field_diagram or not position_highlight:
		return

	var zone = POSITION_ZONES.get(pos, POSITION_ZONES["CM"])
	var field_size = field_diagram.custom_minimum_size

	# Calculate highlight position and size
	var highlight_size = zone.size * field_size
	var highlight_pos = zone.center * field_size - highlight_size / 2

	# Animate the highlight
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(position_highlight, "position", highlight_pos, 0.25)
	tween.tween_property(position_highlight, "size", highlight_size, 0.25)

	# Handle mirrored positions (FB and WNG appear on both sides)
	if pos in ["FB", "WNG"]:
		position_highlight_mirror.visible = true
		var mirror_pos = Vector2(field_size.x - highlight_pos.x - highlight_size.x, highlight_pos.y)
		tween.tween_property(position_highlight_mirror, "position", mirror_pos, 0.25)
		tween.tween_property(position_highlight_mirror, "size", highlight_size, 0.25)
	else:
		position_highlight_mirror.visible = false


func _calculate_preview_stats(pos: String) -> Dictionary:
	var base = 45
	var weights = StatSystem.POSITION_WEIGHTS.get(pos, StatSystem.POSITION_WEIGHTS["CM"])
	var preview = {}

	for stat_key in StatSystem.PRIMARY_STATS:
		var weight = weights.get(stat_key, 0.5)
		var weighted_base = base + roundi((weight - 0.5) * 10)
		preview[stat_key] = clampi(weighted_base, 30, 65)

	return preview


func _update_stats_display(preview_stats: Dictionary, animate: bool = true) -> void:
	var tween: Tween = null
	if animate:
		tween = create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)

	for stat_key in StatSystem.PRIMARY_STATS:
		var value = preview_stats.get(stat_key, 50)
		var target_color = _get_stat_color(value)

		# Update value label
		if stat_key in stat_value_labels:
			stat_value_labels[stat_key].text = str(value)

		# Update bar with animation
		if stat_key in stat_bars:
			var bar = stat_bars[stat_key]
			if animate and tween:
				tween.tween_property(bar, "custom_minimum_size:x", float(value), 0.3)
				tween.tween_property(bar, "color", target_color, 0.3)
			else:
				bar.custom_minimum_size.x = value
				bar.color = target_color


func _on_name_changed(_new_text: String) -> void:
	_update_name_validation()


func _update_name_validation() -> void:
	var name_length = name_input.text.strip_edges().length()
	var name_valid = name_length >= 2
	start_button.disabled = not name_valid

	if name_length == 0:
		name_hint.text = "Minimum 2 characters"
		name_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif name_valid:
		name_hint.text = "Name looks good!"
		name_hint.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
	else:
		name_hint.text = "Too short - need %d more character(s)" % (2 - name_length)
		name_hint.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))


func _on_start_pressed() -> void:
	var player_name = name_input.text.strip_edges()

	if player_name.length() < 2:
		return

	AudioManager.play_ui_click()
	_show_confirmation_dialog()


func _show_confirmation_dialog() -> void:
	# Clear previous content
	for child in summary_container.get_children():
		child.queue_free()

	# Build summary lines
	var player_name = name_input.text.strip_edges()
	var nationality_name = NATIONALITIES.get(selected_nationality, selected_nationality)
	var foot_display = selected_dominant_foot.capitalize()
	if selected_dominant_foot == "both":
		foot_display = "Both Feet"

	var summary_items = [
		["Name", player_name],
		["Position", "%s - %s" % [selected_position, POSITION_DESCRIPTIONS[selected_position].split(" - ")[0]]],
		["Nationality", nationality_name],
		["Dominant Foot", foot_display],
		["Age", "14 (High School)"]
	]

	# Add traits if any selected
	if selected_traits.size() > 0:
		var trait_names = []
		for trait_id in selected_traits:
			trait_names.append(trait_id.replace("_", " ").capitalize())
		summary_items.append(["Traits", ", ".join(trait_names)])

	# Create summary labels
	for item in summary_items:
		var hbox = HBoxContainer.new()

		var key_label = Label.new()
		key_label.text = item[0] + ":"
		key_label.add_theme_font_size_override("font_size", 18)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		key_label.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(key_label)

		var value_label = Label.new()
		value_label.text = item[1]
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(value_label)

		summary_container.add_child(hbox)

	confirmation_dialog.visible = true
	confirm_button.grab_focus()


func _on_cancel_confirmation() -> void:
	AudioManager.play_ui_click()
	confirmation_dialog.visible = false
	start_button.grab_focus()


func _on_confirm_career() -> void:
	var player_name = name_input.text.strip_edges()

	AudioManager.play_ui_confirm()

	# Start the career
	GameManager.start_new_career(player_name, selected_position, selected_nationality, selected_appearance, selected_dominant_foot, selected_traits)

	# Transition to desktop shell
	get_tree().change_scene_to_file("res://scenes/desktop/desktop_shell.tscn")


func _on_back_pressed() -> void:
	AudioManager.play_ui_click()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


func _on_randomize_pressed() -> void:
	AudioManager.play_ui_click()
	for category in APPEARANCE_OPTIONS:
		var options = APPEARANCE_OPTIONS[category]
		var random_index = randi() % options.size()
		selected_appearance[category] = options[random_index].to_lower()
		appearance_buttons[category].select(random_index)
