extends Node
## DesktopManager - Manages window system, notifications, and desktop state
## Autoloaded singleton accessible via DesktopManager

signal window_opened(window_id: String)
signal window_closed(window_id: String)
signal window_focused(window_id: String)
signal window_minimized(window_id: String)
signal window_restored(window_id: String)
signal notification_received(notification: Dictionary)
signal panel_opened(panel_id: String)
signal panel_closed(panel_id: String)

# Window tracking
var active_windows: Dictionary = {}  # window_id -> WindowBase reference
var window_z_order: Array[String] = []  # Front to back ordering
var minimized_windows: Array[String] = []
var focused_window_id: String = ""

# Panel tracking (for console dashboard)
var active_panel: Control = null
var panel_scenes: Dictionary = {
	"training": "res://scenes/dashboard/panels/panel_training.tscn",
	"schedule": "res://scenes/dashboard/panels/panel_schedule.tscn",
	"team": "res://scenes/dashboard/panels/panel_team.tscn",
	"email": "res://scenes/dashboard/panels/panel_email.tscn",
	"player_stats": "res://scenes/dashboard/panels/panel_player_stats.tscn",
	"social": "res://scenes/dashboard/panels/panel_social.tscn",
	"save_load": "res://scenes/dashboard/panels/panel_save_load.tscn",
	"settings": "res://scenes/dashboard/panels/panel_settings.tscn"
}

# In-game time (for display purposes)
var game_date: Dictionary = {
	"year": 2024,
	"month": 4,
	"day": 1,
	"hour": 8,
	"minute": 0
}

# Notification queue
var pending_notifications: Array[Dictionary] = []
var notification_history: Array[Dictionary] = []
const MAX_NOTIFICATION_HISTORY = 50

# App registry
var registered_apps: Dictionary = {}


func _ready() -> void:
	print("[DesktopManager] Initialized")
	_connect_game_signals()
	_register_default_apps()


func _connect_game_signals() -> void:
	# Connect to existing manager signals for notifications
	CareerManager.scout_interest.connect(_on_scout_interest)
	CareerManager.milestone_reached.connect(_on_milestone_reached)
	CareerManager.contract_offer_received.connect(_on_contract_offer)
	NarrativeEngine.news_article_generated.connect(_on_news_article)
	StatSystem.level_up.connect(_on_level_up)
	SaveManager.save_completed.connect(_on_save_completed)


func _register_default_apps() -> void:
	register_app("player_stats", {
		"title": "Player Stats",
		"icon": "res://assets/ui/icons/icon_stats.svg",
		"scene": "res://scenes/desktop/apps/app_player_stats.tscn",
		"min_size": Vector2(400, 500)
	})
	register_app("email", {
		"title": "ProMail",
		"icon": "res://assets/ui/icons/icon_email.svg",
		"scene": "res://scenes/desktop/apps/app_email.tscn",
		"min_size": Vector2(500, 400)
	})
	register_app("save_load", {
		"title": "Save Manager",
		"icon": "res://assets/ui/icons/icon_save.svg",
		"scene": "res://scenes/desktop/apps/app_save_load.tscn",
		"min_size": Vector2(400, 350)
	})
	register_app("settings", {
		"title": "Settings",
		"icon": "res://assets/ui/icons/icon_settings.svg",
		"scene": "res://scenes/desktop/apps/app_settings.tscn",
		"min_size": Vector2(350, 300)
	})
	register_app("team", {
		"title": "Team Roster",
		"icon": "res://assets/ui/icons/icon_team.svg",
		"scene": "res://scenes/desktop/apps/app_team.tscn",
		"min_size": Vector2(450, 500)
	})
	register_app("social_media", {
		"title": "FanZone",
		"icon": "res://assets/ui/icons/icon_social.svg",
		"scene": "res://scenes/desktop/apps/app_social_media.tscn",
		"min_size": Vector2(400, 450)
	})
	register_app("schedule", {
		"title": "Calendar",
		"icon": "res://assets/ui/icons/icon_calendar.svg",
		"scene": "res://scenes/desktop/apps/app_schedule.tscn",
		"min_size": Vector2(400, 400)
	})
	register_app("training", {
		"title": "Training Center",
		"icon": "res://assets/ui/icons/icon_training.svg",
		"scene": "res://scenes/desktop/apps/app_training.tscn",
		"min_size": Vector2(450, 400)
	})


