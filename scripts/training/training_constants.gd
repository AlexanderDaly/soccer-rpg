class_name TrainingConstants
## Shared constants for all training drills

# Console Dashboard Colors
const BG_DARK = Color(0.039, 0.086, 0.157)
const PANEL_BG = Color(0.06, 0.1, 0.18, 0.95)
const BORDER_COLOR = Color(0.15, 0.25, 0.4)
const ACCENT_GREEN = Color(0, 1, 0.5)
const TEXT_PRIMARY = Color(0.9, 0.95, 1)
const TEXT_SECONDARY = Color(0.6, 0.65, 0.7)
const TEXT_MUTED = Color(0.5, 0.55, 0.6)

# State Colors
const COLOR_DEFAULT = Color(0.1, 0.15, 0.25)
const COLOR_SELECTED = Color(0, 0.6, 0.3)
const COLOR_SUCCESS = Color(0, 0.8, 0.4)
const COLOR_FAIL = Color(0.8, 0.3, 0.3)
const COLOR_WARNING = Color(0.9, 0.7, 0.2)
const COLOR_BLOCKED = Color(0.6, 0.2, 0.2)
const COLOR_CONTESTED = Color(0.8, 0.5, 0.2)
const COLOR_OPEN = Color(0.2, 0.5, 0.8)

# XP Rewards (base values)
const XP_PER_ATTEMPT: int = 5
const XP_GOOD_SESSION_BONUS: int = 25
const XP_PERFECT_SESSION_BONUS: int = 50
const STAT_XP_PER_SUCCESS: int = 3
const STAT_XP_PER_FAIL: int = 1
const STAMINA_COST: int = 15
const ATTEMPTS_PER_SESSION: int = 10

# Power bar ranges (shared by freekick and penalty)
const POWER_RANGES: Array[Dictionary] = [
	{"min": 0, "max": 39, "name": "Weak", "modifier": -15},
	{"min": 40, "max": 69, "name": "Good", "modifier": 0},
	{"min": 70, "max": 85, "name": "Optimal", "modifier": 5},
	{"min": 86, "max": 100, "name": "Overpowered", "modifier": -10}
]

# Zone modifiers (shared by freekick and penalty)
const ZONE_MODIFIERS: Dictionary = {
	"TOP_LEFT": -20, "TOP_CENTER": -15, "TOP_RIGHT": -20,
	"MID_LEFT": -10, "MID_CENTER": 5, "MID_RIGHT": -10,
	"LOW_LEFT": -10, "LOW_CENTER": -5, "LOW_RIGHT": -10
}

# Zone names for iteration
const ZONE_NAMES: Array[String] = [
	"TOP_LEFT", "TOP_CENTER", "TOP_RIGHT",
	"MID_LEFT", "MID_CENTER", "MID_RIGHT",
	"LOW_LEFT", "LOW_CENTER", "LOW_RIGHT"
]

const ZONE_BUTTON_NAMES: Array[String] = [
	"TopLeft", "TopCenter", "TopRight",
	"MidLeft", "MidCenter", "MidRight",
	"LowLeft", "LowCenter", "LowRight"
]

# Charge rate for power bar (100% in 1.5 seconds)
const CHARGE_RATE: float = 66.67


# Helper to get power modifier from power value
static func get_power_modifier(power: float) -> int:
	for range_data in POWER_RANGES:
		if power >= range_data.min and power <= range_data.max:
			return range_data.modifier
	return 0


static func get_power_name(power: float) -> String:
	for range_data in POWER_RANGES:
		if power >= range_data.min and power <= range_data.max:
			return range_data.name
	return "Unknown"
