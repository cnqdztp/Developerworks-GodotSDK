# DWChatClient - Chat completion client

extends Node

var _model: String
var _chat_provider: Node = null
var _auth_manager: Node = null
var _object_provider: Node = null
var _schema_library: DWSchemaLibrary = null

func _init(model: String, chat_provider: Node, auth_manager: Node, object_provider: Node = null):
	_model = model
	_chat_provider = chat_provider
	_auth_manager = auth_manager
	_object_provider = object_provider

## Get model name
func get_model_name() -> String:
	return _model

## Text generation (non-streaming)
func text_generation_async(config: DWDefinitions.ChatConfig) -> DWDefinitions.AIResult:
	# Convert public ChatMessage to internal ChatMessage
	var internal_messages = []
	for msg in config.messages:
		internal_messages.append(AIDataModels.ChatMessage.new(msg.role, msg.content))

	# Create request
	var request = AIDataModels.ChatCompletionRequest.new()
	request.model = _model
	request.messages = internal_messages
	request.temperature = config.temperature
	request.stream = false

	# Send request
	var response = await _chat_provider.chat_completion_async(request)

	if response == null or response.choices.size() == 0:
		return DWDefinitions.AIResult.new("", "Failed to get valid response from AI")

	var content = response.choices[0].message.content
	return DWDefinitions.AIResult.new(content, "")

## Text generation (streaming)
func text_chat_stream_async(
	config: DWDefinitions.ChatStreamConfig,
	on_chunk: Callable,
	on_complete: Callable
) -> void:
	# Convert public ChatMessage to internal ChatMessage
	var internal_messages = []
	for msg in config.messages:
		internal_messages.append(AIDataModels.ChatMessage.new(msg.role, msg.content))

	# Create request
	var request = AIDataModels.ChatCompletionRequest.new()
	request.model = _model
	request.messages = internal_messages
	request.temperature = config.temperature
	request.stream = true

	# Accumulate full response
	var full_response = ""

	# Define callbacks
	var on_text_delta = func(delta: String):
		if delta != "":
			full_response += delta
			on_chunk.call(delta)

	var on_legacy_response = func(stream_response: AIDataModels.StreamCompletionResponse):
		if stream_response == null or stream_response.choices.size() == 0:
			return

		var choice = stream_response.choices[0]
		if choice.delta == null:
			return

		var content = choice.delta.content
		if content != "":
			full_response += content
			on_chunk.call(content)

	var on_finally = func():
		on_complete.call(full_response)

	# Send streaming request
	await _chat_provider.chat_completion_stream_async(
		request,
		on_text_delta,
		on_legacy_response,
		on_finally
	)

## ===== Structured Output Methods =====

## Set schema library for structured output
## @param library: DWSchemaLibrary resource containing schemas
func set_schema_library(library: DWSchemaLibrary) -> void:
	_schema_library = library

## Generate structured output with schema name (single prompt)
## @param schema_name: Name of the schema from the library
## @param prompt: Text prompt for generation
## @return: Dictionary with { success: bool, object_data: Dictionary, error: String, error_code: String }
func generate_structured_async(schema_name: String, prompt: String) -> Dictionary:
	# Validate schema library
	if _schema_library == null:
		var error = DWExceptions.ValidationException.new(
			DWExceptions.VALIDATION_ERROR,
			"No schema library available. Call set_schema_library() first",
			{"operation": "generate_structured"}
		)
		return {
			"success": false,
			"object_data": {},
			"error": error.message,
			"error_code": error.error_code
		}

	if not _schema_library.has_valid_schema(schema_name):
		var available_schemas = _schema_library.get_valid_schema_names()
		var error = DWExceptions.ValidationException.new(
			DWExceptions.VALIDATION_ERROR,
			"Schema '%s' not found in library. Available schemas: %s" % [schema_name, ", ".join(available_schemas)],
			{"schema_name": schema_name, "available_schemas": available_schemas}
		)
		return {
			"success": false,
			"object_data": {},
			"error": error.message,
			"error_code": error.error_code
		}

	# Validate object provider
	if _object_provider == null:
		return {
			"success": false,
			"object_data": {},
			"error": "Object provider not available. SDK initialization may have failed"
		}

	# Get schema
	var schema_entry = _schema_library.find_schema(schema_name)
	var parsed_schema = schema_entry.get_parsed_schema()

	if parsed_schema.is_empty():
		return {
			"success": false,
			"object_data": {},
			"error": "Failed to parse schema '%s'" % schema_name
		}

	# Create request
	var request = AIObjectDataModels.ObjectGenerationRequest.new()
	request.model = _model
	request.prompt = prompt
	request.schema = parsed_schema
	request.schema_name = schema_name
	request.schema_description = schema_entry.description

	# Send request
	var response = await _object_provider.generate_object_async(request)

	if response.success:
		return {
			"success": true,
			"object_data": response.response.object_data,
			"error": ""
		}
	else:
		return {
			"success": false,
			"object_data": {},
			"error": response.error
		}

