extends GutTest
## Unit tests for SaveManager career schema compatibility

var _snapshot: Dictionary = {}


func before_each() -> void:
	_snapshot = {
		"player_data": GameManager.player_data,
		"current_team": GameManager.current_team,
		"match_history": CareerManager.match_history.duplicate(true),
		"career_stats": CareerManager.career_stats.duplicate(true),
		"reputation": CareerManager.reputation,
		"media_coverage": CareerManager.media_coverage,
		"fan_popularity": CareerManager.fan_popularity,
		"scout_attention": CareerManager.scout_attention.duplicate(true),
		"current_contract": CareerManager.current_contract.duplicate(true),
		"club_history": CareerManager.club_history.duplicate(true),
		"pending_contract_offers": CareerManager.pending_contract_offers.duplicate(true),
		"relationships": CareerManager.relationships.duplicate(true),
		"coach_trust": CareerManager.coach_trust,
		"scout_relationships": CareerManager.scout_relationships.duplicate(true),
		"queued_contract_offer": CareerManager.queued_contract_offer.duplicate(true),
		"reputation_event_log": CareerManager.reputation_event_log.duplicate(true),
		"last_match_reputation_report": CareerManager.last_match_reputation_report.duplicate(true),
		"social_rep_day_key": CareerManager.social_rep_day_key,
		"social_rep_awarded_today": CareerManager.social_rep_awarded_today,
		"social_rep_actions_today": CareerManager.social_rep_actions_today,
		"completed_milestones": CareerManager.completed_milestones.duplicate(true),
		"rivals": CareerManager.rivals.duplicate(true),
		"phase": GameManager.current_career_phase,
		"national_phase": GameManager.current_national_phase,
		"prefecture": GameManager.current_prefecture,
		"season": SeasonManager.to_dict()
	}


func after_each() -> void:
	GameManager.player_data = _snapshot.get("player_data", null)
	GameManager.current_team = _snapshot.get("current_team", null)
	CareerManager.match_history.assign(_snapshot.get("match_history", []))
	CareerManager.career_stats = _snapshot.get("career_stats", {}).duplicate(true)
	CareerManager.reputation = int(_snapshot.get("reputation", 10))
	CareerManager.media_coverage = int(_snapshot.get("media_coverage", 0))
	CareerManager.fan_popularity = int(_snapshot.get("fan_popularity", 0))
	CareerManager.scout_attention = _snapshot.get("scout_attention", {}).duplicate(true)
	CareerManager.current_contract = _snapshot.get("current_contract", {}).duplicate(true)
	CareerManager.club_history.assign(_snapshot.get("club_history", []))
	CareerManager.pending_contract_offers.assign(_snapshot.get("pending_contract_offers", []))
	CareerManager.relationships = _snapshot.get("relationships", {}).duplicate(true)
	CareerManager.coach_trust = int(_snapshot.get("coach_trust", 50))
	CareerManager.scout_relationships = _snapshot.get("scout_relationships", {}).duplicate(true)
	CareerManager.queued_contract_offer = _snapshot.get("queued_contract_offer", {}).duplicate(true)
	CareerManager.reputation_event_log.assign(_snapshot.get("reputation_event_log", []))
	CareerManager.last_match_reputation_report = _snapshot.get("last_match_reputation_report", {}).duplicate(true)
	CareerManager.social_rep_day_key = str(_snapshot.get("social_rep_day_key", ""))
	CareerManager.social_rep_awarded_today = int(_snapshot.get("social_rep_awarded_today", 0))
	CareerManager.social_rep_actions_today = int(_snapshot.get("social_rep_actions_today", 0))
	CareerManager.completed_milestones.assign(_snapshot.get("completed_milestones", []))
	CareerManager.rivals.assign(_snapshot.get("rivals", []))
	GameManager.current_career_phase = int(_snapshot.get("phase", 0))
	GameManager.current_national_phase = int(_snapshot.get("national_phase", 0))
	GameManager.current_prefecture = str(_snapshot.get("prefecture", "Kanagawa"))
	SeasonManager.from_dict(_snapshot.get("season", {}))


