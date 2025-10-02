# DWLocalSharedToken - Cross-game token storage (compatible with Unity SDK)
# Handles token storage across different platforms
# - Web: Reads from localStorage (read-only)
# - Windows: Uses %APPDATA%\DeveloperWorks_SDK with AES encryption
# - macOS: Uses ~/Library/Application Support/DeveloperWorks_SDK with AES encryption
# - Linux: Uses ~/.developerworks_sdk with AES encryption

class_name DWLocalSharedToken

const TOKEN_FILE_NAME = "shared_token.txt"
const SHARED_FOLDER_NAME = "DeveloperWorks_SDK"

# AES加密密钥 (与Unity SDK保持一致)
const AES_KEY = "/wu4uTqdUBpCIhutfM50qQ=="  # Base64格式 16字节
const AES_IV = "pCkXFJR0Ahco+YKvkNRq2Q=="   # Base64格式 16字节

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

## Get cross-game shared file path (compatible with Unity SDK)
static func _get_shared_file_path() -> String:
	var folder_path = ""

	if OS.has_feature("windows"):
		# Windows: %APPDATA%\DeveloperWorks_SDK
		folder_path = OS.get_environment("APPDATA")
		if folder_path == "":
			print("[DW_LocalSharedToken] Failed to get APPDATA path")
			return ""
		folder_path = folder_path.path_join(SHARED_FOLDER_NAME)
	elif OS.has_feature("macos"):
		# macOS: ~/Library/Application Support/DeveloperWorks_SDK
		var home = OS.get_environment("HOME")
		if home == "":
			print("[DW_LocalSharedToken] Failed to get HOME path")
			return ""
		folder_path = home.path_join("Library/Application Support").path_join(SHARED_FOLDER_NAME)
	else:
		# Linux等其他平台: ~/.developerworks_sdk
		var home = OS.get_environment("HOME")
		if home == "":
			print("[DW_LocalSharedToken] Failed to get HOME path")
			return ""
		folder_path = home.path_join(".developerworks_sdk")

	# 确保文件夹存在
	DirAccess.make_dir_recursive_absolute(folder_path)

	return folder_path.path_join(TOKEN_FILE_NAME)

## Encrypt string using AES (compatible with Unity SDK)
static func _encrypt_aes(plaintext: String) -> PackedByteArray:
	var aes = AESContext.new()
	var key = Marshalls.base64_to_raw(AES_KEY)
	var iv = Marshalls.base64_to_raw(AES_IV)

	# PKCS7 padding
	var plaintext_bytes = plaintext.to_utf8_buffer()
	var block_size = 16
	var padding_length = block_size - (plaintext_bytes.size() % block_size)
	var padded = plaintext_bytes.duplicate()
	for i in range(padding_length):
		padded.append(padding_length)

	# Encrypt
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	var encrypted = aes.update(padded)
	aes.finish()

	return encrypted

## Decrypt bytes using AES (compatible with Unity SDK)
static func _decrypt_aes(ciphertext: PackedByteArray) -> String:
	if ciphertext.size() == 0:
		return ""

	var aes = AESContext.new()
	var key = Marshalls.base64_to_raw(AES_KEY)
	var iv = Marshalls.base64_to_raw(AES_IV)

	# Decrypt
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	var decrypted = aes.update(ciphertext)
	aes.finish()

	# Remove PKCS7 padding
	if decrypted.size() > 0:
		var padding_length = decrypted[decrypted.size() - 1]
		if padding_length > 0 and padding_length <= 16:
			decrypted.resize(decrypted.size() - padding_length)

	return decrypted.get_string_from_utf8()

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

## Load token from local file (with AES decryption)
static func _load_from_file() -> String:
	var file_path = _get_shared_file_path()
	if file_path == "":
		return ""

	if not FileAccess.file_exists(file_path):
		print("[DW_LocalSharedToken] Token file not found at: ", file_path)
		return ""

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("[DW_LocalSharedToken] Failed to open token file")
		return ""

	var encrypted = file.get_buffer(file.get_length())
	file.close()

	var token = _decrypt_aes(encrypted)
	if token != "":
		print("[DW_LocalSharedToken] Token loaded from shared location: ", file_path.get_base_dir())

	return token

## Save token to local file (with AES encryption)
static func _save_to_file(token: String) -> void:
	var file_path = _get_shared_file_path()
	if file_path == "":
		print("[DW_LocalSharedToken] Failed to get shared file path")
		return

	var encrypted = _encrypt_aes(token)

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		print("[DW_LocalSharedToken] Failed to create token file")
		return

	file.store_buffer(encrypted)
	file.close()

	print("[DW_LocalSharedToken] Token saved (encrypted) to shared location: ", file_path.get_base_dir())

## Erase token from local file
static func _erase_from_file() -> void:
	var file_path = _get_shared_file_path()
	if file_path == "":
		return

	if FileAccess.file_exists(file_path):
		var err = DirAccess.remove_absolute(file_path)
		if err == OK:
			print("[DW_LocalSharedToken] Token file deleted from shared location")
		else:
			print("[DW_LocalSharedToken] Failed to delete token file: ", err)