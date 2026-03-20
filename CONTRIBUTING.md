# Contributing to Soccer Career RPG

Thank you for your interest in contributing to Soccer Career RPG! This document outlines our development workflow and standards.

## Branching Strategy (GitHub Flow)

We use GitHub Flow - a simple, branch-based workflow:

1. **Create a feature branch from main:**
   ```bash
   git checkout main && git pull
   git checkout -b feature/my-feature
   ```

2. **Make commits using Conventional Commits format** (see below)

3. **Push and open a Pull Request:**
   ```bash
   git push -u origin feature/my-feature
   ```

4. **After CI passes and review**, merge to main via GitHub

5. **Clean up:**
   ```bash
   git checkout main && git pull
   git branch -d feature/my-feature
   ```

### Branch Naming Conventions

- `feature/` - New features (e.g., `feature/set-piece-system`)
- `fix/` - Bug fixes (e.g., `fix/goalkeeper-save-logic`)
- `docs/` - Documentation updates (e.g., `docs/update-readme`)
- `refactor/` - Code refactoring (e.g., `refactor/match-state-machine`)
- `chore/` - Maintenance tasks (e.g., `chore/update-godot-4.4`)

## Commit Message Format (Conventional Commits)

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks (dependencies, configs, etc.) |

### Scopes

Common scopes for this project:

- `match` - Match gameplay and turn system
- `tactical` - Tactical/strategic systems
- `ai` - AI behavior (teammate/opponent)
- `narrative` - Story and dialogue systems
- `career` - Career progression
- `ui` - User interface
- `stats` - Stat system
- `core` - Core systems and managers

### Examples

```
feat(match): add through ball action
fix(ai): correct teammate positioning logic
docs: update README installation steps
refactor(tactical): simplify turn state machine
test(stats): add unit tests for stat calculations
chore: update Godot to 4.4
```

## Code Style Guidelines

### GDScript Conventions

- **Functions and variables:** `snake_case`
- **Classes:** `PascalCase`
- **Constants:** `SCREAMING_SNAKE_CASE`
- **Private members:** Prefix with underscore (`_private_var`, `_private_func()`)
- **Signals:** Past tense (`player_moved`, `turn_ended`)

### Documentation

- Document public functions with comments explaining purpose and parameters
- Use `##` for documentation comments (shows in Godot editor)
- Keep comments concise and meaningful

### Example

```gdscript
class_name TacticalUnit
extends Node2D

## Emitted when this unit completes its action
signal action_completed(unit: TacticalUnit)

const MAX_MOVEMENT_RANGE := 5

var player_data: PlayerData
var _current_ap: int = 0

## Move the unit to the target grid position
## Returns true if movement was successful
func move_to(grid_pos: Vector2i) -> bool:
    if not _can_move_to(grid_pos):
        return false
    # ... implementation
    return true

func _can_move_to(grid_pos: Vector2i) -> bool:
    # Private helper function
    pass
```

## Pull Request Process

1. **Fill out the PR template** completely
2. **Ensure CI passes** - linting and project validation must be green
3. **Keep PRs focused** - one feature or fix per PR
4. **Update documentation** if your change affects user-facing behavior
5. **Add tests** for new functionality when applicable

## Reporting Issues

- Use the appropriate issue template (bug report or feature request)
- Search existing issues first to avoid duplicates
- Provide as much context as possible

## Development Setup

1. Install [Godot 4.2+](https://godotengine.org/download)
2. Clone the repository
3. Open the project in Godot
4. Install development tools:
   ```bash
   python3 -m pip install gdtoolkit==4.5.0
   ```

## Testing

Legacy test files under `tests/unit/` were written for [GUT (Godot Unit Testing)](https://github.com/bitwes/Gut), but the `addons/gut` addon is not vendored in this repository and CI does not run a unit-test job right now.

### Current Validation

```bash
python3 -m gdtoolkit.linter scripts/
```

### Test Requirements

- Add or update automated tests when the active harness for the area exists
- If you reintroduce GUT or another runner, wire it into CI and update docs in the same change
- Manual gameplay validation is still expected for UI and runtime changes

## Linting

We use gdlint for static analysis:

```bash
python3 -m gdtoolkit.linter scripts/
```

Configuration is in `.gdlintrc`. The CI pipeline runs linting automatically.

## Continuous Integration

GitHub Actions runs on every push and PR:

1. **Lint**: Checks GDScript code style
2. **Validate**: Checks project structure

All checks must pass before merging.

## Questions?

Feel free to open an issue for any questions about contributing!
