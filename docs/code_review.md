# Code Review Findings (2026-01-29)

## Summary
This review highlights a few correctness issues in the tactical match flow and data persistence that can cause incorrect match results or lost progress.

**Update (2026-01-30):** All identified issues have been verified as fixed.

## Findings

### Critical
- **~~Off-target shots can still score.~~** ✅ FIXED
  - ~~In the shot flow, the `"off_target"` branch still calls `ball.start_shot(...)`, which animates the ball to the goal hex.~~
  - **Fix:** Off-target shots now call `ball.make_loose(miss_hex)` instead of `ball.start_shot()`, preventing the goal-check logic from triggering.
  - Files:
    - `scripts/match/tactical/match_controller.gd:383-386` - Uses `ball.make_loose()`
    - `scripts/match/tactical/match_controller.gd:680-682` - Uses `ball.make_loose()`

### High
- **~~Goal events double-count shots/on-target.~~** ✅ FIXED
  - ~~`ActionResolver.execute_shot()` records a `"shot"` event with `on_target: true`, then records a `"goal"` event. The match data handler increments shots/on-target on `"goal"` as well.~~
  - **Fix:** The `"goal"` event handler in `match_data.gd` now only increments `player_stats.goals`, with a comment noting that shots/shots_on_target are tracked separately by the `"shot"` event.
  - Files:
    - `scripts/data/match_data.gd:133-135`

- **~~Save/load loses key player/team state.~~** ✅ FIXED
  - ~~Save serialization only includes a subset of `PlayerData` fields.~~
  - **Fix:** `PlayerData.to_dict()` now serializes all fields including `stat_xp`, `equipped_skills`, `appearance`, `personality_traits`, `dominant_foot`, `training_records`. Team data is also properly serialized/restored.
  - Files:
    - `scripts/data/player_data.gd:217-239` - Complete serialization
    - `scripts/core/save_manager.gd:283-285` - Team restoration

### Medium
- **~~Match duration likely doubled.~~** ✅ FIXED
  - ~~With `TURNS_PER_HALF = 45` and `MINUTES_PER_TURN = 2`, the match lasts 180 minutes.~~
  - **Fix:** `MINUTES_PER_TURN` is now 1, giving correct 90-minute matches.
  - File:
    - `scripts/match/tactical/match_controller.gd:36`

- **~~Pass accuracy can exceed 100% in sim.~~** ✅ FIXED
  - ~~Pre-match sim uses `0.7 + (PAS / 200.0)` which can exceed 1.0.~~
  - **Fix:** Now uses `minf(0.7 + (player.stats.PAS / 200.0), 1.0)` to clamp.
  - File:
    - `scripts/match/pre_match.gd:201`

### Low
- **~~Unused teammate quality variance.~~** ✅ FIXED
  - ~~`adjusted_quality` is calculated but never used.~~
  - **Fix:** `adjusted_quality` is now passed to `StatSystem.generate_npc_stats()`.
  - File:
    - `scripts/data/team_data.gd:105`

## Resolution
All issues from the original code review have been addressed. No further action required.
