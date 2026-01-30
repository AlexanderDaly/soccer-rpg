# Bug Fixes Session - Development Journal

**Date:** January 29, 2026
**Author:** Development Session
**Scope:** Critical bug fixes, code review remediation, UI fixes

---

## Overview

This session addressed multiple bugs across the codebase, including a game-blocking crash, 6 issues identified in code review (Critical to Low priority), and a desktop UI interaction bug.

---

## Fixes Applied

### 1. Character Creation Crash Fix

**Problem:** Game crashed when clicking "New Game" button.

**Root Causes & Fixes:**

| Issue | File | Fix |
|-------|------|-----|
| Missing script preload | `character_creation.gd` | Changed `preload()` to `load()` for dynamically loaded script |
| Invalid theme override syntax | `character_creation.gd` | Changed `theme_override_constants["separation"] = 10` to `add_theme_constant_override("separation", 10)` |
| Invalid font size override syntax | `character_creation.gd` | Changed `theme_override_font_sizes["font_size"] = 14` to `add_theme_font_size_override("font_size", 14)` |
| Null reference in get_node() | `character_creation.gd` | Stored `summary_container` as class variable instead of inline get_node() |

**Result:** New Game flow now works correctly.

---

### 2. Code Review Bug Fixes

Six issues were identified in `docs/code_review.md` and fixed in priority order:

#### 2.1 Critical: Off-Target Shots Can Still Score

**Problem:** When a shot was determined to be "off_target", the code still called `ball.start_shot()` which could result in a goal.

**Files Modified:** `scripts/match/tactical/match_controller.gd`

**Changes:**
```gdscript
# Before (line ~383 for player, ~679 for AI):
"off_target":
    ball.start_shot(player_unit, target_hex)

# After:
"off_target":
    var miss_hex = _get_off_target_hex(target_hex)
    ball.make_loose(miss_hex)
```

**Added Helper Function:**
```gdscript
func _get_off_target_hex(goal_hex: Vector2i) -> Vector2i:
    var offset_x = 1 if goal_hex.x < HexUtils.GRID_WIDTH / 2 else -1
    var offset_y = randi_range(-3, 3)
    if offset_y == 0:
        offset_y = 1 if randf() > 0.5 else -1
    return Vector2i(
        clampi(goal_hex.x + offset_x, 0, HexUtils.GRID_WIDTH - 1),
        clampi(goal_hex.y + offset_y, 0, HexUtils.GRID_HEIGHT - 1)
    )
```

---

#### 2.2 High: Goal Events Double-Count Shots

**Problem:** When a goal was recorded, `match_data.gd` incremented both `shots` and `shots_on_target`, but these were already tracked by the separate "shot" event.

**File Modified:** `scripts/data/match_data.gd`

**Change:**
```gdscript
# Before:
"goal":
    player_stats.goals += 1
    player_stats.shots += 1
    player_stats.shots_on_target += 1

# After:
"goal":
    player_stats.goals += 1
    # Note: shots and shots_on_target are tracked by the "shot" event
```

---

#### 2.3 High: Save/Load Loses Key Player/Team State

**Problem:** `_serialize_player()` manually selected fields, missing many properties. Team data was not saved at all.

**File Modified:** `scripts/core/save_manager.gd`

**Changes:**

1. Use complete player serialization:
```gdscript
# Before:
func _serialize_player() -> Dictionary:
    return {
        "name": player.name,
        "position": player.position,
        # ... manually selected fields
    }

# After:
func _serialize_player() -> Dictionary:
    if not GameManager.player_data:
        return {}
    return GameManager.player_data.to_dict()
```

2. Added team serialization:
```gdscript
func _serialize_team() -> Dictionary:
    if not GameManager.current_team:
        return {}
    return GameManager.current_team.to_dict()
```

3. Added to `_collect_save_data()`:
```gdscript
"team": _serialize_team(),
```

4. Added team restoration in `_apply_save_data()`:
```gdscript
if "team" in data and data.team:
    GameManager.current_team = TeamData.new()
    GameManager.current_team.from_dict(data.team)
```

---

#### 2.4 Medium: Match Duration Doubled

**Problem:** With `MINUTES_PER_TURN = 2` and 45 turns per half, matches lasted 180 minutes instead of 90.

**File Modified:** `scripts/match/tactical/match_controller.gd`

**Change:**
```gdscript
# Before:
const MINUTES_PER_TURN: int = 2

# After:
const MINUTES_PER_TURN: int = 1  # 45 turns * 1 minute = 45 min per half = 90 min total
```

---

#### 2.5 Medium: Pass Accuracy Can Exceed 100%

**Problem:** In match simulation, pass accuracy was calculated as `0.7 + (player.stats.PAS / 200.0)` which could exceed 1.0 for high PAS values.

**File Modified:** `scripts/match/pre_match.gd`

**Change:**
```gdscript
# Before:
var pass_accuracy = 0.7 + (player.stats.PAS / 200.0)

# After:
var pass_accuracy = minf(0.7 + (player.stats.PAS / 200.0), 1.0)
```

---

#### 2.6 Low: Unused Teammate Quality Variance

**Problem:** `adjusted_quality` was calculated after stats were generated, making the variance have no effect.

**File Modified:** `scripts/data/team_data.gd`

**Change:**
```gdscript
# Before:
var npc_stats = StatSystem.generate_npc_stats(pos, quality)
var quality_variance = randi_range(-1, 1)
var adjusted_quality = clampi(quality + quality_variance, 1, 4)

# After:
var quality_variance = randi_range(-1, 1)
var adjusted_quality = clampi(quality + quality_variance, 1, 4)
var npc_stats = StatSystem.generate_npc_stats(pos, adjusted_quality)
```

---

### 3. Desktop Windows Not Interactive

**Problem:** Windows inside the in-game desktop could not be interacted with - buttons didn't respond and close/minimize controls were non-functional.

**Root Cause:** `WindowLayer` in `desktop_shell.tscn` had `mouse_filter = 2` (MOUSE_FILTER_IGNORE), which prevents child controls from receiving mouse events.

**File Modified:** `scenes/desktop/desktop_shell.tscn`

**Changes:**
```
# Before:
[node name="WindowLayer" ...]
mouse_filter = 2

[node name="NotificationContainer" ...]
mouse_filter = 2

# After:
[node name="WindowLayer" ...]
mouse_filter = 1

[node name="NotificationContainer" ...]
mouse_filter = 1
```

**Result:** Desktop app windows now receive mouse events and are fully interactive.

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `scripts/menus/character_creation.gd` | Fixed preload, theme overrides, null reference |
| `scripts/match/tactical/match_controller.gd` | Fixed off-target shots, match duration |
| `scripts/data/match_data.gd` | Removed shot double-counting in goal handler |
| `scripts/core/save_manager.gd` | Complete player/team serialization |
| `scripts/match/pre_match.gd` | Clamped pass accuracy |
| `scripts/data/team_data.gd` | Fixed quality variance ordering |
| `scenes/desktop/desktop_shell.tscn` | Fixed mouse_filter for WindowLayer and NotificationContainer |

---

## Testing Notes

- Character creation flow: Verified working
- Match system: Off-target shots no longer score
- Save/Load: Full player and team data now persists
- Desktop UI: Windows are now interactive

---

## Related Documentation

- `docs/code_review.md` - Original code review findings
- `docs/bug_report_desktop_windows_input.md` - Desktop interaction bug report

---
