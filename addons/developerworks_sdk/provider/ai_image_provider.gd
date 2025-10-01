# AIImageProvider - Provider for AI image generation
# Handles HTTP requests to the DeveloperWorks AI Image API

extends Node

const BASE_URL = "https://developerworks.agentlandlab.com"
const TIMEOUT_SECONDS = 120  # Images take longer to generate

var _auth_manager: Node = null

func _init(auth_manager: Node):
	_auth_manager = auth_manager

## Get image generation API URL
func get_image_url() -> String:
	if _auth_manager == null or _auth_manager.publishable_key == "":
		push_error("[AIImageProvider] PublishableKey (GameId) is not available")
		return ""

	return "%s/ai/%s/v1/image" % [BASE_URL, _auth_manager.publishable_key]

## Get auth token
func get_auth_token() -> String:
	if _auth_manager == null or _auth_manager.auth_token == "":
		push_error("[AIImageProvider] Authentication token is not available")
		return ""

	return _auth_manager.auth_token

## Validate image size format
func validate_size(size: String) -> Dictionary:
	# Supported sizes for most providers (especially DALL-E)
	var supported_sizes = [
		"1024x1024",
		"1792x1024",
		"1024x1792",
		"512x512",
		"256x256"
	]

	if size in supported_sizes:
		return {"valid": true, "error": null}

	# Check if it's a valid format (widthxheight)
	var parts = size.split("x")
	if parts.size() != 2:
		var error = DWExceptions.ImageGenerationException.new(
			DWExceptions.INVALID_SIZE_FORMAT,
			"Invalid size format. Use 'widthxheight' (e.g., '1024x1024'). Supported sizes: %s" % ", ".join(supported_sizes),
			{"provided_size": size, "supported_sizes": supported_sizes},
			size,
			"format"
		)
		return {
			"valid": false,
			"error": error
		}

	# Check if both parts are numbers
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		var error = DWExceptions.ImageGenerationException.new(
			DWExceptions.INVALID_SIZE_VALUE,
			"Size dimensions must be integers. Supported sizes: %s" % ", ".join(supported_sizes),
			{"provided_size": size, "supported_sizes": supported_sizes},
			size,
			"value"
		)
		return {
			"valid": false,
			"error": error
		}

	# If format is valid but size is not in supported list, warn but allow
	push_warning("[AIImageProvider] Size '%s' may not be supported by all providers. Standard sizes: %s" % [size, ", ".join(supported_sizes)])
	return {"valid": true, "error": null}

## Generate image
func generate_image_async(request: AIImageDataModels.ImageGenerationRequest) -> AIImageDataModels.ImageGenerationResponse:
	var url = get_image_url()
	if url == "":
		return null

	# Validate size
	var size_validation = validate_size(request.size)
	if not size_validation["valid"]:
		DWErrorHelpers.log_error(size_validation["error"], "generate_image_async - size validation")
		return null

	# Validate prompt
	if request.prompt == "":
		push_error("[AIImageProvider] Prompt cannot be empty")
		return null

	# Validate model
	if request.model == "":
		push_error("[AIImageProvider] Model cannot be empty")
		return null

	# Validate n (number of images)
	if request.n < 1 or request.n > 10:
		push_error("[AIImageProvider] Number of images (n) must be between 1 and 10")
		return null

	var http = HTTPRequest.new()
	add_child(http)
	http.timeout = TIMEOUT_SECONDS

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % get_auth_token()
	]

	var json = JSON.stringify(request.to_dict())
	print("[AIImageProvider] Requesting image generation...")
	print("[AIImageProvider] Model: ", request.model, " | Prompt: ", request.prompt.substr(0, 50), "..." if request.prompt.length() > 50 else "")

	var err = http.request(url, headers, HTTPClient.METHOD_POST, json)

	if err != OK:
		push_error("[AIImageProvider] Failed to send request: ", err)
		http.queue_free()
		return null

	var response = await http.request_completed
	http.queue_free()

	var result = response[0]
	var response_code = response[1]
	var response_headers = response[2]
	var body = response[3]

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[AIImageProvider] Request failed: ", result)
		if result == HTTPRequest.RESULT_TIMEOUT:
			push_error("[AIImageProvider] Request timed out after ", TIMEOUT_SECONDS, " seconds")
		return null

	if response_code != 200:
		var error = DWExceptions.parse_api_error(
			body.get_string_from_utf8(),
			response_code
		)
		DWErrorHelpers.log_error(error, "generate_image_async")
		return null

	var json_result = JSON.parse_string(body.get_string_from_utf8())
	if json_result == null:
		push_error("[AIImageProvider] Failed to parse response JSON")
		return null

	print("[AIImageProvider] Image generation successful!")
	return AIImageDataModels.ImageGenerationResponse.new(json_result)