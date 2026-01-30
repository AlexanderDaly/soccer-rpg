extends GutTest
## Unit tests for PlayerData resource


# =============================================================================
# Initialization Tests
# =============================================================================

func test_player_data_default_values() -> void:
	var player = PlayerData.new()

	assert_eq(player.id, "", "Default ID should be empty")
	assert_eq(player.name, "", "Default name should be empty")
	assert_eq(player.position, "", "Default position should be empty")
	assert_eq(player.level, 1, "Default level should be 1")
	assert_eq(player.xp, 0, "Default XP should be 0")
	assert_eq(player.current_form, "average", "Default form should be average")
	assert_eq(player.stamina_current, 100, "Default stamina should be 100")
	assert_eq(player.morale, 50, "Default morale should be 50")


func test_player_data_has_all_primary_stats() -> void:
	var player = PlayerData.new()
	var expected_stats = ["SPD", "STA", "TEC", "PAS", "SHO", "DEF", "PHY", "MEN"]

	for stat in expected_stats:
		assert_has(player.stats, stat, "Player should have %s stat" % stat)


func test_player_data_default_stats_are_fifty() -> void:
	var player = PlayerData.new()

	for stat_key in player.stats:
		assert_eq(player.stats[stat_key], 50, "Default %s should be 50" % stat_key)


# =============================================================================
# Skill Management Tests
# =============================================================================

func test_unlock_skill_adds_to_unlocked() -> void:
	var player = PlayerData.new()

	var result = player.unlock_skill("power_shot")

	assert_true(result, "unlock_skill should return true on success")
	assert_has(player.unlocked_skills, "power_shot", "Skill should be in unlocked_skills")


func test_unlock_skill_duplicate_returns_false() -> void:
	var player = PlayerData.new()
	player.unlock_skill("power_shot")

	var result = player.unlock_skill("power_shot")

	assert_false(result, "unlock_skill should return false for duplicate")
	assert_eq(player.unlocked_skills.size(), 1, "Should only have one copy of skill")


func test_equip_skill_requires_unlocked() -> void:
	var player = PlayerData.new()

	var result = player.equip_skill("power_shot")

	assert_false(result, "Cannot equip skill that isn't unlocked")
	assert_eq(player.equipped_skills.size(), 0, "No skills should be equipped")


func test_equip_skill_success() -> void:
	var player = PlayerData.new()
	player.unlock_skill("power_shot")

	var result = player.equip_skill("power_shot")

	assert_true(result, "equip_skill should return true on success")
	assert_has(player.equipped_skills, "power_shot", "Skill should be equipped")


func test_equip_skill_max_four() -> void:
	var player = PlayerData.new()
	player.unlock_skill("skill1")
	player.unlock_skill("skill2")
	player.unlock_skill("skill3")
	player.unlock_skill("skill4")
	player.unlock_skill("skill5")

	player.equip_skill("skill1")
	player.equip_skill("skill2")
	player.equip_skill("skill3")
	player.equip_skill("skill4")
	var result = player.equip_skill("skill5")

	assert_false(result, "Cannot equip more than 4 skills")
	assert_eq(player.equipped_skills.size(), 4, "Should have exactly 4 equipped skills")


func test_equip_skill_duplicate_returns_false() -> void:
	var player = PlayerData.new()
	player.unlock_skill("power_shot")
	player.equip_skill("power_shot")

	var result = player.equip_skill("power_shot")

	assert_false(result, "Cannot equip same skill twice")


func test_unequip_skill_success() -> void:
	var player = PlayerData.new()
	player.unlock_skill("power_shot")
	player.equip_skill("power_shot")

	var result = player.unequip_skill("power_shot")

	assert_true(result, "unequip_skill should return true on success")
	assert_eq(player.equipped_skills.size(), 0, "No skills should be equipped")


func test_unequip_skill_not_equipped_returns_false() -> void:
	var player = PlayerData.new()

	var result = player.unequip_skill("power_shot")

	assert_false(result, "Cannot unequip skill that isn't equipped")


# =============================================================================
# Overall and Stats Tests
# =============================================================================

func test_get_overall_uses_stat_system() -> void:
	var player = PlayerData.new()
	player.position = "ST"
	player.stats = {"SPD": 80, "STA": 70, "TEC": 75, "PAS": 65, "SHO": 90, "DEF": 30, "PHY": 70, "MEN": 75}

	var overall = player.get_overall()
	var expected = StatSystem.calculate_overall(player.stats, "ST")

	assert_eq(overall, expected, "get_overall should match StatSystem calculation")


func test_get_secondary_stats_returns_all() -> void:
	var player = PlayerData.new()
	player.stats = {"SPD": 50, "STA": 50, "TEC": 50, "PAS": 50, "SHO": 50, "DEF": 50, "PHY": 50, "MEN": 50}

	var secondaries = player.get_secondary_stats()

	assert_has(secondaries, "acceleration")
	assert_has(secondaries, "vision")
	assert_has(secondaries, "finishing")


