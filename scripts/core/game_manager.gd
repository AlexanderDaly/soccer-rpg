extends Node
## GameManager - Central game state and flow controller
## Autoloaded singleton accessible via GameManager

signal game_state_changed(new_state: GameState)
signal match_started(match_data: Dictionary)
signal match_ended(result: Dictionary)
signal career_phase_changed(phase: CareerPhase)

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

var current_state: GameState = GameState.MAIN_MENU
var current_career_phase: CareerPhase = CareerPhase.HIGH_SCHOOL
var player_data: PlayerData = null
var current_team: TeamData = null
var current_match: MatchData = null

# Debug mode
var debug_mode: bool = OS.is_debug_build()


func _ready() -> void:
	print("[GameManager] Initialized")
	_load_config()


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


func start_new_career(player_name: String, position: String) -> void:
	player_data = PlayerData.new()
	player_data.initialize(player_name, position)
	current_career_phase = CareerPhase.HIGH_SCHOOL
	
	# Initialize starting team (high school)
	current_team = _create_high_school_team()
	
	change_state(GameState.CAREER_HUB)
	career_phase_changed.emit(current_career_phase)


func advance_career_phase() -> void:
	var next_phase = current_career_phase + 1
	if next_phase <= CareerPhase.PRO_CAREER:
		current_career_phase = next_phase as CareerPhase
		career_phase_changed.emit(current_career_phase)
		
		# Trigger narrative event for phase transition
		NarrativeEngine.generate_phase_transition_narrative(current_career_phase)


func start_match(opponent_team: TeamData, match_type: String) -> void:
	current_match = MatchData.new()
	current_match.setup(current_team, opponent_team, match_type)
	
	change_state(GameState.PRE_MATCH)
	match_started.emit(current_match.to_dict())


func end_match(result: Dictionary) -> void:
	# Process match results
	StatSystem.process_match_performance(result)
	CareerManager.record_match_result(result)
	
	# Generate post-match narrative
	NarrativeEngine.generate_post_match_narrative(result)
	
	change_state(GameState.POST_MATCH)
	match_ended.emit(result)


func _create_high_school_team() -> TeamData:
	var team = TeamData.new()
	team.name = "Sakura High School"
	team.generate_teammates(10, CareerPhase.HIGH_SCHOOL)  # 10 teammates + player
	return team


func get_career_phase_name() -> String:
	return CareerPhase.keys()[current_career_phase].replace("_", " ").capitalize()
