extends Control
## AppTraining - Training center app (stub implementation)

@onready var stamina_bar: ProgressBar = $VBoxContainer/StatusSection/StaminaRow/StaminaBar
@onready var stamina_label: Label = $VBoxContainer/StatusSection/StaminaRow/StaminaValue
@onready var training_options: VBoxContainer = $VBoxContainer/ScrollContainer/TrainingOptions
@onready var status_label: Label = $VBoxContainer/StatusLabel

var training_types: Array[Dictionary] = [
	{
		"id": "shooting",
		"name": "Shooting Practice",
		"description": "Improve your shooting accuracy and power",
		"stat": "SHO",
		"stamina_cost": 20,
		"xp_gain": 15
	},
	{
		"id": "passing",
		"name": "Passing Drills",
		"description": "Work on short and long-range passing",
		"stat": "PAS",
		"stamina_cost": 15,
		"xp_gain": 12
	},
	{
		"id": "dribbling",
		"name": "Dribbling Circuit",
		"description": "Enhance ball control and technique",
		"stat": "TEC",
		"stamina_cost": 20,
		"xp_gain": 15
	},
	{
		"id": "fitness",
		"name": "Fitness Training",
		"description": "Build stamina and speed",
		"stat": "STA",
		"stamina_cost": 25,
		"xp_gain": 18
	},
	{
		"id": "defense",
		"name": "Defensive Drills",
		"description": "Practice tackling and positioning",
		"stat": "DEF",
		"stamina_cost": 20,
		"xp_gain": 15
	},
	{
		"id": "rest",
		"name": "Rest & Recovery",
		"description": "Recover stamina and improve morale",
		"stat": "",
		"stamina_cost": -30,
		"xp_gain": 0
	}
]


func _ready() -> void:
	_refresh_display()
	_build_training_options()


func _refresh_display() -> void:
	var player = GameManager.player_data
	if not player:
		return

	stamina_bar.value = player.stamina_current
	stamina_label.text = "%d%%" % player.stamina_current


func _build_training_options() -> void:
	# Clear existing
	for child in training_options.get_children():
		child.queue_free()

	for training in training_types:
		_add_training_option(training)

	# Add note about stub
	var note = Label.new()
	note.text = "\n[Full training mini-games coming soon]"
	note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	note.add_theme_font_size_override("font_size", 13)
	training_options.add_child(note)


func _add_training_option(training: Dictionary) -> void:
	var panel = PanelContainer.new()

	var hbox = HBoxContainer.new()

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = training.name
	name_label.add_theme_font_size_override("font_size", 18)

	var desc_label = Label.new()
	desc_label.text = training.description
	desc_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	desc_label.add_theme_font_size_override("font_size", 14)

	var cost_label = Label.new()
	if training.stamina_cost > 0:
		cost_label.text = "Stamina: -%d | Stat: %s +XP" % [training.stamina_cost, training.stat]
	else:
		cost_label.text = "Stamina: +%d" % abs(training.stamina_cost)
	cost_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	cost_label.add_theme_font_size_override("font_size", 13)

	info_vbox.add_child(name_label)
	info_vbox.add_child(desc_label)
	info_vbox.add_child(cost_label)

	var train_btn = Button.new()
	train_btn.text = "Train"
	train_btn.custom_minimum_size = Vector2(70, 40)
	train_btn.pressed.connect(_on_train_pressed.bind(training))

	# Disable if not enough stamina
	var player = GameManager.player_data
	if player and training.stamina_cost > 0 and player.stamina_current < training.stamina_cost:
		train_btn.disabled = true

	hbox.add_child(info_vbox)
	hbox.add_child(train_btn)

	panel.add_child(hbox)
	training_options.add_child(panel)


func _on_train_pressed(training: Dictionary) -> void:
	var player = GameManager.player_data
	if not player:
		return

	AudioManager.play_ui_click()

	if training.id == "rest":
		# Rest and recovery
		player.rest()
		status_label.text = "You rested and recovered some stamina."
		DesktopManager.advance_time(4)
	else:
		# Check stamina
		if player.stamina_current < training.stamina_cost:
			status_label.text = "Not enough stamina! Rest first."
			return

		# Apply training
		player.stamina_current -= training.stamina_cost
		player.add_stat_xp(training.stat, training.xp_gain)
		player.add_xp(training.xp_gain)

		status_label.text = "Completed %s training! %s +XP" % [training.name, training.stat]
		DesktopManager.advance_time(2)

	_refresh_display()
	_build_training_options()
