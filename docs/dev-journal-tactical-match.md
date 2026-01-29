# Tactical Match System - Development Journal

**Date:** January 29, 2026
**Author:** Development Session
**Version:** 1.0.0 (Initial Implementation)

---

## Overview

This document chronicles the implementation of the turn-based tactical match system for Soccer RPG. The system replaces the previous probabilistic match simulation with an interactive hex-grid gameplay experience where the player controls their character in tactical combat-style soccer.

---

## Design Philosophy

### Core Concept
The tactical match system draws inspiration from turn-based tactical games (Fire Emblem, XCOM) applied to soccer. Each match plays out on a hex grid where positioning, stats, and player decisions determine outcomes rather than pure simulation.

### Key Design Decisions

1. **Hex Grid over Square Grid**
   - Hex grids provide 6 equidistant neighbors vs 4 (or 8 with diagonals)
   - More natural movement patterns for sports simulation
   - Better representation of "zones of control" around players

2. **Action Point System**
   - 3 AP per turn provides meaningful choices without analysis paralysis
   - Actions cost 1-2 AP, allowing 2-3 actions per turn
   - Sprint costs stamina instead of AP for risk/reward decisions

3. **Turn Structure (Player → Team → Opponent)**
   - Player acts first to maintain agency
   - AI teammates support without stealing spotlight
   - Opponent phase creates tension and reactive gameplay

4. **Stat Integration**
   - All actions use existing `StatSystem.roll_action_success()`
   - Stats directly affect gameplay (SPD = movement range, PAS = accuracy, etc.)
   - Maintains RPG progression feeling - better stats = more effective

---

## Implementation Log

### Phase 1: Foundation (hex_utils.gd)

**Goal:** Create the mathematical foundation for hex grid operations.

**Implementation Details:**
```
File: scripts/match/tactical/hex_utils.gd
Lines: ~280
Class: HexUtils (RefCounted)
```

**Key Functions:**
- `hex_to_pixel()` / `pixel_to_hex()` - Coordinate conversions using axial coordinates
- `hex_distance()` - Manhattan distance on hex grid
- `get_reachable_hexes()` - BFS for movement range calculation
- `find_path()` - A* pathfinding between hexes
- `get_hex_line()` - Bresenham-style line drawing for passes/shots
- `get_formation_positions()` - Maps formations (4-4-2, 4-3-3, etc.) to hex positions

**Technical Notes:**
- Using flat-top hexagon orientation
- Axial coordinates (q, r) with implicit s = -q - r
- Grid size: 21 wide × 14 tall (representing ~105m × 68m pitch)
- Hex size: 32 pixels from center to corner

**Challenges Solved:**
- Rounding fractional hex coordinates required cube coordinate conversion
- Formation mirroring for away team (flip x-coordinates)

---

### Phase 2: Unit System (player_unit.gd)

**Goal:** Create the player/NPC unit representation on the pitch.

**Implementation Details:**
```
File: scripts/match/tactical/player_unit.gd
Lines: ~180
Class: PlayerUnit (Node2D)
```

**Properties:**
- `hex_position: Vector2i` - Current grid position
- `action_points: int` - Remaining AP this turn (max 3)
- `stamina: int` - Fatigue system (0-100)
- `has_ball: bool` - Possession state
- `is_player_controlled: bool` - Distinguishes human player
- `stats: Dictionary` - Copied from PlayerData/NPC data

**Visual System:**
- Procedurally generated circle sprites with team colors
- Player character highlighted in gold
- Selection indicator ring
- Name label (truncated to 8 chars)
- AP indicator below unit

**Movement:**
- Path-based movement with lerp interpolation
- `move_speed = 200 pixels/second`
- Emits `move_completed` signal for AI sequencing

---

### Phase 3: Ball Physics (ball_controller.gd)

**Goal:** Manage ball state and movement during play.

**Implementation Details:**
```
File: scripts/match/tactical/ball_controller.gd
Lines: ~150
Class: BallController (Node2D)
```

**State Machine:**
```
POSSESSED ←→ LOOSE ←→ IN_FLIGHT
    ↓           ↓          ↓
 (with unit) (contestable) (pass/shot)
```

**Ball Flight:**
- Linear interpolation from origin to target
- `flight_speed = 400 pixels/second`
- Tracks current hex during flight for interception checks
- Emits `ball_arrived` when reaching destination

**Goal Detection:**
- HOME_GOAL_HEX = (0, 7)
- AWAY_GOAL_HEX = (20, 7)
- `goal_scored` signal with `is_home_goal` parameter

---

### Phase 4: Action Resolution (action_resolver.gd)

**Goal:** Execute game actions with stat-based outcomes.

**Implementation Details:**
```
File: scripts/match/tactical/action_resolver.gd
Lines: ~300
Class: ActionResolver (RefCounted, static methods)
```

