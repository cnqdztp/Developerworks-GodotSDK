# DWAuthManager - Authentication Manager
# Manages authentication tokens and user sessions

extends Node

const PLAYER_TOKEN_KEY = "DW_SDK_PlayerToken"
const TOKEN_EXPIRY_KEY = "DW_SDK_TokenExpiry"

var publishable_key: String = ""  # Game ID
var auth_token: String = ""
var is_developer_token: bool = false

var _player_client: Node = null  # Will be set by DW_SDK

## Setup authentication manager
func setup(game_id: String, developer_token: String = "") -> void:
	publishable_key = game_id
	print("[DW_AuthManager] Initializing with game ID: ", game_id)

	if developer_token != "":
		auth_token = developer_token
		is_developer_token = true
		print("[DW_AuthManager] Using developer token")

## Authenticate user
## Returns true if authentication successful
func authenticate_async() -> bool:
	# Developer token mode: always successful
	if is_developer_token:
		print("[DW_AuthManager] Developer token mode - authentication successful")
		return true

	# Step 1: Try loading shared token (Web: localStorage, Others: encrypted file)
	_load_shared_token()
	if await _is_token_valid_with_api_check():
		print("[DW_AuthManager] Valid shared token found")
		return true

	# Step 2: Try loading player token from local storage
	_load_player_token()
	if await _is_token_valid_with_api_check():
		print("[DW_AuthManager] Valid player token found")
		return true

	# Step 3: No valid tokens found
	print("[DW_AuthManager] No valid tokens found - authentication failed")
	return false

## Load shared token (cross-game)
func _load_shared_token() -> void:
	if is_developer_token or auth_token != "":
		return

	var shared_token = DWLocalSharedToken.load_token()
	if shared_token != "":
		auth_token = shared_token
		print("[DW_AuthManager] Loaded shared token")

## Load player token from local storage
func _load_player_token() -> void:
	if is_developer_token:
		return

	var token = _get_config_value(PLAYER_TOKEN_KEY, "")
	if token != "":
		auth_token = token
		print("[DW_AuthManager] Loaded player token from local storage")

## Check if current token is valid
func _is_token_valid() -> bool:
	if auth_token == "":
		return false

	# Developer tokens are always valid
	if is_developer_token:
		return true

	# Check token expiry
	var expiry_str = _get_config_value(TOKEN_EXPIRY_KEY, "0")
	var expiry_ticks = int(expiry_str)

	if expiry_ticks == 0:
		return false

	var current_ticks = Time.get_unix_time_from_system()
	if current_ticks > expiry_ticks:
		print("[DW_AuthManager] Token has expired")
		_clear_player_token()
		return false

	return true

## Check if token is valid with API verification
func _is_token_valid_with_api_check() -> bool:
	if auth_token == "":
		return false

	# Developer tokens are always valid
	if is_developer_token:
		return true

	# First check local expiry (non-Web only to avoid extra checks)
	if not OS.has_feature("web"):
		if not _is_token_valid():
			return false

	# Verify with API if PlayerClient is available
	if _player_client == null:
		print("[DW_AuthManager] PlayerClient not available for token verification")
		return true  # Trust local validation

	# Set token in player client
	if not _player_client.has_method("has_valid_player_token") or not _player_client.has_valid_player_token():
		_player_client.set_player_token(auth_token)

	# Verify with API
	print("[DW_AuthManager] Verifying token with API...")
	var result = await _player_client.get_player_info_async()

	if not result.success:
		print("[DW_AuthManager] Token verification failed: ", result.error)
		_clear_player_token()
		return false

	print("[DW_AuthManager] Token verified successfully")
	return true

## Save player token
static func save_player_token(token: String, expires_at: String = "") -> void:
	_set_config_value(PLAYER_TOKEN_KEY, token)

	# Calculate expiry
	var expiry_ticks: int
	if expires_at == "" or expires_at == "null":
		# Never expires - set far future
		expiry_ticks = 9999999999  # Year 2286
	else:
		# Parse ISO 8601 date
		var expiry_dict = Time.get_datetime_dict_from_datetime_string(expires_at, false)
		expiry_ticks = Time.get_unix_time_from_datetime_dict(expiry_dict)

	_set_config_value(TOKEN_EXPIRY_KEY, str(expiry_ticks))

	# Also save to shared storage
	DWLocalSharedToken.save_token(token)

	print("[DW_AuthManager] Player token saved successfully")

## Clear player token
func _clear_player_token() -> void:
	_delete_config_value(PLAYER_TOKEN_KEY)
	_delete_config_value(TOKEN_EXPIRY_KEY)
	DWLocalSharedToken.erase_token()
	auth_token = ""
	print("[DW_AuthManager] Player token cleared")

## Get PlayerClient for public access
func get_player_client() -> Node:
	if _is_token_valid():
		return _player_client
	return null

# ============================================================
# Config File Helpers (mimics PlayerPrefs)
# ============================================================

static func _get_config_value(key: String, default_value: String) -> String:
	var config = ConfigFile.new()
	var err = config.load("user://dw_sdk_config.cfg")
	if err != OK:
		return default_value
	return config.get_value("auth", key, default_value)

static func _set_config_value(key: String, value: String) -> void:
	var config = ConfigFile.new()
	config.load("user://dw_sdk_config.cfg")  # Load existing or create new
	config.set_value("auth", key, value)
	config.save("user://dw_sdk_config.cfg")

static func _delete_config_value(key: String) -> void:
	var config = ConfigFile.new()
	if config.load("user://dw_sdk_config.cfg") == OK:
		config.erase_section_key("auth", key)
		config.save("user://dw_sdk_config.cfg")