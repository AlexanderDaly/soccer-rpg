extends Control
## AppEmail - ProMail app for scout offers, contracts, and messages

@onready var inbox_list: ItemList = $HSplitContainer/LeftPanel/InboxList
@onready var message_title: Label = $HSplitContainer/RightPanel/MessageHeader/MessageTitle
@onready var message_from: Label = $HSplitContainer/RightPanel/MessageHeader/MessageFrom
@onready var message_body: RichTextLabel = $HSplitContainer/RightPanel/ScrollContainer/MessageBody
@onready var action_container: HBoxContainer = $HSplitContainer/RightPanel/ActionContainer

# Email storage
var emails: Array[Dictionary] = []
var selected_index: int = -1


func _ready() -> void:
	_generate_initial_emails()
	_sync_contract_offer_emails()
	_refresh_inbox()
	_connect_signals()


func _connect_signals() -> void:
	inbox_list.item_selected.connect(_on_email_selected)
	CareerManager.scout_interest.connect(_on_scout_interest)
	CareerManager.contract_offer_received.connect(_on_contract_offer)
	CareerManager.contract_offer_resolved.connect(_on_contract_offer_resolved)


func _generate_initial_emails() -> void:
	# Welcome email
	emails.append({
		"id": "welcome",
		"from": "Coach Yamamoto",
		"subject": "Welcome to the Team!",
		"body": "Welcome to Sakura High School soccer team!\n\nI've been watching your progress and I see great potential in you. Work hard in practice, give your all in matches, and I know you'll go far.\n\nRemember: talent is nothing without dedication. Let's make this season one to remember!\n\n- Coach Yamamoto",
		"date": DesktopManager.get_date_string(),
		"read": false,
		"type": "coach"
	})

	# Tips email
	emails.append({
		"id": "tips",
		"from": "Career Advisor",
		"subject": "Tips for Rising Stars",
		"body": "Here are some tips for advancing your career:\n\n1. Perform well in matches to increase your reputation\n2. High reputation attracts scouts\n3. Scouts may send you contract offers\n4. Check FanZone for news about your career\n5. Train regularly to improve your stats\n\nGood luck on your journey to the pros!",
		"date": DesktopManager.get_date_string(),
		"read": false,
		"type": "system"
	})


func _refresh_inbox() -> void:
	inbox_list.clear()

	for i in range(emails.size()):
		var email = emails[i]
		var prefix = "" if email.get("read", false) else "[NEW] "
		inbox_list.add_item(prefix + email.get("subject", "No Subject"))

		# Visual indicator for unread
		if not email.get("read", false):
			inbox_list.set_item_custom_fg_color(i, Color(0.0, 0.0, 0.5))


func _on_email_selected(index: int) -> void:
	if index < 0 or index >= emails.size():
		return

	AudioManager.play_ui_click()
	selected_index = index
	var email = emails[index]

	# Mark as read
	email.read = true
	_refresh_inbox()
	inbox_list.select(index)

	# Display email
	message_title.text = email.get("subject", "No Subject")
	message_from.text = "From: %s  |  %s" % [email.get("from", "Unknown"), email.get("date", "")]
	message_body.text = email.get("body", "")

	# Setup action buttons based on email type
	_setup_action_buttons(email)


func _setup_action_buttons(email: Dictionary) -> void:
	# Clear existing buttons
	for child in action_container.get_children():
		child.queue_free()

	var email_type = email.get("type", "")

	if email_type == "contract_offer":
		var accept_btn = Button.new()
		accept_btn.text = "Accept Offer"
		accept_btn.pressed.connect(_on_accept_contract.bind(email))

		var decline_btn = Button.new()
		decline_btn.text = "Decline"
		decline_btn.pressed.connect(_on_decline_contract.bind(email))

		action_container.add_child(accept_btn)
		action_container.add_child(decline_btn)

	elif email_type == "scout":
		var info_label = Label.new()
		info_label.text = "Keep performing well to receive an offer!"
		action_container.add_child(info_label)

	# Delete button for all emails
	var delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(_on_delete_email.bind(email))
	action_container.add_child(delete_btn)


func _on_accept_contract(email: Dictionary) -> void:
	AudioManager.play_ui_confirm()
	if email.has("offer_data"):
		CareerManager.accept_contract(email.offer_data)
	DesktopManager.show_notification(
		"Contract Signed!",
		"You've accepted the offer from %s!" % email.get("team_name", "the team"),
		"",
		"email"
	)
	_remove_email(email)


func _on_decline_contract(email: Dictionary) -> void:
	AudioManager.play_ui_click()
	if email.has("offer_data"):
		CareerManager.decline_contract(email.offer_data)
	DesktopManager.show_notification(
		"Offer Declined",
		"You've declined the offer",
		"",
		""
	)
	_remove_email(email)


