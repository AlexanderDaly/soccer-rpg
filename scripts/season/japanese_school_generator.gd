extends RefCounted
class_name JapaneseSchoolGenerator
## JapaneseSchoolGenerator - Generates authentic Japanese high school names

# Japanese prefectures with their capital cities
const PREFECTURES = {
	"Hokkaido": "Sapporo",
	"Aomori": "Aomori",
	"Iwate": "Morioka",
	"Miyagi": "Sendai",
	"Akita": "Akita",
	"Yamagata": "Yamagata",
	"Fukushima": "Fukushima",
	"Ibaraki": "Mito",
	"Tochigi": "Utsunomiya",
	"Gunma": "Maebashi",
	"Saitama": "Saitama",
	"Chiba": "Chiba",
	"Tokyo": "Tokyo",
	"Kanagawa": "Yokohama",
	"Niigata": "Niigata",
	"Toyama": "Toyama",
	"Ishikawa": "Kanazawa",
	"Fukui": "Fukui",
	"Yamanashi": "Kofu",
	"Nagano": "Nagano",
	"Gifu": "Gifu",
	"Shizuoka": "Shizuoka",
	"Aichi": "Nagoya",
	"Mie": "Tsu",
	"Shiga": "Otsu",
	"Kyoto": "Kyoto",
	"Osaka": "Osaka",
	"Hyogo": "Kobe",
	"Nara": "Nara",
	"Wakayama": "Wakayama",
	"Tottori": "Tottori",
	"Shimane": "Matsue",
	"Okayama": "Okayama",
	"Hiroshima": "Hiroshima",
	"Yamaguchi": "Yamaguchi",
	"Tokushima": "Tokushima",
	"Kagawa": "Takamatsu",
	"Ehime": "Matsuyama",
	"Kochi": "Kochi",
	"Fukuoka": "Fukuoka",
	"Saga": "Saga",
	"Nagasaki": "Nagasaki",
	"Kumamoto": "Kumamoto",
	"Oita": "Oita",
	"Miyazaki": "Miyazaki",
	"Kagoshima": "Kagoshima",
	"Okinawa": "Naha"
}

# Famous high school soccer powerhouses (real schools for reference/inspiration)
const POWERHOUSE_PREFIXES = [
	"Seisho", "Toho", "Meiwa", "Nankatsu", "Otomo",
	"Aoyama", "Musashi", "Ryukyu", "Furano", "Kojiro"
]

# Geographic/directional prefixes (common in Japanese school names)
const DIRECTIONAL_PREFIXES = [
	"Higashi",  # East
	"Nishi",    # West
	"Minami",   # South
	"Kita",     # North
	"Chuo",     # Central
	"Shinsei",  # New/Fresh
	"Daichi",   # First/Great
	"Kaisei",   # Reform/Open
	"Seibu",    # Western
	"Tobu"      # Eastern
]

# Nature-inspired prefixes
const NATURE_PREFIXES = [
	"Sakura",    # Cherry blossom
	"Aoba",      # Green leaves
	"Hikari",    # Light
	"Asahi",     # Morning sun
	"Yamato",    # Japan/harmony
	"Tsubasa",   # Wings
	"Taiyou",    # Sun
	"Sora",      # Sky
	"Umi",       # Sea
	"Yama"       # Mountain
]

# Quality/virtue prefixes
const VIRTUE_PREFIXES = [
	"Seiei",     # Elite
	"Gakuen",    # Academy
	"Seiwa",     # Harmony
	"Meiko",     # Bright
	"Kosei",     # Individuality
	"Seirin",    # Blue forest
	"Shohoku",   # Pine/North
	"Kainan",    # Sea south
	"Ryonan",    # Good south
	"Shoyo"      # Pine sun
]

# School type suffixes
const SCHOOL_SUFFIXES = [
	"High School",
	"Gakuen",      # Academy
	"Technical",
	"Commercial",
	"Industrial",
	"Academy"
]

# Short suffixes for display
const SHORT_SUFFIXES = [
	"HS",
	"Gakuen",
	"Tech",
	"AC"
]

# Regional cities/areas for variety
const REGIONAL_AREAS = {
	"Hokkaido": ["Sapporo", "Asahikawa", "Hakodate", "Kushiro", "Obihiro"],
	"Tohoku": ["Sendai", "Morioka", "Aomori", "Yamagata", "Akita"],
	"Kanto": ["Yokohama", "Kawasaki", "Urawa", "Ichihara", "Kashiwa"],
	"Chubu": ["Nagoya", "Shizuoka", "Niigata", "Hamamatsu", "Kofu"],
	"Kansai": ["Osaka", "Kobe", "Kyoto", "Nara", "Wakayama"],
	"Chugoku": ["Hiroshima", "Okayama", "Sanfrecce", "Yamaguchi", "Matsue"],
	"Shikoku": ["Matsuyama", "Takamatsu", "Tokushima", "Kochi"],
	"Kyushu": ["Fukuoka", "Kitakyushu", "Kumamoto", "Kagoshima", "Nagasaki"]
}