func register_app(app_id: String, app_data: Dictionary) -> void:
	registered_apps[app_id] = app_data


func get_app_info(app_id: String) -> Dictionary:
	return registered_apps.get(app_id, {})


# Window management
func register_window(window_id: String, window_ref: Node) -> void:
	active_windows[window_id] = window_ref
	window_z_order.push_front(window_id)
	window_opened.emit(window_id)
	focus_window(window_id)


func unregister_window(window_id: String) -> void:
	if window_id in active_windows:
		active_windows.erase(window_id)
		window_z_order.erase(window_id)
		minimized_windows.erase(window_id)

		if focused_window_id == window_id:
			focused_window_id = ""
			# Focus next window if available
			if not window_z_order.is_empty():
				focus_window(window_z_order[0])

		window_closed.emit(window_id)


func focus_window(window_id: String) -> void:
	if window_id not in active_windows:
		return

	# Restore if minimized
	if window_id in minimized_windows:
		restore_window(window_id)

	# Move to front of z-order
	window_z_order.erase(window_id)
	window_z_order.push_front(window_id)

	# Update z-indices
	_update_window_z_indices()

	var old_focused = focused_window_id
	focused_window_id = window_id

	# Update visual states
	for wid in active_windows:
		var window = active_windows[wid]
		if window.has_method("set_focused"):
			window.set_focused(wid == window_id)

	window_focused.emit(window_id)


func minimize_window(window_id: String) -> void:
	if window_id not in active_windows:
		return

	if window_id not in minimized_windows:
		minimized_windows.append(window_id)

	var window = active_windows[window_id]
	if window:
		window.visible = false

	# Focus next available window
	if focused_window_id == window_id:
		focused_window_id = ""
		for wid in window_z_order:
			if wid not in minimized_windows:
				focus_window(wid)
				break

	window_minimized.emit(window_id)


func restore_window(window_id: String) -> void:
	if window_id not in active_windows:
		return

	minimized_windows.erase(window_id)

	var window = active_windows[window_id]
	if window:
		window.visible = true

	focus_window(window_id)
	window_restored.emit(window_id)


func is_window_open(window_id: String) -> bool:
	return window_id in active_windows


func is_window_minimized(window_id: String) -> bool:
	return window_id in minimized_windows


func get_open_windows() -> Array[String]:
	var windows: Array[String] = []
	windows.assign(window_z_order)
	return windows


func reset_window_state() -> void:
	active_windows.clear()
	window_z_order.clear()
	minimized_windows.clear()
	focused_window_id = ""


func _update_window_z_indices() -> void:
	var z_index = 100
	for window_id in window_z_order:
		if window_id in active_windows:
			var window = active_windows[window_id]
			if window:
				window.z_index = z_index
				z_index -= 1


# Notification system
func show_notification(title: String, message: String, icon: String = "", app_id: String = "") -> void:
	var notification = {
		"title": title,
		"message": message,
		"icon": icon,
		"app_id": app_id,
		"timestamp": Time.get_datetime_string_from_system(),
		"read": false
	}

	pending_notifications.append(notification)
	notification_history.append(notification)

	# Trim history if too long
	while notification_history.size() > MAX_NOTIFICATION_HISTORY:
		notification_history.pop_front()

	notification_received.emit(notification)


func get_pending_notifications() -> Array[Dictionary]:
	var notifications: Array[Dictionary] = []
	notifications.assign(pending_notifications)
	return notifications


