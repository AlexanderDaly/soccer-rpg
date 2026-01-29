extends PanelContainer
## Taskbar - Bottom taskbar with start button, open windows, and system tray

@onready var start_button: Button = $HBoxContainer/StartButton
@onready var open_windows_container: HBoxContainer = $HBoxContainer/OpenWindowsContainer
@onready var notification_badge: Label = $HBoxContainer/SystemTray/NotificationBadge
@onready var clock_label: Label = $HBoxContainer/SystemTray/ClockLabel

var window_buttons: Dictionary = {}  # window_id -> Button
var clock_timer: Timer


func _ready() -> void:
	_setup_style()
	_connect_signals()
	_start_clock()


func _setup_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.75, 0.75, 0.75)
	style.border_width_top = 2
	style.border_color = Color(1, 1, 1)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	add_theme_stylebox_override("panel", style)


func _connect_signals() -> void:
	start_button.pressed.connect(_on_start_pressed)
	DesktopManager.window_opened.connect(_on_window_opened)
	DesktopManager.window_closed.connect(_on_window_closed)
	DesktopManager.window_focused.connect(_on_window_focused)
	DesktopManager.window_minimized.connect(_on_window_minimized)
	DesktopManager.notification_received.connect(_on_notification_received)


func _start_clock() -> void:
	clock_timer = Timer.new()
	clock_timer.wait_time = 1.0
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)
	clock_timer.start()
	_update_clock()


func _update_clock() -> void:
	clock_label.text = DesktopManager.get_time_string() + "  " + DesktopManager.get_date_string()
	_update_notification_badge()


func _update_notification_badge() -> void:
	var count = DesktopManager.get_unread_count()
	if count > 0:
		notification_badge.text = str(count)
		notification_badge.visible = true
	else:
		notification_badge.visible = false


func _on_start_pressed() -> void:
	AudioManager.play_ui_click()
	# Could open a start menu here in the future


func _on_window_opened(window_id: String) -> void:
	_add_window_button(window_id)


func _on_window_closed(window_id: String) -> void:
	_remove_window_button(window_id)


func _on_window_focused(window_id: String) -> void:
	_update_button_states(window_id)


func _on_window_minimized(window_id: String) -> void:
	_update_button_states("")


func _on_notification_received(_notification: Dictionary) -> void:
	_update_notification_badge()


func _add_window_button(window_id: String) -> void:
	if window_id in window_buttons:
		return

	var app_info = DesktopManager.get_app_info(window_id)
	var title = app_info.get("title", window_id)

	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(120, 28)
	button.toggle_mode = true
	button.button_pressed = true
	button.pressed.connect(_on_window_button_pressed.bind(window_id))

	open_windows_container.add_child(button)
	window_buttons[window_id] = button


func _remove_window_button(window_id: String) -> void:
	if window_id in window_buttons:
		var button = window_buttons[window_id]
		button.queue_free()
		window_buttons.erase(window_id)


func _update_button_states(focused_id: String) -> void:
	for window_id in window_buttons:
		var button = window_buttons[window_id]
		button.button_pressed = (window_id == focused_id)

		# Visual feedback for minimized windows
		if DesktopManager.is_window_minimized(window_id):
			button.modulate = Color(0.8, 0.8, 0.8)
		else:
			button.modulate = Color.WHITE


func _on_window_button_pressed(window_id: String) -> void:
	AudioManager.play_ui_click()

	if DesktopManager.is_window_minimized(window_id):
		DesktopManager.restore_window(window_id)
	else:
		var is_focused = (DesktopManager.focused_window_id == window_id)
		if is_focused:
			DesktopManager.minimize_window(window_id)
		else:
			DesktopManager.focus_window(window_id)
