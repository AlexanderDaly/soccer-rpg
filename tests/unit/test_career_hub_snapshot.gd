extends GutTest
## Unit tests for Career Hub snapshot shaping and offer lifecycle

var _snapshot: Dictionary = {}


func before_each() -> void:
	seed(4242)
	_snapshot = {
		"player_data": GameManager.player_data,
		"current_team": GameManager.current_team,
		"career_phase": GameManager.current_career_phase,
		"national_phase": GameManager.current_national_phase,
		"prefecture": GameManager.current_prefecture,
		"season": SeasonManager.to_dict(),
		"match_history": CareerManager.match_history.duplicate(true),
		"career_stats": CareerManager.career_stats.duplicate(true),
		"reputation": CareerManager.reputation,
		"fan_popularity": CareerManager.fan_popularity,
		"media_coverage": CareerManager.media_coverage,
		"current_contract": CareerManager.current_contract.duplicate(true),
		"club_history": CareerManager.club_history.duplicate(true),
		"pending_contract_offers": CareerManager.pending_contract_offers.duplicate(true),
		"relationships": CareerManager.relationships.duplicate(true),
		"coach_trust": CareerManager.coach_trust,
		"scout_relationships": CareerManager.scout_relationships.duplicate(true),
		"queued_contract_offer": CareerManager.queued_contract_offer.duplicate(true),
		"completed_milestones": CareerManager.completed_milestones.duplicate(true),
		"rivals": CareerManager.rivals.duplicate(true)
	}
	_reset_world()


func after_each() -> void:
	GameManager.player_data = _snapshot.get("player_data", null)
	GameManager.current_team = _snapshot.get("current_team", null)
	GameManager.current_career_phase = int(_snapshot.get("career_phase", GameManager.CareerPhase.HIGH_SCHOOL))
	GameManager.current_national_phase = int(_snapshot.get("national_phase", GameManager.NationalPhase.NONE))
	GameManager.current_prefecture = str(_snapshot.get("prefecture", "Kanagawa"))
	SeasonManager.from_dict(_snapshot.get("season", {}))

	CareerManager.match_history.assign(_snapshot.get("match_history", []))
	CareerManager.career_stats = _snapshot.get("career_stats", {}).duplicate(true)
	CareerManager.reputation = int(_snapshot.get("reputation", 10))
	CareerManager.fan_popularity = int(_snapshot.get("fan_popularity", 0))
	CareerManager.media_coverage = int(_snapshot.get("media_coverage", 0))
	CareerManager.current_contract = _snapshot.get("current_contract", {}).duplicate(true)
	CareerManager.club_history.assign(_snapshot.get("club_history", []))
	CareerManager.pending_contract_offers.assign(_snapshot.get("pending_contract_offers", []))
	CareerManager.relationships = _snapshot.get("relationships", {}).duplicate(true)
	CareerManager.coach_trust = int(_snapshot.get("coach_trust", 50))
	CareerManager.scout_relationships = _snapshot.get("scout_relationships", {}).duplicate(true)
	CareerManager.queued_contract_offer = _snapshot.get("queued_contract_offer", {}).duplicate(true)
	CareerManager.completed_milestones.assign(_snapshot.get("completed_milestones", []))
	CareerManager.rivals.assign(_snapshot.get("rivals", []))


func test_snapshot_handles_fresh_career_empty_sections() -> void:
	var team = _setup_basic_career(GameManager.CareerPhase.HIGH_SCHOOL, 1)
	CareerManager.initialize_new_career_state(team)

	var snapshot = CareerManager.get_career_hub_snapshot()

	assert_eq(snapshot.get("player_overview", {}).get("team_name", ""), team.name)
	assert_eq(int(snapshot.get("offers", {}).get("pending_count", -1)), 0)
	assert_eq(int(snapshot.get("rivals", {}).get("count", -1)), 0)
	assert_eq(int(snapshot.get("relationships", {}).get("total_meaningful", -1)), 0)


