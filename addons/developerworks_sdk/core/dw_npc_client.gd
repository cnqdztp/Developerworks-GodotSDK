# DWNPCClient - AI-powered NPC with automatic conversation history management
# This is a "sugar" wrapper around DWChatClient for easier NPC usage
# Based on Unity SDK DW_NPCClient.cs

extends Node
class_name DWNPCClient

## Exported variables for editor
@export_group("Character Settings")
@export_multiline var character_design: String = ""
@export var chat_model: String = ""

@export_group("History Management")
@export var auto_save_history: bool = false
@export_file var history_save_path: String = ""

## Signals
signal talking_started()
signal talking_finished(response: String)
signal chunk_received(chunk: String)
signal history_changed()
signal state_changed(is_talking: bool)

## Private members
var _chat_client: Node = null
var _conversation_history: Array = []  # Array of DWDefinitions.ChatMessage
var _current_prompt: String = ""
var _is_talking: bool = false
var _is_ready: bool = false
var _schema_library: DWSchemaLibrary = null

## Default chat model constant
const DEFAULT_CHAT_MODEL = "gpt-4o-mini"

## ==========================================================================
## LIFECYCLE
## ==========================================================================

func _ready():
	await _initialize()

func _initialize():
	# Wait for SDK to be ready
	while not DW_SDK.is_ready():
		await get_tree().process_frame

	# Determine model to use
	var model_to_use = chat_model if chat_model != "" else DEFAULT_CHAT_MODEL

	# Create chat client
	_chat_client = DW_SDK.Factory.create_chat_client(model_to_use)

	if _chat_client == null:
		push_error("[DWNPCClient] Failed to create chat client")
		return

	# Set system prompt if provided
	if character_design != "":
		set_system_prompt(character_design)

	_is_ready = true
	print("[DWNPCClient] NPC client initialized with model: %s" % model_to_use)

## ==========================================================================
## PUBLIC PROPERTIES
## ==========================================================================

## Check if NPC is currently talking (processing a request)
func is_talking() -> bool:
	return _is_talking

## Check if NPC is ready to use
func is_ready() -> bool:
	return _is_ready

## Get a copy of the conversation history
func get_history() -> Array:
	return _conversation_history.duplicate()

## Get the number of messages in history
func get_history_length() -> int:
	return _conversation_history.size()

## Get the current system prompt
func get_system_prompt() -> String:
	return _current_prompt

## ==========================================================================
## SETUP
## ==========================================================================

## Set schema library for structured output support
## @param library: DWSchemaLibrary resource
func set_schema_library(library: DWSchemaLibrary) -> void:
	_schema_library = library
	if _chat_client != null:
		_chat_client.set_schema_library(library)
		print("[DWNPCClient] Schema library attached")

## ==========================================================================
## BASIC CONVERSATION
## ==========================================================================

## Send a message to the NPC and get a response (non-streaming)
## The conversation history is automatically managed
## @param message: The message to send to the NPC
## @return: The NPC's response text
func talk(message: String) -> String:
	if not _is_ready:
		await _wait_until_ready()

	if message.is_empty():
		push_warning("[DWNPCClient] Cannot send empty message")
		return ""

	_is_talking = true
	talking_started.emit()
	state_changed.emit(true)

	# Add user message to history
	var user_msg = DWDefinitions.ChatMessage.new("user", message)
	_conversation_history.append(user_msg)
	history_changed.emit()

	# Create chat config with full conversation history
	var config = DWDefinitions.ChatConfig.new("", _conversation_history)

	# Get response from chat client
	var result = await _chat_client.text_generation_async(config)

	_is_talking = false

	if result.success and result.response != "":
		# Add assistant response to history
		var assistant_msg = DWDefinitions.ChatMessage.new("assistant", result.response)
		_conversation_history.append(assistant_msg)
		history_changed.emit()

		# Auto-save if enabled
		if auto_save_history and history_save_path != "":
			save_history(history_save_path)

		talking_finished.emit(result.response)
		state_changed.emit(false)
		return result.response
	else:
		push_error("[DWNPCClient] Failed to get response: %s" % result.error_message)
		talking_finished.emit("")
		state_changed.emit(false)
		return ""

## ==========================================================================
## STREAMING CONVERSATION
## ==========================================================================