func _on_delete_email(email: Dictionary) -> void:
	AudioManager.play_ui_click()
	_remove_email(email)


func _remove_email(email: Dictionary) -> void:
	var index = emails.find(email)
	if index >= 0:
		emails.remove_at(index)
		_refresh_inbox()
		_clear_message_view()


func _clear_message_view() -> void:
	selected_index = -1
	message_title.text = "Select an email"
	message_from.text = ""
	message_body.text = ""
	for child in action_container.get_children():
		child.queue_free()


func _on_scout_interest(scout_data: Dictionary) -> void:
	var email = {
		"id": "scout_%d" % randi(),
		"from": scout_data.get("scout_name", "Unknown Scout"),
		"subject": "Interest from %s" % scout_data.get("team_name", "Unknown Team"),
		"body": "Hello,\n\nMy name is %s, and I'm a scout for %s.\n\nI was at your recent match and I must say, I was impressed with your performance. We're always looking for talented young players like yourself.\n\nKeep up the good work, and you might be hearing from us again soon.\n\nBest regards,\n%s\nScout, %s" % [
			scout_data.get("scout_name", ""),
			scout_data.get("team_name", ""),
			scout_data.get("scout_name", ""),
			scout_data.get("team_name", "")
		],
		"date": DesktopManager.get_date_string(),
		"read": false,
		"type": "scout",
		"scout_data": scout_data
	}
	emails.insert(0, email)
	_refresh_inbox()


func _on_contract_offer(offer: Dictionary) -> void:
	_upsert_contract_email(offer)
	_refresh_inbox()


func _on_contract_offer_resolved(offer: Dictionary, _resolution: String) -> void:
	_remove_contract_email(str(offer.get("team_id", "")))
	_refresh_inbox()


func _sync_contract_offer_emails() -> void:
	var seen_offer_ids: Dictionary = {}
	for offer in CareerManager.pending_contract_offers:
		var team_id = str(offer.get("team_id", ""))
		if team_id.is_empty():
			continue
		seen_offer_ids[_contract_email_id(team_id)] = true
		_upsert_contract_email(offer)

	for i in range(emails.size() - 1, -1, -1):
		var email = emails[i]
		if str(email.get("type", "")) != "contract_offer":
			continue
		var email_id = str(email.get("id", ""))
		if not seen_offer_ids.has(email_id):
			if selected_index == i:
				_clear_message_view()
			emails.remove_at(i)


func _upsert_contract_email(offer: Dictionary) -> void:
	var team_id = str(offer.get("team_id", ""))
	if team_id.is_empty():
		return

	var email = _build_contract_email(offer)
	var email_id = str(email.get("id", ""))
	for i in range(emails.size()):
		if str(emails[i].get("id", "")) == email_id:
			var was_read = bool(emails[i].get("read", false))
			emails[i] = email
			emails[i]["read"] = was_read
			return

	emails.insert(0, email)


func _build_contract_email(offer: Dictionary) -> Dictionary:
	var team_name = offer.get("team_name", "Unknown Team")
	var salary = offer.get("salary", 0)
	var duration = offer.get("duration_years", 1)
	var role = offer.get("squad_role", "prospect")
	var expires_on = offer.get("expires_on", {})
	var team_id = str(offer.get("team_id", ""))

	return {
		"id": _contract_email_id(team_id),
		"from": "%s Management" % team_name,
		"subject": "Contract Offer from %s!" % team_name,
		"body": "Dear %s,\n\nWe are pleased to extend an official contract offer to join %s!\n\nOffer Details:\n- Salary: $%d per year\n- Duration: %d year(s)\n- Role: %s\n- Signing Bonus: $%d\n- Window: %s\n- Expires: %02d/%02d/%04d\n\nThis is an exciting opportunity to take your career to the next level. Please respond before the offer window closes.\n\nWe hope to welcome you to our club soon!\n\nBest regards,\n%s Management" % [
			GameManager.player_data.name if GameManager.player_data else "Player",
			team_name,
			salary,
			duration,
			role.capitalize(),
			offer.get("signing_bonus", 0),
			offer.get("offer_window", "offseason").capitalize(),
			int(expires_on.get("month", 1)),
			int(expires_on.get("day", 1)),
			int(expires_on.get("year", 2024)),
			team_name
		],
		"date": DesktopManager.get_date_string(),
		"read": false,
		"type": "contract_offer",
		"offer_data": offer.duplicate(true),
		"team_name": team_name
	}


func _remove_contract_email(team_id: String) -> void:
	var target_id = _contract_email_id(team_id)
	for i in range(emails.size() - 1, -1, -1):
		if str(emails[i].get("id", "")) != target_id:
			continue
		if selected_index == i:
			_clear_message_view()
		emails.remove_at(i)


func _contract_email_id(team_id: String) -> String:
	return "contract_offer_%s" % team_id
