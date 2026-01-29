# Soccer Career RPG - Claude Code Development Instructions

## Project Overview

This is an **anime-style tactical soccer RPG** built in **Godot 4.2+** using **GDScript**. The player rises from high school soccer through the U20 World Cup and into professional ranks.

**Core gameplay:**
- Turn-based tactical 11v11 matches on a grid-based pitch
- RPG stat progression and skill unlocks
- Dynamic AI-generated narrative that responds to player performance
- Career mode with reputation, scouts, and contract offers

## What's Already Built

### Autoload Singletons (in `scripts/core/` and related)
These are globally accessible via their class names:

1. **GameManager** (`scripts/core/game_manager.gd`)
   - Central game state controller
   - Manages `GameState` enum: MAIN_MENU, CAREER_HUB, PRE_MATCH, IN_MATCH, POST_MATCH, TRAINING, DIALOGUE, CUTSCENE, LOADING
   - Manages `CareerPhase` enum: HIGH_SCHOOL, YOUTH_ACADEMY, U20_QUALIFIERS, U20_WORLD_CUP, PRO_CAREER
   - Holds `player_data: PlayerData`, `current_team: TeamData`, `current_match: MatchData`

2. **StatSystem** (`scripts/core/stat_system.gd`)
   - Primary stats: SPD, STA, TEC, PAS, SHO, DEF, PHY, MEN (1-99 scale)
   - Secondary stats derived from primaries (acceleration, vision, finishing, etc.)
   - Position archetypes with stat weights: GK, CB, FB, CDM, CM, CAM, WNG, ST
   - XP calculations and action success rolls

3. **CareerManager** (`scripts/career/career_manager.gd`)
   - Tracks match history, career stats, reputation (0-100)
   - Milestone system (first_goal, first_assist, regional_champion, etc.)
   - Scout interest tracking and contract offer generation
   - Rival system

4. **NarrativeEngine** (`scripts/ai_narrative/narrative_engine.gd`)
   - AI-driven story generation via HTTP API (optional, has fallback templates)
   - Generates post-match narratives, phase transitions, dialogue
   - Maintains narrative context (player stats, relationships, notable moments)

5. **AudioManager** (`scripts/core/audio_manager.gd`)
   - Music and SFX playback with pooling
   - Volume controls and fading

6. **SaveManager** (`scripts/core/save_manager.gd`)
   - 5 save slots, JSON-based saves
   - Auto-save support

### Data Classes (in `scripts/data/`)

1. **PlayerData** (`player_data.gd`) - Resource class
   - Stats, level, XP, skills, form, morale, appearance, personality

2. **TeamData** (`team_data.gd`) - Resource class  
   - Team info, formation, tactics, NPC player generation

3. **MatchData** (`match_data.gd`) - Resource class
   - Match state, scores, player performance tracking, event log, grid state

### Existing Scenes
- `scenes/menus/main_menu.tscn` - Basic main menu with New Career, Load, Settings, Quit buttons

### Project Configuration
- `project.godot` - Configured with autoloads, input mappings, display settings
- Resolution: 1920x1080, canvas_items stretch mode

---

## What Needs to Be Built

### Priority 1: Character Creation Screen
**File:** `scenes/menus/character_creation.tscn` + `scripts/ui/character_creation.gd`

**Requirements:**
- Player name input (LineEdit)
- Position selection (GK, CB, FB, CDM, CM, CAM, WNG, ST) with descriptions
- Show starting stat preview based on position (use `StatSystem.POSITION_WEIGHTS`)
- Optional: Appearance customization (hair color, style, etc. - stored in `PlayerData.appearance`)
- Optional: Personality trait selection (affects narrative generation)
- "Start Career" button that:
  - Calls `GameManager.start_new_career(name, position)`
  - Transitions to Career Hub

**UI Style:** Clean anime aesthetic, dark theme consistent with main menu

---

### Priority 2: Career Hub
**File:** `scenes/career/career_hub.tscn` + `scripts/career/career_hub.gd`

**Requirements:**
- Display current career phase (e.g., "Sakura High School - Year 1")
- Player card showing: name, position, overall rating, current form
- Quick stats panel: matches played, goals, assists, reputation
- Navigation buttons:
  - "Next Match" → Pre-match screen
  - "Training" → Training scene (can be placeholder)
  - "Team" → View teammates
  - "Stats" → Detailed player stats
  - "Save Game" → Trigger save
- Upcoming fixture display (opponent, match type, importance)
- News ticker or recent narrative events from NarrativeEngine

---

### Priority 3: Pre-Match Screen
**File:** `scenes/match/pre_match.tscn` + `scripts/match/pre_match.gd`