static func get_all_prefectures() -> Array[String]:
	var result: Array[String] = []
	for pref in PREFECTURES:
		result.append(pref)
	result.sort()
	return result


static func get_prefecture_capital(prefecture: String) -> String:
	return PREFECTURES.get(prefecture, prefecture)


static func get_region_for_prefecture(prefecture: String) -> String:
	var hokkaido = ["Hokkaido"]
	var tohoku = ["Aomori", "Iwate", "Miyagi", "Akita", "Yamagata", "Fukushima"]
	var kanto = ["Ibaraki", "Tochigi", "Gunma", "Saitama", "Chiba", "Tokyo", "Kanagawa"]
	var chubu = ["Niigata", "Toyama", "Ishikawa", "Fukui", "Yamanashi", "Nagano", "Gifu", "Shizuoka", "Aichi"]
	var kansai = ["Mie", "Shiga", "Kyoto", "Osaka", "Hyogo", "Nara", "Wakayama"]
	var chugoku = ["Tottori", "Shimane", "Okayama", "Hiroshima", "Yamaguchi"]
	var shikoku = ["Tokushima", "Kagawa", "Ehime", "Kochi"]
	var kyushu = ["Fukuoka", "Saga", "Nagasaki", "Kumamoto", "Oita", "Miyazaki", "Kagoshima", "Okinawa"]

	if prefecture in hokkaido:
		return "Hokkaido"
	elif prefecture in tohoku:
		return "Tohoku"
	elif prefecture in kanto:
		return "Kanto"
	elif prefecture in chubu:
		return "Chubu"
	elif prefecture in kansai:
		return "Kansai"
	elif prefecture in chugoku:
		return "Chugoku"
	elif prefecture in shikoku:
		return "Shikoku"
	elif prefecture in kyushu:
		return "Kyushu"
	return "Kanto"


static func generate_school_name(prefecture: String = "", use_short: bool = false) -> String:
	var prefix: String
	var suffix: String

	# Choose a prefix type based on random chance
	var prefix_type = randi() % 5
	match prefix_type:
		0:
			prefix = POWERHOUSE_PREFIXES[randi() % POWERHOUSE_PREFIXES.size()]
		1:
			prefix = DIRECTIONAL_PREFIXES[randi() % DIRECTIONAL_PREFIXES.size()]
		2:
			prefix = NATURE_PREFIXES[randi() % NATURE_PREFIXES.size()]
		3:
			prefix = VIRTUE_PREFIXES[randi() % VIRTUE_PREFIXES.size()]
		_:
			# Use prefecture-based name
			if prefecture != "":
				var capital = get_prefecture_capital(prefecture)
				prefix = capital
			else:
				prefix = DIRECTIONAL_PREFIXES[randi() % DIRECTIONAL_PREFIXES.size()]

	# Choose suffix
	if use_short:
		suffix = SHORT_SUFFIXES[randi() % SHORT_SUFFIXES.size()]
	else:
		suffix = SCHOOL_SUFFIXES[randi() % SCHOOL_SUFFIXES.size()]

	return "%s %s" % [prefix, suffix]


static func generate_unique_school_names(prefecture: String, count: int) -> Array[String]:
	var names: Array[String] = []
	var used_prefixes: Array[String] = []

	# Always include the prefecture's main school
	var capital = get_prefecture_capital(prefecture)
	names.append("%s First High School" % capital)
	used_prefixes.append(capital)

	# Generate remaining names
	var all_prefixes: Array[String] = []
	all_prefixes.append_array(POWERHOUSE_PREFIXES)
	all_prefixes.append_array(DIRECTIONAL_PREFIXES)
	all_prefixes.append_array(NATURE_PREFIXES)
	all_prefixes.append_array(VIRTUE_PREFIXES)
	all_prefixes.shuffle()

	for prefix in all_prefixes:
		if names.size() >= count:
			break
		if prefix not in used_prefixes:
			var suffix = SCHOOL_SUFFIXES[randi() % SCHOOL_SUFFIXES.size()]
			names.append("%s %s" % [prefix, suffix])
			used_prefixes.append(prefix)

	return names


