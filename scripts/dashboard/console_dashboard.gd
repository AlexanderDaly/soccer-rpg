extends Control
class_name ConsoleDashboard
## ConsoleDashboard - Main FIFA/Pro Evo style console dashboard

const TILE_CONFIG: Array[Dictionary] = [
	{"id": "training", "title": "Training", "icon": "res://assets/ui/icons/icon_training.svg", "panel": "res://scenes/dashboard/panels/panel_training.tscn"},
	{"id": "schedule", "title": "Schedule", "icon": "res://assets/ui/icons/icon_calendar.svg", "panel": "res://scenes/dashboard/panels/panel_schedule.tscn"},
	{"id": "league", "title": "League", "icon": "res://assets/ui/icons/icon_league.svg", "panel": "res://scenes/dashboard/panels/panel_league_table.tscn"},
	{"id": "tournament", "title": "Tournament", "icon": "res://assets/ui/icons/icon_trophy.svg", "panel": "res://scenes/dashboard/panels/panel_tournament_bracket.tscn"},
	{"id": "awards", "title": "Awards", "icon": "res://assets/ui/icons/icon_trophy.svg", "panel": "res://scenes/dashboard/panels/panel_season_awards.tscn"},
	{"id": "team", "title": "Team", "icon": "res://assets/ui/icons/icon_team.svg", "panel": "res://scenes/dashboard/panels/panel_team.tscn"},
	{"id": "stats", "title": "Stats", "icon": "res://assets/ui/icons/icon_stats.svg", "panel": "res://scenes/dashboard/panels/panel_player_stats.tscn"},
	{"id": "email", "title": "Email", "icon": "res://assets/ui/icons/icon_email.svg", "panel": "res://scenes/dashboard/panels/panel_email.tscn"},
	{"id": "desktop", "title": "Desktop", "icon": "res://assets/ui/icons/icon_settings.svg", "scene": "res://scenes/desktop/desktop_shell.tscn"},
	{"id": "career_hub", "title": "Career Hub", "icon": "res://assets/ui/icons/icon_team.svg", "scene": "res://scenes/career/career_hub.tscn"},
	{"id": "social", "title": "FanZone", "icon": "res://assets/ui/icons/icon_team.svg", "panel": "res://scenes/dashboard/panels/panel_social.tscn"},
	{"id": "save", "title": "Save", "icon": "res://assets/ui/icons/icon_save.svg", "panel": "res://scenes/dashboard/panels/panel_save_load.tscn"},
	{"id": "settings", "title": "Settings", "icon": "res://assets/ui/icons/icon_settings.svg", "panel": "res://scenes/dashboard/panels/panel_settings.tscn"}
]

@onready var background: ColorRect = $Background
@onready var header: PanelContainer = $MainLayout/Header
@onready var club_badge: TextureRect = $MainLayout/Header/HeaderContent/ClubBadge
@onready var club_name_label: Label = $MainLayout/Header/HeaderContent/ClubNameLabel
@onready var notification_badge: Label = $MainLayout/Header/HeaderContent/NotificationBadge
@onready var clock_label: Label = $MainLayout/Header/HeaderContent/ClockLabel
@onready var player_mini_card: PlayerMiniCard = $MainLayout/ContentArea/LeftSection/PlayerMiniCard
@onready var tile_grid: GridContainer = $MainLayout/ContentArea/LeftSection/TileGrid
@onready var hero_match_card: HeroMatchCard = $MainLayout/ContentArea/RightSection/HeroMatchCard
@onready var footer: PanelContainer = $MainLayout/Footer
@onready var footer_hints: Label = $MainLayout/Footer/FooterHints
@onready var panel_layer: Control = $PanelLayer

var tile_navigation: TileNavigation
var tiles: Array[FeatureTile] = []
var active_panel: PanelBase = null
var clock_timer: Timer


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.CAREER_HUB)
	_setup_background()
	_setup_header()
	_setup_tiles()
	_setup_footer()
	_setup_clock()
	_connect_signals()

	AudioManager.play_music("menu")


func _setup_background() -> void:
	if background:
		# Create gradient background
		background.color = Color(0.039, 0.086, 0.157)


func _setup_header() -> void:
	# Style the header
	if header:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.05, 0.1, 0.9)
		style.border_color = Color(0.15, 0.25, 0.4)
		style.set_border_width_all(0)
		style.border_width_bottom = 1
		style.set_content_margin_all(16)
		header.add_theme_stylebox_override("panel", style)

	# Set club info
	var team = GameManager.current_team
	if club_name_label:
		club_name_label.text = team.name if team else "Your Team"
		club_name_label.add_theme_font_size_override("font_size", 20)
		club_name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1))

	_update_notification_badge()
	_update_clock()


