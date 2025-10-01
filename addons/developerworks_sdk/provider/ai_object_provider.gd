# AIObjectProvider - Provider for AI structured object generation
# Handles HTTP requests to the DeveloperWorks AI Object Generation API
# Reference: Unity AIObjectProvider.cs

extends Node

const BASE_URL = "https://developerworks.agentlandlab.com"

var _auth_manager: Node = null

func _init(auth_manager: Node):
	_auth_manager = auth_manager

## Get object generation API URL
func get_object_url() -> String:
	if _auth_manager == null or _auth_manager.publishable_key == "":
		push_error("[AIObjectProvider] PublishableKey (GameId) is not available")
		return ""

	return "%s/ai/%s/v1/generateObject" % [BASE_URL, _auth_manager.publishable_key]

## Get auth token
func get_auth_token() -> String:
	if _auth_manager == null or _auth_manager.auth_token == "":
		push_error("[AIObjectProvider] Authentication token is not available")
		return ""

	return _auth_manager.auth_token

## Generate structured object
## @param request: ObjectGenerationRequest containing the generation parameters
## @return: Dictionary with { success: bool, response: ObjectGenerationResponse, error: String }
func generate_object_async(request: AIObjectDataModels.ObjectGenerationRequest) -> Dictionary:
	var url = get_object_url()
	if url == "":
		return {
			"success": false,
			"response": null,
			"error": "Failed to get object generation URL"
		}

	var http = HTTPRequest.new()
	add_child(http)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % get_auth_token()
	]

	var json = JSON.stringify(request.to_dict())

	# Debug logging
	print("[AIObjectProvider] Request URL: ", url)
	print("[AIObjectProvider] Request JSON: ", json)

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		push_error("[AIObjectProvider] Failed to send request: ", err)
		http.queue_free()
		return {
			"success": false,
			"response": null,
			"error": "Failed to send HTTP request: %s" % str(err)
		}

	var response = await http.request_completed
	http.queue_free()

	var result = response[0]
	var response_code = response[1]
	var response_headers = response[2]
	var body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[AIObjectProvider] Request failed: ", result)
		return {
			"success": false,
			"response": null,
			"error": "HTTP request failed: %s" % str(result)
		}

	var body_text = body.get_string_from_utf8()

	if response_code != 200:
		var error = DWExceptions.parse_api_error(body_text, response_code)
		DWErrorHelpers.log_error(error, "generate_object_async")
		return {
			"success": false,
			"response": null,
			"error": error.message,
			"error_code": error.error_code
		}

	# Parse response
	var json_result = JSON.parse_string(body_text)
	if json_result == null:
		push_error("[AIObjectProvider] Failed to parse response JSON")
		return {
			"success": false,
			"response": null,
			"error": "Failed to parse response JSON"
		}

	# Create response object
	var obj_response = AIObjectDataModels.ObjectGenerationResponse.new(json_result)

	print("[AIObjectProvider] Successfully generated structured object")
	if obj_response.usage != null:
		print("[AIObjectProvider] Token usage - Input: %d, Output: %d, Total: %d, Cost: $%.4f" % [
			obj_response.usage.input_tokens,
			obj_response.usage.output_tokens,
			obj_response.usage.total_tokens,
			obj_response.usage.cost
		])

	return {
		"success": true,
		"response": obj_response,
		"error": ""
	}