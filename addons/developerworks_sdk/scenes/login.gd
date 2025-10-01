# login.gd - Login UI Controller
extends Control

# Signals
signal login_success
signal login_failed(error: String)
signal login_cancelled

# API Configuration
const BASE_URL = "https://developerworks.agentlandlab.com"
const TIMEOUT_SECONDS = 30

# Node references (assigned in _ready)
@onready var identifier_panel: Control = $Panel/Control/Identifier_Panel
@onready var otp_panel: Control = $Panel/Control/OTP_Panel
@onready var type_selection: TabBar = $Panel/Control/Identifier_Panel/TypeSelection
@onready var identifier_input: LineEdit = $Panel/Control/Identifier_Panel/Identifier_Input
@onready var identifier_submit: Button = $Panel/Control/Identifier_Panel/Identifier_Submit
@onready var otp_input: LineEdit = $Panel/Control/OTP_Panel/OTP_Input
@onready var otp_submit: Button = $Panel/Control/OTP_Panel/OTP_Submit
@onready var error_label: Label = $ErrorLabel
@onready var loading_modal: Panel = $LoadingModal
@onready var back_button: Button = $Panel/Control/OTP_Panel/BackButton

# State
var _current_session_id: String = ""
var _auth_manager: Node = null
var _player_client: Node = null

## Initialize login with auth manager and player client
func setup(auth_manager: Node, player_client: Node) -> void:
	_auth_manager = auth_manager
	_player_client = player_client

func _ready() -> void:
	# Setup initial UI state
	_show_identifier_panel()
	error_label.text = ""
	loading_modal.visible = false

	# Connect signals
	identifier_submit.pressed.connect(_on_send_code_clicked)
	otp_submit.pressed.connect(_on_verify_clicked)
	back_button.pressed.connect(_on_back_clicked)
	type_selection.tab_changed.connect(_on_type_changed)

	# Auto-detect region and set default auth type
	_set_default_auth_type_by_region()

## Show identifier input panel
func _show_identifier_panel() -> void:
	identifier_panel.visible = true
	otp_panel.visible = false
	back_button.visible = false
	error_label.text = ""

## Show OTP verification panel
func _show_otp_panel() -> void:
	identifier_panel.visible = false
	otp_panel.visible = true
	back_button.visible = true
	error_label.text = ""

## Handle send code button click
func _on_send_code_clicked() -> void:
	error_label.text = ""

	var identifier = identifier_input.text.strip_edges()
	if identifier == "":
		error_label.text = "Please enter your email or phone number"
		return

	# Get auth type from tab selection
	var auth_type = "email" if type_selection.current_tab == 0 else "phone"

	identifier_submit.disabled = true
	_show_loading_modal()

	var success = await _send_verification_code(identifier, auth_type)

	_hide_loading_modal()
	identifier_submit.disabled = false

	if success:
		_show_otp_panel()
	# Error message already set by _send_verification_code

## Handle verify button click
func _on_verify_clicked() -> void:
	error_label.text = ""

	var code = otp_input.text.strip_edges()
	if code == "" or code.length() < 6:
		error_label.text = "Please enter a valid 6-digit code"
		return

	otp_submit.disabled = true
	_show_loading_modal()

	await _submit_verification_code(code)

	_hide_loading_modal()
	otp_submit.disabled = false

## Handle back button click
func _on_back_clicked() -> void:
	_show_identifier_panel()
	otp_input.text = ""

## Handle auth type tab change
func _on_type_changed(tab: int) -> void:
	if tab == 0:  # Email
		identifier_input.placeholder_text = "Enter your email address"
	else:  # Phone
		identifier_input.placeholder_text = "Enter your phone number (+86 Only)"

## Auto-detect region and set default auth type
func _set_default_auth_type_by_region() -> void:
	_show_loading_modal()

	var url = "%s/api/reachability" % BASE_URL
	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_SECONDS

	var headers = ["Content-Type: application/json"]
	var err = http.request(url, headers, HTTPClient.METHOD_GET)

	if err != OK:
		print("[Login] Reachability check failed, using email as default")
		_hide_loading_modal()
		http.queue_free()
		return

	var response = await http.request_completed
	http.queue_free()

	var result_code = response[0]
	var body = response[3]

	if result_code == HTTPRequest.RESULT_SUCCESS:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("region") and json["region"] == "CN":
			type_selection.current_tab = 1  # Phone
			_on_type_changed(1)

	_hide_loading_modal()

