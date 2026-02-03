# Season Awards Implementation - Development Journal

**Date:** January 30, 2026
**Author:** Development Session
**Scope:** Track match stats across the season for awards (Golden Boot, Top Assister, Golden Glove)

---

## Overview

Implemented a complete season awards system that tracks player statistics across league matches and computes individual awards at season end. The system tracks goals, assists, and clean sheets for all players (including NPCs) and determines award winners with proper tie-break rules.

---

## Implementation Phases

### Phase 1: NPC ID Stability

**Problem:** NPC IDs used `randi()` which generated non-deterministic IDs, breaking stat tracking across save/load.

**File Modified:** `scripts/data/team_data.gd`

**Changes:**
- Added `player_index` parameter to `_generate_npc_player()`
- Changed ID generation from `"npc_%d" % randi()` to deterministic format:
  ```gdscript
  var npc_id = "npc_%s_%s_%d" % [id.substr(0, 8), pos, player_index]
  ```
- Updated `generate_teammates()` to pass index when generating each player

---

### Phase 2: Season Player Stats Data Model

**New File:** `scripts/data/season_player_stats.gd`

Created a Resource class to track player stats across the league season:

| Property | Type | Description |
|----------|------|-------------|
| `player_stats` | Dictionary | player_id -> {team_id, name, position, goals, assists, clean_sheets, matches_played} |

**Methods:**
- `record_appearance(player, team_id)` - Track match appearances
- `record_goal(player_id)` - Increment goal count
- `record_assist(player_id)` - Increment assist count
- `record_clean_sheet(player_id)` - Track GK clean sheets
- `get_golden_boot_winner(total_matches)` - Top scorer
- `get_top_assister(total_matches)` - Top assist provider
- `get_golden_glove(total_matches)` - Best GK by clean sheets
- `get_all_awards(total_matches)` - All awards in one call
- `get_top_scorers(count)` / `get_top_assisters(count)` - Leaderboards
- `to_dict()` / `from_dict()` - Persistence

**Eligibility:** Minimum 50% of league matches played.

**Tie-break Rules:**
- Golden Boot: goals > assists > fewer matches
- Top Assister: assists > goals > fewer matches
- Golden Glove: clean sheets > fewer matches

---

### Phase 3: Goal Attribution in MatchSimulator

**File Modified:** `scripts/season/match_simulator.gd`

**Added Constants:**
```gdscript
const POSITION_GOAL_WEIGHTS = {
    "ST": 5.0, "WNG": 2.5, "CAM": 2.0, "CM": 1.0,
    "CDM": 0.5, "FB": 0.3, "CB": 0.2, "GK": 0.01
}
const ASSIST_CHANCE = 0.7
```

**Added Methods:**
- `_attribute_goals(team, goals_scored)` - Returns array of goal events with scorer/assister
- `_weighted_player_select(players, weights, exclude_id)` - Position+rating weighted selection

**Match Result Extension:**
```gdscript
result["home_goal_events"] = _attribute_goals(home_team, home_score)
result["away_goal_events"] = _attribute_goals(away_team, away_score)
```

---

### Phase 4: Stats Recording in LeagueData

**File Modified:** `scripts/data/league_data.gd`

**Added Properties:**
```gdscript
@export var player_stats: SeasonPlayerStats = null
@export var league_awards: Dictionary = {}
```

**Modified Methods:**
- `_initialize_standings()` - Now initializes `player_stats = SeasonPlayerStats.new()`
- `record_result()` - Extended signature to accept goal events:
  ```gdscript
  func record_result(home_id, away_id, home_score, away_score,
                     home_events: Array = [], away_events: Array = [])
  ```
- Added `_record_player_stats()` helper to:
  - Record appearances for all starting players
  - Record goals/assists from events
  - Record clean sheets when opponent scores 0
- Extended `to_dict()` / `from_dict()` for persistence

---

### Phase 5: Update SeasonManager

**File Modified:** `scripts/season/season_manager.gd`

**Changes:**
- Updated `_simulate_league_cpu_matches()` to pass goal events:
  ```gdscript
  current_season.league.record_result(
      result.home_team_id, result.away_team_id,
      result.home_score, result.away_score,
      result.get("home_goal_events", []),
      result.get("away_goal_events", [])
  )
  ```

---

### Phase 6: Award Computation

**File Modified:** `scripts/season/season_manager.gd`

**Changes in `_transition_to_qualifiers()`:**
```gdscript
# Compute and store league awards
if current_season.league and current_season.league.player_stats:
    var total_matches = current_season.league.player_stats.get_total_matches_in_league(current_season.league.teams.size())
    var awards = current_season.league.player_stats.get_all_awards(total_matches)
    current_season.league.league_awards = awards
```

---

### Phase 7: UI Integration

**File Modified:** `scripts/data/season_data.gd`

Extended `get_season_summary()` to include:
```gdscript
summary["league_awards"] = league.league_awards
summary["top_scorers"] = league.player_stats.get_top_scorers(5, total_matches)
summary["top_assisters"] = league.player_stats.get_top_assisters(5, total_matches)
```

**New Files:**
- `scripts/dashboard/panels/panel_season_awards.gd` - Panel controller
- `scenes/dashboard/panels/panel_season_awards.tscn` - Scene file

**Panel Features:**
- Award winner cards (Golden Boot, Playmaker Award, Golden Glove)
- Gold border highlighting for won awards
- Top 5 scorers and assisters leaderboards
- Player character name highlighted in green
- Medal colors for top 3 positions (gold/silver/bronze)

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `scripts/data/team_data.gd` | Deterministic NPC IDs |
| `scripts/season/match_simulator.gd` | Goal attribution logic |
| `scripts/data/league_data.gd` | player_stats, record_result extension, persistence |
| `scripts/season/season_manager.gd` | Pass events, trigger award computation |
| `scripts/data/season_data.gd` | Include awards in summary |

## New Files

| File | Purpose |
|------|---------|
| `scripts/data/season_player_stats.gd` | Stats tracking Resource class |
| `scripts/dashboard/panels/panel_season_awards.gd` | Awards panel script |
| `scenes/dashboard/panels/panel_season_awards.tscn` | Awards panel scene |

---

## Testing Notes

To verify implementation:
1. Start new season, simulate league matches via debug
2. Check that `league.player_stats` accumulates goals/assists
3. Verify NPC IDs stay consistent across save/load
4. Complete league and verify awards computed correctly
5. Open Season Awards panel to view leaderboards

---

## Related Documentation

- `docs/todo-season-awards.md` - Original feature specification

---
