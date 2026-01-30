extends PanelBase
class_name PanelEmail
## PanelEmail - Email inbox panel

@onready var inbox_list: VBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HSplitContainer/InboxPanel/ScrollContainer/InboxList
@onready var message_panel: PanelContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HSplitContainer/MessagePanel
@onready var message_from: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HSplitContainer/MessagePanel/VBoxContainer/FromLabel
@onready var message_subject: Label = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HSplitContainer/MessagePanel/VBoxContainer/SubjectLabel
@onready var message_body: RichTextLabel = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HSplitContainer/MessagePanel/VBoxContainer/BodyText
@onready var action_buttons: HBoxContainer = $ContentContainer/MarginContainer/VBoxContainer/ContentArea/MainContent/HSplitContainer/MessagePanel/VBoxContainer/ActionButtons

var emails: Array[Dictionary] = []
var selected_email_index: int = -1


func _on_panel_ready() -> void:
	panel_title = "ProMail"
	if title_label:
		title_label.text = panel_title


func _on_panel_opened() -> void:
	_connect_signals()
	_load_emails()
	_refresh_inbox()


func _connect_signals() -> void:
	if not CareerManager.scout_interest.is_connected(_on_scout_interest):
		CareerManager.scout_interest.connect(_on_scout_interest)
	if not CareerManager.contract_offer_received.is_connected(_on_contract_offer):
		CareerManager.contract_offer_received.connect(_on_contract_offer)


func _load_emails() -> void:
	# Load saved emails or generate default welcome email
	if emails.is_empty():
		emails.append({
			"from": "Coach",
			"subject": "Welcome to the Team!",
			"body": "Welcome to your new career journey! Check your schedule for upcoming matches and hit the training center to improve your skills.\n\nGood luck!",
			"date": DesktopManager.get_date_string(),
			"read": false,
			"type": "info"
		})


func _refresh_inbox() -> void:
	if not inbox_list:
		return

	for child in inbox_list.get_children():
		child.queue_free()

	for i in range(emails.size()):
		var email = emails[i]
		_add_inbox_item(email, i)

	if emails.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No emails"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		inbox_list.add_child(empty_label)
	elif selected_email_index < 0 and not emails.is_empty():
		_select_email(0)


func _add_inbox_item(email: Dictionary, index: int) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)

	if not email.read:
		style.bg_color = Color(0.1, 0.15, 0.25)
		style.border_color = Color(0, 0.6, 0.3)
		style.set_border_width_all(1)
	else:
		style.bg_color = Color(0.06, 0.1, 0.18, 0.8)
		style.border_color = Color(0.15, 0.25, 0.4)
		style.set_border_width_all(1)

	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var from_label = Label.new()
	from_label.text = email.from
	from_label.add_theme_font_size_override("font_size", 14)
	if not email.read:
		from_label.add_theme_color_override("font_color", Color(0, 1, 0.5))
	else:
		from_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	var subject_label = Label.new()
	subject_label.text = email.subject
	subject_label.add_theme_font_size_override("font_size", 12)
	subject_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	subject_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	vbox.add_child(from_label)
	vbox.add_child(subject_label)
	panel.add_child(vbox)

	panel.gui_input.connect(_on_inbox_item_clicked.bind(index))
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	inbox_list.add_child(panel)


func _on_inbox_item_clicked(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_email(index)


func _select_email(index: int) -> void:
	if index < 0 or index >= emails.size():
		return

	selected_email_index = index
	var email = emails[index]
	email.read = true

	_display_email(email)
	_refresh_inbox()


func _display_email(email: Dictionary) -> void:
	if message_from:
		message_from.text = "From: %s" % email.from
		message_from.add_theme_color_override("font_color", Color(0.9, 0.95, 1))

	if message_subject:
		message_subject.text = email.subject
		message_subject.add_theme_font_size_override("font_size", 18)
		message_subject.add_theme_color_override("font_color", Color(0.9, 0.95, 1))

	if message_body:
		message_body.text = email.body
		message_body.add_theme_color_override("default_color", Color(0.8, 0.85, 0.9))

	_setup_action_buttons(email)


func _setup_action_buttons(email: Dictionary) -> void:
	if not action_buttons:
		return

	for child in action_buttons.get_children():
		child.queue_free()

	if email.type == "contract":
		var accept_btn = _create_button("Accept", Color(0, 0.6, 0.3))
		accept_btn.pressed.connect(_on_accept_contract.bind(email))
		action_buttons.add_child(accept_btn)

		var decline_btn = _create_button("Decline", Color(0.6, 0.2, 0.2))
		decline_btn.pressed.connect(_on_decline_contract.bind(email))
		action_buttons.add_child(decline_btn)

	var delete_btn = _create_button("Delete", Color(0.4, 0.15, 0.15))
	delete_btn.pressed.connect(_on_delete_email)
	action_buttons.add_child(delete_btn)


func _create_button(text: String, bg_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 32)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = bg_color.lightened(0.2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))

	return btn


func _on_accept_contract(email: Dictionary) -> void:
	AudioManager.play_ui_confirm()

	if email.has("offer_data"):
		CareerManager.accept_contract(email.offer_data)

	emails.erase(email)
	selected_email_index = -1
	_refresh_inbox()
	_clear_message_display()

	DesktopManager.show_notification(
		"Contract Accepted!",
		"Congratulations on your new contract!",
		"",
		"email"
	)


func _on_decline_contract(email: Dictionary) -> void:
	AudioManager.play_ui_click()

	emails.erase(email)
	selected_email_index = -1
	_refresh_inbox()
	_clear_message_display()


func _on_delete_email() -> void:
	if selected_email_index >= 0 and selected_email_index < emails.size():
		AudioManager.play_ui_click()
		emails.remove_at(selected_email_index)
		selected_email_index = -1
		_refresh_inbox()
		_clear_message_display()


func _clear_message_display() -> void:
	if message_from:
		message_from.text = ""
	if message_subject:
		message_subject.text = "Select an email"
	if message_body:
		message_body.text = ""
	if action_buttons:
		for child in action_buttons.get_children():
			child.queue_free()


func _on_scout_interest(scout_data: Dictionary) -> void:
	emails.insert(0, {
		"from": "Scout Report",
		"subject": "Interest from %s" % scout_data.get("team_name", "Unknown Club"),
		"body": "A scout from %s was impressed with your recent performance! Keep playing well to attract more attention." % scout_data.get("team_name", "a club"),
		"date": DesktopManager.get_date_string(),
		"read": false,
		"type": "scout"
	})

	if is_open:
		_refresh_inbox()


func _on_contract_offer(offer: Dictionary) -> void:
	emails.insert(0, {
		"from": offer.get("team_name", "Club"),
		"subject": "Contract Offer!",
		"body": "We are pleased to offer you a contract to join %s!\n\nWages: $%d/week\nLength: %d years\n\nWe hope you will consider this opportunity." % [
			offer.get("team_name", "our club"),
			offer.get("wages", 1000),
			offer.get("length", 2)
		],
		"date": DesktopManager.get_date_string(),
		"read": false,
		"type": "contract",
		"offer_data": offer
	})

	if is_open:
		_refresh_inbox()