static func generate_league_teams(prefecture: String, player_team: TeamData, count: int = 10) -> Array[TeamData]:
	var teams: Array[TeamData] = []
	var school_names = generate_unique_school_names(prefecture, count - 1)

	# Add player's team first
	teams.append(player_team)

	# Generate opponent teams
	for i in range(mini(count - 1, school_names.size())):
		var team = TeamData.new()
		team.name = school_names[i]
		team.short_name = _generate_short_name(school_names[i])
		team.league = "%s Prefecture" % prefecture
		team.tier = 1  # High school tier

		# Vary team strength slightly
		var strength_variance = randi_range(-1, 1)
		team.tier = clampi(1 + strength_variance, 1, 2)

		team.formation = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"][randi() % 4]
		team.generate_teammates(10, GameManager.CareerPhase.HIGH_SCHOOL)

		teams.append(team)

	return teams


static func generate_qualifier_teams(prefecture: String, league_teams: Array[TeamData], count: int = 16) -> Array[TeamData]:
	# Start with league teams
	var teams: Array[TeamData] = []
	teams.append_array(league_teams)

	# Generate additional teams for the qualifier
	var additional_needed = count - teams.size()
	if additional_needed > 0:
		var region = get_region_for_prefecture(prefecture)
		var additional_names = _generate_regional_school_names(region, additional_needed, teams)

		for name_entry in additional_names:
			var team = TeamData.new()
			team.name = name_entry
			team.short_name = _generate_short_name(name_entry)
			team.league = "%s Prefecture" % prefecture
			team.tier = 1
			team.formation = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"][randi() % 4]
			team.generate_teammates(10, GameManager.CareerPhase.HIGH_SCHOOL)
			teams.append(team)

	return teams


static func generate_national_teams(player_team: TeamData, count: int = 48) -> Array[TeamData]:
	var teams: Array[TeamData] = [player_team]
	var used_names: Array[String] = [player_team.name]

	# Generate teams from different prefectures
	var prefectures = get_all_prefectures()
	prefectures.shuffle()

	for pref in prefectures:
		if teams.size() >= count:
			break

		var capital = get_prefecture_capital(pref)
		var school_name = "%s %s" % [capital, SCHOOL_SUFFIXES[randi() % SCHOOL_SUFFIXES.size()]]

		if school_name not in used_names:
			var team = TeamData.new()
			team.name = school_name
			team.short_name = _generate_short_name(school_name)
			team.league = "%s Prefecture" % pref
			team.tier = randi_range(1, 2)  # National teams are stronger
			team.formation = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"][randi() % 4]
			team.generate_teammates(10, GameManager.CareerPhase.HIGH_SCHOOL)
			teams.append(team)
			used_names.append(school_name)

	# Fill remaining with generated names
	while teams.size() < count:
		var all_prefixes: Array[String] = []
		all_prefixes.append_array(POWERHOUSE_PREFIXES)
		all_prefixes.append_array(VIRTUE_PREFIXES)
		all_prefixes.shuffle()

		for prefix in all_prefixes:
			if teams.size() >= count:
				break

			var suffix = SCHOOL_SUFFIXES[randi() % SCHOOL_SUFFIXES.size()]
			var school_name = "%s %s" % [prefix, suffix]

			if school_name not in used_names:
				var team = TeamData.new()
				team.name = school_name
				team.short_name = _generate_short_name(school_name)
				team.tier = randi_range(1, 2)
				team.formation = ["4-4-2", "4-3-3", "4-2-3-1", "3-5-2"][randi() % 4]
				team.generate_teammates(10, GameManager.CareerPhase.HIGH_SCHOOL)
				teams.append(team)
				used_names.append(school_name)

	return teams


static func _generate_short_name(full_name: String) -> String:
	var words = full_name.split(" ")
	if words.size() > 0:
		var first_word = words[0]
		if first_word.length() > 3:
			return first_word.substr(0, 3).to_upper()
		return first_word.to_upper()
	return "UNK"


static func _generate_regional_school_names(region: String, count: int, existing_teams: Array[TeamData]) -> Array[String]:
	var names: Array[String] = []
	var used_names: Array[String] = []

	for team in existing_teams:
		used_names.append(team.name)

	var areas = REGIONAL_AREAS.get(region, REGIONAL_AREAS["Kanto"])
	var prefixes: Array[String] = []
	prefixes.append_array(areas)
	prefixes.append_array(DIRECTIONAL_PREFIXES)
	prefixes.append_array(NATURE_PREFIXES)
	prefixes.shuffle()

	for prefix in prefixes:
		if names.size() >= count:
			break

		var suffix = SCHOOL_SUFFIXES[randi() % SCHOOL_SUFFIXES.size()]
		var school_name = "%s %s" % [prefix, suffix]

		if school_name not in used_names and school_name not in names:
			names.append(school_name)

	return names