## Send a message to the NPC and get a streaming response
## The conversation history is automatically managed
## @param message: The message to send to the NPC
## @param on_chunk: Callback for each chunk of text (optional)
## @param on_complete: Callback when complete response is ready (optional)
func talk_stream(message: String, on_chunk: Callable = Callable(), on_complete: Callable = Callable()) -> void:
	if not _is_ready:
		await _wait_until_ready()

	if message.is_empty():
		push_warning("[DWNPCClient] Cannot send empty message")
		if on_chunk.is_valid():
			on_chunk.call("")
		if on_complete.is_valid():
			on_complete.call("")
		return

	_is_talking = true
	talking_started.emit()
	state_changed.emit(true)

	# Add user message to history
	var user_msg = DWDefinitions.ChatMessage.new("user", message)
	_conversation_history.append(user_msg)
	history_changed.emit()

	# Create chat config with full conversation history
	var config = DWDefinitions.ChatStreamConfig.new("", _conversation_history)

	# Define chunk callback
	var chunk_callback = func(chunk: String):
		chunk_received.emit(chunk)
		if on_chunk.is_valid():
			on_chunk.call(chunk)

	# Define complete callback
	var complete_callback = func(full_response: String):
		_is_talking = false

		if full_response != "":
			# Add assistant response to history
			var assistant_msg = DWDefinitions.ChatMessage.new("assistant", full_response)
			_conversation_history.append(assistant_msg)
			history_changed.emit()

			# Auto-save if enabled
			if auto_save_history and history_save_path != "":
				save_history(history_save_path)

		if on_complete.is_valid():
			on_complete.call(full_response)

		talking_finished.emit(full_response)
		state_changed.emit(false)

	# Send streaming request
	await _chat_client.text_chat_stream_async(config, chunk_callback, complete_callback)

## ==========================================================================
## STRUCTURED OUTPUT CONVERSATION
## ==========================================================================

## Send a message and get a structured response using a schema name
## Returns a dictionary with the structured object and extracted dialogue
## The conversation history is automatically managed
## @param message: The message to send to the NPC
## @param schema_name: Name of the schema from the library
## @return: Dictionary with { success: bool, object_data: Dictionary, response_text: String, error: String }
func talk_structured(message: String, schema_name: String) -> Dictionary:
	if not _is_ready:
		await _wait_until_ready()

	if message.is_empty() or schema_name.is_empty():
		push_warning("[DWNPCClient] Message and schema name cannot be empty")
		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": "Message and schema name are required"
		}

	if _schema_library == null:
		push_error("[DWNPCClient] No schema library set. Call set_schema_library() first")
		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": "No schema library available"
		}

	_is_talking = true
	talking_started.emit()
	state_changed.emit(true)

	# Build conversation context from history
	var conversation_context = _build_conversation_context()
	var full_prompt = message if conversation_context.is_empty() else "%s\n\nUser: %s" % [conversation_context, message]

	# Get structured response
	var result = await _chat_client.generate_structured_async(schema_name, full_prompt)

	_is_talking = false

	if result.success:
		# Add user message to history
		var user_msg = DWDefinitions.ChatMessage.new("user", message)
		_conversation_history.append(user_msg)

		# Extract response text from structured object
		var response_text = _extract_response_from_structured(result.object_data, schema_name)

		# Add assistant response to history
		var assistant_msg = DWDefinitions.ChatMessage.new("assistant", response_text)
		_conversation_history.append(assistant_msg)
		history_changed.emit()

		# Auto-save if enabled
		if auto_save_history and history_save_path != "":
			save_history(history_save_path)

		talking_finished.emit(response_text)
		state_changed.emit(false)

		return {
			"success": true,
			"object_data": result.object_data,
			"response_text": response_text,
			"error": ""
		}
	else:
		push_error("[DWNPCClient] Failed to get structured response: %s" % result.error)
		talking_finished.emit("")
		state_changed.emit(false)

		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": result.error
		}