## Generate structured output with schema name (conversation history)
## @param schema_name: Name of the schema from the library
## @param messages: Array of DWDefinitions.ChatMessage for conversation history
## @return: Dictionary with { success: bool, object_data: Dictionary, error: String, error_code: String }
func generate_structured_with_history_async(schema_name: String, messages: Array) -> Dictionary:
	# Validate schema library
	if _schema_library == null:
		var error = DWExceptions.ValidationException.new(
			DWExceptions.VALIDATION_ERROR,
			"No schema library available. Call set_schema_library() first",
			{"operation": "generate_structured_with_history"}
		)
		return {
			"success": false,
			"object_data": {},
			"error": error.message,
			"error_code": error.error_code
		}

	if not _schema_library.has_valid_schema(schema_name):
		var available_schemas = _schema_library.get_valid_schema_names()
		var error = DWExceptions.ValidationException.new(
			DWExceptions.VALIDATION_ERROR,
			"Schema '%s' not found in library. Available schemas: %s" % [schema_name, ", ".join(available_schemas)],
			{"schema_name": schema_name, "available_schemas": available_schemas}
		)
		return {
			"success": false,
			"object_data": {},
			"error": error.message,
			"error_code": error.error_code
		}

	# Validate object provider
	if _object_provider == null:
		return {
			"success": false,
			"object_data": {},
			"error": "Object provider not available. SDK initialization may have failed"
		}

	# Validate messages
	if messages.is_empty():
		return {
			"success": false,
			"object_data": {},
			"error": "Messages array cannot be empty"
		}

	# Get schema
	var schema_entry = _schema_library.find_schema(schema_name)
	var parsed_schema = schema_entry.get_parsed_schema()

	if parsed_schema.is_empty():
		return {
			"success": false,
			"object_data": {},
			"error": "Failed to parse schema '%s'" % schema_name
		}

	# Create request
	var request = AIObjectDataModels.ObjectGenerationRequest.new()
	request.model = _model
	request.messages = messages
	request.schema = parsed_schema
	request.schema_name = schema_name
	request.schema_description = schema_entry.description

	# Send request
	var response = await _object_provider.generate_object_async(request)

	if response.success:
		return {
			"success": true,
			"object_data": response.response.object_data,
			"error": ""
		}
	else:
		return {
			"success": false,
			"object_data": {},
			"error": response.error
		}

## Generate structured output with direct schema JSON (no library needed)
## @param schema_json: JSON schema as string
## @param prompt: Text prompt for generation
## @return: Dictionary with { success: bool, object_data: Dictionary, error: String }
func generate_structured_with_schema_async(schema_json: String, prompt: String) -> Dictionary:
	# Validate object provider
	if _object_provider == null:
		return {
			"success": false,
			"object_data": {},
			"error": "Object provider not available. SDK initialization may have failed"
		}

	# Parse schema JSON
	var json_parser = JSON.new()
	var error = json_parser.parse(schema_json)
	if error != OK:
		return {
			"success": false,
			"object_data": {},
			"error": "Invalid schema JSON: %s" % json_parser.get_error_message()
		}

	var parsed_schema = json_parser.get_data()
	if not parsed_schema is Dictionary:
		return {
			"success": false,
			"object_data": {},
			"error": "Schema JSON did not parse to a Dictionary"
		}

	# Create request
	var request = AIObjectDataModels.ObjectGenerationRequest.new()
	request.model = _model
	request.prompt = prompt
	request.schema = parsed_schema
	request.schema_name = "DirectSchema"

	# Send request
	var response = await _object_provider.generate_object_async(request)

	if response.success:
		return {
			"success": true,
			"object_data": response.response.object_data,
			"error": ""
		}
	else:
		return {
			"success": false,
			"object_data": {},
			"error": response.error
		}

## Check if a schema exists in the library
## @param schema_name: Name of the schema to check
## @return: True if schema exists and is valid
func has_schema(schema_name: String) -> bool:
	if _schema_library == null:
		return false
	return _schema_library.has_valid_schema(schema_name)

## Get available schema names from the library
## @return: Array of valid schema names
func get_available_schemas() -> Array:
	if _schema_library == null:
		return []
	return _schema_library.get_valid_schema_names()