func test_snapshot_uses_high_school_league_objective_when_outside_top_three() -> void:
	var team = _setup_basic_career(GameManager.CareerPhase.HIGH_SCHOOL, 1)
	var season = _create_league_season(team, GameManager.CareerPhase.HIGH_SCHOOL, "high_school", "Kanagawa")
	_push_player_team_outside_top_three(season.league)

	var snapshot = CareerManager.get_career_hub_snapshot()

	assert_eq(snapshot.get("journey_status", {}).get("phase_type", ""), "league")
	assert_eq(snapshot.get("current_objective", {}).get("title", ""), "Break into the Top 3")


func test_snapshot_uses_knockout_objective_during_qualifiers() -> void:
	var team = _setup_basic_career(GameManager.CareerPhase.HIGH_SCHOOL, 2)
	var season = _create_league_season(team, GameManager.CareerPhase.HIGH_SCHOOL, "high_school", "Kanagawa")
	season.start_qualifiers(season.league.teams.duplicate(), 0, "Kanagawa Cup")

	var snapshot = CareerManager.get_career_hub_snapshot()

	assert_eq(snapshot.get("journey_status", {}).get("phase_type", ""), "knockout")
	assert_eq(snapshot.get("current_objective", {}).get("title", ""), "Win the Knockout Tie")


func test_snapshot_prioritizes_national_overlay_objective() -> void:
	var team = _setup_basic_career(GameManager.CareerPhase.YOUTH_ACADEMY, 3)
	GameManager.current_national_phase = GameManager.NationalPhase.U20_QUALIFIERS
	CareerManager.reputation = 45
	SeasonManager.initialize_season("Kanagawa", team)

	var snapshot = CareerManager.get_career_hub_snapshot()

	assert_true(bool(snapshot.get("journey_status", {}).get("national_overlay_active", false)))
	assert_eq(snapshot.get("current_objective", {}).get("title", ""), "Advance on International Duty")


func test_snapshot_surfaces_fallback_progression_offer_after_third_year() -> void:
	_setup_basic_career(GameManager.CareerPhase.HIGH_SCHOOL, 3)
	CareerManager.reputation = 10

	var offers = CareerManager.generate_progression_offers({})
	var snapshot = CareerManager.get_career_hub_snapshot()

	assert_false(offers.is_empty())
	assert_eq(snapshot.get("current_objective", {}).get("title", ""), "Review Contract Offers")
	assert_eq(int(snapshot.get("offers", {}).get("pending_count", 0)), 1)
	assert_eq(snapshot.get("offers", {}).get("pending", [])[0].get("team_name", ""), "Metro Youth Academy")


func test_snapshot_prioritizes_queued_contract_over_other_goals() -> void:
	var team = _setup_basic_career(GameManager.CareerPhase.YOUTH_ACADEMY, 3)
	CareerManager.reputation = 55
	SeasonManager.initialize_season("Kanagawa", team)

	var offer = CareerManager.generate_contract_offer("city_united", true, {"apply_in_offseason": true})
	CareerManager.accept_contract(offer)
	var snapshot = CareerManager.get_career_hub_snapshot()

	assert_true(bool(snapshot.get("offers", {}).get("queued_contract", {}).get("available", false)))
	assert_eq(snapshot.get("current_objective", {}).get("title", ""), "Finish the Season")


func test_accept_contract_emits_resolution_and_removes_pending_offer() -> void:
	var team = _setup_basic_career(GameManager.CareerPhase.YOUTH_ACADEMY, 3)
	CareerManager.reputation = 55
	SeasonManager.initialize_season("Kanagawa", team)

	var offer = CareerManager.generate_contract_offer("city_united", true, {"apply_in_offseason": true})
	var payload := {"called": false, "team_id": "", "resolution": ""}
	var callback := func(resolved_offer: Dictionary, resolution: String) -> void:
		payload["called"] = true
		payload["team_id"] = str(resolved_offer.get("team_id", ""))
		payload["resolution"] = resolution
	CareerManager.contract_offer_resolved.connect(callback, CONNECT_ONE_SHOT)

	CareerManager.accept_contract(offer)

	assert_true(payload.get("called", false))
	assert_eq(payload.get("team_id", ""), "city_united")
	assert_eq(payload.get("resolution", ""), "accepted")
	assert_eq(CareerManager.pending_contract_offers.size(), 0)


