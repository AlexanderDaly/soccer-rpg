extends PanelBase
class_name PanelTraining
## PanelTraining - Training center panel for the console dashboard

@onready var stamina_bar: ProgressBar = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/StatusSection/StaminaRow/StaminaBar
@onready var stamina_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/StatusSection/StaminaRow/StaminaValue
@onready var training_options: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/ScrollContainer/TrainingOptions
@onready var status_label: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/StatusLabel

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


func _on_panel_ready() -> void:
	panel_title = "Training Center"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_refresh_display()
	_build_training_options()


func _refresh_display() -> void:
	var player = GameManager.player_data
	if not player:
		return

	if stamina_bar:
		stamina_bar.value = player.stamina_current
	if stamina_label:
		stamina_label.text = "%d%%" % player.stamina_current


func _build_training_options() -> void:
	if not training_options:
		return

	# Clear existing
	for child in training_options.get_children():
		child.queue_free()

	# Add mini-games section
	var minigame_header = Label.new()
	minigame_header.text = "Training Mini-Games"
	minigame_header.add_theme_font_size_override("font_size", 18)
	minigame_header.add_theme_color_override("font_color", Color(0, 0.8, 0.4))
	training_options.add_child(minigame_header)

	for minigame in minigame_types:
		_add_training_option(minigame)

	# Add separator
	var separator = HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.2, 0.3, 0.5))
	training_options.add_child(separator)

	# Add basic training section
	var basic_header = Label.new()
	basic_header.text = "Basic Training"
	basic_header.add_theme_font_size_override("font_size", 18)
	basic_header.add_theme_color_override("font_color", Color(0, 0.8, 0.4))
	training_options.add_child(basic_header)

	for training in training_types:
		_add_training_option(training)


func _add_training_option(training: Dictionary) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.18, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.15, 0.25, 0.4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = training.name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))

	var desc_label = Label.new()
	desc_label.text = training.description
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	desc_label.add_theme_font_size_override("font_size", 13)

	var cost_label = Label.new()
	if training.stamina_cost > 0:
		cost_label.text = "Stamina: -%d | Stat: %s +XP" % [training.stamina_cost, training.stat]
	else:
		cost_label.text = "Stamina: +%d" % abs(training.stamina_cost)
	cost_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	cost_label.add_theme_font_size_override("font_size", 12)

	info_vbox.add_child(name_label)
	info_vbox.add_child(desc_label)
	info_vbox.add_child(cost_label)

	var player = GameManager.player_data
	var not_enough_stamina = player and training.stamina_cost > 0 and player.stamina_current < training.stamina_cost

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

	var btn_container = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 4)

	if is_minigame:
		var play_btn = _create_button("Play")
		play_btn.pressed.connect(_on_train_pressed.bind(training))
		if not_enough_stamina:
			play_btn.disabled = true
		btn_container.add_child(play_btn)

		if has_best_score:
			var sim_btn = _create_button("Sim (%d/%d)" % [best_score, best_attempts])
			sim_btn.pressed.connect(_on_simulate_pressed.bind(training, best_score, best_attempts))
			if not_enough_stamina:
				sim_btn.disabled = true
			btn_container.add_child(sim_btn)
		else:
			var hint_label = Label.new()
			hint_label.text = "Play to unlock sim"
			hint_label.add_theme_font_size_override("font_size", 10)
			hint_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
			btn_container.add_child(hint_label)
	else:
		var train_btn = _create_button("Train")
		train_btn.pressed.connect(_on_train_pressed.bind(training))
		if not_enough_stamina:
			train_btn.disabled = true
		btn_container.add_child(train_btn)

	hbox.add_child(info_vbox)
	hbox.add_child(btn_container)

	panel.add_child(hbox)
	training_options.add_child(panel)


func _create_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 32)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.15, 0.25, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.4, 0.6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0, 0.6, 0.3)
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color(0, 0.8, 0.4)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	return btn


