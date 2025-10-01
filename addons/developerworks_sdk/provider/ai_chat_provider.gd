# AIChatProvider - Provider for AI chat completions
# Handles HTTP requests to the DeveloperWorks AI API

extends Node

const BASE_URL = "https://developerworks.agentlandlab.com"

var _auth_manager: Node = null

func _init(auth_manager: Node):
	_auth_manager = auth_manager

## Get chat API URL
func get_chat_url() -> String:
	if _auth_manager == null or _auth_manager.publishable_key == "":
		push_error("[AIChatProvider] PublishableKey (GameId) is not available")
		return ""

	return "%s/ai/%s/v1/chat" % [BASE_URL, _auth_manager.publishable_key]

## Get auth token
func get_auth_token() -> String:
	if _auth_manager == null or _auth_manager.auth_token == "":
		push_error("[AIChatProvider] Authentication token is not available")
		return ""

	return _auth_manager.auth_token

## Chat completion (non-streaming)
func chat_completion_async(request: AIDataModels.ChatCompletionRequest) -> AIDataModels.ChatCompletionResponse:
	var url = get_chat_url()
	if url == "":
		return null

	var http = HTTPRequest.new()
	add_child(http)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % get_auth_token()
	]

	var json = JSON.stringify(request.to_dict())
	var err = http.request(url, headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		push_error("[AIChatProvider] Failed to send request: ", err)
		http.queue_free()
		return null

	var response = await http.request_completed
	http.queue_free()

	var result = response[0]
	var response_code = response[1]
	var response_headers = response[2]
	var body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[AIChatProvider] Request failed: ", result)
		return null

	if response_code != 200:
		var error = DWExceptions.parse_api_error(
			body.get_string_from_utf8(),
			response_code
		)
		DWErrorHelpers.log_error(error, "chat_completion_async")
		return null

	var json_result = JSON.parse_string(body.get_string_from_utf8())
	if json_result == null:
		push_error("[AIChatProvider] Failed to parse response JSON")
		return null

	return AIDataModels.ChatCompletionResponse.new(json_result)

## Chat completion streaming
## Calls on_text_delta for UI Message Stream format
## Calls on_legacy_response for legacy OpenAI format
## Calls on_finally when complete
func chat_completion_stream_async(
	request: AIDataModels.ChatCompletionRequest,
	on_text_delta: Callable,
	on_legacy_response: Callable,
	on_finally: Callable
) -> void:
	var url = get_chat_url()
	if url == "":
		on_finally.call()
		return

	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = 120  # 2 minutes timeout

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % get_auth_token()
	]

	# Buffer for incomplete JSON data
	var buffer = ""

	# Connect to body_part_received signal for streaming
	http.body_part_received.connect(func(body_part: PackedByteArray):
		var text = body_part.get_string_from_utf8()
		buffer += text

		# Process complete lines
		var lines = buffer.split("\n")

		# Keep last incomplete line in buffer
		buffer = lines[-1]
		lines = lines.slice(0, -1)

		for line in lines:
			if line.begins_with("data: "):
				var json_data = line.substr(6).strip_edges()

				if json_data == "[DONE]":
					continue

				# Try parsing as UI Message Stream format
				var parsed = JSON.parse_string(json_data)
				if parsed == null:
					continue

				# Check for UI Message Stream format
				if parsed.has("type"):
					var ui_msg = AIDataModels.UIMessageStreamResponse.new(parsed)
					if ui_msg.type == "text-delta" and ui_msg.delta != "":
						on_text_delta.call(ui_msg.delta)
					continue

				# Fallback: Legacy OpenAI format
				if parsed.has("choices"):
					var stream_response = AIDataModels.StreamCompletionResponse.new(parsed)
					on_legacy_response.call(stream_response)
	)

	var json = JSON.stringify(request.to_dict())
	var err = http.request(url, headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		push_error("[AIChatProvider] Failed to send stream request: ", err)
		http.queue_free()
		on_finally.call()
		return

	var response = await http.request_completed

	# Check for errors in streaming response
	var result = response[0]
	var response_code = response[1]
	var body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[AIChatProvider] Stream request failed: ", result)

	if response_code != 200:
		var error = DWExceptions.parse_api_error(
			body.get_string_from_utf8(),
			response_code
		)
		DWErrorHelpers.log_error(error, "chat_completion_stream_async")

	http.queue_free()
	on_finally.call()