**Action Costs:**
| Action | AP Cost | Primary Stat |
|--------|---------|--------------|
| Move | 1 per 2 hexes | SPD (range) |
| Pass | 1 | PAS |
| Through Ball | 2 | PAS + MEN |
| Shoot | 2 | SHO |
| Dribble | 1 | TEC vs DEF |
| Tackle | 1 | DEF vs TEC |
| Sprint | 0 (10 stamina) | - |

**Resolution Flow (Pass Example):**
1. Check AP cost
2. Check ball possession
3. Calculate difficulty from distance
4. Roll `StatSystem.roll_action_success(PAS, 0, difficulty)`
5. If success, check interception along path
6. Record event to MatchData
7. Return result dictionary

**Interception System:**
- Check defenders within 1 hex of pass line
- Each defender rolls interception (DEF + MEN based)
- Through balls have 0.7x interception difficulty

**Tackle Fouls:**
- Base 15% foul chance
- +15% if tackle fails
- 2% red card, 15% yellow card on foul

---

### Phase 5: AI Systems

#### Teammate AI (teammate_ai.gd)

**Goal:** Control friendly units to support player without stealing spotlight.

**Implementation Details:**
```
File: scripts/match/tactical/ai/teammate_ai.gd
Lines: ~280
Class: TeammateAI (RefCounted, static methods)
```

**Decision Tree:**
```
Has Ball?
├── Yes → Check shooting opportunity
│         ├── Under pressure? → Find safe pass
│         └── Look for forward pass → Carry ball
└── No → Team has possession?
         ├── Yes → Support run / Hold position
         └── No → Defensive positioning
```

**Position Behaviors (weights by role):**
- GK: 90% stay, 10% position
- CB/CDM: High stay, medium position
- CM/CAM: Low stay, high support
- WNG/ST: Very low stay, high support runs

#### Opponent AI (opponent_ai.gd)

**Goal:** Create challenging opposition that respects team tactics.

**Implementation Details:**
```
File: scripts/match/tactical/ai/opponent_ai.gd
Lines: ~350
Class: OpponentAI (RefCounted, static methods)
```

**Tactics Integration:**
```gdscript
MENTALITY_MODIFIERS = {
    "defensive": {"press_range": 3, "hold_line": 0.7, "shoot_threshold": 4},
    "balanced": {"press_range": 5, "hold_line": 0.5, "shoot_threshold": 5},
    "attacking": {"press_range": 7, "hold_line": 0.3, "shoot_threshold": 6},
    "all-out-attack": {"press_range": 10, "hold_line": 0.1, "shoot_threshold": 8}
}
```

**Decision Priorities:**
1. Shooting opportunity (if close enough based on mentality)
2. Escape pressure with pass/dribble
3. Through ball opportunity
4. Forward pass progression
5. Ball carry
6. Safe possession

**Defensive AI:**
- Goalkeeper positioning between ball and goal
- Adjacent tackle opportunities
- Press ball carrier within press_range
- Hold defensive line (probability based on mentality)
- Mark nearest unmarked attacker

---

### Phase 6: Match Controller (match_controller.gd)

**Goal:** Orchestrate all systems into cohesive gameplay.

**Implementation Details:**
```
File: scripts/match/tactical/match_controller.gd
Lines: ~550
Class: MatchController (Node2D)
```

**Turn Flow:**
```
_start_player_turn()
    ↓ (player actions + end turn)
_advance_to_team_phase()
    ↓ (await _process_team_ai())
_advance_to_opponent_phase()
    ↓ (await _process_opponent_ai())
_end_turn()
    ↓ (advance minute, check half/full time)
_start_player_turn() [loop]
```

**Match Timing:**
- 45 turns per half (90 turns total)
- 2 minutes per turn
- Half-time triggers formation reset and side switch
- Full-time triggers result generation and scene transition

**Input Handling:**
- Left click: Select unit / Execute action at hex
- Right click: Cancel current action
- Only active during PLAYER phase

**Unit Spawning:**
- Reads `get_starting_eleven()` from both teams
- Maps to formation positions via `HexUtils.get_formation_positions()`
- Identifies player character by `is_player` flag in data

**AI Execution:**
- Each AI unit gets up to 3 actions per turn
- 0.1 second delay between actions for visibility
- Awaits movement/ball flight completion before next action

---

### Phase 7: Scene & UI (tactical_match.tscn)

**Goal:** Visual presentation and player interface.

**Scene Structure:**
```
TacticalMatch (Node2D)
├── Camera2D (centered on pitch)
├── PitchBackground (green ColorRect)
├── PitchLines (Line2D children for markings)
├── MatchController (game logic)
└── UI (CanvasLayer)
    ├── TopBar (score, teams, minute)
    ├── ActionPanel (buttons, AP display)
    ├── InfoPanel (selected unit stats)
    └── UIController (button handlers)
```