func test_decline_contract_emits_resolution_and_removes_pending_offer() -> void:
	_setup_basic_career(GameManager.CareerPhase.YOUTH_ACADEMY, 3)
	CareerManager.reputation = 55

	var offer = CareerManager.generate_contract_offer("city_united", true)
	var payload := {"called": false, "team_id": "", "resolution": ""}
	var callback := func(resolved_offer: Dictionary, resolution: String) -> void:
		payload["called"] = true
		payload["team_id"] = str(resolved_offer.get("team_id", ""))
		payload["resolution"] = resolution
	CareerManager.contract_offer_resolved.connect(callback, CONNECT_ONE_SHOT)

	CareerManager.decline_contract(offer)

	assert_true(payload.get("called", false))
	assert_eq(payload.get("team_id", ""), "city_united")
	assert_eq(payload.get("resolution", ""), "declined")
	assert_eq(CareerManager.pending_contract_offers.size(), 0)


func _reset_world() -> void:
	GameManager.player_data = null
	GameManager.current_team = null
	GameManager.current_career_phase = GameManager.CareerPhase.HIGH_SCHOOL
	GameManager.current_national_phase = GameManager.NationalPhase.NONE
	GameManager.current_prefecture = "Kanagawa"
	SeasonManager.from_dict({})
	CareerManager.reset_for_new_career()


func _setup_basic_career(phase: GameManager.CareerPhase, school_year: int) -> TeamData:
	GameManager.current_career_phase = phase
	GameManager.current_national_phase = GameManager.NationalPhase.NONE
	GameManager.current_prefecture = "Kanagawa"
	GameManager.player_data = _make_player(school_year)
	GameManager.current_team = _make_team("team_player", "Kanagawa First", phase, "Kanagawa League")
	CareerManager.initialize_new_career_state(GameManager.current_team)
	return GameManager.current_team


func _make_player(school_year: int) -> PlayerData:
	var player = PlayerData.new()
	player.id = "player_hub_test"
	player.name = "Akira Test"
	player.position = "WNG"
	player.nationality = "JPN"
	player.age = 14 + maxi(school_year - 1, 0)
	player.school_year = school_year
	player.dominant_foot = "right"
	player.stats = {
		"SPD": 62,
		"STA": 57,
		"TEC": 61,
		"PAS": 56,
		"SHO": 58,
		"DEF": 42,
		"PHY": 49,
		"MEN": 54
	}
	return player


func _make_team(team_id: String, name: String, phase: GameManager.CareerPhase, league_name: String) -> TeamData:
	var team = TeamData.new()
	team.id = team_id
	team.name = name
	team.short_name = name.substr(0, mini(3, name.length())).to_upper()
	team.league = league_name
	team.tier = 1 if phase == GameManager.CareerPhase.HIGH_SCHOOL else 2
	team.formation = "4-3-3"
	team.generate_teammates(10, phase, false)
	return team


func _create_league_season(player_team: TeamData, phase: GameManager.CareerPhase, season_kind: String, prefecture: String) -> SeasonData:
	var season = SeasonData.new()
	var other_teams: Array[TeamData] = []
	for i in range(9):
		other_teams.append(_make_team("team_%d" % i, "Opponent %d" % i, phase, "%s League" % prefecture))
	season.initialize(prefecture, 2024, player_team, other_teams, season_kind, "%s League" % prefecture)
	SeasonManager.current_season = season
	SeasonManager.national_overlay = null
	SeasonManager.national_overlay_competition = ""
	SeasonManager.national_overlay_match_type = ""
	SeasonManager.national_team = null
	return season


func _push_player_team_outside_top_three(league: LeagueData) -> void:
	var player_team_id = league.get_player_team_id()
	var bonus_points = 12
	for team in league.teams:
		var stats = league.standings[team.id]
		if team.id == player_team_id:
			stats["points"] = 0
		else:
			stats["points"] = bonus_points
			bonus_points = maxi(bonus_points - 2, 0)
		league.standings[team.id] = stats
