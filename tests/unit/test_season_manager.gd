extends GutTest

var _snapshot: Dictionary = {}


func before_each() -> void:
	_snapshot = {
		"career_phase": GameManager.current_career_phase,
		"national_phase": GameManager.current_national_phase,
		"player_data": GameManager.player_data,
		"current_team": GameManager.current_team,
		"current_prefecture": GameManager.current_prefecture,
		"season": SeasonManager.to_dict()
	}


func after_each() -> void:
	GameManager.current_career_phase = _snapshot.get("career_phase", GameManager.CareerPhase.HIGH_SCHOOL)
	GameManager.current_national_phase = _snapshot.get("national_phase", GameManager.NationalPhase.NONE)
	GameManager.player_data = _snapshot.get("player_data", null)
	GameManager.current_team = _snapshot.get("current_team", null)
	GameManager.current_prefecture = _snapshot.get("current_prefecture", "Kanagawa")
	SeasonManager.from_dict(_snapshot.get("season", {}))


func test_get_upcoming_fixtures_merges_primary_and_u20_overlay() -> void:
	GameManager.current_career_phase = GameManager.CareerPhase.YOUTH_ACADEMY
	GameManager.current_national_phase = GameManager.NationalPhase.U20_QUALIFIERS
	GameManager.current_prefecture = "Kanagawa"

	var player = PlayerData.new()
	player.id = "player_test"
	player.name = "Fixture Test"
	player.position = "WNG"
	player.nationality = "JPN"
	player.age = 18
	player.school_year = 3
	GameManager.player_data = player

	CareerManager.reputation = 45

	var team = CareerManager.create_team_from_catalog({
		"id": "metro_youth_academy",
		"name": "Metro Youth Academy",
		"short_name": "MYA",
		"league": "Youth Elite",
		"tier": 2
	}, GameManager.CareerPhase.YOUTH_ACADEMY)
	GameManager.current_team = team

	SeasonManager.initialize_season("Kanagawa", team)

	var fixtures = SeasonManager.get_upcoming_fixtures()
	var has_primary = false
	var has_overlay = false
	for fixture in fixtures:
		var competition = str(fixture.get("competition", ""))
		if competition.contains("Youth Elite"):
			has_primary = true
		if competition.contains("U20"):
			has_overlay = true

	assert_true(fixtures.size() > 1, "Unified fixture feed should include league fixtures plus the U20 overlay")
	assert_true(has_primary, "Primary club fixtures should be present")
	assert_true(has_overlay, "National overlay fixtures should be present")
