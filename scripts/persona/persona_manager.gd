extends Node
## PersonaManager - Manages NPC persona generation, caching, and AI enhancement

signal persona_generated(npc_id: String, persona: NpcPersona)
signal persona_generation_failed(npc_id: String, error: String)
signal batch_generation_progress(completed: int, total: int)

# Persona cache: npc_id -> NpcPersona
var persona_cache: Dictionary = {}

# Generation queue for AI enhancement
var generation_queue: Array[Dictionary] = []
var is_generating: bool = false

# OpenRouter API configuration
var openrouter_endpoint: String = "https://openrouter.ai/api/v1/chat/completions"
var openrouter_api_key: String = ""
var openrouter_model: String = "anthropic/claude-3-haiku"
var use_ai_generation: bool = false

# Rate limiting
var rate_limit_ms: int = 1000
var _last_request_time: int = 0
var _rate_limit_timer: Timer

# Batch generation tracking
var _batch_total: int = 0
var _batch_completed: int = 0

# Persona config
var tone_preset: String = "anime"
var auto_generate: bool = true
var batch_size: int = 5

# System prompt for AI persona generation
const PERSONA_SYSTEM_PROMPT = """You are a creative writer for an anime-style soccer RPG game. Generate a detailed character persona for an NPC.

Output ONLY valid JSON with this exact structure (no markdown, no explanation):
{
  "personality_traits": ["trait1", "trait2", "trait3"],
  "speech_style": "description of how they speak",
  "catchphrases": ["phrase1", "phrase2"],
  "goals": ["goal1", "goal2"],
  "fears": ["fear1"],
  "secrets": ["a hidden motivation or secret"],
  "backstory_hooks": ["interesting background detail"]
}

Make the character feel authentic to anime sports drama - passionate about soccer, with clear motivations and personality."""


func _ready() -> void:
	print("[PersonaManager] Initialized")
	_load_config()
	_setup_rate_limit_timer()


func _load_config() -> void:
	"""Load AI and persona configuration from user config file."""
	var config_path = "user://ai_config.json"
	if not FileAccess.file_exists(config_path):
		return

	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		return

	var config = JSON.parse_string(file.get_as_text())
	file.close()

	if not config:
		return

	# OpenRouter config
	if "openrouter" in config:
		var or_config = config.openrouter
		openrouter_endpoint = or_config.get("endpoint", openrouter_endpoint)
		openrouter_api_key = or_config.get("api_key", "")
		openrouter_model = or_config.get("model", openrouter_model)
		use_ai_generation = or_config.get("enabled", false)

	# Persona config
	if "persona" in config:
		var p_config = config.persona
		tone_preset = p_config.get("tone_preset", tone_preset)
		auto_generate = p_config.get("auto_generate", auto_generate)
		batch_size = p_config.get("batch_size", batch_size)

	print("[PersonaManager] Config loaded - AI generation: %s" % use_ai_generation)


func _setup_rate_limit_timer() -> void:
	_rate_limit_timer = Timer.new()
	_rate_limit_timer.one_shot = true
	_rate_limit_timer.timeout.connect(_process_queue)
	add_child(_rate_limit_timer)


func get_persona(npc_id: String) -> NpcPersona:
	"""Get persona synchronously - returns cached or generates fallback."""
	if npc_id in persona_cache:
		return persona_cache[npc_id]

	# Generate fallback persona
	var npc_data = _find_npc_data(npc_id)
	if npc_data.is_empty():
		push_warning("[PersonaManager] No NPC data found for: %s" % npc_id)
		return null

	var context = {"role": _determine_role(npc_id), "tone_preset": tone_preset}
	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)
	persona_cache[npc_id] = persona

	return persona


func get_persona_async(npc_id: String) -> void:
	"""Queue persona for AI generation/enhancement. Emits persona_generated when done."""
	# If already cached and AI-generated, emit immediately
	if npc_id in persona_cache and persona_cache[npc_id].is_ai_generated:
		persona_generated.emit(npc_id, persona_cache[npc_id])
		return

	# Get or create fallback first
	var persona = get_persona(npc_id)
	if not persona:
		persona_generation_failed.emit(npc_id, "No NPC data found")
		return

	# If AI not enabled, just emit the fallback
	if not use_ai_generation or openrouter_api_key == "":
		persona_generated.emit(npc_id, persona)
		return

	# Queue for AI enhancement
	_queue_generation(npc_id)


