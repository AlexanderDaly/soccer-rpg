extends Control
## DesktopShell - Main desktop controller managing the retro PC interface

const WINDOW_BASE_SCENE = preload("res://scenes/desktop/components/window_base.tscn")

# Desktop colors
const DESKTOP_BG_COLOR = Color(0.0, 0.5, 0.5)  # Teal

# Icon grid settings
const ICON_SPACING = Vector2(80, 90)
const ICON_START_OFFSET = Vector2(20, 20)
const ICONS_PER_COLUMN = 8

@onready var wallpaper: ColorRect = $Wallpaper
@onready var desktop_icons: Control = $DesktopIcons
@onready var window_layer: Control = $WindowLayer
@onready var taskbar: PanelContainer = $Taskbar
@onready var notification_container: Control = $NotificationContainer

# Desktop icon instances
var icon_instances: Dictionary = {}

# Apps to show on desktop
var desktop_apps: Array[String] = [
	"player_stats",
	"email",
	"team",
	"social_media",
	"schedule",
	"training",
	"save_load",
	"settings"
]


func _ready() -> void:
	_setup_wallpaper()
	_create_desktop_icons()
	_connect_signals()
	_connect_input_layer_signals()
	_refresh_input_layers()
	GameManager.change_state(GameManager.GameState.CAREER_HUB)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_back"):
		return_to_dashboard()
		get_viewport().set_input_as_handled()


func _setup_wallpaper() -> void:
	wallpaper.color = DESKTOP_BG_COLOR


func _create_desktop_icons() -> void:
	var icon_scene = preload("res://scenes/desktop/components/desktop_icon.tscn")
	var column = 0
	var row = 0

	for app_id in desktop_apps:
		var app_info = DesktopManager.get_app_info(app_id)
		if app_info.is_empty():
			continue

		var icon = icon_scene.instantiate()
		desktop_icons.add_child(icon)

		icon.setup(app_id, app_info.get("title", "App"), app_info.get("icon", ""))
		icon.position = ICON_START_OFFSET + Vector2(column * ICON_SPACING.x, row * ICON_SPACING.y)
		icon.icon_double_clicked.connect(_on_icon_double_clicked)

		icon_instances[app_id] = icon

		row += 1
		if row >= ICONS_PER_COLUMN:
			row = 0
			column += 1


func _connect_signals() -> void:
	DesktopManager.window_opened.connect(_on_window_opened)
	DesktopManager.window_closed.connect(_on_window_closed)
	DesktopManager.notification_received.connect(_on_notification_received)


func _connect_input_layer_signals() -> void:
	window_layer.child_entered_tree.connect(_on_input_layer_child_changed)
	window_layer.child_exiting_tree.connect(_on_input_layer_child_changed)
	notification_container.child_entered_tree.connect(_on_input_layer_child_changed)
	notification_container.child_exiting_tree.connect(_on_input_layer_child_changed)


func _on_input_layer_child_changed(_child: Node) -> void:
	call_deferred("_refresh_input_layers")


func _refresh_input_layers() -> void:
	window_layer.mouse_filter = Control.MOUSE_FILTER_PASS if window_layer.get_child_count() > 0 else Control.MOUSE_FILTER_IGNORE
	notification_container.mouse_filter = Control.MOUSE_FILTER_PASS if notification_container.get_child_count() > 0 else Control.MOUSE_FILTER_IGNORE


func _on_icon_double_clicked(app_id: String) -> void:
	open_app(app_id)


func open_app(app_id: String) -> void:
	# If already open, just focus it
	if DesktopManager.is_window_open(app_id):
		DesktopManager.focus_window(app_id)
		return

	var app_info = DesktopManager.get_app_info(app_id)
	if app_info.is_empty():
		push_warning("[DesktopShell] Unknown app: %s" % app_id)
		return

	# Create window
	var window = WINDOW_BASE_SCENE.instantiate()
	window_layer.add_child(window)

	# Setup window
	var min_size = app_info.get("min_size", Vector2(300, 200))
	window.setup(app_id, app_info.get("title", "App"), app_info.get("icon", ""), min_size)

	# Load and add app content
	var scene_path = app_info.get("scene", "")
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var app_content = load(scene_path).instantiate()
		window.set_content(app_content)

	# Position window (cascade from top-left)
	var open_count = DesktopManager.get_open_windows().size()
	window.position = Vector2(150 + open_count * 30, 50 + open_count * 30)

	# Register with manager
	DesktopManager.register_window(app_id, window)

	AudioManager.play_ui_click()


func _on_window_opened(_window_id: String) -> void:
	# Taskbar will handle this via its own signal connection
	pass


func _on_window_closed(_window_id: String) -> void:
	# Taskbar will handle this via its own signal connection
	pass


func _on_notification_received(notification: Dictionary) -> void:
	_show_notification_toast(notification)


func return_to_dashboard() -> void:
	DesktopManager.reset_window_state()
	get_tree().change_scene_to_file("res://scenes/dashboard/console_dashboard.tscn")


func _show_notification_toast(notification: Dictionary) -> void:
	var toast_scene = preload("res://scenes/desktop/components/notification_toast.tscn")
	var toast = toast_scene.instantiate()
	notification_container.add_child(toast)

	toast.setup(
		notification.get("title", ""),
		notification.get("message", ""),
		notification.get("icon", "")
	)

	# Position toast at bottom-right, above taskbar
	var screen_size = get_viewport_rect().size
	toast.position = Vector2(screen_size.x - 320, screen_size.y - 140 - notification_container.get_child_count() * 80)

	# Connect to open related app on click
	var app_id = notification.get("app_id", "")
	if app_id != "":
		toast.clicked.connect(func(): open_app(app_id))
