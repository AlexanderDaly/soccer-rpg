# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Training Games UI Redesign**: Updated all training mini-games from retro Windows 95-style to dark FIFA/Pro Evo console dashboard aesthetic
  - Dark navy backgrounds with semi-transparent panels
  - Green accent colors for selection and success states
  - Amber/red indicators for warnings and failures
  - Removed drop shadows, added subtle rounded corners
  - Light text on dark backgrounds for readability
  - Affected drills: Freekick, Penalty, Rondo

### Added
- GUT testing framework with unit tests for core systems
- GitHub Actions CI/CD pipeline
- EditorConfig for consistent formatting
- GDLint configuration for code quality
- Issue and PR templates

#### Character Creation UX Improvements
- **Position Field Diagram**: Mini soccer pitch graphic showing where each position plays
  - Animated highlight zones with smooth transitions (0.25s ease-out)
  - Mirrored highlights for FB/WNG positions showing both flanks
  - Field lines include boundary, center line, center circle, and penalty areas
- **Stat Tooltips**: Hover tooltips explaining what each stat affects in gameplay
  - Covers all 8 primary stats (SPD, STA, TEC, PAS, SHO, DEF, PHY, MEN)
  - Includes position relevance hints
- **Keyboard Shortcuts**: Full keyboard navigation support
  - Arrow keys navigate position selection
  - Tab/Shift+Tab cycles between sections (Name, Position, Appearance, Traits)
  - Enter opens confirmation dialog when name is valid
  - Escape returns to main menu or closes confirmation dialog
- **Nationality Flag Icons**: Visual flag display for nationality selection
  - 73 SVG country flags from flag-icons library (MIT License)
  - Flag displayed next to selected nationality
  - Flags shown in dropdown list for easy identification

## [0.1.0] - 2025-01-29

### Added

#### Core Systems
- **GameManager**: Central game state management singleton
- **StatSystem**: Complete stat system with 8 primary stats (SPD, STA, TEC, PAS, SHO, DEF, PHY, MEN)
  - Secondary stat calculations derived from primaries
  - Position-weighted overall rating calculation
  - XP curves and leveling system
  - Form modifiers affecting stats
  - NPC stat generation by quality tier
- **AudioManager**: Sound effect and music management
- **SaveManager**: Game save/load functionality
- **CareerManager**: Career progression tracking

#### Data Classes
- **PlayerData**: Complete player data model with stats, skills, appearance, and serialization
- **TeamData**: Team roster and formation data
- **MatchData**: Match state and statistics tracking

#### Tactical Match System
- **HexUtils**: Hex grid math and pathfinding utilities
  - Axial coordinate system (flat-top hexagons)
  - A* pathfinding with obstacle avoidance
  - Formation position generation (4-4-2, 4-3-3, 3-5-2, 4-2-3-1)
  - Movement range calculation
  - Shot difficulty calculation
- **ActionResolver**: Turn-based action execution
  - Move and sprint actions
  - Pass and through ball actions
  - Shooting with goalkeeper saves
  - Dribbling and tackling with contest resolution
  - Foul and card system
- **PlayerUnit**: On-field player representation
- **BallController**: Ball state and possession management
- **MatchController**: Match flow and turn management
- **AI Systems**: Teammate and opponent AI decision making

#### Desktop Mode
- **DesktopManager**: In-game desktop simulation
- **DesktopShell**: Desktop environment UI
- **Window System**: Draggable, resizable app windows
- **Apps**: Settings, Email, Player Stats, Team, Social Media, Training, Save/Load, Schedule

#### UI
- Main menu system
- Character creation screen
- Career hub interface
- Pre-match and post-match screens
- Tactical UI controller

#### AI Narrative
- **NarrativeEngine**: Context-aware story generation framework

### Technical
- Godot 4.x project structure
- Autoloaded singleton architecture
- Resource-based data storage
- Input mapping for match controls

[Unreleased]: https://github.com/yourusername/soccer-rpg/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/soccer-rpg/releases/tag/v0.1.0