func _on_train_pressed(training: Dictionary) -> void:
	var player = GameManager.player_data
	if not player:
		return

	AudioManager.play_ui_click()

	if training.id == "rest":
		player.rest()
		if status_label:
			status_label.text = "You rested and recovered some stamina."
		DesktopManager.advance_time(4)
	elif training.get("is_minigame", false):
		if player.stamina_current < training.stamina_cost:
			if status_label:
				status_label.text = "Not enough stamina! Rest first."
			return

		if status_label:
			status_label.text = "Starting %s..." % training.name
		close()
		_launch_minigame(training.scene)
		return
	else:
		if player.stamina_current < training.stamina_cost:
			if status_label:
				status_label.text = "Not enough stamina! Rest first."
			return

		player.stamina_current -= training.stamina_cost
		player.add_stat_xp(training.stat, training.xp_gain)
		player.add_xp(training.xp_gain)
		_apply_training_injuries({
			"training_type": training.id,
			"attempts": TrainingConstants.ATTEMPTS_PER_SESSION,
			"accuracy": 1.0,
			"player_stamina": player.stamina_current + training.stamina_cost,
			"stamina_cost": training.stamina_cost
		})

		if status_label:
			status_label.text = "Completed %s training! %s +XP" % [training.name, training.stat]
		DesktopManager.advance_time(2)

	_refresh_display()
	_build_training_options()


func _launch_minigame(scene_path: String) -> void:
	var minigame_scene = load(scene_path)
	if minigame_scene:
		get_tree().change_scene_to_packed(minigame_scene)


func _on_simulate_pressed(training: Dictionary, best_score: int, attempts: int) -> void:
	var player = GameManager.player_data
	if not player:
		return

	AudioManager.play_ui_click()

	if player.stamina_current < training.stamina_cost:
		if status_label:
			status_label.text = "Not enough stamina! Rest first."
		return

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
			rewards = {"total_xp": 50, "sho_xp": 10, "men_xp": 10, "stamina_cost": training.stamina_cost}

	player.stamina_current = maxi(player.stamina_current - rewards.stamina_cost, 0)
	player.add_xp(rewards.total_xp)

	if training.id == "penalty_drill":
		player.add_stat_xp("SHO", rewards.sho_xp)
		player.add_stat_xp("MEN", rewards.men_xp)
	elif training.id == "rondo_drill":
		player.add_stat_xp("PAS", rewards.pas_xp)
		player.add_stat_xp("TEC", rewards.tec_xp)
	elif training.id == "freekick_drill":
		player.add_stat_xp("SHO", rewards.sho_xp)
		player.add_stat_xp("TEC", rewards.tec_xp)

	DesktopManager.advance_time(1)

	var stat_gains: String
	if training.id == "rondo_drill":
		stat_gains = "+%d PAS, +%d TEC" % [rewards.get("pas_xp", 0), rewards.get("tec_xp", 0)]
	elif training.id == "freekick_drill":
		stat_gains = "+%d SHO, +%d TEC" % [rewards.get("sho_xp", 0), rewards.get("tec_xp", 0)]
	else:
		stat_gains = "+%d SHO, +%d MEN" % [rewards.get("sho_xp", 0), rewards.get("men_xp", 0)]

	if status_label:
		status_label.text = "Simulated %s (%d/%d): +%d XP, %s" % [
			training.name, best_score, attempts,
			rewards.total_xp, stat_gains
		]

	DesktopManager.show_notification(
		"Training Simulated",
		"%s: %d/%d - Earned %d XP" % [training.name, best_score, attempts, rewards.total_xp],
		"",
		"training"
	)

	var stamina_after = player.stamina_current
	var accuracy = float(best_score) / float(maxi(attempts, 1))
	var stamina_before = stamina_after + rewards.stamina_cost
	_apply_training_injuries({
		"training_type": training.id,
		"attempts": attempts,
		"accuracy": accuracy,
		"player_stamina": stamina_before,
		"stamina_cost": rewards.stamina_cost
	})

	_refresh_display()
	_build_training_options()


func _apply_training_injuries(training_context: Dictionary) -> void:
	var injuries = InjurySystem.process_training_injuries(GameManager.current_team, training_context)
	if injuries.is_empty():
		return

	for injury in injuries:
		var player_name = injury.get("player_name", "Player")
		var description = injury.get("description", "injury")
		var matches_out = int(injury.get("matches_out", 0))
		var severity = injury.get("type", "minor")
		var injury_type = injury.get("injury_type", "")
		var severity_text = InjurySystem.get_severity_text(severity)
		var match_suffix = "es" if matches_out != 1 else ""
		var match_out_text = " - %d match%s out" % [matches_out, match_suffix] if matches_out > 0 else ""
		var detail = description if injury_type == "" else "%s (%s)" % [description, injury_type]

		DesktopManager.show_notification(
			"Injury Report",
			"%s suffered a %s (%s)%s." % [player_name, severity_text, detail, match_out_text],
			"",
			"training"
		)
