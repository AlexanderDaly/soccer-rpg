extends Resource
class_name NpcPersona
## NpcPersona - Structured persona data for NPC roleplay by an LLM

@export var npc_id: String = ""
@export var name: String = ""
@export var age: int = 16
@export var role: String = ""  # teammate, rival, coach, scout, manager
@export var position: String = ""  # GK, CB, FB, CDM, CM, CAM, WNG, ST

@export var personality_traits: Array[String] = []
@export var speech_style: String = ""
@export var catchphrases: Array[String] = []

@export var goals: Array[String] = []
@export var fears: Array[String] = []
@export var secrets: Array[String] = []
@export var relationships: Dictionary = {}  # npc_id -> relationship description
@export var backstory_hooks: Array[String] = []

@export var boundaries: Array[String] = ["no_violence", "no_explicit", "soccer_context"]
@export var tone_preset: String = "anime"
@export var generation_seed: int = 0
@export var roleplay_prompt: String = ""

# Metadata
@export var is_ai_generated: bool = false
@export var generation_timestamp: int = 0


func _init() -> void:
	generation_seed = randi()


func to_prompt() -> String:
	"""Generate the roleplay system prompt for this NPC."""
	if roleplay_prompt != "":
		return roleplay_prompt

	var prompt_parts: Array[String] = []

	# Character identity
	prompt_parts.append("You are %s, a %d-year-old %s." % [name, age, _role_description()])

	if position != "":
		prompt_parts.append("You play as a %s." % _position_name())

	# Personality
	if not personality_traits.is_empty():
		prompt_parts.append("Your personality: %s." % ", ".join(personality_traits))

	# Speech style
	if speech_style != "":
		prompt_parts.append("Speech style: %s." % speech_style)

	if not catchphrases.is_empty():
		prompt_parts.append("You sometimes say things like: \"%s\"." % "\", \"".join(catchphrases))

	# Motivations
	if not goals.is_empty():
		prompt_parts.append("Your goals: %s." % ", ".join(goals))

	if not fears.is_empty():
		prompt_parts.append("Your fears: %s." % ", ".join(fears))

	# Backstory
	if not backstory_hooks.is_empty():
		prompt_parts.append("Background: %s." % ". ".join(backstory_hooks))

	# Secrets (for internal motivation, not to be revealed directly)
	if not secrets.is_empty():
		prompt_parts.append("(Internal motivation, don't reveal directly: %s)" % ", ".join(secrets))

	# Tone
	prompt_parts.append(_tone_instructions())

	# Boundaries
	prompt_parts.append(_boundary_instructions())

	return "\n".join(prompt_parts)


func to_dict() -> Dictionary:
	"""Serialize persona to dictionary for saving."""
	return {
		"npc_id": npc_id,
		"name": name,
		"age": age,
		"role": role,
		"position": position,
		"personality_traits": personality_traits,
		"speech_style": speech_style,
		"catchphrases": catchphrases,
		"goals": goals,
		"fears": fears,
		"secrets": secrets,
		"relationships": relationships,
		"backstory_hooks": backstory_hooks,
		"boundaries": boundaries,
		"tone_preset": tone_preset,
		"generation_seed": generation_seed,
		"roleplay_prompt": roleplay_prompt,
		"is_ai_generated": is_ai_generated,
		"generation_timestamp": generation_timestamp
	}


func from_dict(data: Dictionary) -> void:
	"""Load persona from dictionary."""
	npc_id = data.get("npc_id", "")
	name = data.get("name", "")
	age = data.get("age", 16)
	role = data.get("role", "")
	position = data.get("position", "")
	personality_traits.assign(data.get("personality_traits", []))
	speech_style = data.get("speech_style", "")
	catchphrases.assign(data.get("catchphrases", []))
	goals.assign(data.get("goals", []))
	fears.assign(data.get("fears", []))
	secrets.assign(data.get("secrets", []))
	relationships = data.get("relationships", {})
	backstory_hooks.assign(data.get("backstory_hooks", []))
	boundaries.assign(data.get("boundaries", ["no_violence", "no_explicit", "soccer_context"]))
	tone_preset = data.get("tone_preset", "anime")
	generation_seed = data.get("generation_seed", 0)
	roleplay_prompt = data.get("roleplay_prompt", "")
	is_ai_generated = data.get("is_ai_generated", false)
	generation_timestamp = data.get("generation_timestamp", 0)


func is_valid() -> bool:
	"""Check if persona has minimum required data."""
	return npc_id != "" and name != "" and role != ""


func _role_description() -> String:
	match role:
		"teammate":
			return "soccer player and teammate"
		"rival":
			return "rival soccer player"
		"coach":
			return "soccer coach"
		"scout":
			return "talent scout"
		"manager":
			return "team manager"
		_:
			return role


func _position_name() -> String:
	var position_names = {
		"GK": "goalkeeper",
		"CB": "center back",
		"FB": "fullback",
		"CDM": "defensive midfielder",
		"CM": "central midfielder",
		"CAM": "attacking midfielder",
		"WNG": "winger",
		"ST": "striker"
	}
	return position_names.get(position, position)


func _tone_instructions() -> String:
	match tone_preset:
		"anime":
			return "Respond in an anime sports drama style - passionate, dramatic moments of growth, friendship through competition, and determination. Keep dialogue punchy and expressive."
		"realistic":
			return "Respond in a realistic, grounded manner befitting professional soccer. Focus on tactical awareness and practical communication."
		"comedic":
			return "Respond with humor and lightheartedness while still caring about soccer. Use comedic timing and friendly banter."
		_:
			return "Respond naturally as this character would."


func _boundary_instructions() -> String:
	var boundary_text: Array[String] = []

	for boundary in boundaries:
		match boundary:
			"no_violence":
				boundary_text.append("No graphic violence")
			"no_explicit":
				boundary_text.append("Keep content appropriate for all ages")
			"soccer_context":
				boundary_text.append("Stay focused on soccer and team dynamics")

	if boundary_text.is_empty():
		return ""

	return "Guidelines: %s." % ", ".join(boundary_text)
