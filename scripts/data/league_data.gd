extends Resource
class_name LeagueData
## LeagueData - Manages league standings, fixtures, and round-robin logic

# Japanese HS Soccer Calendar
# League runs April-October, ~1 match per week on weekends
const SEASON_START_MONTH: int = 4  # April
const SEASON_START_DAY: int = 6    # First Saturday of April (approx)
const DAYS_BETWEEN_MATCHDAYS: int = 7  # Weekly matches

@export var id: String = ""
@export var name: String = ""  # e.g., "Kanagawa Prefecture League"
@export var teams: Array[TeamData] = []
@export var player_team_index: int = 0

# Season timing
@export var season_year: int = 2024

# Standings: team_id -> {played, won, drawn, lost, gf, ga, points}
@export var standings: Dictionary = {}

# Fixtures: [{match_id, matchday, home_id, away_id, played, home_score, away_score, match_date}]
@export var fixtures: Array[Dictionary] = []

@export var current_matchday: int = 1
@export var is_complete: bool = false


func _init() -> void:
	id = "league_%d" % randi()


func initialize(league_name: String, league_teams: Array[TeamData], player_idx: int, year: int = 2024) -> void:
	name = league_name
	teams = league_teams
	player_team_index = player_idx
	season_year = year

	_initialize_standings()
	_generate_fixtures()


func _initialize_standings() -> void:
	standings.clear()
	for team in teams:
		standings[team.id] = {
			"team_id": team.id,
			"team_name": team.name,
			"played": 0,
			"won": 0,
			"drawn": 0,
			"lost": 0,
			"gf": 0,  # Goals for
			"ga": 0,  # Goals against
			"gd": 0,  # Goal difference
			"points": 0,
			"form": []  # Last 5 results: "W", "D", "L"
		}


func _generate_fixtures() -> void:
	# Generate round-robin fixtures (each team plays each other twice - home and away)
	fixtures.clear()

	var num_teams = teams.size()
	if num_teams < 2:
		return

	var match_id_counter = 0
	var matchday = 1

	# First half of season (each team plays every other team once)
	for i in range(num_teams):
		for j in range(i + 1, num_teams):
			fixtures.append({
				"match_id": "match_%d_%d" % [id.hash(), match_id_counter],
				"matchday": matchday,
				"home_id": teams[i].id,
				"away_id": teams[j].id,
				"home_team_name": teams[i].name,
				"away_team_name": teams[j].name,
				"played": false,
				"home_score": 0,
				"away_score": 0
			})
			match_id_counter += 1
			matchday = (matchday % (num_teams - 1)) + 1

	# Second half of season (reverse fixtures)
	var first_half_count = fixtures.size()
	for i in range(first_half_count):
		var original = fixtures[i]
		fixtures.append({
			"match_id": "match_%d_%d" % [id.hash(), match_id_counter],
			"matchday": matchday + original.matchday,
			"home_id": original.away_id,
			"away_id": original.home_id,
			"home_team_name": original.away_team_name,
			"away_team_name": original.home_team_name,
			"played": false,
			"home_score": 0,
			"away_score": 0
		})
		match_id_counter += 1

	# Sort fixtures by matchday
	fixtures.sort_custom(func(a, b): return a.matchday < b.matchday)

	# Assign calendar dates to each fixture
	_assign_fixture_dates()


func _assign_fixture_dates() -> void:
	# Assign calendar dates based on matchday
	# Each matchday is ~1 week apart, starting from April
	for i in range(fixtures.size()):
		var matchday = fixtures[i].matchday
		fixtures[i].match_date = get_date_for_matchday(matchday)


func get_date_for_matchday(matchday: int) -> Dictionary:
	# Calculate the date for a given matchday
	# Matchday 1 = First Saturday of April
	# Each subsequent matchday is 1 week later
	var days_offset = (matchday - 1) * DAYS_BETWEEN_MATCHDAYS

	# Start from April 6th (first Saturday typically)
	var start_day = SEASON_START_DAY + days_offset
	var month = SEASON_START_MONTH
	var year = season_year

	# Handle month overflow
	var days_in_month = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	# Adjust for leap year
	if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
		days_in_month[2] = 29

	while start_day > days_in_month[month]:
		start_day -= days_in_month[month]
		month += 1
		if month > 12:
			month = 1
			year += 1

	return {"year": year, "month": month, "day": start_day}


func get_formatted_date(matchday: int) -> String:
	var date = get_date_for_matchday(matchday)
	var months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d" % [months[date.month], date.day]


func record_result(home_id: String, away_id: String, home_score: int, away_score: int) -> void:
	# Find and update the fixture
	for i in range(fixtures.size()):
		var fixture = fixtures[i]
		if fixture.home_id == home_id and fixture.away_id == away_id and not fixture.played:
			fixtures[i].played = true
			fixtures[i].home_score = home_score
			fixtures[i].away_score = away_score

			# Update standings
			_update_standings(home_id, away_id, home_score, away_score)

			# Check if all matches for current matchday are played
			_check_matchday_complete()
			break


