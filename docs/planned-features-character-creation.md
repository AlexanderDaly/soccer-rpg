# Character Creation Screen - Planned Features

This document tracks planned improvements for the character creation screen (`scenes/menus/character_creation.tscn`).

## Status Legend
- [ ] Not started
- [x] Completed

---

## Gameplay/RPG Additions

### Nationality Selection
- [x] Add country/nationality dropdown or searchable list
- [ ] Could affect starting league options or unlock regional storylines
- [x] Flag icons for visual identification (73 SVG flags in assets/flags/)

### Dominant Foot
- [x] Add Left/Right/Both foot preference selection
- [ ] Affects gameplay mechanics (shooting, passing angles)
- [ ] Could influence position suitability ratings

### Starting Age
- [x] Fixed starting age of 14 (high school freshman)
- [x] All players begin at the same age for consistent career progression
- [x] Age stored in PlayerData and increments as career progresses

### Personality Traits
- [x] Select 0-2 personality traits from a curated list of 10 traits
- [ ] Traits influence dialogue options during story events
- [ ] Affects team chemistry and manager relationships
- [x] Implemented traits: Leader, Hot-headed, Professional, Fan Favorite, Introvert, Showboat, Workhorse, Clinical, Ambitious, Loyal

---

## UX Improvements

### Randomize Button
- [x] Add "Randomize" button for appearance options
- [x] Single click generates random values for all appearance fields
- [x] Common feature in character creators, speeds up the process

### Position Field Diagram
- [x] Add visual mini soccer pitch graphic
- [x] Highlight the zone where selected position typically plays
- [x] Helps players unfamiliar with position abbreviations
- [x] Animated highlight transition when changing positions
- [x] Mirrored highlights for FB/WNG showing both flanks

### Stat Tooltips
- [x] Add hover/focus tooltips for each stat
- [x] Explain what the stat affects in gameplay
- [x] Examples:
  - "Pace - Affects sprint speed and acceleration"
  - "Shooting - Determines shot power and accuracy"
  - "Passing - Influences pass accuracy and vision"

### Name Validation Feedback
- [x] Show hint text below name input: "Minimum 2 characters"
- [x] Real-time feedback as user types
- [x] Clear visual indication when name is valid

### Confirmation Dialog
- [x] Show confirmation before starting career
- [x] Display summary: Name, Position, Nationality, Dominant Foot, Age, Traits
- [x] Prevents accidental career starts with wrong settings

---

## Polish

### Character Silhouette/Avatar Preview
- [ ] Add visual representation of the player character
- [ ] Reflect appearance choices (hair, build, skin tone)
- [ ] Could be simple silhouette or stylized avatar

### Animated Stat Bars
- [x] Tween/animate stat bars when switching positions
- [x] Smooth transitions make the UI feel more responsive
- [x] Uses Godot's Tween system with EASE_OUT TRANS_CUBIC (0.3s duration)

### Position Button Styling
- [x] Group positions by category with visual separators
- [x] Categories: Defense (GK, CB, FB) / Midfield (CDM, CM, CAM) / Attack (WNG, ST)
- [x] Color coding or icons per category

### Keyboard Shortcuts
- [x] Arrow keys to navigate position selection
- [x] Tab to move between sections (Name → Position → Appearance → Traits)
- [x] Enter to confirm/start when ready
- [x] Escape to go back (or close confirmation dialog)

---

## Advanced Features (Lower Priority)

### Difficulty Selection
- [ ] Add difficulty options: Casual / Normal / Hardcore
- [ ] Affects progression speed and AI opponent difficulty
- [ ] Hardcore could include permadeath or stricter contract rules

### Background Story Selection
- [ ] Choose player origin story
- [ ] Options:
  - **Academy Product** - Balanced start, good club reputation
  - **Late Bloomer** - Lower starting stats, faster growth rate
  - **Prodigy** - Higher starting stats, more pressure/expectations
- [ ] Affects starting stats, reputation, and early story events

---

## Implementation Notes

- Current implementation: `scripts/ui/character_creation.gd`
- Scene file: `scenes/menus/character_creation.tscn`
- Player data stored via: `GameManager.start_new_career()`
- Stats system: `StatSystem` singleton
- **Nationality selection**: Implemented with searchable dropdown (73 nations), stored in `PlayerData.nationality`
- **Flag icons**: SVG flags loaded from `res://assets/flags/{CODE}.svg`, displayed in selector and dropdown list
- **Dominant foot**: Implemented with toggle buttons (Left/Right/Both), stored in `PlayerData.dominant_foot`
- **Starting age**: Fixed at 14 (high school), stored in `PlayerData.age`
- **Personality traits**: Implemented with checkbox selection (0-2 traits), stored in `PlayerData.personality_traits`
- **Position field diagram**: Mini pitch graphic with animated position highlight zones, mirrors for FB/WNG
- **Stat tooltips**: Hover tooltips on each stat row explaining gameplay effects
- **Keyboard shortcuts**: `_unhandled_key_input()` handles Tab (sections), Arrow keys (positions), Enter (start), Escape (back)

## Priority Recommendations

**Quick Wins (High impact, low effort):**
1. ~~Randomize button~~ (DONE)
2. ~~Name validation feedback~~ (DONE)
3. ~~Dominant foot selection~~ (DONE)

**Medium Effort:**
1. ~~Position field diagram~~ (DONE)
2. ~~Animated stat bars~~ (DONE)
3. ~~Keyboard shortcuts~~ (DONE)
4. ~~Confirmation dialog~~ (DONE)
5. ~~Stat tooltips~~ (DONE)

**Larger Features:**
1. ~~Nationality selection~~ (DONE - implemented with 68 nations)
2. ~~Personality traits~~ (DONE - 10 traits with checkbox selection)
3. Character avatar preview (requires art)
4. Background story system (requires game design)