func test_serialize_career_includes_reputation_schema_fields() -> void:
	CareerManager.media_coverage = 31
	CareerManager.fan_popularity = 44
	CareerManager.reputation_event_log = [{"source": "test", "applied_delta": 2}]
	CareerManager.last_match_reputation_report = {"reputation_delta": 5}
	CareerManager.social_rep_day_key = "2024-04-02"
	CareerManager.social_rep_awarded_today = 3
	CareerManager.social_rep_actions_today = 4

	var data = SaveManager._serialize_career()

	assert_true(data.has("media_coverage"))
	assert_true(data.has("fan_popularity"))
	assert_true(data.has("reputation_event_log"))
	assert_true(data.has("last_match_reputation_report"))
	assert_true(data.has("social_rep_day_key"))
	assert_true(data.has("social_rep_awarded_today"))
	assert_true(data.has("social_rep_actions_today"))
	assert_true(data.has("current_contract"))
	assert_true(data.has("pending_contract_offers"))
	assert_true(data.has("relationships"))
	assert_true(data.has("coach_trust"))
	assert_eq(int(data.get("media_coverage", 0)), 31)
	assert_eq(int(data.get("fan_popularity", 0)), 44)


func test_apply_save_data_old_save_defaults_new_career_fields() -> void:
	CareerManager.media_coverage = 99
	CareerManager.reputation_event_log = [{"source": "old"}]
	CareerManager.last_match_reputation_report = {"reputation_delta": 9}
	CareerManager.social_rep_day_key = "stale"
	CareerManager.social_rep_awarded_today = 9
	CareerManager.social_rep_actions_today = 9

	var old_style_save = {
		"version": 1,
		"career_phase": 0,
		"player": {},
		"career": {
			"match_history": [],
			"career_stats": {
				"matches_played": 1,
				"goals": 0,
				"assists": 0,
				"clean_sheets": 0,
				"man_of_match_awards": 0,
				"trophies": [],
				"current_season": 1
			},
			"reputation": 18,
			"scout_attention": {},
			"completed_milestones": [],
			"rivals": []
		}
	}

	SaveManager._apply_save_data(old_style_save)

	assert_eq(CareerManager.reputation, 18)
	assert_eq(CareerManager.media_coverage, 0, "Missing media_coverage should default to 0")
	assert_eq(CareerManager.fan_popularity, 0, "Missing fan_popularity should default to 0")
	assert_eq(CareerManager.reputation_event_log.size(), 0, "Missing event log should default empty")
	assert_true(CareerManager.last_match_reputation_report.is_empty(), "Missing match report should default empty")
	assert_eq(CareerManager.social_rep_day_key, "", "Missing day key should default empty")
	assert_eq(CareerManager.social_rep_awarded_today, 0)
	assert_eq(CareerManager.social_rep_actions_today, 0)
	assert_eq(GameManager.current_national_phase, GameManager.NationalPhase.NONE)


func test_migrate_overlay_phase_save_sets_primary_and_national_phases() -> void:
	var save_data = {
		"version": 2,
		"career_phase": GameManager.CareerPhase.U20_WORLD_CUP,
		"player": {},
		"career": {}
	}

	var migrated = SaveManager._migrate_save_data(save_data)

	assert_eq(int(migrated.get("career_phase", -1)), GameManager.CareerPhase.YOUTH_ACADEMY)
	assert_eq(int(migrated.get("national_phase", -1)), GameManager.NationalPhase.U20_WORLD_CUP)