func generate_team_personas(team: TeamData, enhance_with_ai: bool = false) -> void:
	"""Generate personas for all players on a team."""
	if not team:
		return

	_batch_total = team.players.size()
	_batch_completed = 0

	for player in team.players:
		var npc_id = player.get("id", "")
		if npc_id == "":
			continue

		# Generate fallback immediately
		var context = {"role": "teammate", "tone_preset": tone_preset}
		var persona = PersonaTemplates.generate_fallback_persona(player, context)
		persona_cache[npc_id] = persona

		_batch_completed += 1
		batch_generation_progress.emit(_batch_completed, _batch_total)

		# Queue for AI enhancement if requested
		if enhance_with_ai and use_ai_generation:
			_queue_generation(npc_id)


func generate_opponent_personas(team: TeamData) -> void:
	"""Generate personas for opponent team players."""
	if not team:
		return

	for player in team.players:
		var npc_id = player.get("id", "")
		if npc_id == "":
			continue

		var context = {"role": "rival", "tone_preset": tone_preset}
		var persona = PersonaTemplates.generate_fallback_persona(player, context)
		persona_cache[npc_id] = persona


func has_persona(npc_id: String) -> bool:
	"""Check if a persona exists for this NPC."""
	return npc_id in persona_cache


func clear_cache() -> void:
	"""Clear all cached personas."""
	persona_cache.clear()


func save_personas_to_dict() -> Dictionary:
	"""Serialize all personas for saving."""
	var data = {}
	for npc_id in persona_cache:
		var persona = persona_cache[npc_id]
		if persona:
			data[npc_id] = persona.to_dict()
	return data


func load_personas_from_dict(data: Dictionary) -> void:
	"""Load personas from save data."""
	persona_cache.clear()
	for npc_id in data:
		var persona = NpcPersona.new()
		persona.from_dict(data[npc_id])
		persona_cache[npc_id] = persona
	print("[PersonaManager] Loaded %d personas from save" % persona_cache.size())


func _queue_generation(npc_id: String) -> void:
	"""Add NPC to AI generation queue."""
	# Don't queue duplicates
	for item in generation_queue:
		if item.npc_id == npc_id:
			return

	generation_queue.append({"npc_id": npc_id})

	if not is_generating:
		_process_queue()


func _process_queue() -> void:
	"""Process the next item in the generation queue."""
	if generation_queue.is_empty():
		is_generating = false
		return

	is_generating = true

	# Check rate limit
	var current_time = Time.get_ticks_msec()
	var time_since_last = current_time - _last_request_time
	if time_since_last < rate_limit_ms:
		var wait_time = (rate_limit_ms - time_since_last) / 1000.0
		_rate_limit_timer.start(wait_time)
		return

	var item = generation_queue.pop_front()
	_generate_with_ai(item.npc_id)


func _generate_with_ai(npc_id: String) -> void:
	"""Send request to OpenRouter API for persona enhancement."""
	_last_request_time = Time.get_ticks_msec()

	var npc_data = _find_npc_data(npc_id)
	var existing_persona = persona_cache.get(npc_id)

	var prompt = _build_generation_prompt(npc_data, existing_persona)

	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_ai_response.bind(npc_id, http))

	var request_body = {
		"model": openrouter_model,
		"messages": [
			{"role": "system", "content": PERSONA_SYSTEM_PROMPT},
			{"role": "user", "content": prompt}
		],
		"max_tokens": 800,
		"temperature": 0.7
	}

	var body_json = JSON.stringify(request_body)
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % openrouter_api_key,
		"HTTP-Referer: https://soccer-rpg.game",
		"X-Title: Soccer Career RPG"
	]

	var error = http.request(openrouter_endpoint, headers, HTTPClient.METHOD_POST, body_json)
	if error != OK:
		push_warning("[PersonaManager] HTTP request failed: %s" % error)
		http.queue_free()
		_on_generation_failed(npc_id, "HTTP request failed")


func _on_ai_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, npc_id: String, http: HTTPRequest) -> void:
	"""Handle OpenRouter API response."""
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		_on_generation_failed(npc_id, "Request failed with result: %d" % result)
		return

	if response_code != 200:
		var error_body = body.get_string_from_utf8()
		push_warning("[PersonaManager] API error %d: %s" % [response_code, error_body])
		_on_generation_failed(npc_id, "API returned status: %d" % response_code)
		return

	var response = JSON.parse_string(body.get_string_from_utf8())
	if not response or not response.has("choices") or response.choices.is_empty():
		_on_generation_failed(npc_id, "Invalid API response format")
		return

	var content = response.choices[0].message.content

	# Parse the JSON content from the response
	var persona_data = JSON.parse_string(content)
	if not persona_data:
		# Try to extract JSON from markdown code blocks
		var json_match = _extract_json_from_text(content)
		persona_data = JSON.parse_string(json_match) if json_match else null

	if not persona_data:
		push_warning("[PersonaManager] Failed to parse persona JSON from response")
		_on_generation_failed(npc_id, "Failed to parse AI response")
		return

	# Enhance existing persona with AI-generated content
	_apply_ai_enhancements(npc_id, persona_data)

	# Emit success
	var persona = persona_cache.get(npc_id)
	if persona:
		persona_generated.emit(npc_id, persona)

	# Continue processing queue
	call_deferred("_process_queue")


