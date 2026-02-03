class_name PersonaTemplates
## PersonaTemplates - Deterministic template-based persona generation for offline play

# Personality type expansions - maps base personality to detailed traits
const PERSONALITY_EXPANSIONS = {
	"leader": {
		"traits": ["commanding", "protective", "responsible", "confident"],
		"speech": "authoritative yet encouraging, uses 'we' often, gives direct instructions",
		"goals": ["lead_team_to_victory", "develop_younger_players", "earn_respect"],
		"fears": ["letting_the_team_down", "losing_authority", "internal_conflict"],
		"catchphrases": ["Let's show them what we're made of!", "Together, we're unstoppable!", "I've got your back."]
	},
	"hardworker": {
		"traits": ["diligent", "humble", "persistent", "disciplined"],
		"speech": "straightforward, action over words, practical, modest",
		"goals": ["prove_through_effort", "never_give_up", "earn_starting_spot"],
		"fears": ["being_seen_as_lazy", "wasted_potential", "injury"],
		"catchphrases": ["Hard work beats talent.", "One more rep.", "Actions speak louder than words."]
	},
	"creative": {
		"traits": ["imaginative", "unpredictable", "expressive", "intuitive"],
		"speech": "colorful language, metaphors, thinks out loud, artistic references",
		"goals": ["create_beautiful_moments", "inspire_others", "express_through_play"],
		"fears": ["being_restricted", "boring_matches", "losing_creativity"],
		"catchphrases": ["Watch this!", "The pitch is my canvas.", "Feel the flow!"]
	},
	"aggressive": {
		"traits": ["intense", "competitive", "fearless", "direct"],
		"speech": "short sentences, challenge-oriented, fired up, confrontational",
		"goals": ["dominate_opponents", "never_back_down", "prove_strength"],
		"fears": ["appearing_weak", "being_outplayed", "losing_edge"],
		"catchphrases": ["Bring it on!", "Is that all you've got?", "No mercy!"]
	},
	"calm": {
		"traits": ["composed", "analytical", "patient", "steady"],
		"speech": "measured, thoughtful pauses, logical, rarely raises voice",
		"goals": ["maintain_composure", "read_the_game", "be_reliable"],
		"fears": ["losing_control", "chaos", "emotional_decisions"],
		"catchphrases": ["Stay focused.", "Patience wins games.", "Think before you act."]
	},
	"passionate": {
		"traits": ["emotional", "inspiring", "dramatic", "wholehearted"],
		"speech": "expressive, exclamation points, wears heart on sleeve, motivational",
		"goals": ["play_with_heart", "inspire_teammates", "create_memories"],
		"fears": ["apathy", "meaningless_games", "losing_passion"],
		"catchphrases": ["This is what we live for!", "Feel the fire!", "Give it everything!"]
	},
	"reliable": {
		"traits": ["consistent", "trustworthy", "supportive", "dependable"],
		"speech": "reassuring, steady, team-focused, practical advice",
		"goals": ["be_someone_others_depend_on", "maintain_consistency", "support_team"],
		"fears": ["making_mistakes", "letting_others_down", "being_forgotten"],
		"catchphrases": ["I'll be there.", "You can count on me.", "Steady as she goes."]
	}
}

# Role-specific backstory hooks
const ROLE_BACKSTORY_HOOKS = {
	"teammate": [
		"has been training since childhood",
		"joined the team to follow a family tradition",
		"transferred from another school/club",
		"grew up in this neighborhood",
		"has a younger sibling who looks up to them"
	],
	"rival": [
		"once played on the same youth team",
		"comes from a rival school with a long history",
		"has beaten you before in a crucial match",
		"shares the same position and competes for attention",
		"respects your skill but won't admit it"
	],
	"coach": [
		"was a professional player who retired due to injury",
		"has been coaching for over a decade",
		"known for developing young talent",
		"has a tactical philosophy they're famous for",
		"coached a rival team before"
	]
}

# Position-specific traits that can be added
const POSITION_TRAITS = {
	"GK": ["brave", "commanding", "focused", "cat-like reflexes"],
	"CB": ["strong", "no-nonsense", "vocal", "reads the game"],
	"FB": ["energetic", "overlapping runs", "balanced", "versatile"],
	"CDM": ["disciplined", "shield", "interceptor", "simple passes"],
	"CM": ["box-to-box", "engine", "versatile", "links play"],
	"CAM": ["visionary", "key pass", "between lines", "creative spark"],
	"WNG": ["tricky", "pace merchant", "direct", "loves 1v1s"],
	"ST": ["clinical", "poacher", "target man", "goal-hungry"]
}

# Japanese first names by personality type tendency
const FIRST_NAMES_BY_VIBE = {
	"energetic": ["Haruto", "Kaito", "Ren", "Yuto", "Soma"],
	"calm": ["Yuki", "Minato", "Akira", "Sora", "Haru"],
	"strong": ["Takumi", "Ryota", "Kenta", "Daiki", "Shota"],
	"creative": ["Riku", "Hayate", "Asahi", "Hinata", "Itsuki"]
}

