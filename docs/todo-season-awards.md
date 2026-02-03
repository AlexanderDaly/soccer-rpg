# TODO: Season Awards (Top Scorer / Top Assister)

**Status:** IMPLEMENTED (January 30, 2026)

Goal: track match stats across the season to award titles like Top Goal Scorer and Top Assister at season end.

## Dependencies / Prerequisites
- [x] **Critical**: Modify `MatchSimulator` to attribute goals/assists to NPC players
  - Use team roster from `TeamData.players[]`
  - Weight by position (ST > WNG > CAM > CM for goals)
  - Probability based on player `overall` rating

## Data Model
- [x] Follow `CareerManager.career_stats` pattern for structure
- [x] Decide stat granularity: per-player stats for all teams vs team-only aggregates.
- [x] Introduce a season stats container (new Resource or extend `SeasonData`) to store:
  - [x] player_id -> {team_id, name, goals, assists, matches_played}
  - [x] team_id -> {goals_for, goals_against}
- [x] Add stable NPC player identities (id, name, team_id, position) for season tracking.
- [x] Define award categories and tie-break rules (e.g., goals then assists, fewer matches).
- [x] Consider Golden Glove award (most clean sheets for goalkeepers)
- [x] Scope: League matches only (exclude qualifiers/nationals)

## Match Recording
- [x] Extend `MatchData` result payload to include scorer/assist events for both teams.
- [ ] Tactical matches: record goal events for all scorers (not just player) so season totals can be updated.
- [x] Simulated matches (`MatchSimulator`) generate per-team and per-player goal/assist distributions:
  - [x] Use team roster from `TeamData.players[]`
  - [x] Weight by position (ST > WNG > CAM > CM for goals)
  - [x] Probability based on player `overall` rating
- [x] Ensure match results include matchday context (league vs tournament) for award eligibility.

## Aggregation Flow
- [x] Add a single entry point in `SeasonManager` to ingest match results and update season stats.
- [x] Specify hook location: Extend `LeagueData.record_result()` or add parallel call in `SeasonManager`
- [x] Update league results (player and CPU matches) to call the new aggregation hook.
- [x] Update tournament results to either:
  - [x] contribute to awards (if desired), or
  - [x] be excluded explicitly. *(Excluded - league only)*

## Award Computation
- [x] Implement `SeasonManager.compute_awards()` or `SeasonData.get_awards()`:
  - [x] Top Goal Scorer (Golden Boot)
  - [x] Top Assister
  - [x] Golden Glove (optional - most clean sheets for goalkeepers)
- [x] Define minimum matches for eligibility (e.g., 50% of league matches)
- [x] Tie-break: If goals equal, compare assists. If still tied, fewer matches played wins.
- [x] Store computed awards in season summary for UI and save/load.

## Edge Cases
- [ ] Player transfers mid-season (if implemented later)
- [ ] What if player wins an award? (narrative event, reputation boost, milestone?)
- [x] Handle case where controlled player wins vs NPC wins *(UI highlights player name)*

## UI / UX
- [x] Add awards section to post-season summary screen/panel.
- [x] Add notification at season end (e.g., Desktop notification toast).
- [x] Optional: show running leaders in League Table panel.
- [x] Add UI in desktop/phone interface *(panel_season_awards.tscn)*

## Persistence
- [x] Serialize season stats and awards in `SeasonData.to_dict()` / `.from_dict()`.
- [x] Ensure `SaveManager` captures the new season stats without data loss.

## Tests
- [ ] Unit tests for stat accumulation across multiple matches.
- [ ] Unit tests for tie-break logic.
- [ ] Integration test for season end award generation.

## File References
- `scripts/season/match_simulator.gd` - Goal attribution added
- `scripts/data/league_data.gd` - Extended with player_stats, league_awards
- `scripts/data/season_player_stats.gd` - **NEW** Stats tracking Resource
- `scripts/season/season_manager.gd` - Award computation on phase transition
- `scripts/data/season_data.gd` - Awards included in summary
- `scripts/dashboard/panels/panel_season_awards.gd` - **NEW** Awards UI panel
- `scenes/dashboard/panels/panel_season_awards.tscn` - **NEW** Awards scene

## Implementation Order
This feature should be implemented **before** NPC Persona Generator as it:
1. Is more foundational (no external API dependency)
2. Provides award data that can feed NPC persona context

---

## Implementation Notes (January 30, 2026)

### Completed
- NPC IDs now deterministic: `npc_{team_id_prefix}_{position}_{index}`
- SeasonPlayerStats Resource tracks all player stats
- MatchSimulator attributes goals with position-weighted selection
- LeagueData records player stats via extended record_result()
- Awards computed at league completion in _transition_to_qualifiers()
- Season summary includes awards and leaderboards
- UI panel created for viewing awards

### Remaining Work
- Tactical match goal attribution (currently only simulated matches track stats)
- Unit tests