**Requirements:**
- Show matchup: Your Team vs Opponent Team
- Display both team formations
- Show starting XI for both sides (player highlighted on user's team)
- Team overall ratings comparison
- Match type and importance indicator
- "Start Match" button → Transitions to match scene
- Optional: Basic tactical instructions (mentality, pressing level)

---

### Priority 4: Match System (Core Gameplay)
**Files:** 
- `scenes/match/match.tscn` + `scripts/match/match_controller.gd`
- `scripts/match/tactical_grid.gd`
- `scripts/match/player_unit.gd`
- `scripts/match/match_ai.gd`

**Grid System:**
- Pitch grid: approximately 21x14 hexes (or squares)
- Camera: Top-down or isometric view
- Visual: Green pitch with grid overlay, goals at each end

**Turn Structure (suggested):**
- Phase-based: Possession team acts, then defense reacts
- Each player unit has Action Points (based on STA stat)
- Actions: Move, Pass, Shoot, Dribble, Tackle, Special Move
- Ball possession tracked separately

**Player Units:**
- Visual representation on grid (sprites or simple shapes for prototype)
- Show position, selected state, movement range
- Health/stamina bar optional

**Action Resolution:**
- Use `StatSystem.roll_action_success(actor_stat, defender_stat, difficulty)`
- Contested actions (tackle vs dribble) compare relevant stats
- Display success/fail feedback

**Match Flow:**
- Simplified: Show key moments rather than full 90 minutes
- Or: Condensed turns representing phases of play
- Track events via `MatchData.record_event()`
- Half-time and full-time states

**AI Opponent:**
- Basic AI that selects actions for opponent players
- Consider position, ball location, tactical settings
- Doesn't need to be sophisticated for prototype

**End of Match:**
- Call `MatchData.generate_result()` to compile stats
- Call `GameManager.end_match(result)` which triggers:
  - `StatSystem.process_match_performance()`
  - `CareerManager.record_match_result()`
  - `NarrativeEngine.generate_post_match_narrative()`
- Transition to Post-Match screen

---

### Priority 5: Post-Match Screen
**File:** `scenes/match/post_match.tscn` + `scripts/match/post_match.gd`

**Requirements:**
- Final score display
- Player performance summary (goals, assists, rating, key stats)
- XP gained notification
- Milestone unlocks if any
- Generated narrative text from NarrativeEngine
- "Continue" button → Return to Career Hub

---

### Lower Priority (Build Later)

**Load Game Screen** (`scenes/menus/load_game.tscn`)
- Show 5 save slots with info from `SaveManager.get_all_save_info()`
- Load selected slot, delete option

**Settings Screen** (`scenes/menus/settings.tscn`)
- Music/SFX volume sliders
- Auto-save toggle
- Back button

**Training Scene** (`scenes/training/training.tscn`)
- Mini-games that award stat XP
- Simple prototypes: target shooting, passing accuracy, etc.

**Team View** (`scenes/career/team_view.tscn`)
- List of teammates with stats
- Chemistry/relationship indicators

**Detailed Stats Screen** (`scenes/career/player_stats.tscn`)
- Full stat breakdown
- Skill tree / unlocked abilities
- Career history

---

## Code Style Guidelines

1. **Use type hints** everywhere: `func foo(bar: int) -> String:`
2. **Signal-driven architecture** - emit signals for state changes, connect in `_ready()`
3. **Use the autoloads** - Don't create new instances of managers, access via `GameManager`, `StatSystem`, etc.
4. **Resource classes** - PlayerData, TeamData, MatchData are Resources, use `.new()` to instantiate
5. **Scene transitions** - Use `get_tree().change_scene_to_file("res://path/to/scene.tscn")`
6. **UI nodes** - Use Control nodes, anchor presets, and VBox/HBoxContainers for layout
7. **Comments** - Add `##` doc comments to functions and classes

---

## Quick Reference: Key Function Calls

```gdscript
# Start a new career
GameManager.start_new_career("Player Name", "ST")

# Access player data
var player = GameManager.player_data
var overall = player.get_overall()
var secondary_stats = player.get_secondary_stats()

# Generate NPC teammates (already done in start_new_career)
var team = GameManager.current_team
var starting_11 = team.get_starting_eleven()

# Start a match
var opponent = TeamData.new()
opponent.name = "Rival High School"
opponent.generate_teammates(10, GameManager.current_career_phase)
GameManager.start_match(opponent, "league")

# During match - record events
GameManager.current_match.record_event("goal", {"is_player": true})
GameManager.current_match.record_event("pass", {"is_player": true, "successful": true})

# End match
var result = GameManager.current_match.generate_result()
GameManager.end_match(result)

# Roll for action success
var roll = StatSystem.roll_action_success(player_shooting, keeper_reflexes, 0.5)
if roll.success:
    # Goal!

# Generate dialogue
var dialogue = NarrativeEngine.generate_dialogue("coach", "praise")
print(dialogue.text)

# Save game
SaveManager.save_game(0)  # Slot 0
```

---

## Getting Started

1. Open the project in Godot 4.2+
2. Start with **Character Creation** - it's the first missing piece
3. Test by running from main menu → New Career
4. Build Career Hub next to see the game loop
5. Prototype the match system with simple visuals first, polish later

Good luck! The foundation is solid - now bring the gameplay to life! ⚽🎮
