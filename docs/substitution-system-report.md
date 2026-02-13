# Substitution System Implementation Report

## Overview
Added a tactical-match substitution flow with in-match lineup replacement for the player-controlled side.

## What changed
- `scripts/match/tactical/match_controller.gd`
  - Added substitution state tracking:
    - `home_lineup`, `away_lineup`
    - `home_substitutions_used`, `away_substitutions_used`
    - `MAX_SUBSTITUTIONS_PER_SIDE = 3`
  - Added runtime roster helpers to identify bench candidates from active squad data.
  - Added player-facing APIs used by UI:
    - `get_substitution_candidates_for_player_team()`
    - `get_remaining_substitutions()`
    - `can_player_substitute()`
    - `perform_substitution()`
  - Added substitution execution logic in `_apply_substitution(...)` to:
    - Replace the outgoing on-field `PlayerUnit` instance
    - Instantiate the incoming player
    - Update lineup arrays, unit arrays, and initiative order references
    - Transfer ball possession if outgoing had possession
    - Emit `substitution_executed` and record a `substitution` match event

- `scripts/match/tactical/tactical_ui_controller.gd`
  - Added Substitute button binding and handler:
    - New `@onready` binding for `SubstituteBtn`
    - New `_on_substitute_btn_pressed()` handler
    - Substitution button disables unless valid
    - Button label updates with remaining subs

- `scenes/match/tactical/tactical_match.tscn`
  - Added `SubstituteBtn` under the action button grid
  - Connected signal to `_on_substitute_btn_pressed()`

## Notes / current scope
- The current substitution selection is automated:
  - **Outgoing:** lowest-rated non-player unit (falls back to any unit if needed)
  - **Incoming:** highest-rated available bench player
- This keeps implementation lightweight while providing full gameplay capability.
- Substitution is only enabled when:
  - It is the player turn
  - Player turn actions are active
  - Current player unit is at full AP
  - Remaining substitution budget exists
  - Bench candidates are available

## Team-facing follow-up suggestions
- Add explicit UI for selecting outgoing and incoming players.
- Add support for opponent-side substitutions and scenario rules (time windows/injury flags).
- Add substitution animation/feedback when swap occurs.