func test_apply_save_data_restores_career_hub_snapshot_sections() -> void:
	var player = PlayerData.new()
	player.id = "player_save_test"
	player.name = "Save Test"
	player.position = "CM"
	player.nationality = "JPN"
	player.age = 18
	player.school_year = 3
	player.stats = {
		"SPD": 58,
		"STA": 60,
		"TEC": 61,
		"PAS": 63,
		"SHO": 52,
		"DEF": 51,
		"PHY": 50,
		"MEN": 59
	}

	var team = TeamData.new()
	team.id = "save_team"
	team.name = "Save Team FC"
	team.short_name = "STF"
	team.league = "Youth Elite"
	team.tier = 2
	team.formation = "4-3-3"

	var save_data = {
		"version": SaveManager.SAVE_VERSION,
		"career_phase": GameManager.CareerPhase.YOUTH_ACADEMY,
		"national_phase": GameManager.NationalPhase.NONE,
		"prefecture": "Kanagawa",
		"player": player.to_dict(),
		"team": team.to_dict(),
		"career": {
			"match_history": [],
			"career_stats": {
				"matches_played": 12,
				"goals": 4,
				"assists": 7,
				"clean_sheets": 0,
				"man_of_match_awards": 2,
				"trophies": ["Kanagawa Youth Cup"],
				"current_season": 2,
				"awards": [{"type": "playmaker_award", "value": 7, "season": 1}]
			},
			"reputation": 48,
			"media_coverage": 48,
			"fan_popularity": 66,
			"scout_attention": {"city_united": 45},
			"reputation_event_log": [],
			"last_match_reputation_report": {},
			"social_rep_day_key": "",
			"social_rep_awarded_today": 0,
			"social_rep_actions_today": 0,
			"completed_milestones": ["first_goal", "playmaker_award"],
			"rivals": [{"id": "rival_1", "name": "Riku Sato", "team_name": "City United", "position": "ST"}],
			"current_contract": {
				"team_id": "save_team",
				"team_name": "Save Team FC",
				"phase": "YOUTH_ACADEMY",
				"role": "starter",
				"salary": 1200,
				"duration_years": 2,
				"status": "active"
			},
			"club_history": [{"team_name": "Kanagawa First High"}],
			"pending_contract_offers": [{
				"team_id": "city_united",
				"team_name": "City United",
				"salary": 4200,
				"duration_years": 2,
				"length": 2,
				"signing_bonus": 500,
				"squad_role": "rotation",
				"reputation_tier": "Rising Star",
				"target_phase": GameManager.CareerPhase.PRO_CAREER,
				"offer_window": "offseason",
				"starts_next_window": false,
				"expires_on": {"year": 2024, "month": 11, "day": 15},
				"effective_interest": 45,
				"league": "Division One",
				"role_floor": "rotation"
			}],
			"relationships": {
				"npc_teammate": {
					"entity_id": "npc_teammate",
					"type": "teammate",
					"name": "Daiki Mori",
					"affinity": 18,
					"trust": 62
				}
			},
			"coach_trust": 61,
			"scout_relationships": {},
			"queued_contract_offer": {}
		},
		"season": {},
		"narrative": {},
		"personas": {},
		"npc_registry": {},
		"social_feed": {},
		"settings": {}
	}

	SaveManager._apply_save_data(save_data)
	var snapshot = CareerManager.get_career_hub_snapshot()

	assert_eq(int(snapshot.get("offers", {}).get("pending_count", 0)), 1)
	assert_true(bool(snapshot.get("player_overview", {}).get("active_contract", {}).get("available", false)))
	assert_eq(int(snapshot.get("milestones", {}).get("completed_count", 0)), 2)
	assert_eq(int(snapshot.get("relationships", {}).get("total_meaningful", 0)), 1)
	assert_eq(int(snapshot.get("rivals", {}).get("count", 0)), 1)


func test_apply_save_data_restores_player_injury_and_discipline_fields() -> void:
	var player = PlayerData.new()
	player.id = "player_save_rules"
	player.name = "Rules Save"
	player.position = "CM"
	player.apply_injury_report({
		"type": "moderate",
		"injury_type": "hamstring_pull",
		"matches_out": 3,
		"description": "Hamstring pull"
	})
	player.record_competition_card("league::kanagawa", "yellow")
	player.record_competition_card("league::kanagawa", "yellow")
	player.record_competition_card("league::kanagawa", "yellow")

	var save_data = {
		"version": SaveManager.SAVE_VERSION,
		"career_phase": GameManager.CareerPhase.HIGH_SCHOOL,
		"national_phase": GameManager.NationalPhase.NONE,
		"prefecture": "Kanagawa",
		"player": player.to_dict(),
		"career": {},
		"season": {},
		"narrative": {},
		"personas": {},
		"npc_registry": {},
		"social_feed": {},
		"settings": {}
	}

	SaveManager._apply_save_data(save_data)

	assert_eq(GameManager.player_data.get_injury_record().get("injury_type", ""), "hamstring_pull")
	assert_false(GameManager.player_data.is_match_eligible("league::kanagawa"))
