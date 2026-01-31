# NPC Persona Generator Implementation - Development Journal

**Date:** January 30, 2026
**Author:** Development Session
**Scope:** Generate structured persona prompts for NPCs to be roleplayed by an LLM via OpenRouter

---

## Overview

Implemented a complete NPC persona generation system that creates structured character profiles for LLM-based roleplay. The system provides instant fallback personas using deterministic templates and optional AI enhancement via OpenRouter API.

---

## Architecture Decision

Created separate `PersonaManager` autoload (not extending NarrativeEngine) because:
- **Different responsibility:** Character identity vs story beats
- **Different API format:** OpenRouter uses messages array (chat format)
- **Different lifecycle:** Personas cached long-term, narratives generated frequently

---

## Implementation Phases

### Phase 1: NpcPersona Data Model

**New File:** `scripts/persona/npc_persona.gd`

Created a Resource class with comprehensive persona schema:

| Property | Type | Description |
|----------|------|-------------|
| `npc_id` | String | Unique identifier |
| `name` | String | Display name |
| `age` | int | Character age |
| `role` | String | teammate, rival, coach, scout, manager |
| `position` | String | GK, CB, FB, CDM, CM, CAM, WNG, ST |
| `personality_traits` | Array[String] | Core personality traits |
| `speech_style` | String | How they speak |
| `catchphrases` | Array[String] | Signature phrases |
| `goals` | Array[String] | What they want |
| `fears` | Array[String] | What they avoid |
| `secrets` | Array[String] | Hidden motivations |
| `relationships` | Dictionary | npc_id -> relationship |
| `backstory_hooks` | Array[String] | Background details |
| `boundaries` | Array[String] | Content guardrails |
| `tone_preset` | String | anime, realistic, comedic |

**Methods:**
- `to_prompt()` - Generates complete roleplay system prompt
- `to_dict()` / `from_dict()` - Serialization
- `is_valid()` - Validates minimum required fields

---

### Phase 2: Fallback Templates

**New File:** `scripts/persona/persona_templates.gd`

Static class for deterministic offline generation using `hash(npc_id)` as RNG seed.

**Personality Expansions (7 types):**

| Type | Traits | Speech Style |
|------|--------|--------------|
| leader | commanding, protective, responsible | authoritative, uses "we" |
| hardworker | diligent, humble, persistent | straightforward, action over words |
| creative | imaginative, unpredictable | colorful, metaphors |
| aggressive | intense, competitive, fearless | short sentences, confrontational |
| calm | composed, analytical, patient | measured, logical |
| passionate | emotional, inspiring, dramatic | expressive, motivational |
| reliable | consistent, trustworthy | reassuring, steady |

**Additional Data Pools:**
- `ROLE_BACKSTORY_HOOKS` - Role-specific background details
- `POSITION_TRAITS` - Position-specific characteristics
- `SECRETS_POOL` - Hidden motivations by role

**Key Method:**
```gdscript
static func generate_fallback_persona(npc_data: Dictionary, context: Dictionary) -> NpcPersona
```

---

### Phase 3: PersonaManager Autoload

**New File:** `scripts/persona/persona_manager.gd`

Core autoload for persona management with signals:
- `persona_generated(npc_id, persona)` - Async generation complete
- `persona_generation_failed(npc_id, error)` - Generation failed
- `batch_generation_progress(completed, total)` - Batch progress

**Configuration (from `user://ai_config.json`):**
```json
{
  "openrouter": {
    "endpoint": "https://openrouter.ai/api/v1/chat/completions",
    "api_key": "",
    "model": "anthropic/claude-3-haiku",
    "enabled": false
  },
  "persona": {
    "tone_preset": "anime",
    "auto_generate": true,
    "batch_size": 5
  }
}
```

**Key Methods:**
- `get_persona(npc_id)` - Synchronous, returns cached or fallback
- `get_persona_async(npc_id)` - Queues AI enhancement
- `generate_team_personas(team, enhance_with_ai)` - Batch generation
- `generate_opponent_personas(team)` - Rival personas
- `save_personas_to_dict()` / `load_personas_from_dict()` - Persistence

**Rate Limiting:** Timer-based 1-second delay between API requests.

---

### Phase 4: OpenRouter Integration

**Request Format:**
```gdscript
{
    "model": "anthropic/claude-3-haiku",
    "messages": [
        {"role": "system", "content": PERSONA_SYSTEM_PROMPT},
        {"role": "user", "content": generation_prompt}
    ],
    "max_tokens": 800,
    "temperature": 0.7
}
```

**Response Handling:**
- Parses JSON from `choices[0].message.content`
- Handles markdown code blocks in response
- Falls back gracefully on parse errors

---

### Phase 5: SaveManager Integration

**File Modified:** `scripts/core/save_manager.gd`

Added to `_collect_save_data()`:
```gdscript
"personas": PersonaManager.save_personas_to_dict()
```

Added to `_apply_save_data()`:
```gdscript
if "personas" in data:
    PersonaManager.load_personas_from_dict(data.personas)
```

---

### Phase 6: Autoload Registration

**File Modified:** `project.godot`

Added to autoload section:
```
PersonaManager="*res://scripts/persona/persona_manager.gd"
```

---

## Files Summary

### New Files

| File | Purpose |
|------|---------|
| `scripts/persona/npc_persona.gd` | Persona data Resource class |
| `scripts/persona/persona_templates.gd` | Offline fallback templates |
| `scripts/persona/persona_manager.gd` | Autoload for generation/caching |

### Modified Files

| File | Changes |
|------|---------|
| `scripts/core/save_manager.gd` | Added persona serialization |
| `project.godot` | Registered PersonaManager autoload |

---

## Generation Flow

1. **Season start:** Generate fallback personas for player team (instant)
2. **Pre-match:** Queue AI enhancement for opponent team (background)
3. **On interaction:** Return cached persona (fallback or AI-enhanced)
4. **Background:** Gradually enhance all personas when idle

---

## Testing Notes

To verify implementation:
1. Start new season, check that teammates get fallback personas
2. Save and reload, verify personas persist
3. Check deterministic generation (same NPC ID = same fallback)
4. Configure OpenRouter in `user://ai_config.json` and test AI enhancement
5. Verify rate limiting prevents API spam
6. Check batch generation progress signals

---

## Related Documentation

- `docs/todo-npc-persona-generator.md` - Original feature specification

---