func _on_generation_failed(npc_id: String, error: String) -> void:
	"""Handle generation failure - emit signal and continue queue."""
	push_warning("[PersonaManager] Generation failed for %s: %s" % [npc_id, error])
	persona_generation_failed.emit(npc_id, error)

	# Still emit the fallback persona if we have one
	if npc_id in persona_cache:
		persona_generated.emit(npc_id, persona_cache[npc_id])

	call_deferred("_process_queue")


func _apply_ai_enhancements(npc_id: String, ai_data: Dictionary) -> void:
	"""Apply AI-generated content to existing persona."""
	if npc_id not in persona_cache:
		return

	var persona = persona_cache[npc_id]

	# Update with AI-generated content
	if "personality_traits" in ai_data:
		var traits: Array[String] = []
		for trait in ai_data.personality_traits:
			traits.append(str(trait))
		persona.personality_traits = traits

	if "speech_style" in ai_data:
		persona.speech_style = str(ai_data.speech_style)

	if "catchphrases" in ai_data:
		var phrases: Array[String] = []
		for phrase in ai_data.catchphrases:
			phrases.append(str(phrase))
		persona.catchphrases = phrases

	if "goals" in ai_data:
		var goals: Array[String] = []
		for goal in ai_data.goals:
			goals.append(str(goal))
		persona.goals = goals

	if "fears" in ai_data:
		var fears: Array[String] = []
		for fear in ai_data.fears:
			fears.append(str(fear))
		persona.fears = fears

	if "secrets" in ai_data:
		var secrets: Array[String] = []
		for secret in ai_data.secrets:
			secrets.append(str(secret))
		persona.secrets = secrets

	if "backstory_hooks" in ai_data:
		var hooks: Array[String] = []
		for hook in ai_data.backstory_hooks:
			hooks.append(str(hook))
		persona.backstory_hooks = hooks

	# Mark as AI-generated
	persona.is_ai_generated = true
	persona.generation_timestamp = Time.get_unix_time_from_system() as int


func _build_generation_prompt(npc_data: Dictionary, existing_persona: NpcPersona) -> String:
	"""Build the prompt for AI persona generation."""
	var prompt_parts: Array[String] = []

	prompt_parts.append("Generate a persona for this soccer player:")
	prompt_parts.append("Name: %s" % npc_data.get("name", "Unknown"))
	prompt_parts.append("Position: %s" % npc_data.get("position", "Unknown"))

	var role = "teammate"
	if existing_persona:
		role = existing_persona.role
	prompt_parts.append("Role: %s" % role)

	var personality = npc_data.get("personality", "")
	if personality != "":
		prompt_parts.append("Base personality type: %s" % personality)

	prompt_parts.append("")
	prompt_parts.append("Create a unique character that fits an anime sports drama. Make them memorable with specific quirks and motivations.")

	return "\n".join(prompt_parts)


func _find_npc_data(npc_id: String) -> Dictionary:
	"""Find NPC data from teams."""
	# Check player's team
	if GameManager.current_team:
		var player = GameManager.current_team.get_player_by_id(npc_id)
		if not player.is_empty():
			return player

	# Could extend to search other sources (opponent teams, etc.)
	return {}


func _determine_role(npc_id: String) -> String:
	"""Determine NPC's role based on their context."""
	# If they're on the player's team, they're a teammate
	if GameManager.current_team:
		var player = GameManager.current_team.get_player_by_id(npc_id)
		if not player.is_empty():
			return "teammate"

	# Default to rival for unknown NPCs
	return "rival"


func _extract_json_from_text(text: String) -> String:
	"""Try to extract JSON from text that might have markdown formatting."""
	# Look for JSON in code blocks
	var start = text.find("```json")
	if start >= 0:
		start = text.find("\n", start) + 1
		var end = text.find("```", start)
		if end > start:
			return text.substr(start, end - start).strip_edges()

	# Look for bare code blocks
	start = text.find("```")
	if start >= 0:
		start = text.find("\n", start) + 1
		var end = text.find("```", start)
		if end > start:
			return text.substr(start, end - start).strip_edges()

	# Try to find JSON object directly
	start = text.find("{")
	if start >= 0:
		var end = text.rfind("}")
		if end > start:
			return text.substr(start, end - start + 1)

	return ""
