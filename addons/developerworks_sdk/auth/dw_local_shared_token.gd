# DWLocalSharedToken - Cross-game token storage
# Handles token storage across different platforms
# - Web: Reads from localStorage (read-only)
# - Other platforms: Uses ConfigFile for local storage

class_name DWLocalSharedToken

const TOKEN_FILE = "user://developerworks_sdk/shared_token.cfg"
const SHARED_FOLDER = "user://developerworks_sdk"

## Load shared token
## Returns the token string if found, empty string otherwise
static func load_token() -> String:
	if OS.has_feature("web"):
		return _load_from_web_storage()
	else:
		return _load_from_file()

## Save shared token
## Note: Web builds do not save tokens (read-only)
static func save_token(token: String) -> void:
	if OS.has_feature("web"):
		print("[DW_LocalSharedToken] Web build does not save tokens")
		return
	else:
		_save_to_file(token)

## Erase shared token
static func erase_token() -> void:
	if OS.has_feature("web"):
		_erase_from_web_storage()
	else:
		_erase_from_file()

# ============================================================
# Private Methods
# ============================================================

## Load token from web localStorage
static func _load_from_web_storage() -> String:
	if not JavaScriptBridge:
		print("[DW_LocalSharedToken] JavaScriptBridge not available")
		return ""

	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		print("[DW_LocalSharedToken] Failed to get window object")
		return ""

	var local_storage = window.localStorage
	if local_storage == null:
		print("[DW_LocalSharedToken] Failed to get localStorage")
		return ""

	var token = local_storage.getItem("shared_token")
	if token != null and token != "":
		print("[DW_LocalSharedToken] Token loaded from localStorage")
		return token
	else:
		print("[DW_LocalSharedToken] No token found in localStorage")
		return ""

## Erase token from web localStorage
static func _erase_from_web_storage() -> void:
	if not JavaScriptBridge:
		return

	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return

	var local_storage = window.localStorage
	if local_storage == null:
		return

	local_storage.removeItem("shared_token")
	print("[DW_LocalSharedToken] Token erased from localStorage")

## Load token from local file
static func _load_from_file() -> String:
	var config = ConfigFile.new()
	var err = config.load(TOKEN_FILE)

	if err != OK:
		return ""

	var token = config.get_value("auth", "shared_token", "")
	if token != "":
		print("[DW_LocalSharedToken] Token loaded from file: ", TOKEN_FILE.get_base_dir())

	return token

## Save token to local file
static func _save_to_file(token: String) -> void:
	# Ensure directory exists
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("developerworks_sdk"):
			dir.make_dir("developerworks_sdk")

	var config = ConfigFile.new()
	config.set_value("auth", "shared_token", token)

	var err = config.save(TOKEN_FILE)
	if err == OK:
		print("[DW_LocalSharedToken] Token saved to file: ", TOKEN_FILE.get_base_dir())
	else:
		print("[DW_LocalSharedToken] Failed to save token: ", err)

## Erase token from local file
static func _erase_from_file() -> void:
	if FileAccess.file_exists(TOKEN_FILE):
		var err = DirAccess.remove_absolute(TOKEN_FILE)
		if err == OK:
			print("[DW_LocalSharedToken] Token file deleted")
		else:
			print("[DW_LocalSharedToken] Failed to delete token file: ", err)