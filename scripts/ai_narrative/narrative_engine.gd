extends Node
## NarrativeEngine - AI-driven dynamic narrative generation
## Generates contextual story beats, dialogue, and news articles based on player progress

signal narrative_generated(narrative_type: String, content: Dictionary)
signal dialogue_ready(dialogue_data: Dictionary)
signal news_article_generated(article: Dictionary)

# Narrative context storage
var narrative_context: Dictionary = {
	"player_name": "",
	"position": "",
	"career_phase": "",
	"recent_performances": [],
	"key_relationships": {},
	"rivalry_history": {},
	"personality_traits": [],
	"notable_moments": []
}

# Dialogue templates for fallback when AI is unavailable
var dialogue_templates: Dictionary = {}

# News article templates
var news_templates: Array[String] = []

# AI API configuration
var ai_api_endpoint: String = ""
var ai_api_key: String = ""
var use_ai_generation: bool = false

# Generation queue
var generation_queue: Array[Dictionary] = []
var is_generating: bool = false


func _ready() -> void:
	print("[NarrativeEngine] Initialized")
	_load_templates()
	_load_ai_config()


func _load_templates() -> void:
	# Load fallback dialogue templates
	dialogue_templates = {
		"coach_praise": [
			"Excellent work out there, {player_name}! Keep it up!",
			"That's the kind of performance that gets you noticed, {player_name}.",
			"You're really showing your potential. I'm proud of you."
		],
		"coach_criticism": [
			"We need more from you, {player_name}. I know you can do better.",
			"That wasn't your best game. Let's work on it in training.",
			"Focus, {player_name}. The team is counting on you."
		],
		"teammate_friendly": [
			"Great pass out there! We make a good combo.",
			"Hey, want to practice some set pieces after training?",
			"You're getting better every match. Respect."
		],
		"rival_taunt": [
			"Is that all you've got, {player_name}? I expected more.",
			"Next time we meet, I won't go easy on you.",
			"You got lucky today. It won't happen again."
		],
		"scout_interest": [
			"I've been watching your progress. Very impressive.",
			"My club is interested in players with your potential.",
			"Keep performing like this and we'll be in touch."
		]
	}
	
	news_templates = [
		"{player_name} shines in {match_type} victory",
		"Rising star {player_name} scores {goals} in dominant display",
		"{team_name} celebrates as {player_name} leads the charge",
		"Scouts take notice: {player_name}'s breakout performance"
	]


func _load_ai_config() -> void:
	# Load AI API configuration from settings
	# In production, this would load from a secure config file
	var config_path = "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		var config = JSON.parse_string(file.get_as_text())
		file.close()
		
		if config:
			ai_api_endpoint = config.get("endpoint", "")
			ai_api_key = config.get("api_key", "")
			use_ai_generation = config.get("enabled", false)


func update_context(key: String, value: Variant) -> void:
	narrative_context[key] = value


func update_rivalry_context(rival_id: String, encounter_result: Dictionary) -> void:
	if rival_id not in narrative_context.rivalry_history:
		narrative_context.rivalry_history[rival_id] = []
	
	narrative_context.rivalry_history[rival_id].append(encounter_result)


func add_notable_moment(moment: Dictionary) -> void:
	narrative_context.notable_moments.append(moment)
	
	# Keep only recent moments (last 20)
	if narrative_context.notable_moments.size() > 20:
		narrative_context.notable_moments.pop_front()


func generate_post_match_narrative(match_result: Dictionary) -> void:
	var request = {
		"type": "post_match",
		"context": _build_match_context(match_result),
		"match_result": match_result
	}
	
	_queue_generation(request)


func generate_phase_transition_narrative(new_phase: GameManager.CareerPhase) -> void:
	var request = {
		"type": "phase_transition",
		"context": narrative_context.duplicate(),
		"new_phase": GameManager.CareerPhase.keys()[new_phase]
	}
	
	_queue_generation(request)


func generate_dialogue(character_type: String, mood: String, context: Dictionary = {}) -> Dictionary:
	# Synchronous fallback generation for immediate needs
	var merged_context = narrative_context.duplicate()
	merged_context.merge(context)
	
	var template_key = "%s_%s" % [character_type, mood]
	if template_key in dialogue_templates:
		var templates = dialogue_templates[template_key]
		var template = templates[randi() % templates.size()]
		
		return {
			"text": _fill_template(template, merged_context),
			"speaker": character_type,
			"mood": mood,
			"generated": false
		}
	
	return {
		"text": "...",
		"speaker": character_type,
		"mood": "neutral",
		"generated": false
	}


func generate_news_article(match_result: Dictionary) -> Dictionary:
	var context = _build_match_context(match_result)
	
	var template = news_templates[randi() % news_templates.size()]
	var headline = _fill_template(template, context)
	
	var article = {
		"headline": headline,
		"body": _generate_article_body(match_result, context),
		"date": Time.get_date_string_from_system(),
		"source": _random_news_source()
	}
	
	news_article_generated.emit(article)
	return article


