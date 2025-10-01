# DWPlayerClient - Player information and token management client

extends Node

signal player_info_updated(player_info: PlayerInfo)
signal player_token_received(token: String)
signal error_occurred(error_msg: String)

const BASE_URL = "https://developerworks.agentlandlab.com"
const TIMEOUT_SECONDS = 30
const MAX_RETRY_COUNT = 3
const RETRY_DELAY_SECONDS = 3.0

var _auth_manager: Node = null
var player_token: String = ""
var cached_player_info: PlayerInfo = null
var last_exchange_response: JWTExchangeResponse = null

## Player information data class
class PlayerInfo:
	var user_id: String = ""
	var credits: float = 0.0

	func _init(data: Dictionary = {}):
		if data.is_empty():
			return
		user_id = data.get("userId", "")
		credits = float(data.get("credits", 0.0))

## JWT Exchange response data class
class JWTExchangeResponse:
	var success: bool = false
	var user_id: String = ""
	var player_token: String = ""
	var token_name: String = ""
	var created_at: String = ""
	var expires_at: String = ""

	func _init(data: Dictionary = {}):
		if data.is_empty():
			return
		success = data.get("success", false)
		user_id = data.get("userId", "")
		player_token = data.get("playerToken", "")
		token_name = data.get("tokenName", "")
		created_at = data.get("createdAt", "")
		expires_at = data.get("expiresAt", "")

func _init(auth_manager: Node):
	_auth_manager = auth_manager

## Initialize with JWT and exchange for player token
func initialize_async(jwt: String) -> Dictionary:
	print("[DWPlayerClient] Exchanging JWT for player token...")

	if jwt == "":
		var error = "JWT token cannot be empty"
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error}

	var result = await _exchange_jwt_for_player_token_async(jwt)
	return result

## Exchange JWT for player token
func _exchange_jwt_for_player_token_async(jwt: String) -> Dictionary:
	var url = "%s/api/external/exchange-jwt" % BASE_URL

	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_SECONDS

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % jwt
	]

	# Send empty object as body
	var json = JSON.stringify({})
	var err = http.request(url, headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		var error = "Failed to send exchange request: %s" % err
		push_error("[DWPlayerClient] ", error)
		http.queue_free()
		error_occurred.emit(error)
		return {"success": false, "error": error}

	var response = await http.request_completed
	http.queue_free()

	var result_code = response[0]
	var response_code = response[1]
	var body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		var error = "Exchange request failed: %s" % result_code
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error}

	var json_result = JSON.parse_string(body.get_string_from_utf8())
	if json_result == null:
		var error = "Failed to parse exchange response"
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error}

	var exchange_response = JWTExchangeResponse.new(json_result)

	if not exchange_response.success:
		var error = "JWT exchange failed on server"
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error}

	# Store the results
	player_token = exchange_response.player_token
	last_exchange_response = exchange_response

	print("[DWPlayerClient] Player token received: ", player_token.substr(0, min(20, player_token.length())), "...")
	print("[DWPlayerClient] Token name: ", exchange_response.token_name)
	print("[DWPlayerClient] Expires at: ", exchange_response.expires_at if exchange_response.expires_at != "" else "Never")

	player_token_received.emit(player_token)

	# Auto-fetch player info
	get_player_info_async()

	return {"success": true, "error": ""}

## Get player information
func get_player_info_async() -> Dictionary:
	var auth_token = _get_auth_token()
	if auth_token == "":
		var error = "No valid auth token available"
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error, "data": null}

	var url = "%s/api/external/player-info" % BASE_URL

	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_SECONDS

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % auth_token
	]

	var err = http.request(url, headers, HTTPClient.METHOD_GET)

	if err != OK:
		var error = "Failed to send player info request: %s" % err
		push_error("[DWPlayerClient] ", error)
		http.queue_free()
		error_occurred.emit(error)
		return {"success": false, "error": error, "data": null}

	var response = await http.request_completed
	http.queue_free()

	var result_code = response[0]
	var response_code = response[1]
	var body = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		var error = "Player info request failed: %s" % result_code
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error, "data": null}

	if response_code != 200:
		var error = "Player info API error: %s" % response_code
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error, "data": null}

	var json_result = JSON.parse_string(body.get_string_from_utf8())
	if json_result == null:
		var error = "Failed to parse player info response"
		push_error("[DWPlayerClient] ", error)
		error_occurred.emit(error)
		return {"success": false, "error": error, "data": null}

	var player_info = PlayerInfo.new(json_result)
	cached_player_info = player_info

	print("[DWPlayerClient] Player info updated: ", player_info.user_id, " has ", player_info.credits, " credits")
	player_info_updated.emit(player_info)

	return {"success": true, "error": "", "data": player_info}

## Check if has valid player token
func has_valid_player_token() -> bool:
	return player_token != ""

## Get player token
func get_player_token() -> String:
	return player_token

## Set player token (when loading from storage)
func set_player_token(token: String) -> void:
	player_token = token
	print("[DWPlayerClient] Player token set: ", token.substr(0, min(20, token.length())), "...")

	# Auto-fetch player info
	get_player_info_async()

## Get cached player info
func get_cached_player_info() -> PlayerInfo:
	return cached_player_info

## Get auth token (player token or fallback to JWT)
func _get_auth_token() -> String:
	if player_token != "":
		return player_token
	if _auth_manager and _auth_manager.auth_token != "":
		return _auth_manager.auth_token
	return ""