func clear_pending_notifications() -> void:
	for notification in pending_notifications:
		notification.read = true
	pending_notifications.clear()


func get_unread_count() -> int:
	return pending_notifications.size()


# Signal handlers for game events
func _on_scout_interest(scout_data: Dictionary) -> void:
	show_notification(
		"Scout Spotted!",
		"A scout from %s was watching!" % scout_data.get("team_name", "Unknown"),
		"res://assets/ui/icons/icon_email.svg",
		"email"
	)


func _on_milestone_reached(milestone_id: String) -> void:
	var milestone = CareerManager.MILESTONES.get(milestone_id, {})
	show_notification(
		"Milestone Achieved!",
		milestone.get("name", "Unknown") + " - " + milestone.get("description", ""),
		"res://assets/ui/icons/icon_stats.svg",
		"player_stats"
	)


func _on_contract_offer(offer: Dictionary) -> void:
	show_notification(
		"New Contract Offer!",
		"You've received a contract offer!",
		"res://assets/ui/icons/icon_email.svg",
		"email"
	)


func _on_news_article(article: Dictionary) -> void:
	show_notification(
		"FanZone Update",
		article.get("headline", "New article published"),
		"res://assets/ui/icons/icon_social.svg",
		"social_media"
	)


func _on_level_up(player_id: String, new_level: int) -> void:
	if GameManager.player_data and player_id == GameManager.player_data.id:
		show_notification(
			"Level Up!",
			"You've reached level %d!" % new_level,
			"res://assets/ui/icons/icon_stats.svg",
			"player_stats"
		)


func _on_save_completed(slot: int, success: bool) -> void:
	if success:
		show_notification(
			"Game Saved",
			"Progress saved to slot %d" % (slot + 1),
			"res://assets/ui/icons/icon_save.svg",
			""
		)


# Time management
func advance_time(hours: int = 0, days: int = 0) -> void:
	game_date.minute = 0
	game_date.hour += hours

	while game_date.hour >= 24:
		game_date.hour -= 24
		game_date.day += 1

	game_date.day += days

	# Simple month/year rollover (30 days per month for simplicity)
	while game_date.day > 30:
		game_date.day -= 30
		game_date.month += 1

	while game_date.month > 12:
		game_date.month -= 12
		game_date.year += 1


func get_time_string() -> String:
	return "%02d:%02d" % [game_date.hour, game_date.minute]


func get_date_string() -> String:
	var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d, %d" % [months[game_date.month - 1], game_date.day, game_date.year]


# Panel management (for console dashboard)
func open_panel(panel_id: String, parent: Node) -> Control:
	if active_panel:
		close_current_panel()

	var panel_path = panel_scenes.get(panel_id, "")
	if panel_id == "social" and SocialFeedManager and SocialFeedManager.is_v2_enabled():
		panel_path = "res://scenes/dashboard/panels/panel_social_v2.tscn"
	if panel_path.is_empty():
		push_error("Unknown panel: " + panel_id)
		return null

	var panel_scene = load(panel_path)
	if not panel_scene:
		push_error("Failed to load panel scene: " + panel_path)
		return null

	active_panel = panel_scene.instantiate()
	parent.add_child(active_panel)

	if active_panel.has_method("open"):
		active_panel.open()

	panel_opened.emit(panel_id)
	return active_panel


func close_current_panel() -> void:
	if not active_panel:
		return

	if active_panel.has_method("close"):
		active_panel.close()
	else:
		active_panel.queue_free()

	active_panel = null
	panel_closed.emit("")


func get_active_panel() -> Control:
	return active_panel


func is_panel_open() -> bool:
	return active_panel != null


func register_panel(panel_id: String, scene_path: String) -> void:
	panel_scenes[panel_id] = scene_path


func get_panel_scene_path(panel_id: String) -> String:
	return panel_scenes.get(panel_id, "")