## Send a message and get a structured response with full conversation history
## Uses the messages format instead of building a context string
## @param message: The message to send to the NPC
## @param schema_name: Name of the schema from the library
## @return: Dictionary with { success: bool, object_data: Dictionary, response_text: String, error: String }
func talk_structured_with_history(message: String, schema_name: String) -> Dictionary:
	if not _is_ready:
		await _wait_until_ready()

	if message.is_empty() or schema_name.is_empty():
		push_warning("[DWNPCClient] Message and schema name cannot be empty")
		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": "Message and schema name are required"
		}

	if _schema_library == null:
		push_error("[DWNPCClient] No schema library set. Call set_schema_library() first")
		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": "No schema library available"
		}

	_is_talking = true
	talking_started.emit()
	state_changed.emit(true)

	# Add user message to history first
	var user_msg = DWDefinitions.ChatMessage.new("user", message)
	_conversation_history.append(user_msg)

	# Get structured response with full message history
	var result = await _chat_client.generate_structured_with_history_async(schema_name, _conversation_history)

	_is_talking = false

	if result.success:
		# Extract response text from structured object
		var response_text = _extract_response_from_structured(result.object_data, schema_name)

		# Add assistant response to history
		var assistant_msg = DWDefinitions.ChatMessage.new("assistant", response_text)
		_conversation_history.append(assistant_msg)
		history_changed.emit()

		# Auto-save if enabled
		if auto_save_history and history_save_path != "":
			save_history(history_save_path)

		talking_finished.emit(response_text)
		state_changed.emit(false)

		return {
			"success": true,
			"object_data": result.object_data,
			"response_text": response_text,
			"error": ""
		}
	else:
		push_error("[DWNPCClient] Failed to get structured response: %s" % result.error)
		talking_finished.emit("")
		state_changed.emit(false)

		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": result.error
		}

## Send a message and get a structured response using direct JSON schema
## Does not require a schema library
## @param message: The message to send to the NPC
## @param schema_json: JSON schema as string
## @return: Dictionary with { success: bool, object_data: Dictionary, response_text: String, error: String }
func talk_structured_direct(message: String, schema_json: String) -> Dictionary:
	if not _is_ready:
		await _wait_until_ready()

	if message.is_empty() or schema_json.is_empty():
		push_warning("[DWNPCClient] Message and schema JSON cannot be empty")
		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": "Message and schema JSON are required"
		}

	_is_talking = true
	talking_started.emit()
	state_changed.emit(true)

	# Build conversation context from history
	var conversation_context = _build_conversation_context()
	var full_prompt = message if conversation_context.is_empty() else "%s\n\nUser: %s" % [conversation_context, message]

	# Get structured response with direct schema
	var result = await _chat_client.generate_structured_with_schema_async(schema_json, full_prompt)

	_is_talking = false

	if result.success:
		# Add user message to history
		var user_msg = DWDefinitions.ChatMessage.new("user", message)
		_conversation_history.append(user_msg)

		# Extract response text from structured object
		var response_text = _extract_response_from_structured(result.object_data, "DirectSchema")

		# Add assistant response to history
		var assistant_msg = DWDefinitions.ChatMessage.new("assistant", response_text)
		_conversation_history.append(assistant_msg)
		history_changed.emit()

		# Auto-save if enabled
		if auto_save_history and history_save_path != "":
			save_history(history_save_path)

		talking_finished.emit(response_text)
		state_changed.emit(false)

		return {
			"success": true,
			"object_data": result.object_data,
			"response_text": response_text,
			"error": ""
		}
	else:
		push_error("[DWNPCClient] Failed to get structured response: %s" % result.error)
		talking_finished.emit("")
		state_changed.emit(false)

		return {
			"success": false,
			"object_data": {},
			"response_text": "",
			"error": result.error
		}

## ==========================================================================
## HISTORY MANAGEMENT
## ==========================================================================

## Set the system prompt for the NPC character
## This will update the conversation history with the new prompt
## @param prompt: The new system prompt
func set_system_prompt(prompt: String) -> void:
	_current_prompt = prompt

	# Remove existing system messages
	var i = _conversation_history.size() - 1
	while i >= 0:
		if _conversation_history[i].role == "system":
			_conversation_history.remove_at(i)
		i -= 1

	# Add new system message at the beginning if we have a prompt
	if not _current_prompt.is_empty():
		var system_msg = DWDefinitions.ChatMessage.new("system", _current_prompt)
		_conversation_history.insert(0, system_msg)

	history_changed.emit()
	print("[DWNPCClient] System prompt updated")