func test_get_effective_stat_applies_form() -> void:
	var player = PlayerData.new()
	player.stats["SPD"] = 50

	player.current_form = "excellent"
	var excellent_stat = player.get_effective_stat("SPD")

	player.current_form = "terrible"
	var terrible_stat = player.get_effective_stat("SPD")

	assert_eq(excellent_stat, 60, "Excellent form should add 10")
	assert_eq(terrible_stat, 40, "Terrible form should subtract 10")


func test_get_effective_stat_unknown_returns_zero() -> void:
	var player = PlayerData.new()

	var result = player.get_effective_stat("UNKNOWN")

	assert_eq(result, 0, "Unknown stat should return 0")


# =============================================================================
# Rest and Recovery Tests
# =============================================================================

func test_rest_recovers_stamina() -> void:
	var player = PlayerData.new()
	player.stamina_current = 50

	player.rest()

	assert_eq(player.stamina_current, 80, "Rest should recover 30 stamina")


func test_rest_stamina_capped_at_100() -> void:
	var player = PlayerData.new()
	player.stamina_current = 90

	player.rest()

	assert_eq(player.stamina_current, 100, "Stamina should not exceed 100")


func test_rest_improves_morale() -> void:
	var player = PlayerData.new()
	player.morale = 50

	player.rest()

	assert_eq(player.morale, 55, "Rest should improve morale by 5")


func test_rest_morale_capped_at_100() -> void:
	var player = PlayerData.new()
	player.morale = 98

	player.rest()

	assert_eq(player.morale, 100, "Morale should not exceed 100")


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict_contains_all_fields() -> void:
	var player = PlayerData.new()
	player.id = "test_123"
	player.name = "Test Player"
	player.position = "CM"

	var data = player.to_dict()

	assert_eq(data["id"], "test_123")
	assert_eq(data["name"], "Test Player")
	assert_eq(data["position"], "CM")
	assert_has(data, "stats")
	assert_has(data, "level")
	assert_has(data, "xp")
	assert_has(data, "unlocked_skills")
	assert_has(data, "equipped_skills")
	assert_has(data, "appearance")
	assert_has(data, "personality_traits")


func test_from_dict_restores_all_fields() -> void:
	var data = {
		"id": "restored_123",
		"name": "Restored Player",
		"position": "ST",
		"stats": {"SPD": 80, "STA": 70, "TEC": 75, "PAS": 65, "SHO": 90, "DEF": 30, "PHY": 70, "MEN": 75},
		"level": 5,
		"xp": 150,
		"stat_xp": {"SPD": 50},
		"unlocked_skills": ["power_shot"],
		"equipped_skills": ["power_shot"],
		"skill_points": 3,
		"current_form": "good",
		"stamina_current": 80,
		"morale": 75,
		"injury_status": "",
		"appearance": {"hair_color": "blonde"},
		"personality_traits": ["determined"]
	}

	var player = PlayerData.new()
	player.from_dict(data)

	assert_eq(player.id, "restored_123")
	assert_eq(player.name, "Restored Player")
	assert_eq(player.position, "ST")
	assert_eq(player.level, 5)
	assert_eq(player.xp, 150)
	assert_eq(player.stats["SHO"], 90)
	assert_eq(player.skill_points, 3)
	assert_eq(player.current_form, "good")
	assert_has(player.unlocked_skills, "power_shot")
	assert_has(player.equipped_skills, "power_shot")


func test_from_dict_handles_missing_fields() -> void:
	var data = {
		"name": "Minimal Player"
	}

	var player = PlayerData.new()
	player.from_dict(data)

	assert_eq(player.name, "Minimal Player")
	assert_eq(player.position, "CM", "Missing position should default to CM")
	assert_eq(player.level, 1, "Missing level should default to 1")


func test_round_trip_serialization() -> void:
	var original = PlayerData.new()
	original.id = "round_trip_test"
	original.name = "Round Trip"
	original.position = "CAM"
	original.stats["TEC"] = 85
	original.level = 10
	original.unlock_skill("through_ball")
	original.equip_skill("through_ball")

	var data = original.to_dict()
	var restored = PlayerData.new()
	restored.from_dict(data)

	assert_eq(restored.id, original.id)
	assert_eq(restored.name, original.name)
	assert_eq(restored.position, original.position)
	assert_eq(restored.stats["TEC"], 85)
	assert_eq(restored.level, 10)
	assert_has(restored.unlocked_skills, "through_ball")
	assert_has(restored.equipped_skills, "through_ball")


# =============================================================================
# Appearance Tests
# =============================================================================

func test_default_appearance_has_all_fields() -> void:
	var player = PlayerData.new()

	assert_has(player.appearance, "hair_color")
	assert_has(player.appearance, "hair_style")
	assert_has(player.appearance, "eye_color")
	assert_has(player.appearance, "skin_tone")
	assert_has(player.appearance, "height")
	assert_has(player.appearance, "build")
