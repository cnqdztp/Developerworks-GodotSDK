# DW_SDK - DeveloperWorks SDK Main Entry Point
# This should be added as an Autoload singleton

extends Node
class_name DW_SDK_Internal  # Internal class name for self-reference

# Preload scripts
const DWAuthManager = preload("res://addons/developerworks_sdk/auth/dw_auth_manager.gd")
const DWPlayerClient = preload("res://addons/developerworks_sdk/core/dw_player_client.gd")
const DWChatClient = preload("res://addons/developerworks_sdk/core/dw_chat_client.gd")
const DWNPCClient = preload("res://addons/developerworks_sdk/core/dw_npc_client.gd")
const DWImageClient = preload("res://addons/developerworks_sdk/core/dw_image_client.gd")
const AIChatProvider = preload("res://addons/developerworks_sdk/provider/ai_chat_provider.gd")
const AIObjectProvider = preload("res://addons/developerworks_sdk/provider/ai_object_provider.gd")
const AIImageProvider = preload("res://addons/developerworks_sdk/provider/ai_image_provider.gd")
const DWSchemaLibrary = preload("res://addons/developerworks_sdk/schema/dw_schema_library.gd")

# Singleton state
static var instance: Node = null
static var _is_initialized: bool = false

# Core components
var _auth_manager: Node = null
var _player_client: Node = null
var _chat_provider: Node = null
var _object_provider: Node = null
var _image_provider: Node = null

# Default model settings
var default_chat_model: String = "gpt-4.1-mini"
var default_image_model: String = "dall-e-3"

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

	# Create object provider
	instance._object_provider = AIObjectProvider.new(instance._auth_manager)
	instance.add_child(instance._object_provider)

	# Create image provider
	instance._image_provider = AIImageProvider.new(instance._auth_manager)
	instance.add_child(instance._image_provider)

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
		if not DW_SDK_Internal.instance:
			push_error("[DW_SDK] SDK instance not found")
			return null

		if not DW_SDK_Internal._is_initialized:
			push_error("[DW_SDK] SDK not initialized. Call initialize_async() first")
			return null

		var model = model_name if model_name != "" else DW_SDK_Internal.instance.default_chat_model

		var chat_client = DWChatClient.new(
			model,
			DW_SDK_Internal.instance._chat_provider,
			DW_SDK_Internal.instance._auth_manager,
			DW_SDK_Internal.instance._object_provider
		)

		DW_SDK_Internal.instance.add_child(chat_client)
		print("[DW_SDK] Chat client created with model: ", model)

		return chat_client

	## Create a chat client with schema library
	## @param model_name: Model name (empty string uses default)
	## @param schema_library: DWSchemaLibrary resource containing schemas
	## @return: Chat client with schema library set
	static func create_chat_client_with_schemas(model_name: String, schema_library: DWSchemaLibrary) -> Node:
		var chat_client = create_chat_client(model_name)
		if chat_client != null:
			chat_client.set_schema_library(schema_library)
			print("[DW_SDK] Schema library attached to chat client")
		return chat_client

	## Create an image generation client
	## @param model_name: Model name (empty string uses default: "dall-e-3")
	## @return: Image client for generating images
	static func create_image_client(model_name: String = "") -> Node:
		if not DW_SDK_Internal.instance:
			push_error("[DW_SDK] SDK instance not found")
			return null

		if not DW_SDK_Internal._is_initialized:
			push_error("[DW_SDK] SDK not initialized. Call initialize_async() first")
			return null

		var model = model_name if model_name != "" else DW_SDK_Internal.instance.default_image_model

		var image_client = DWImageClient.new(
			model,
			DW_SDK_Internal.instance._image_provider
		)

		DW_SDK_Internal.instance.add_child(image_client)
		print("[DW_SDK] Image client created with model: ", model)

		return image_client

	## Create an NPC client with automatic conversation history management
	## @param character_design: Character system prompt/design (optional, can set later)
	## @param model_name: Model name (empty string uses default)
	## @param schema_library: Optional DWSchemaLibrary for structured output support
	## @return: NPC client for AI-powered NPCs
	static func create_npc_client(
		character_design: String = "",
		model_name: String = "",
		schema_library: DWSchemaLibrary = null
	) -> Node:
		if not DW_SDK_Internal.instance:
			push_error("[DW_SDK] SDK instance not found")
			return null

		if not DW_SDK_Internal._is_initialized:
			push_error("[DW_SDK] SDK not initialized. Call initialize_async() first")
			return null

		var npc_client = DWNPCClient.new()
		npc_client.character_design = character_design
		npc_client.chat_model = model_name if model_name != "" else DW_SDK_Internal.instance.default_chat_model

		if schema_library != null:
			npc_client.set_schema_library(schema_library)

		DW_SDK_Internal.instance.add_child(npc_client)
		print("[DW_SDK] NPC client created")

		return npc_client

	## Create an NPC client and attach it to an existing node
	## @param node: The node to attach the NPC client to
	## @param character_design: Character system prompt/design (optional)
	## @param model_name: Model name (empty string uses default)
	## @param schema_library: Optional DWSchemaLibrary for structured output support
	## @return: NPC client attached to the node
	static func create_npc_client_for_node(
		node: Node,
		character_design: String = "",
		model_name: String = "",
		schema_library: DWSchemaLibrary = null
	) -> Node:
		if node == null:
			push_error("[DW_SDK] Node cannot be null")
			return null

		var npc_client = create_npc_client(character_design, model_name, schema_library)
		if npc_client != null:
			# Remove from SDK instance and add to target node
			if npc_client.get_parent() != null:
				npc_client.get_parent().remove_child(npc_client)
			node.add_child(npc_client)
			print("[DW_SDK] NPC client attached to node: %s" % node.name)

		return npc_client
