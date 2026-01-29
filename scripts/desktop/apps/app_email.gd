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
	_refresh_inbox()
	_connect_signals()


func _connect_signals() -> void:
	inbox_list.item_selected.connect(_on_email_selected)
	CareerManager.scout_interest.connect(_on_scout_interest)
	CareerManager.contract_offer_received.connect(_on_contract_offer)


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
	# Process contract acceptance
	# This would trigger career progression in full implementation
	DesktopManager.show_notification(
		"Contract Signed!",
		"You've accepted the offer from %s!" % email.get("team_name", "the team"),
		"",
		"email"
	)
	_remove_email(email)


func _on_decline_contract(email: Dictionary) -> void:
	AudioManager.play_ui_click()
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
	var team_name = offer.get("team_name", "Unknown Team")
	var salary = offer.get("salary", 0)
	var duration = offer.get("duration_years", 1)
	var role = offer.get("squad_role", "prospect")

	var email = {
		"id": "contract_%d" % randi(),
		"from": "%s Management" % team_name,
		"subject": "Contract Offer from %s!" % team_name,
		"body": "Dear %s,\n\nWe are pleased to extend an official contract offer to join %s!\n\nOffer Details:\n- Salary: $%d per year\n- Duration: %d year(s)\n- Role: %s\n- Signing Bonus: $%d\n\nThis is an exciting opportunity to take your career to the next level. Please respond at your earliest convenience.\n\nWe hope to welcome you to our club soon!\n\nBest regards,\n%s Management" % [
			GameManager.player_data.name if GameManager.player_data else "Player",
			team_name,
			salary,
			duration,
			role.capitalize(),
			offer.get("signing_bonus", 0),
			team_name
		],
		"date": DesktopManager.get_date_string(),
		"read": false,
		"type": "contract_offer",
		"offer_data": offer,
		"team_name": team_name
	}
	emails.insert(0, email)
	_refresh_inbox()
