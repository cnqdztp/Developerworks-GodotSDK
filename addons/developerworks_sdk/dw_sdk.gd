# DW_SDK - DeveloperWorks SDK Main Entry Point
# This should be added as an Autoload singleton

extends Node

# Preload scripts
const DWAuthManager = preload("auth/dw_auth_manager.gd")
const DWPlayerClient = preload("core/dw_player_client.gd")
const DWChatClient = preload("core/dw_chat_client.gd")
const AIChatProvider = preload("provider/ai_chat_provider.gd")

# Singleton state
static var instance: Node = null
static var _is_initialized: bool = false

# Core components
var _auth_manager: Node = null
var _player_client: Node = null
var _chat_provider: Node = null

# Default model settings
var default_chat_model: String = "gpt-4o-mini"

func _ready():
	if instance == null:
		instance = self
	else:
		queue_free()

## Initialize the SDK
## @param game_id: Your game's publishable key from DeveloperWorks
## @param developer_token: Optional developer token for testing
## @return: true if initialization successful
static func initialize_async(game_id: String, developer_token: String = "") -> bool:
	if not instance:
		push_error("[DW_SDK] SDK instance not found. Make sure DW_SDK is added as Autoload")
		return false

	if game_id == "":
		push_error("[DW_SDK] Game ID cannot be empty. Get one from https://developerworks.agentlandlab.com")
		return false

	print("[DW_SDK] Initializing...")

	if _is_initialized:
		print("[DW_SDK] Already initialized")
		return true

	# Create auth manager
	instance._auth_manager = DWAuthManager.new()
	instance.add_child(instance._auth_manager)

	# Create player client
	instance._player_client = DWPlayerClient.new(instance._auth_manager)
	instance.add_child(instance._player_client)

	# Link player client to auth manager
	instance._auth_manager._player_client = instance._player_client

	# Setup authentication
	if developer_token != "":
		print("[DW_SDK] Using developer token (development mode)")
		instance._auth_manager.setup(game_id, developer_token)
	else:
		instance._auth_manager.setup(game_id)

	# Authenticate
	var auth_success = await instance._auth_manager.authenticate_async()

	if not auth_success:
		push_error("[DW_SDK] Authentication failed")
		return false

	# Create chat provider
	instance._chat_provider = AIChatProvider.new(instance._auth_manager)
	instance.add_child(instance._chat_provider)

	_is_initialized = true
	print("[DW_SDK] Initialization successful!")

	return true

## Check if SDK is ready to use
static func is_ready() -> bool:
	return _is_initialized and instance != null

## Get player client for user information
static func get_player_client() -> Node:
	if not _is_initialized or not instance:
		push_warning("[DW_SDK] SDK not initialized. Call initialize_async() first")
		return null

	if instance._auth_manager == null:
		return null

	return instance._auth_manager.get_player_client()

## Factory class for creating clients
class Factory:
	## Create a chat client
	static func create_chat_client(model_name: String = "") -> Node:
		if not DW_SDK.instance:
			push_error("[DW_SDK] SDK instance not found")
			return null

		if not DW_SDK._is_initialized:
			push_error("[DW_SDK] SDK not initialized. Call initialize_async() first")
			return null

		var model = model_name if model_name != "" else DW_SDK.instance.default_chat_model

		var chat_client = DWChatClient.new(
			model,
			DW_SDK.instance._chat_provider,
			DW_SDK.instance._auth_manager
		)

		DW_SDK.instance.add_child(chat_client)
		print("[DW_SDK] Chat client created with model: ", model)

		return chat_client