extends GutTest
## Unit tests for NPC registry and TeamData registry integration


func before_each() -> void:
	NpcRegistry.clear()


func after_each() -> void:
	NpcRegistry.clear()


func test_promote_school_years_includes_injured() -> void:
	var team_id = NpcRegistry.generate_stable_team_id("Test High", "Kanagawa")
	var npc_data = {
		"name": "Test Player",
		"position": "ST",
		"stats": {"pace": 50},
		"overall": 50,
		"school_year": 2,
		"status": "injured"
	}
	var npc = NpcRegistry.get_or_create_npc(team_id, "ST", 0, npc_data, false)

	NpcRegistry.promote_school_years()

	var updated = NpcRegistry.get_npc(npc.id)
	assert_eq(updated.school_year, 3, "Injured players should still be promoted")


func test_registry_generated_npc_has_core_fields() -> void:
	var team = TeamData.new()
	team.set_stable_id("Test High", "Kanagawa")

	var npc = team._get_or_create_npc_via_registry("ST", 1, GameManager.CareerPhase.HIGH_SCHOOL, 0)

	assert_true(npc.has("name"), "NPC should have a name")
	assert_true(npc.has("stats"), "NPC should have stats")
	assert_true(npc.has("overall"), "NPC should have overall rating")

	var stored = NpcRegistry.get_npc(npc.id)
	assert_true(stored.has("name"), "Registry entry should include name")
	assert_true(stored.has("stats"), "Registry entry should include stats")


func test_competition_suspension_blocks_and_serves() -> void:
	var team_id = NpcRegistry.generate_stable_team_id("Test High", "Kanagawa")
	var npc = NpcRegistry.get_or_create_npc(team_id, "CM", 0, {
		"name": "Carded Midfielder",
		"position": "CM",
		"stats": {"PAS": 55},
		"overall": 55
	}, false)

	NpcRegistry.record_competition_card(npc.id, "league::kanagawa", "yellow")
	NpcRegistry.record_competition_card(npc.id, "league::kanagawa", "yellow")
	NpcRegistry.record_competition_card(npc.id, "league::kanagawa", "yellow")

	assert_false(NpcRegistry.is_npc_match_eligible(npc.id, "league::kanagawa"))

	NpcRegistry.serve_suspension(npc.id, "league::kanagawa")

	assert_true(NpcRegistry.is_npc_match_eligible(npc.id, "league::kanagawa"))