func _setup_tiles() -> void:
	if not tile_grid:
		return

	# Clear any existing tiles
	for child in tile_grid.get_children():
		child.queue_free()
	tiles.clear()

	# Load tile scene
	var tile_scene = preload("res://scenes/dashboard/components/feature_tile.tscn")

	# Create tiles
	for config in TILE_CONFIG:
		var tile = tile_scene.instantiate() as FeatureTile
		var icon: Texture2D = null
		if ResourceLoader.exists(config.icon):
			icon = load(config.icon)
		tile.setup(config.id, config.title, icon)
		tile.pressed.connect(_on_tile_pressed)
		tile_grid.add_child(tile)
		tiles.append(tile)

	# Setup navigation
	tile_navigation = TileNavigation.new()
	tile_navigation.columns = tile_grid.columns if tile_grid else 2
	add_child(tile_navigation)
	tile_navigation.register_tiles(tiles)


func _setup_footer() -> void:
	if footer:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.02, 0.05, 0.1, 0.9)
		style.border_color = Color(0.15, 0.25, 0.4)
		style.set_border_width_all(0)
		style.border_width_top = 1
		style.set_content_margin_all(12)
		footer.add_theme_stylebox_override("panel", style)

	if footer_hints:
		footer_hints.text = "[Arrows/D-pad = Navigate]    [Enter/A = Select]    [Escape/B = Back]"
		footer_hints.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		footer_hints.add_theme_font_size_override("font_size", 14)


func _setup_clock() -> void:
	clock_timer = Timer.new()
	clock_timer.wait_time = 1.0
	clock_timer.autostart = true
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)


func _connect_signals() -> void:
	DesktopManager.notification_received.connect(_on_notification_received)

	if hero_match_card:
		hero_match_card.play_match_pressed.connect(_on_play_match)


func _update_notification_badge() -> void:
	if notification_badge:
		var count = DesktopManager.get_unread_count()
		if count > 0:
			notification_badge.visible = true
			notification_badge.text = str(count) if count < 100 else "99+"

			var style = StyleBoxFlat.new()
			style.bg_color = Color(1, 0.3, 0.3)
			style.set_corner_radius_all(10)
			style.set_content_margin_all(4)
			notification_badge.add_theme_stylebox_override("normal", style)
		else:
			notification_badge.visible = false


func _update_clock() -> void:
	if clock_label:
		clock_label.text = "%s  %s" % [DesktopManager.get_date_string(), DesktopManager.get_time_string()]
		clock_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))


func _on_notification_received(_notification: Dictionary) -> void:
	_update_notification_badge()


func _on_tile_pressed(tile_id: String) -> void:
	# Find the panel path for this tile
	for config in TILE_CONFIG:
		if config.id == tile_id:
			if config.has("panel"):
				_open_panel(config.panel)
			elif config.has("scene"):
				_open_scene(config.scene)
			return


func _open_panel(panel_path: String) -> void:
	if active_panel:
		return  # Already have a panel open

	var panel_scene = load(panel_path)
	if not panel_scene:
		push_error("Failed to load panel: " + panel_path)
		return

	active_panel = panel_scene.instantiate() as PanelBase
	if not active_panel:
		push_error("Panel is not a PanelBase: " + panel_path)
		return

	panel_layer.add_child(active_panel)
	active_panel.panel_closed.connect(_on_panel_closed)
	active_panel.open()

	# Disable tile navigation while panel is open
	if tile_navigation:
		tile_navigation.set_navigation_enabled(false)


func _open_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return

	get_tree().change_scene_to_file(scene_path)


func _on_panel_closed() -> void:
	if active_panel:
		active_panel.queue_free()
		active_panel = null

	# Re-enable tile navigation
	if tile_navigation:
		tile_navigation.set_navigation_enabled(true)

	# Refresh displays
	if player_mini_card:
		player_mini_card._refresh_display()

	_update_notification_badge()


func _on_play_match(match_data: Dictionary) -> void:
	# Match is started by hero_match_card, scene transition handled there
	pass


func _input(event: InputEvent) -> void:
	# Handle back button when no panel is open (go to main menu)
	if active_panel:
		return

	if event.is_action_pressed("ui_cancel"):
		# Show confirmation or go to settings
		_open_panel("res://scenes/dashboard/panels/panel_settings.tscn")
