# Soccer Career RPG

[![CI](https://github.com/yourusername/soccer-rpg/actions/workflows/ci.yml/badge.svg)](https://github.com/yourusername/soccer-rpg/actions/workflows/ci.yml)
[![Godot 4.x](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An anime-style tactical soccer RPG where you rise from high school stardom to international glory.

## 🎮 Game Overview

**Soccer Career RPG** is a turn-based tactical soccer game with deep RPG progression and AI-driven dynamic storytelling. Guide your custom player from high school soccer through the U20 World Cup and into the professional ranks.

### Key Features

- **Turn-Based Tactical Matches**: Full 11v11 matches on a grid-based pitch with chess-like strategic gameplay
- **Career Progression**: Journey from high school → youth academy → U20 World Cup → professional career
- **RPG Stat System**: 8 primary stats, derived secondary stats, and position-based archetypes
- **Dynamic AI Narrative**: Context-aware story generation that adapts to your performance and choices
- **Anime Art Style**: AI-generated character portraits and dramatic special moves
- **Relationship System**: Build bonds with teammates, rivals, and coaches

## 🛠️ Tech Stack

- **Engine**: Godot 4.x
- **Language**: GDScript
- **AI Integration**: HTTP API calls for narrative generation (Claude/OpenAI compatible)

## 📁 Project Structure

```
soccer-rpg/
├── project.godot          # Godot project configuration
├── scenes/
│   ├── match/             # Match gameplay scenes
│   ├── menus/             # UI screens (main menu, settings, etc.)
│   ├── career/            # Career hub and management
│   ├── dialogue/          # Dialogue/cutscene scenes
│   └── training/          # Training mini-games
├── scripts/
│   ├── core/              # Autoloaded singletons
│   │   ├── game_manager.gd
│   │   ├── stat_system.gd
│   │   ├── audio_manager.gd
│   │   └── save_manager.gd
│   ├── match/             # Match logic and turn system
│   ├── career/            # Career progression
│   │   └── career_manager.gd
│   ├── ai_narrative/      # AI story generation
│   │   └── narrative_engine.gd
│   ├── ui/                # UI scripts
│   └── data/              # Data classes
│       ├── player_data.gd
│       ├── team_data.gd
│       └── match_data.gd
├── assets/
│   ├── sprites/           # Game sprites (characters, pitch, UI)
│   ├── portraits/         # Character portrait images
│   ├── audio/             # Sound effects and music
│   └── fonts/             # Custom fonts
├── resources/             # Godot resource files (.tres)
│   ├── stats/             # Stat configurations
│   ├── skills/            # Special move definitions
│   ├── teams/             # Team data
│   └── story/             # Story beat definitions
└── addons/                # Godot plugins
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

## 🚀 Getting Started

### Prerequisites
- [Godot 4.2+](https://godotengine.org/download)

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/soccer-rpg.git
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

## 📋 Development Roadmap

- [x] Project structure setup
- [x] Core autoload singletons
- [x] Stat system implementation
- [x] Data classes (Player, Team, Match)
- [x] Basic UI framework
- [ ] Character creation screen
- [ ] Tactical match prototype
- [ ] Career hub implementation
- [ ] AI narrative integration
- [ ] Training mini-games
- [ ] Art asset pipeline

## 🧪 Testing

This project uses [GUT (Godot Unit Testing)](https://github.com/bitwes/Gut) for testing.

### Running Tests

**In Godot Editor:**
1. Open the project in Godot
2. Enable the GUT plugin in Project Settings > Plugins
3. Open the GUT panel (bottom dock)
4. Click "Run All"

**From Command Line:**
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -gexit
```

### Test Structure
```
tests/
└── unit/
    ├── test_stat_system.gd    # StatSystem calculations
    ├── test_player_data.gd    # PlayerData resource
    └── test_hex_utils.gd      # Hex grid utilities
```

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:
- Branching strategy (GitHub Flow)
- Commit message format (Conventional Commits)
- Code style guidelines
- Testing requirements

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by *Inazuma Eleven*, *Captain Tsubasa*, and *Football Manager*
- Built with [Godot Engine](https://godotengine.org/)