**Pitch Dimensions:**
- Background: 1376 × 960 pixels (with margin)
- Lines drawn at key positions (boxes, center circle)
- Camera zoom: 0.9x for overview

**Action Panel Buttons:**
- Move (1) - Always available with AP
- Pass (1) - Requires ball possession
- Shoot (2) - Requires ball possession
- Dribble (1) - Requires ball possession
- Tackle (1) - Requires adjacent ball carrier
- End Turn - Always available

---

## Integration Points

### Entry Point (pre_match.gd)
```gdscript
func _on_play_pressed() -> void:
    AudioManager.play_ui_click()
    GameManager.change_state(GameManager.GameState.IN_MATCH)
    get_tree().change_scene_to_file("res://scenes/match/tactical/tactical_match.tscn")
```

### Exit Point (match_controller.gd)
```gdscript
func _end_match() -> void:
    match_phase = MatchPhase.FULL_TIME
    match_data.home_score = home_score
    match_data.away_score = away_score
    var result = match_data.generate_result()
    GameManager.end_match(result)
    get_tree().change_scene_to_file("res://scenes/match/post_match.tscn")
```

### Stat Recording
All actions record events to MatchData:
```gdscript
match_data.record_event("pass", {
    "is_player": passer.is_player_controlled,
    "successful": roll.success,
    "distance": distance
})
```

This ensures post-match stats, XP, and narrative generation work correctly.

---

## File Summary

| File | Lines | Purpose |
|------|-------|---------|
| hex_utils.gd | ~280 | Grid math, pathfinding |
| player_unit.gd | ~180 | Unit state and visuals |
| ball_controller.gd | ~150 | Ball state machine |
| action_resolver.gd | ~300 | Action execution |
| match_controller.gd | ~550 | Main orchestrator |
| tactical_ui_controller.gd | ~150 | UI handling |
| teammate_ai.gd | ~280 | Friendly AI |
| opponent_ai.gd | ~350 | Enemy AI |
| tactical_match.tscn | ~185 | Main scene |
| player_unit.tscn | ~10 | Unit prefab |

**Total:** ~2,400 lines of new code

---

## Known Limitations & Future Work

### Current Limitations
1. **Set Pieces** - Free kicks, corners, penalties not implemented (ball just goes loose)
2. **Substitutions** - Not available during match
3. **Animations** - Units are simple circles, no sprite animations
4. **Sound Effects** - No match audio (whistles, kicks, crowd)
5. **Offside** - Not enforced
6. **Injury System** - Not active during tactical play

### Planned Enhancements (Phase 2)
1. Set piece positioning and execution
2. Stamina drain during match affecting stats
3. Card accumulation leading to suspensions
4. Better visual feedback (shot trajectories, pass lines)
5. Commentary/event log panel

### Planned Enhancements (Phase 3)
1. Skill system integration (special moves consuming skill slots)
2. Weather effects on gameplay
3. Home/away crowd influence
4. Replay highlights of key moments
5. Tactical adjustments mid-match (formation changes)

---

## Testing Checklist

- [ ] Launch tactical match from pre-match screen
- [ ] Verify 22 players spawn in correct formations
- [ ] Player unit highlighted in gold
- [ ] Click to select player unit
- [ ] Movement range highlights appear
- [ ] Click valid hex to move
- [ ] AP decrements correctly
- [ ] Pass action highlights teammates
- [ ] Pass succeeds/fails based on stats
- [ ] Shoot action targets goal
- [ ] Goals increment score
- [ ] Kickoff reset after goal
- [ ] AI teammates take actions
- [ ] AI opponents take actions
- [ ] Half-time side switch occurs
- [ ] Full-time transitions to post-match
- [ ] Stats recorded to MatchData
- [ ] Post-match screen shows correct data

---

## Lessons Learned

1. **Hex math is tricky** - Axial coordinates simplify most operations, but rounding requires cube coordinate conversion.

2. **Async AI is essential** - Using `await` for AI actions prevents the game from feeling like it's frozen during AI turns.

3. **Stat integration early** - Building on existing StatSystem from day one ensured consistent feel with the RPG elements.

4. **Signal-driven architecture** - Extensive use of signals made components loosely coupled and easier to debug.

5. **Static classes for utilities** - HexUtils, ActionResolver, and AI classes as static methods on RefCounted classes keeps memory clean and access simple.

---

## Conclusion

The tactical match system provides a solid foundation for interactive soccer gameplay that integrates with the existing RPG progression systems. The modular architecture allows for iterative enhancement without major refactoring.

Next steps: Playtesting to balance action costs, stat influences, and AI behavior, followed by visual polish and set piece implementation.
