# TODO: NPC Persona Prompt Generator (OpenRouter)

Goal: generate a structured persona prompt for NPCs to be roleplayed by an LLM via OpenRouter.

## Dependencies / Prerequisites
- [x] Address NPC ID stability: Change from `"npc_%d" % randi()` to deterministic seeding (e.g., hash of team_id + roster_index + season)
- [x] Persist NPC identities across seasons (enables deeper narratives and rivalries)

## Requirements
- [x] Reference existing `NarrativeEngine` (`scripts/ai_narrative/narrative_engine.gd`) - has HTTP pattern, config loading, fallback system
- [x] Define the persona schema: name, age, role, personality traits, speech style, goals, relationships, secrets, boundaries.
- [x] Determine which game data sources feed the persona (team, career phase, rivalry history, recent matches).
- [x] Choose output format (plain text prompt vs JSON with a `prompt` field).
- [x] Decide how to handle localization or tone presets (anime, grounded, comedic).
- [x] Decide integration strategy: Extend `NarrativeEngine` vs create separate `PersonaEngine`

## Data + Generation Flow
- [x] Create an `NpcPersona` data model (Resource or Dictionary) with a `to_prompt()` method.
- [x] Implement a generator utility that:
  - [x] selects traits from weighted pools (existing: `["leader", "hardworker", "creative", "aggressive", "calm", "passionate", "reliable"]`)
  - [x] injects game context (team, phase, events)
  - [x] enforces safe/allowed content rules
- [x] Add deterministic seeding (e.g., by npc id) to keep personas stable.
- [x] Define when personas are generated: on-demand vs pre-generated at season start
- [ ] Handle NPC roster changes (transfers, injuries) and persona updates

## OpenRouter Integration
- [x] Leverage existing `NarrativeEngine` HTTPRequest pattern instead of building new client
- [x] Add a client wrapper for OpenRouter HTTP calls:
  - [x] API key + endpoint configuration (existing pattern in `user://ai_config.json`)
  - [x] model selection + temperature defaults
  - [x] timeouts, retries, error handling
- [x] Add rate limiting / request throttling for batch generation
- [x] Cache generated personas to reduce API calls
- [x] Define request/response contract for persona generation.
- [x] Add a fallback path for offline generation (template-based prompt).

## Performance
- [x] Batch generation strategy (don't generate 100+ NPCs at once)
- [x] Background generation with loading indicator
- [x] Define generation timing: season start vs on-demand

## Storage + Persistence
- [x] Store generated persona prompts in NPC data to avoid re-generation.
- [x] Save/load persona prompts with NPC data.
- [x] Integrate with `SaveManager` (`scripts/core/save_manager.gd`)

## UI / Debug
- [x] Add a debug view to inspect NPC personas and prompts.
- [x] Add a dev tool to regenerate a persona for a selected NPC.
- [x] Add UI in desktop/phone interface

## Tests
- [ ] Unit tests for deterministic persona generation.
- [ ] Validation tests for required fields in the prompt schema.
- [ ] Integration test for OpenRouter request handling (mocked).

## File References
- `scripts/ai_narrative/narrative_engine.gd` - Existing API pattern
- `scripts/data/team_data.gd` - NPC generation (`_random_personality()`, `players[]`)
- `scripts/core/save_manager.gd` - Persistence pattern
- `scripts/core/npc_registry.gd` - **NEW** Persistent NPC identity storage
- `scripts/persona/npc_persona.gd` - Persona data model
- `scripts/persona/persona_templates.gd` - Fallback templates
- `scripts/persona/persona_manager.gd` - PersonaManager autoload
