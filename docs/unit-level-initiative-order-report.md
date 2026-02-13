# Unit-Level Initiative Order Report

## Summary
We implemented a per-unit initiative order for tactical match turns in `MatchController` so the next actor is chosen by unit initiative each match minute, not by fixed Team → Opponent sequencing.

## What changed
- Added initiative queue state in `scripts/match/tactical/match_controller.gd`:
  - `initiative_order: Array[PlayerUnit]`
  - `initiative_cursor: int`
  - `is_player_turn_active: bool`
- Replaced fixed turn-phase flow (`PLAYER -> TEAM -> OPPONENT`) with queue-driven flow:
  - Start-of-turn setup resets all units.
  - Build sorted initiative order from units.
  - Process each actor in order:
    - Player actor → `TurnPhase.PLAYER` and input waits.
    - AI actor → `TurnPhase.TEAM` or `TurnPhase.OPPONENT` and performs up to 3 AI actions.
  - Turn advances when initiative queue is exhausted.
- Added initiative scoring helpers:
  - `_build_initiative_order`
  - `_calculate_unit_initiative`
  - `_sort_initiative_entries`
  - `_get_next_initiative_actor`
- Added AI turn runner:
  - `_process_ai_unit_turn`
- Kept existing half-time and minute progression, score flow, and event recording intact.

## Initiative formula
Current implementation currently uses:
- `SPD * 2`
- + player control bonus (+2)
- + goalkeeper penalty (-3)
- + random variance (`randi_range(0, 12)`)

This keeps turns responsive and still lets speed-driven differences matter without fully removing momentum from stat progression.

## Impact on gameplay
- No longer a rigid “all teammates, then all opponents” phase lock.
- Faster perceived back-and-forth potential: stronger players can act earlier regardless of team.
- Player still has explicit control of when to end their initiative turn.
- Existing action economy (AP) and 45-turn minute pacing are preserved.

## Operational notes for team
- If we want this to be deterministic for replay/balancing analysis, remove initiative jitter.
- If we want deeper fairness, tie-breaker can be expanded to include role/fitness/fatigue context.
- Next likely iteration: expose initiative order in UI for readability in commentary/log panel.
