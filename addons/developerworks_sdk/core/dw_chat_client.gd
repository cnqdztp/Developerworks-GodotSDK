# DWChatClient - Chat completion client

extends Node

var _model: String
var _chat_provider: Node = null
var _auth_manager: Node = null

func _init(model: String, chat_provider: Node, auth_manager: Node):
	_model = model
	_chat_provider = chat_provider
	_auth_manager = auth_manager

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