## Send verification code to API
func _send_verification_code(identifier: String, type: String) -> bool:
	var url = "%s/api/auth/send-code" % BASE_URL

	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_SECONDS

	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"identifier": identifier,
		"type": type
	})

	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)

	if err != OK:
		error_label.text = "Network error. Please try again."
		http.queue_free()
		return false

	var response = await http.request_completed
	http.queue_free()

	var result_code = response[0]
	var response_code = response[1]
	var response_body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		error_label.text = "Network error. Please try again."
		return false

	if response_code != 200:
		error_label.text = "Failed to send code. Please check your input."
		return false

	var json = JSON.parse_string(response_body.get_string_from_utf8())

	if json == null or not json.get("success", false):
		error_label.text = "Failed to send code. Please try again."
		return false

	_current_session_id = json.get("sessionId", "")

	if _current_session_id == "":
		error_label.text = "Server error. Please try again later."
		return false

	print("[Login] Verification code sent. Session ID: ", _current_session_id)
	return true

## Submit verification code and complete authentication
func _submit_verification_code(code: String) -> void:
	if _current_session_id == "":
		error_label.text = "Session expired. Please request a new code."
		login_failed.emit("No session ID")
		return

	var url = "%s/api/auth/verify-code" % BASE_URL

	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_SECONDS

	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({
		"sessionId": _current_session_id,
		"code": code
	})

	var err = http.request(url, headers, HTTPClient.METHOD_POST, body)

	if err != OK:
		error_label.text = "Network error. Please try again."
		http.queue_free()
		login_failed.emit("Network error")
		return

	var response = await http.request_completed
	http.queue_free()

	var result_code = response[0]
	var response_code = response[1]
	var response_body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		error_label.text = "Network error. Please try again."
		login_failed.emit("Network error")
		return

	if response_code != 200:
		error_label.text = "Invalid verification code."
		login_failed.emit("Invalid code")
		return

	var json = JSON.parse_string(response_body.get_string_from_utf8())

	if json == null or not json.get("success", false):
		error_label.text = "Verification failed. Please try again."
		login_failed.emit("Verification failed")
		return

	var global_token = json.get("globalToken", "")

	if global_token == "":
		error_label.text = "Server error. Please try again later."
		login_failed.emit("No token received")
		return

	print("[Login] Global token received, exchanging for player token...")

	# Exchange JWT for player token
	var exchange_success = await _exchange_jwt_for_player_token(global_token)

	if exchange_success:
		print("[Login] Login successful!")
		login_success.emit()
		# Don't queue_free() here - let auth_manager handle cleanup
	else:
		error_label.text = "Final authentication step failed."
		login_failed.emit("Token exchange failed")

## Exchange JWT for long-lived player token
func _exchange_jwt_for_player_token(jwt: String) -> bool:
	if _player_client == null:
		push_error("[Login] PlayerClient not available!")
		return false

	var result = await _player_client.initialize_async(jwt)

	if not result.success:
		push_error("[Login] Failed to exchange JWT: ", result.error)
		return false

	# Get player token and save it
	var player_token = _player_client.get_player_token()
	var expires_at = _player_client.last_exchange_response.expires_at if _player_client.last_exchange_response else ""

	# Save to local storage and shared storage via auth manager static method
	var DWAuthManager = load("res://addons/developerworks_sdk/auth/dw_auth_manager.gd")
	DWAuthManager.save_player_token(player_token, expires_at)

	print("[Login] Player token saved successfully")
	return true

## Show loading modal
func _show_loading_modal() -> void:
	if loading_modal:
		loading_modal.visible = true

## Hide loading modal
func _hide_loading_modal() -> void:
	if loading_modal:
		loading_modal.visible = false
