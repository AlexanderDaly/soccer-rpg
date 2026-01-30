# Code Review Findings (2026-01-29)

## Summary
This review highlights a few correctness issues in the tactical match flow and data persistence that can cause incorrect match results or lost progress. No code changes were made.

## Findings

### Critical
- **Off-target shots can still score.**
  - In the shot flow, the `"off_target"` branch still calls `ball.start_shot(...)`, which animates the ball to the goal hex. The ball controller only checks the landing hex to decide a goal, so off-target shots can incorrectly score if the target is the goal hex.
  - Affects both player and AI shot resolution.
  - Files:
    - `scripts/match/tactical/match_controller.gd:383`
    - `scripts/match/tactical/match_controller.gd:679`
    - `scripts/match/tactical/ball_controller.gd:150`

### High
- **Goal events double-count shots/on-target.**
  - `ActionResolver.execute_shot()` records a `"shot"` event with `on_target: true`, then records a `"goal"` event. The match data handler increments shots/on-target on `"goal"` as well, inflating shot stats.
  - Files:
    - `scripts/match/tactical/action_resolver.gd:251`
    - `scripts/data/match_data.gd:121`

- **Save/load loses key player/team state.**
  - Save serialization only includes a subset of `PlayerData` fields (e.g., no `stat_xp`, `equipped_skills`, `appearance`, `personality_traits`, `dominant_foot`, etc.).
  - `GameManager.current_team` is not serialized/restored, which can break team/desktop screens after load.
  - Files:
    - `scripts/core/save_manager.gd:175`
    - `scripts/core/save_manager.gd:205`

### Medium
- **Match duration likely doubled.**
  - With `TURNS_PER_HALF = 45` and `MINUTES_PER_TURN = 2`, the match lasts 180 minutes (90 per half). If a 90-minute match is intended, one of these constants is wrong.
  - Files:
    - `scripts/match/tactical/match_controller.gd:35`
    - `scripts/match/tactical/match_controller.gd:516`

- **Pass accuracy can exceed 100% in sim.**
  - Pre-match sim uses `0.7 + (PAS / 200.0)` which can exceed 1.0, resulting in guaranteed passes. Clamp to 1.0.
  - File:
    - `scripts/match/pre_match.gd:201`

### Low
- **Unused teammate quality variance.**
  - `adjusted_quality` is calculated but never used, so quality variance has no effect.
  - File:
    - `scripts/data/team_data.gd:100`

## Notes / Questions
- Is a 180-minute match intentional for tactical mode?
- Should goals increment shots, or should goal events avoid incrementing shot counters?
- Should save/load preserve full `PlayerData` and `current_team` for consistent UI behavior?