func _queue_generation(request: Dictionary) -> void:
	generation_queue.append(request)
	
	if not is_generating:
		_process_queue()


func _process_queue() -> void:
	if generation_queue.is_empty():
		is_generating = false
		return
	
	is_generating = true
	var request = generation_queue.pop_front()
	
	if use_ai_generation and ai_api_endpoint != "":
		_generate_with_ai(request)
	else:
		_generate_fallback(request)


func _generate_with_ai(request: Dictionary) -> void:
	# Create HTTP request to AI API
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_ai_response.bind(request, http))
	
	var prompt = _build_ai_prompt(request)
	var body = JSON.stringify({
		"prompt": prompt,
		"max_tokens": 500,
		"temperature": 0.8
	})
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % ai_api_key
	]
	
	var error = http.request(ai_api_endpoint, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_warning("[NarrativeEngine] AI request failed, using fallback")
		http.queue_free()
		_generate_fallback(request)


func _on_ai_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request: Dictionary, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[NarrativeEngine] AI response error, using fallback")
		_generate_fallback(request)
		return
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response and "text" in response:
		var content = {
			"text": response.text,
			"type": request.type,
			"generated": true
		}
		narrative_generated.emit(request.type, content)
	else:
		_generate_fallback(request)
	
	# Continue processing queue
	_process_queue()


func _generate_fallback(request: Dictionary) -> void:
	var content = {}
	
	match request.type:
		"post_match":
			content = _fallback_post_match(request)
		"phase_transition":
			content = _fallback_phase_transition(request)
		_:
			content = {"text": "...", "type": request.type, "generated": false}
	
	narrative_generated.emit(request.type, content)
	
	# Continue processing queue
	call_deferred("_process_queue")


func _fallback_post_match(request: Dictionary) -> Dictionary:
	var result = request.match_result
	var context = request.context
	
	var summary = ""
	if result.get("won", false):
		summary = "A strong performance led to victory."
	elif result.get("draw", false):
		summary = "A hard-fought match ended in a draw."
	else:
		summary = "Despite the loss, valuable lessons were learned."
	
	if result.get("goals", 0) > 0:
		summary += " {player_name} found the net {goals} time(s).".format(context)
	
	if result.get("man_of_match", false):
		summary += " An outstanding individual display earned the Man of the Match award."
	
	return {
		"text": summary.format(context),
		"type": "post_match",
		"generated": false
	}


func _fallback_phase_transition(request: Dictionary) -> Dictionary:
	var phase = request.new_phase
	var messages = {
		"YOUTH_ACADEMY": "Your talent has been recognized. A new chapter begins at the academy.",
		"U20_QUALIFIERS": "The national team calls. It's time to prove yourself on the international stage.",
		"U20_WORLD_CUP": "You've made it to the World Cup squad. This is what you've been working for.",
		"PRO_CAREER": "The professional ranks await. Your childhood dream is within reach."
	}
	
	return {
		"text": messages.get(phase, "A new chapter in your career begins."),
		"type": "phase_transition",
		"generated": false
	}


func _build_ai_prompt(request: Dictionary) -> String:
	var context_str = JSON.stringify(request.context, "  ")
	
	match request.type:
		"post_match":
			return """Generate a brief, anime-style narrative summary for a soccer match.
Context: %s
Match Result: %s
Write 2-3 sentences capturing the drama and emotion. Include the player's name naturally.""" % [context_str, JSON.stringify(request.match_result)]
		
		"phase_transition":
			return """Generate a dramatic anime-style narrative for a career milestone.
Context: %s
New Phase: %s
Write 2-3 impactful sentences marking this transition. Be inspiring and dramatic.""" % [context_str, request.new_phase]
		
		_:
			return "Generate brief narrative content for: %s" % JSON.stringify(request)


func _build_match_context(match_result: Dictionary) -> Dictionary:
	return {
		"player_name": narrative_context.player_name,
		"position": narrative_context.position,
		"team_name": GameManager.current_team.name if GameManager.current_team else "the team",
		"goals": str(match_result.get("goals", 0)),
		"assists": str(match_result.get("assists", 0)),
		"match_type": match_result.get("match_type", "match"),
		"opponent": match_result.get("opponent_name", "the opponent")
	}


func _fill_template(template: String, context: Dictionary) -> String:
	var result = template
	for key in context:
		result = result.replace("{%s}" % key, str(context[key]))
	return result


func _generate_article_body(match_result: Dictionary, context: Dictionary) -> String:
	var body = "%s delivered a memorable performance " % context.player_name
	
	if match_result.get("won", false):
		body += "as their team secured an important victory. "
	else:
		body += "despite the challenging result. "
	
	if int(context.get("goals", "0")) > 0:
		body += "The young talent found the back of the net, showcasing their growing prowess. "
	
	body += "Scouts from several clubs were reportedly in attendance."
	
	return body


func _random_news_source() -> String:
	var sources = ["Soccer Weekly", "The Athletic Tribune", "Goal! Magazine", "Football Daily", "Sports Central"]
	return sources[randi() % sources.size()]
