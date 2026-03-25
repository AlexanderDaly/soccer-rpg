extends Node
## GameManager - Central game state and flow controller
## Autoloaded singleton accessible via GameManager

const TacticalMatchRules = preload("res://scripts/match/tactical/tactical_match_rules.gd")

signal game_state_changed(new_state: GameState)
signal match_started(match_data: Dictionary)
signal match_ended(result: Dictionary)
signal career_phase_changed(phase: CareerPhase)
signal national_phase_changed(phase: NationalPhase)

enum GameState {
	MAIN_MENU,
	CAREER_HUB,
	PRE_MATCH,
	IN_MATCH,
	POST_MATCH,
	TRAINING,
	DIALOGUE,
	CUTSCENE,
	LOADING
}

enum CareerPhase {
	HIGH_SCHOOL,
	YOUTH_ACADEMY,
	U20_QUALIFIERS,
	U20_WORLD_CUP,
	PRO_CAREER
}

enum NationalPhase {
	NONE,
	U20_QUALIFIERS,
	U20_WORLD_CUP
}

var current_state: GameState = GameState.MAIN_MENU
var current_career_phase: CareerPhase = CareerPhase.HIGH_SCHOOL
var current_national_phase: NationalPhase = NationalPhase.NONE
var player_data: PlayerData = null
var current_team: TeamData = null
var current_match: MatchData = null
var current_prefecture: String = ""

# Debug mode
var debug_mode: bool = OS.is_debug_build()


func _ready() -> void:
	print("[GameManager] Initialized")
	_load_config()
	if SeasonManager and SeasonManager.has_signal("season_completed") and not SeasonManager.season_completed.is_connected(_on_season_completed):
		SeasonManager.season_completed.connect(_on_season_completed)


func _load_config() -> void:
	# Load any persistent configuration
	pass


func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	
	var old_state = current_state
	current_state = new_state
	
	if debug_mode:
		print("[GameManager] State changed: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])
	
	game_state_changed.emit(new_state)


func start_new_career(player_name: String, position: String, nationality: String = "USA", appearance: Dictionary = {}, dominant_foot: String = "right", traits: Array[String] = [], prefecture: String = "Kanagawa", background_story: String = "academy_product", career_difficulty: String = "normal") -> void:
	if CareerManager and CareerManager.has_method("reset_for_new_career"):
		CareerManager.reset_for_new_career()

	player_data = PlayerData.new()
	player_data.initialize(player_name, position, nationality, appearance, dominant_foot, traits, background_story, career_difficulty)
	current_career_phase = CareerPhase.HIGH_SCHOOL
	current_national_phase = NationalPhase.NONE
	current_prefecture = prefecture

	# Initialize starting team (high school)
	current_team = _create_high_school_team()

	# Initialize the season system
	SeasonManager.initialize_season(prefecture, current_team)
	CareerManager.initialize_new_career_state(current_team)

	change_state(GameState.CAREER_HUB)
	career_phase_changed.emit(current_career_phase)
	national_phase_changed.emit(current_national_phase)


func advance_career_phase() -> void:
	var next_phase = current_career_phase + 1
	if next_phase <= CareerPhase.PRO_CAREER:
		set_career_phase(next_phase as CareerPhase)
		
		# Trigger narrative event for phase transition
		NarrativeEngine.generate_phase_transition_narrative(current_career_phase)


func start_match(opponent_team: TeamData, match_type: String, player_is_home: bool = true, player_team_override: TeamData = null) -> void:
	current_match = MatchData.new()
	current_match.setup(player_team_override if player_team_override else current_team, opponent_team, match_type, player_is_home)

	change_state(GameState.PRE_MATCH)
	match_started.emit(current_match.to_dict())


func end_match(result: Dictionary) -> void:
	# Process match results
	if current_match:
		TacticalMatchRules.serve_competition_suspensions(current_match)
		TacticalMatchRules.apply_result_discipline(current_match, result)
		TacticalMatchRules.apply_result_injuries(result)

	if not bool(result.get("did_not_play", false)):
		StatSystem.process_match_performance(result)
	CareerManager.record_match_result(result)
	SocialFeedManager.on_match_ended(result)
	
	# Generate post-match narrative
	if not bool(result.get("did_not_play", false)):
		NarrativeEngine.generate_post_match_narrative(result)
	
	change_state(GameState.POST_MATCH)
	match_ended.emit(result)


func set_career_phase(new_phase: CareerPhase) -> void:
	if current_career_phase == new_phase:
		return
	current_career_phase = new_phase
	career_phase_changed.emit(current_career_phase)


func set_national_phase(new_phase: NationalPhase) -> void:
	if current_national_phase == new_phase:
		return
	current_national_phase = new_phase
	national_phase_changed.emit(current_national_phase)


func _create_high_school_team() -> TeamData:
	var team = TeamData.new()
	# Generate authentic Japanese school name based on prefecture
	var capital = JapaneseSchoolGenerator.get_prefecture_capital(current_prefecture)
	team.name = "%s First High School" % capital
	team.short_name = capital.substr(0, 3).to_upper() if capital.length() >= 3 else capital.to_upper()
	team.league = "%s Prefecture" % current_prefecture
	team.tier = 1
	team.generate_teammates(10, CareerPhase.HIGH_SCHOOL)  # 10 teammates + player
	return team


func get_career_phase_name() -> String:
	return CareerPhase.keys()[current_career_phase].replace("_", " ").capitalize()


func get_national_phase_name() -> String:
	return NationalPhase.keys()[current_national_phase].replace("_", " ").capitalize()


func _on_season_completed(summary: Dictionary) -> void:
	if not player_data:
		return

	CareerManager.handle_primary_season_completion(summary)

	if current_career_phase == CareerPhase.HIGH_SCHOOL:
		if player_data.school_year < 3:
			player_data.age += 1
			player_data.school_year += 1
			SeasonManager.initialize_season(current_prefecture, current_team)
		else:
			player_data.age += 1
			CareerManager.generate_progression_offers(summary)
		return

	player_data.age += 1

	if CareerManager.has_queued_contract():
		CareerManager.apply_queued_contract()
	else:
		SeasonManager.initialize_season(current_prefecture, current_team)