func _update_standings(home_id: String, away_id: String, home_score: int, away_score: int) -> void:
	var home_stats = standings[home_id]
	var away_stats = standings[away_id]

	# Update matches played
	home_stats.played += 1
	away_stats.played += 1

	# Update goals
	home_stats.gf += home_score
	home_stats.ga += away_score
	away_stats.gf += away_score
	away_stats.ga += home_score

	# Update goal difference
	home_stats.gd = home_stats.gf - home_stats.ga
	away_stats.gd = away_stats.gf - away_stats.ga

	# Determine winner and update points/form
	if home_score > away_score:
		# Home win
		home_stats.won += 1
		home_stats.points += 3
		away_stats.lost += 1
		_add_form(home_id, "W")
		_add_form(away_id, "L")
	elif away_score > home_score:
		# Away win
		away_stats.won += 1
		away_stats.points += 3
		home_stats.lost += 1
		_add_form(away_id, "W")
		_add_form(home_id, "L")
	else:
		# Draw
		home_stats.drawn += 1
		away_stats.drawn += 1
		home_stats.points += 1
		away_stats.points += 1
		_add_form(home_id, "D")
		_add_form(away_id, "D")

	standings[home_id] = home_stats
	standings[away_id] = away_stats


func _add_form(team_id: String, result: String) -> void:
	var team_stats = standings[team_id]
	team_stats.form.append(result)
	if team_stats.form.size() > 5:
		team_stats.form.pop_front()


func _check_matchday_complete() -> void:
	var matchday_complete = true
	for fixture in fixtures:
		if fixture.matchday == current_matchday and not fixture.played:
			matchday_complete = false
			break

	if matchday_complete:
		current_matchday += 1

		# Check if entire league is complete
		var all_played = true
		for fixture in fixtures:
			if not fixture.played:
				all_played = false
				break

		is_complete = all_played


func get_sorted_standings() -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for team_id in standings:
		sorted.append(standings[team_id])

	# Sort by: points, goal difference, goals for
	sorted.sort_custom(func(a, b):
		if a.points != b.points:
			return a.points > b.points
		if a.gd != b.gd:
			return a.gd > b.gd
		return a.gf > b.gf
	)

	return sorted


func get_team_position(team_id: String) -> int:
	var sorted = get_sorted_standings()
	for i in range(sorted.size()):
		if sorted[i].team_id == team_id:
			return i + 1
	return -1


func get_player_team() -> TeamData:
	if player_team_index >= 0 and player_team_index < teams.size():
		return teams[player_team_index]
	return null


func get_player_team_id() -> String:
	var team = get_player_team()
	return team.id if team else ""


func get_next_player_fixture() -> Dictionary:
	var player_id = get_player_team_id()
	for fixture in fixtures:
		if not fixture.played and (fixture.home_id == player_id or fixture.away_id == player_id):
			return fixture
	return {}


func get_all_player_fixtures() -> Array[Dictionary]:
	# Returns all fixtures involving the player team (played and unplayed)
	var result: Array[Dictionary] = []
	var player_id = get_player_team_id()
	for fixture in fixtures:
		if fixture.home_id == player_id or fixture.away_id == player_id:
			result.append(fixture)
	return result


func get_remaining_player_fixtures() -> Array[Dictionary]:
	# Returns only unplayed fixtures involving the player team
	var result: Array[Dictionary] = []
	var player_id = get_player_team_id()
	for fixture in fixtures:
		if not fixture.played and (fixture.home_id == player_id or fixture.away_id == player_id):
			result.append(fixture)
	return result


func get_fixtures_for_matchday(matchday: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fixture in fixtures:
		if fixture.matchday == matchday:
			result.append(fixture)
	return result


func get_unplayed_cpu_fixtures_for_matchday(matchday: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var player_id = get_player_team_id()

	for fixture in fixtures:
		if fixture.matchday == matchday and not fixture.played:
			if fixture.home_id != player_id and fixture.away_id != player_id:
				result.append(fixture)

	return result


func get_team_by_id(team_id: String) -> TeamData:
	for team in teams:
		if team.id == team_id:
			return team
	return null


func is_in_qualifying_position(team_id: String) -> bool:
	# Top 2 teams qualify for the prefecture qualifier
	return get_team_position(team_id) <= 2


func to_dict() -> Dictionary:
	var teams_data: Array[Dictionary] = []
	for team in teams:
		teams_data.append(team.to_dict())

	return {
		"id": id,
		"name": name,
		"teams": teams_data,
		"player_team_index": player_team_index,
		"season_year": season_year,
		"standings": standings,
		"fixtures": fixtures,
		"current_matchday": current_matchday,
		"is_complete": is_complete
	}


func from_dict(data: Dictionary) -> void:
	id = data.get("id", id)
	name = data.get("name", "")
	player_team_index = data.get("player_team_index", 0)
	season_year = data.get("season_year", 2024)
	standings = data.get("standings", {})
	fixtures.assign(data.get("fixtures", []))
	current_matchday = data.get("current_matchday", 1)
	is_complete = data.get("is_complete", false)

	# Restore teams
	teams.clear()
	var teams_data = data.get("teams", [])
	for team_data in teams_data:
		var team = TeamData.new()
		team.from_dict(team_data)
		teams.append(team)
