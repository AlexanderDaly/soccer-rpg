# Soccer Career RPG

[![CI](https://github.com/AlexanderDaly/soccer-rpg/actions/workflows/ci.yml/badge.svg)](https://github.com/AlexanderDaly/soccer-rpg/actions/workflows/ci.yml)
[![Godot 4.x](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An anime-style tactical soccer RPG where you rise from high school stardom to international glory.

## 🎮 Game Overview

**Soccer Career RPG** is a turn-based tactical soccer game with deep RPG progression and AI-driven dynamic storytelling. Guide your custom player through the Japanese high school soccer system—from prefecture league play through regional qualifiers to the national championship.

### Key Features

- **Turn-Based Tactical Matches**: Full 11v11 matches on a hex-based pitch with chess-like strategic gameplay
- **Japanese High School Season**: Authentic 3-phase season system with prefecture leagues, regional qualifiers, and the national championship
- **RPG Stat System**: 8 primary stats, 10 derived secondary stats, and 8 position-based archetypes
- **Training Mini-Games**: Free kick, penalty, and rondo drills with skill check mechanics and XP rewards
- **Dynamic AI Narrative**: Context-aware story generation that adapts to your performance and choices
- **Dual UI Modes**: Modern console dashboard (FIFA/Pro Evo style) and retro desktop simulation
- **Career Progression**: Journey from high school → youth academy → U20 World Cup → professional career

## 🛠️ Tech Stack

- **Engine**: Godot 4.x
- **Language**: GDScript
- **AI Integration**: HTTP API calls for narrative generation (Claude/OpenAI compatible)

## 📁 Project Structure

```
soccer-rpg/
├── project.godot              # Godot project configuration
├── scripts/                   # 64 GDScript files (~19k LOC)
│   ├── core/                  # Autoloaded singletons
│   │   ├── game_manager.gd    # Central state controller
│   │   ├── stat_system.gd     # Stats, XP, leveling
│   │   ├── audio_manager.gd   # Sound/music management
│   │   └── save_manager.gd    # Save/load serialization
│   ├── season/                # Season system
│   │   ├── season_manager.gd  # Season orchestration
│   │   ├── season_data.gd     # Season state
│   │   ├── league_data.gd     # Round-robin leagues
│   │   └── tournament_data.gd # Knockout tournaments
│   ├── match/tactical/        # Turn-based match system (50+ files)
│   │   ├── match_controller.gd
│   │   ├── hex_utils.gd       # Hex grid & A* pathfinding
│   │   └── action_resolver.gd # Move, pass, shoot, tackle
│   ├── dashboard/             # Console UI panels (13 files)
│   ├── desktop/               # Desktop shell & apps (12 files)
│   ├── training/              # Training mini-games
│   ├── career/                # Career progression
│   ├── ai_narrative/          # AI story generation
│   └── data/                  # Data classes
│       ├── player_data.gd
│       ├── team_data.gd
│       └── match_data.gd
├── scenes/                    # 41 scene files
│   ├── dashboard/             # Console dashboard panels
│   ├── match/                 # Tactical match UI
│   ├── desktop/               # Desktop shell & apps
│   ├── training/              # Mini-game scenes
│   ├── menus/                 # Main menu, settings
│   └── career/                # Career hub
├── tests/unit/                # Legacy GUT-authored test files (addon not vendored)
├── assets/
│   ├── flags/                 # 73 SVG country flags
│   ├── ui/icons/              # Dashboard icons
│   ├── audio/                 # Optional local sound/music assets (not shipped here)
│   └── fonts/                 # Custom fonts
├── resources/themes/          # UI themes (.tres)
└── docs/                      # Development journals
```

## 🎯 Stat System

### Primary Stats (1-99 scale)
| Stat | Abbr | Description |
|------|------|-------------|
| Speed | SPD | Movement range, chase/escape success |
| Stamina | STA | Actions per match, recovery rate |
| Technique | TEC | Dribble, first touch, skill moves |
| Passing | PAS | Pass accuracy, range, through-balls |
| Shooting | SHO | Shot power, accuracy, long-range |
| Defense | DEF | Tackle, interception, marking |
| Physical | PHY | Aerial duels, hold-up, resistance |
| Mental | MEN | Composure, consistency, pressure |

### Position Archetypes
- **GK** - Goalkeeper
- **CB** - Center Back
- **FB** - Full Back
- **CDM** - Defensive Midfielder
- **CM** - Central Midfielder
- **CAM** - Attacking Midfielder
- **WNG** - Winger
- **ST** - Striker

## ⚽ Season System

The game features an authentic Japanese high school soccer season structure:

### Three Phases
1. **Prefecture League** (April - October)
   - 10-team round-robin competition
   - 18 matchdays with automatic scheduling
   - Top 3 qualify for regional qualifiers

2. **Prefecture Qualifiers** (November)
   - 16-team single elimination tournament
   - Winner advances to nationals

3. **National Championship** (December - January)
   - 48-team knockout tournament
   - Authentic prefecture representation

### Features
- Real date scheduling with calendar integration
- CPU match simulation using Poisson distribution
- League standings with form guide
- Tournament bracket visualization
- Career milestone tracking (champion, finalist, etc.)

## 🏋️ Training Mini-Games

Three skill-based training drills to improve your player:

| Drill | Description | Mechanics |
|-------|-------------|-----------|
| **Free Kick** | 10-shot session against a wall | Zone targeting, curve direction, power charging |
| **Penalty** | Penalty spot practice | Goalkeeper mind games, placement accuracy |
| **Rondo** | Possession keep-away | Pass count tracking, interception defense |

Each drill features:
- Difficulty levels (Youth, Pro, Elite)
- XP rewards with bonus multipliers
- Skill check math with multiple modifiers
- Training records tracking

## 🚀 Getting Started

### Prerequisites
- [Godot 4.2+](https://godotengine.org/download)

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/AlexanderDaly/soccer-rpg.git
   ```
2. Open Godot and import the project
3. Press F5 to run

### AI Narrative Setup (Optional)
To enable AI-generated narrative content:
1. Create `user://ai_config.json` with your API credentials:
   ```json
   {
     "endpoint": "https://api.anthropic.com/v1/messages",
     "api_key": "your-api-key",
     "enabled": true
   }
   ```
2. The game falls back to template-based narrative if AI is unavailable

## 🎮 Controls

### Match Controls
- **Left Click**: Select unit / Confirm action
- **Right Click**: Cancel / Deselect
- **Space**: End turn
- **WASD/Arrows**: Pan camera

### Menu Controls
- **Enter/Space**: Confirm
- **Escape**: Back / Menu
- **Arrow Keys**: Navigate options
- **Tab**: Next field

### Training Controls
- **Arrow Keys**: Select zone target
- **Left/Right**: Choose curve direction
- **Hold Space**: Charge power
- **Release Space**: Execute shot

## 📋 Development Status

### Completed Features
- [x] Core autoload singletons (GameManager, StatSystem, SaveManager, AudioManager)
- [x] Complete stat system (8 primary, 10 secondary, position archetypes)
- [x] Data classes with full serialization (Player, Team, Match, Season)
- [x] Character creation (name, position, appearance, nationality, traits)
- [x] Tactical match system (11v11, hex-based, turn-based with AI)
- [x] Japanese high school season system (league, qualifiers, nationals)
- [x] Training mini-games (free kick, penalty, rondo)
- [x] Console dashboard UI (9 feature panels)
- [x] Desktop simulation UI (retro 90s aesthetic)
- [x] AI narrative engine with fallback templates
- [x] Save/load system with multiple slots
- [x] Professional dev infrastructure (CI/CD, project validation, GDLint)

### In Progress
- [ ] Career phase progression beyond high school
- [ ] Match animations and visual polish
- [ ] Sound effects and music integration

## 🔮 Future Projects

### Near-Term Goals
1. **Youth Academy Phase**
   - Scout recruitment mechanics
   - Academy training programs
   - Youth international callups (U17, U18)

2. **U20 World Cup Arc**
   - International squad selection
   - Tournament bracket play
   - Rival nation storylines

3. **Match Visual Polish**
   - Animated player sprites
   - Goal celebration cutscenes
   - Weather effects (rain, snow)

### Mid-Term Goals
4. **Professional Career Launch**
   - Club transfer system
   - Contract negotiations
   - Multiple league support (J-League, European leagues)

5. **Relationship System**
   - Teammate bond mechanics
   - Rival progression
   - Coach/manager interactions
   - Press conference events

6. **Special Moves System**
   - Unlockable signature techniques
   - Anime-style special move animations
   - Team combination plays

### Long-Term Vision
7. **Art Asset Pipeline**
   - AI-generated character portraits
   - Dynamic match backgrounds
   - Season/weather visual changes

8. **Advanced Narrative**
   - Branching storylines based on performance
   - Multiple career endings
   - Newspaper/social media integration

9. **Community Features**
   - Custom team creation
   - Share custom formations
   - Leaderboards for training games

## 🧪 Testing

Automated unit tests are not currently wired in this repository. The `tests/unit/` directory contains legacy test files written for [GUT (Godot Unit Testing)](https://github.com/bitwes/Gut), but the `addons/gut` addon is not vendored here and CI does not execute a GUT test job.

### What CI Runs

```bash
python3 -m gdtoolkit.linter scripts/
```

GitHub Actions also validates the expected project structure on every push and pull request.

### Legacy Test Files

The checked-in GUT test files are retained for future reactivation, but they are currently documentation of past coverage rather than an active, runnable test harness.

## 🔊 Audio Assets

The repository does not currently ship music or sound-effect binaries under `assets/audio/`. Missing audio files are treated as optional placeholders, so the game falls back silently instead of warning on startup or button clicks.

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Branching strategy (GitHub Flow)
- Commit message format (Conventional Commits)
- Code style guidelines
- Testing requirements

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by *Inazuma Eleven*, *Captain Tsubasa*, *Football Manager*, and *FIFA Career Mode*
- Built with [Godot Engine](https://godotengine.org/)
- Country flags from [flag-icons](https://github.com/lipis/flag-icons) (MIT License)
- Japanese prefecture data for authentic school generation
