extends Resource
class_name SeasonData
## SeasonData - Orchestrates season phases and holds all competition data

enum Phase {
	PRE_SEASON,
	LEAGUE,
	QUALIFIERS,
	NATIONALS,
	POST_SEASON
}

@export var prefecture: String = ""
@export var year: int = 2024
@export var season_kind: String = "high_school"

@export var league: LeagueData
@export var prefecture_qualifier: TournamentData
@export var national_championship: TournamentData

@export var current_phase: Phase = Phase.PRE_SEASON
@export var qualified_for_nationals: bool = false
@export var eliminated_from_qualifiers: bool = false

# Season calendar - month when each phase starts
const PHASE_CALENDAR = {
	Phase.PRE_SEASON: 4,   # April
	Phase.LEAGUE: 4,       # April-November
	Phase.QUALIFIERS: 11,  # November
	Phase.NATIONALS: 12,   # December-January
	Phase.POST_SEASON: 1   # January (next year)
}


func _init() -> void:
	pass


func initialize(pref: String, season_year: int, player_team: TeamData, other_teams: Array[TeamData], kind: String = "high_school", league_name: String = "", cup_name: String = "") -> void:
	prefecture = pref
	year = season_year
	season_kind = kind

	# Initialize league
	var league_teams: Array[TeamData] = [player_team]
	league_teams.append_array(other_teams.slice(0, 9))  # 10 teams total

	league = LeagueData.new()
	var resolved_league_name = league_name
	if resolved_league_name.is_empty():
		resolved_league_name = "%s Prefecture League" % prefecture if season_kind == "high_school" else "%s League" % pref
	league.initialize(resolved_league_name, league_teams, 0, year)

	current_phase = Phase.LEAGUE


func start_qualifiers(qualifier_teams: Array[TeamData], player_team_idx: int, tournament_name: String = "") -> void:
	prefecture_qualifier = TournamentData.new()
	var resolved_name = tournament_name if not tournament_name.is_empty() else "%s Prefecture Qualifier" % prefecture
	prefecture_qualifier.initialize(
		resolved_name,
		qualifier_teams,
		player_team_idx,
		TournamentData.TournamentType.PREFECTURE_QUALIFIER
	)
	current_phase = Phase.QUALIFIERS


func start_nationals(national_teams: Array[TeamData], player_team_idx: int) -> void:
	national_championship = TournamentData.new()
	national_championship.initialize(
		"National High School Championship",
		national_teams,
		player_team_idx,
		TournamentData.TournamentType.NATIONAL_CHAMPIONSHIP
	)
	qualified_for_nationals = true
	current_phase = Phase.NATIONALS


func advance_to_post_season() -> void:
	current_phase = Phase.POST_SEASON


func get_current_competition_name() -> String:
	match current_phase:
		Phase.LEAGUE:
			return league.name if league else "Prefecture League"
		Phase.QUALIFIERS:
			return prefecture_qualifier.name if prefecture_qualifier else "Cup"
		Phase.NATIONALS:
			return national_championship.name if national_championship else "National Championship"
		_:
			return ""


func get_next_player_match() -> Dictionary:
	match current_phase:
		Phase.LEAGUE:
			if league:
				return league.get_next_player_fixture()
		Phase.QUALIFIERS:
			if prefecture_qualifier:
				return prefecture_qualifier.get_next_player_match()
		Phase.NATIONALS:
			if national_championship:
				return national_championship.get_next_player_match()

	return {}


func get_match_type_for_phase() -> String:
	match current_phase:
		Phase.LEAGUE:
			return "league"
		Phase.QUALIFIERS:
			return "prefecture_qualifier" if season_kind == "high_school" else "cup"
		Phase.NATIONALS:
			return "national_championship"
		_:
			return "friendly"