## Clear the conversation history, starting fresh
## The system prompt (character design) will be preserved
func clear_history() -> void:
	_conversation_history.clear()

	# Re-add system message if we have a prompt
	if not _current_prompt.is_empty():
		var system_msg = DWDefinitions.ChatMessage.new("system", _current_prompt)
		_conversation_history.append(system_msg)

	history_changed.emit()
	print("[DWNPCClient] Conversation history cleared")

## Revert the last N exchanges (user + assistant pairs) from history
## The system prompt is preserved
## @param count: Number of exchanges to revert (default 1)
## @return: True if successfully reverted, false if no history to revert
func revert_history(count: int = 1) -> bool:
	if count <= 0:
		return false

	var reverted = 0

	for i in range(count):
		# Find the last assistant message and the user message before it
		var last_assistant_index = -1
		var last_user_index = -1

		for j in range(_conversation_history.size() - 1, -1, -1):
			if _conversation_history[j].role == "assistant" and last_assistant_index == -1:
				last_assistant_index = j
			elif _conversation_history[j].role == "user" and last_assistant_index != -1 and last_user_index == -1:
				last_user_index = j
				break

		if last_assistant_index != -1 and last_user_index != -1:
			# Remove both messages (assistant first, then user)
			_conversation_history.remove_at(last_assistant_index)
			_conversation_history.remove_at(last_user_index)
			reverted += 1
		else:
			break

	if reverted > 0:
		history_changed.emit()
		print("[DWNPCClient] Reverted %d exchange(s) from history" % reverted)
		return true
	else:
		print("[DWNPCClient] No history to revert")
		return false

## Manually append a chat message to the conversation history
## @param role: The role of the message (system, user, assistant)
## @param content: The content of the message
func append_chat_message(role: String, content: String) -> void:
	if role.is_empty() or content.is_empty():
		push_warning("[DWNPCClient] Role and content cannot be empty when appending chat message")
		return

	var msg = DWDefinitions.ChatMessage.new(role, content)
	_conversation_history.append(msg)
	history_changed.emit()
	print("[DWNPCClient] Appended %s message to history" % role)

## Revert (remove) the last N chat messages from history
## More granular than revert_history() which removes pairs
## @param count: Number of messages to remove from the end
## @return: Number of messages actually removed
func revert_chat_messages(count: int) -> int:
	if count <= 0:
		return 0

	var messages_to_remove = mini(count, _conversation_history.size())
	var original_count = _conversation_history.size()

	# Remove from the end
	for i in range(messages_to_remove):
		_conversation_history.remove_at(_conversation_history.size() - 1)

	var actually_removed = original_count - _conversation_history.size()

	if actually_removed > 0:
		history_changed.emit()
		print("[DWNPCClient] Reverted %d message(s) from history. Remaining: %d" % [actually_removed, _conversation_history.size()])

	return actually_removed

## ==========================================================================
## SAVE/LOAD
## ==========================================================================

## Save the current conversation history to a file
## Format: JSON with character_design, model, timestamps, and history array
## @param file_path: Path to save file (uses history_save_path if empty)
## @return: True if successfully saved
func save_history(file_path: String = "") -> bool:
	var path = file_path if file_path != "" else history_save_path

	if path.is_empty():
		push_error("[DWNPCClient] No save path specified")
		return false

	# Build save data
	var save_data = {
		"character_design": _current_prompt,
		"model": _chat_client.get_model_name() if _chat_client != null else "",
		"created_at": Time.get_datetime_string_from_system(),
		"updated_at": Time.get_datetime_string_from_system(),
		"total_messages": _conversation_history.size(),
		"history": []
	}

	# Convert messages to dictionaries
	for msg in _conversation_history:
		save_data["history"].append(msg.to_dict())

	# Save to file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[DWNPCClient] Failed to open file for writing: %s" % path)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	print("[DWNPCClient] Conversation saved to: %s" % path)
	return true

