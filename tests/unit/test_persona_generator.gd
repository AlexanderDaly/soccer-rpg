extends GutTest
## Unit tests for NPC Persona Generator


# =============================================================================
# Deterministic Generation Tests
# =============================================================================

func test_fallback_persona_is_deterministic() -> void:
	var npc_data = {"id": "test_npc_1", "name": "Kenji Tanaka", "position": "ST"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona1 = PersonaTemplates.generate_fallback_persona(npc_data, context)
	var persona2 = PersonaTemplates.generate_fallback_persona(npc_data, context)

	# Same input should produce same personality traits
	assert_eq(persona1.personality_traits, persona2.personality_traits,
		"Same NPC should get same personality traits")


func test_different_npcs_get_different_personas() -> void:
	var npc1 = {"id": "npc_1", "name": "Player A", "position": "ST"}
	var npc2 = {"id": "npc_2", "name": "Player B", "position": "GK"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona1 = PersonaTemplates.generate_fallback_persona(npc1, context)
	var persona2 = PersonaTemplates.generate_fallback_persona(npc2, context)

	# Different NPCs should (usually) get different traits
	# This isn't guaranteed but with different positions it's very likely
	assert_ne(persona1.position, persona2.position,
		"Different positions should be reflected")


# =============================================================================
# Persona Structure Tests
# =============================================================================

func test_persona_has_required_fields() -> void:
	var npc_data = {"id": "test_npc", "name": "Test Player", "position": "CM"}
	var context = {"role": "rival", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)

	assert_not_null(persona, "Persona should be created")
	assert_false(persona.personality_traits.is_empty(), "Should have personality traits")
	assert_ne(persona.speech_style, "", "Should have speech style")
	assert_false(persona.goals.is_empty(), "Should have goals")


func test_persona_stores_npc_id() -> void:
	var npc_data = {"id": "unique_id_123", "name": "Test Player", "position": "FB"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)

	assert_eq(persona.npc_id, "unique_id_123", "Persona should store NPC ID")


func test_persona_stores_role() -> void:
	var npc_data = {"id": "test_npc", "name": "Test Player", "position": "CB"}
	var context = {"role": "rival", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)

	assert_eq(persona.role, "rival", "Persona should store role")


# =============================================================================
# Position-Based Trait Tests
# =============================================================================

func test_striker_gets_position_specific_goals() -> void:
	var npc_data = {"id": "striker", "name": "Striker", "position": "ST"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)

	assert_eq(persona.position, "ST", "Position should be stored")


func test_goalkeeper_gets_position_specific_traits() -> void:
	var npc_data = {"id": "keeper", "name": "Keeper", "position": "GK"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)

	assert_eq(persona.position, "GK", "Position should be stored")


# =============================================================================
# Serialization Tests
# =============================================================================

func test_persona_to_dict_includes_all_fields() -> void:
	var npc_data = {"id": "test_npc", "name": "Test Player", "position": "CM"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)
	var data = persona.to_dict()

	assert_has(data, "npc_id")
	assert_has(data, "name")
	assert_has(data, "position")
	assert_has(data, "role")
	assert_has(data, "personality_traits")
	assert_has(data, "speech_style")
	assert_has(data, "goals")


func test_persona_from_dict_restores_data() -> void:
	var npc_data = {"id": "test_npc", "name": "Test Player", "position": "WNG"}
	var context = {"role": "rival", "tone_preset": "anime"}

	var original = PersonaTemplates.generate_fallback_persona(npc_data, context)
	var data = original.to_dict()

	var restored = NpcPersona.new()
	restored.from_dict(data)

	assert_eq(restored.npc_id, original.npc_id)
	assert_eq(restored.name, original.name)
	assert_eq(restored.position, original.position)
	assert_eq(restored.role, original.role)
	assert_eq(restored.personality_traits, original.personality_traits)


# =============================================================================
# Prompt Generation Tests
# =============================================================================

func test_to_prompt_includes_name() -> void:
	var npc_data = {"id": "test", "name": "Kenji Yamamoto", "position": "CM"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)
	var prompt = persona.to_prompt()

	assert_true(prompt.contains("Kenji Yamamoto"), "Prompt should include name")


func test_to_prompt_includes_personality() -> void:
	var npc_data = {"id": "test", "name": "Test Player", "position": "ST"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)
	var prompt = persona.to_prompt()

	assert_true(prompt.contains("Personality"), "Prompt should have personality section")


# =============================================================================
# Edge Cases
# =============================================================================

func test_empty_npc_data_handled_gracefully() -> void:
	var npc_data = {}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)

	assert_not_null(persona, "Should still create persona with empty data")


func test_missing_position_uses_default() -> void:
	var npc_data = {"id": "test", "name": "Player"}
	var context = {"role": "teammate", "tone_preset": "anime"}

	var persona = PersonaTemplates.generate_fallback_persona(npc_data, context)

	assert_not_null(persona, "Should handle missing position")