func get_match_importance_for_phase() -> float:
	match current_phase:
		Phase.LEAGUE:
			return 1.0
		Phase.QUALIFIERS:
			return 1.5 if season_kind == "high_school" else 1.6
		Phase.NATIONALS:
			if national_championship:
				match national_championship.current_stage:
					TournamentData.Stage.FINAL:
						return 3.0
					TournamentData.Stage.SEMI_FINAL:
						return 2.5
					TournamentData.Stage.QUARTER_FINAL:
						return 2.0
					_:
						return 1.8
			return 1.8
		_:
			return 0.5


func is_league_complete() -> bool:
	return league and league.is_complete


func is_qualifiers_complete() -> bool:
	return prefecture_qualifier and prefecture_qualifier.is_complete


func is_nationals_complete() -> bool:
	return national_championship and national_championship.is_complete


func player_won_league() -> bool:
	if league and league.is_complete:
		return league.get_team_position(league.get_player_team_id()) == 1
	return false


func player_qualified_through_league() -> bool:
	if league and league.is_complete:
		return league.is_in_qualifying_position(league.get_player_team_id())
	return false


func player_won_qualifiers() -> bool:
	return prefecture_qualifier and prefecture_qualifier.player_won_tournament()


func player_won_nationals() -> bool:
	return national_championship and national_championship.player_won_tournament()


func player_eliminated_from_qualifiers() -> bool:
	return prefecture_qualifier and prefecture_qualifier.player_eliminated


func player_eliminated_from_nationals() -> bool:
	return national_championship and national_championship.player_eliminated


func get_season_summary() -> Dictionary:
	var summary = {
		"prefecture": prefecture,
		"year": year,
		"phase": Phase.keys()[current_phase],
		"league_position": league.get_team_position(league.get_player_team_id()) if league else 0,
		"league_complete": is_league_complete(),
		"qualified_for_nationals": qualified_for_nationals,
		"nationals_stage_reached": national_championship.get_current_stage_name() if national_championship else "",
		"national_champion": player_won_nationals()
	}

	# Include league awards and leaderboards if available
	if league:
		summary["league_awards"] = league.league_awards
		if league.player_stats:
			var total_matches = league.player_stats.get_total_matches_in_league(league.teams.size())
			summary["top_scorers"] = league.player_stats.get_top_scorers(5, total_matches)
			summary["top_assisters"] = league.player_stats.get_top_assisters(5, total_matches)
		summary["avg_fouls_per_game"] = league.get_avg_fouls_per_game()

	return summary


func to_dict() -> Dictionary:
	return {
		"prefecture": prefecture,
		"year": year,
		"season_kind": season_kind,
		"league": league.to_dict() if league else {},
		"prefecture_qualifier": prefecture_qualifier.to_dict() if prefecture_qualifier else {},
		"national_championship": national_championship.to_dict() if national_championship else {},
		"current_phase": current_phase,
		"qualified_for_nationals": qualified_for_nationals,
		"eliminated_from_qualifiers": eliminated_from_qualifiers
	}


func from_dict(data: Dictionary) -> void:
	prefecture = data.get("prefecture", "")
	year = data.get("year", 2024)
	season_kind = data.get("season_kind", "high_school")
	current_phase = data.get("current_phase", Phase.PRE_SEASON)
	qualified_for_nationals = data.get("qualified_for_nationals", false)
	eliminated_from_qualifiers = data.get("eliminated_from_qualifiers", false)

	# Restore league
	var league_data = data.get("league", {})
	if not league_data.is_empty():
		league = LeagueData.new()
		league.from_dict(league_data)

	# Restore qualifier
	var qualifier_data = data.get("prefecture_qualifier", {})
	if not qualifier_data.is_empty():
		prefecture_qualifier = TournamentData.new()
		prefecture_qualifier.from_dict(qualifier_data)

	# Restore nationals
	var nationals_data = data.get("national_championship", {})
	if not nationals_data.is_empty():
		national_championship = TournamentData.new()
		national_championship.from_dict(nationals_data)
