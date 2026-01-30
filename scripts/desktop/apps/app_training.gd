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

var minigame_types: Array[Dictionary] = [
	{
		"id": "penalty_drill",
		"name": "Penalty Practice",
		"description": "Practice penalty kicks against a goalkeeper",
		"stat": "SHO",
		"stamina_cost": 15,
		"is_minigame": true,
		"scene": "res://scenes/training/penalty_drill.tscn"
	},
	{
		"id": "rondo_drill",
		"name": "Rondo Training",
		"description": "Keep-ball drill: pass to open teammates under pressure",
		"stat": "PAS",
		"stamina_cost": 15,
		"is_minigame": true,
		"scene": "res://scenes/training/rondo_drill.tscn"
	},
	{
		"id": "freekick_drill",
		"name": "Free Kick Challenge",
		"description": "Bend it around the wall from various distances",
		"stat": "SHO",
		"stamina_cost": 15,
		"is_minigame": true,
		"scene": "res://scenes/training/freekick_drill.tscn"
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

	# Add mini-games section
	var minigame_header = Label.new()
	minigame_header.text = "Training Mini-Games"
	minigame_header.add_theme_font_size_override("font_size", 16)
	minigame_header.add_theme_color_override("font_color", Color(0.2, 0.4, 0.6))
	training_options.add_child(minigame_header)

	for minigame in minigame_types:
		_add_training_option(minigame)

	# Add separator
	var separator = HSeparator.new()
	training_options.add_child(separator)

	# Add basic training section
	var basic_header = Label.new()
	basic_header.text = "Basic Training"
	basic_header.add_theme_font_size_override("font_size", 16)
	basic_header.add_theme_color_override("font_color", Color(0.2, 0.4, 0.6))
	training_options.add_child(basic_header)

	for training in training_types:
		_add_training_option(training)


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

	var player = GameManager.player_data
	var not_enough_stamina = player and training.stamina_cost > 0 and player.stamina_current < training.stamina_cost

	# Check if this is a minigame with a best score
	var is_minigame = training.get("is_minigame", false)
	var has_best_score = false
	var best_score = 0
	var best_attempts = 10

	if is_minigame and player:
		var record = player.training_records.get(training.id, {})
		if record.has("best_score"):
			has_best_score = true
			best_score = record.best_score
			best_attempts = record.get("attempts", 10)

	# Button container for minigames (Play + Simulate)
	var btn_container = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 4)

	if is_minigame:
		# Play button
		var play_btn = Button.new()
		play_btn.text = "Play"
		play_btn.custom_minimum_size = Vector2(90, 30)
		play_btn.pressed.connect(_on_train_pressed.bind(training))
		if not_enough_stamina:
			play_btn.disabled = true
		btn_container.add_child(play_btn)

		# Simulate button (only if has best score)
		if has_best_score:
			var sim_btn = Button.new()
			sim_btn.text = "Sim (%d/%d)" % [best_score, best_attempts]
			sim_btn.custom_minimum_size = Vector2(90, 30)
			sim_btn.pressed.connect(_on_simulate_pressed.bind(training, best_score, best_attempts))
			if not_enough_stamina:
				sim_btn.disabled = true
			btn_container.add_child(sim_btn)
		else:
			# Show hint that simulation unlocks after playing
			var hint_label = Label.new()
			hint_label.text = "Play to unlock sim"
			hint_label.add_theme_font_size_override("font_size", 10)
			hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn_container.add_child(hint_label)
	else:
		# Regular training button
		var train_btn = Button.new()
		train_btn.text = "Train"
		train_btn.custom_minimum_size = Vector2(70, 40)
		train_btn.pressed.connect(_on_train_pressed.bind(training))
		if not_enough_stamina:
			train_btn.disabled = true
		btn_container.add_child(train_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(btn_container)

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
	elif training.get("is_minigame", false):
		# Launch minigame scene
		if player.stamina_current < training.stamina_cost:
			status_label.text = "Not enough stamina! Rest first."
			return

		status_label.text = "Starting %s..." % training.name
		_launch_minigame(training.scene)
		return  # Don't refresh yet, minigame handles it
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


func _launch_minigame(scene_path: String) -> void:
	var minigame_scene = load(scene_path)
	if minigame_scene:
		var minigame = minigame_scene.instantiate()
		# Add as sibling so it overlays the training app
		get_parent().add_child(minigame)
		# Connect to drill completion to refresh when done
		if minigame.has_signal("drill_completed"):
			minigame.drill_completed.connect(_on_minigame_completed)
		# Also refresh when minigame is freed
		minigame.tree_exiting.connect(_on_minigame_exiting)


func _on_minigame_completed(_results: Dictionary) -> void:
	# Results are applied by the minigame itself
	pass


func _on_minigame_exiting() -> void:
	# Refresh display when returning from minigame
	_refresh_display()
	_build_training_options()
	status_label.text = "Ready for more training!"


func _on_simulate_pressed(training: Dictionary, best_score: int, attempts: int) -> void:
	var player = GameManager.player_data
	if not player:
		return

	AudioManager.play_ui_click()

	# Check stamina
	if player.stamina_current < training.stamina_cost:
		status_label.text = "Not enough stamina! Rest first."
		return

	# Load the minigame script to use its reward calculation
	var rewards: Dictionary
	match training.id:
		"penalty_drill":
			var PenaltyDrill = load("res://scripts/training/penalty_drill.gd")
			rewards = PenaltyDrill.calculate_simulated_rewards(best_score, attempts)
		"rondo_drill":
			var RondoDrill = load("res://scripts/training/rondo_drill.gd")
			rewards = RondoDrill.calculate_simulated_rewards(best_score, attempts)
		"freekick_drill":
			var FreekickDrill = load("res://scripts/training/freekick_drill.gd")
			rewards = FreekickDrill.calculate_simulated_rewards(best_score, attempts)
		_:
			# Fallback for other minigames
			rewards = {"total_xp": 50, "sho_xp": 10, "men_xp": 10, "stamina_cost": training.stamina_cost}

	# Apply rewards
	player.stamina_current = maxi(player.stamina_current - rewards.stamina_cost, 0)
	player.add_xp(rewards.total_xp)

	# Apply stat XP based on minigame type
	if training.id == "penalty_drill":
		player.add_stat_xp("SHO", rewards.sho_xp)
		player.add_stat_xp("MEN", rewards.men_xp)
	elif training.id == "rondo_drill":
		player.add_stat_xp("PAS", rewards.pas_xp)
		player.add_stat_xp("TEC", rewards.tec_xp)
	elif training.id == "freekick_drill":
		player.add_stat_xp("SHO", rewards.sho_xp)
		player.add_stat_xp("TEC", rewards.tec_xp)

	# Advance time
	DesktopManager.advance_time(1)

	# Show result
	var stat_gains: String
	if training.id == "rondo_drill":
		stat_gains = "+%d PAS, +%d TEC" % [rewards.get("pas_xp", 0), rewards.get("tec_xp", 0)]
	elif training.id == "freekick_drill":
		stat_gains = "+%d SHO, +%d TEC" % [rewards.get("sho_xp", 0), rewards.get("tec_xp", 0)]
	else:
		stat_gains = "+%d SHO, +%d MEN" % [rewards.get("sho_xp", 0), rewards.get("men_xp", 0)]
	status_label.text = "Simulated %s (%d/%d): +%d XP, %s" % [
		training.name, best_score, attempts,
		rewards.total_xp, stat_gains
	]

	# Show notification
	DesktopManager.show_notification(
		"Training Simulated",
		"%s: %d/%d - Earned %d XP" % [training.name, best_score, attempts, rewards.total_xp],
		"",
		"training"
	)

	_refresh_display()
	_build_training_options()