# Secrets pool by role
const SECRETS_POOL = {
	"teammate": [
		"secretly doubts their own ability",
		"is dealing with pressure from family",
		"has a crush on someone in school",
		"is considering quitting for academics",
		"looks up to the player more than they show"
	],
	"rival": [
		"actually respects you deeply",
		"is jealous of your natural talent",
		"has something to prove to their family",
		"fears they've peaked too early",
		"wants to be friends but pride gets in the way"
	],
	"coach": [
		"sees themselves in one of the players",
		"is under pressure from administration",
		"regrets how their own career ended",
		"is considering retirement",
		"has a soft spot they try to hide"
	]
}


static func generate_fallback_persona(npc_data: Dictionary, context: Dictionary = {}) -> NpcPersona:
	"""Generate a deterministic fallback persona based on NPC data."""
	var persona = NpcPersona.new()

	var npc_id = npc_data.get("id", "unknown")
	var seed_value = hash(npc_id)
	persona.generation_seed = seed_value

	# Use seeded random for deterministic generation
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value

	# Basic info
	persona.npc_id = npc_id
	persona.name = npc_data.get("name", "Unknown")
	persona.position = npc_data.get("position", "")
	persona.role = context.get("role", "teammate")
	persona.age = _generate_age(persona.role, rng)

	# Get base personality from NPC data or generate one
	var base_personality = npc_data.get("personality", _random_personality(rng))
	var expansion = PERSONALITY_EXPANSIONS.get(base_personality, PERSONALITY_EXPANSIONS["reliable"])

	# Build personality traits
	var traits: Array[String] = []
	for trait in expansion.traits:
		traits.append(trait)

	# Add position-specific trait if applicable
	if persona.position in POSITION_TRAITS:
		var pos_traits = POSITION_TRAITS[persona.position]
		var pos_trait = pos_traits[rng.randi() % pos_traits.size()]
		if pos_trait not in traits:
			traits.append(pos_trait)

	persona.personality_traits = traits

	# Speech style
	persona.speech_style = expansion.speech

	# Catchphrases - pick 1-2
	var num_catchphrases = rng.randi_range(1, 2)
	var catchphrases: Array[String] = []
	var available_catchphrases = expansion.catchphrases.duplicate()
	for i in range(mini(num_catchphrases, available_catchphrases.size())):
		var idx = rng.randi() % available_catchphrases.size()
		catchphrases.append(available_catchphrases[idx])
		available_catchphrases.remove_at(idx)
	persona.catchphrases = catchphrases

	# Goals - pick 2
	var goals: Array[String] = []
	var available_goals = expansion.goals.duplicate()
	for i in range(mini(2, available_goals.size())):
		var idx = rng.randi() % available_goals.size()
		goals.append(_humanize_goal(available_goals[idx]))
		available_goals.remove_at(idx)
	persona.goals = goals

	# Fears - pick 1
	var fears: Array[String] = []
	var available_fears = expansion.fears.duplicate()
	if not available_fears.is_empty():
		var idx = rng.randi() % available_fears.size()
		fears.append(_humanize_goal(available_fears[idx]))
	persona.fears = fears

	# Backstory hooks - pick 1-2
	var hooks: Array[String] = []
	var role_hooks = ROLE_BACKSTORY_HOOKS.get(persona.role, ROLE_BACKSTORY_HOOKS["teammate"])
	var available_hooks = role_hooks.duplicate()
	var num_hooks = rng.randi_range(1, 2)
	for i in range(mini(num_hooks, available_hooks.size())):
		var idx = rng.randi() % available_hooks.size()
		hooks.append(available_hooks[idx])
		available_hooks.remove_at(idx)
	persona.backstory_hooks = hooks

	# Secrets - pick 1
	var secrets: Array[String] = []
	var role_secrets = SECRETS_POOL.get(persona.role, SECRETS_POOL["teammate"])
	if not role_secrets.is_empty():
		var idx = rng.randi() % role_secrets.size()
		secrets.append(role_secrets[idx])
	persona.secrets = secrets

	# Set defaults
	persona.tone_preset = context.get("tone_preset", "anime")
	persona.is_ai_generated = false
	persona.generation_timestamp = Time.get_unix_time_from_system() as int

	return persona


static func _generate_age(role: String, rng: RandomNumberGenerator) -> int:
	match role:
		"teammate", "rival":
			return rng.randi_range(15, 18)  # High school age
		"coach":
			return rng.randi_range(35, 55)
		"scout":
			return rng.randi_range(30, 50)
		"manager":
			return rng.randi_range(40, 60)
		_:
			return rng.randi_range(16, 25)


static func _random_personality(rng: RandomNumberGenerator) -> String:
	var personalities = PERSONALITY_EXPANSIONS.keys()
	return personalities[rng.randi() % personalities.size()]


static func _humanize_goal(goal_key: String) -> String:
	"""Convert snake_case goal keys to readable text."""
	return goal_key.replace("_", " ")