## Load conversation history from a file
## Restores character design, model, and history
## @param file_path: Path to save file (uses history_save_path if empty)
## @return: True if successfully loaded
func load_history(file_path: String = "") -> bool:
	var path = file_path if file_path != "" else history_save_path

	if path.is_empty():
		push_error("[DWNPCClient] No load path specified")
		return false

	# Load file
	if not FileAccess.file_exists(path):
		push_error("[DWNPCClient] Save file does not exist: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DWNPCClient] Failed to open file for reading: %s" % path)
		return false

	var json_text = file.get_as_text()
	file.close()

	# Parse JSON
	var json_result = JSON.parse_string(json_text)
	if json_result == null:
		push_error("[DWNPCClient] Failed to parse save file JSON")
		return false

	if not json_result is Dictionary:
		push_error("[DWNPCClient] Save file format is invalid")
		return false

	var save_data = json_result as Dictionary

	# Clear current history
	_conversation_history.clear()

	# Restore system prompt
	if save_data.has("character_design"):
		set_system_prompt(save_data["character_design"])

	# Restore history (skip system messages, they're handled by set_system_prompt)
	if save_data.has("history"):
		for msg_dict in save_data["history"]:
			if msg_dict is Dictionary:
				var role = msg_dict.get("role", "")
				var content = msg_dict.get("content", "")

				# Skip system messages (already added by set_system_prompt)
				if role != "system":
					var msg = DWDefinitions.ChatMessage.new(role, content)
					_conversation_history.append(msg)

	history_changed.emit()
	print("[DWNPCClient] Conversation loaded from: %s (%d messages)" % [path, _conversation_history.size()])
	return true

## ==========================================================================
## DEBUG UTILITIES
## ==========================================================================

## Print the current conversation history in a pretty format for debugging
## @param title: Optional title for the chat log
func print_pretty_chat_messages(title: String = "") -> void:
	var display_title = title if title != "" else "NPC '%s' Conversation History" % name

	print("\n" + "=".repeat(60))
	print(display_title)
	print("=".repeat(60))
	print("Total Messages: %d" % _conversation_history.size())
	print("Model: %s" % (_chat_client.get_model_name() if _chat_client != null else "Unknown"))
	print("-".repeat(60))

	if _conversation_history.is_empty():
		print("(No messages)")
	else:
		for i in range(_conversation_history.size()):
			var msg = _conversation_history[i]
			var icon = ""
			var role_text = ""

			match msg.role:
				"system":
					icon = "🤖"
					role_text = "SYSTEM"
				"user":
					icon = "👤"
					role_text = "USER"
				"assistant":
					icon = "💬"
					role_text = "ASSISTANT"
				_:
					icon = "❓"
					role_text = msg.role.to_upper()

			print("\n[%d] %s %s:" % [i, icon, role_text])
			print(msg.content)

	print("=".repeat(60) + "\n")

## ==========================================================================
## PRIVATE HELPERS
## ==========================================================================

## Wait until NPC is ready
func _wait_until_ready() -> void:
	while not _is_ready:
		await get_tree().process_frame

## Build conversation context from history (for structured generation)
## Skips system messages when building context string
func _build_conversation_context() -> String:
	if _conversation_history.is_empty():
		return ""

	var context_parts = []

	for msg in _conversation_history:
		if msg.role == "system":
			continue

		var role_label = "User" if msg.role == "user" else "Assistant"
		context_parts.append("%s: %s" % [role_label, msg.content])

	return "\n".join(context_parts)

## Smart extraction of response text from structured response
## Looks for common dialogue field names and uses them as the conversation content
## @param object_data: The structured response dictionary
## @param schema_name: The schema name for logging
## @return: The content to add to conversation history
func _extract_response_from_structured(object_data: Dictionary, schema_name: String) -> String:
	if object_data.is_empty():
		return "[Structured Response: %s]" % schema_name

	# Priority fields (checked first)
	var priority_fields = ["talk", "Talk", "dialogue", "Dialogue"]

	for field in priority_fields:
		if object_data.has(field):
			var value = object_data[field]
			if value is String and not value.is_empty():
				print("[DWNPCClient] Using '%s' field from structured response as conversation content" % field)
				return value

	# Fallback fields
	var fallback_fields = ["response", "Response", "message", "Message", "content", "Content", "text", "Text", "speech", "Speech", "say", "Say"]

	for field in fallback_fields:
		if object_data.has(field):
			var value = object_data[field]
			if value is String and not value.is_empty():
				print("[DWNPCClient] Using fallback '%s' field from structured response as conversation content" % field)
				return value

	# No dialogue field found, use raw JSON
	print("[DWNPCClient] No talk/dialogue field found in structured response, using raw JSON")
	return "[Structured Response: %s]" % JSON.stringify(object_data)