# DWExceptions - Comprehensive error handling system for DeveloperWorks SDK
# Based on Unity SDK DW_Exceptions.cs
# Provides structured error codes, custom exception classes, and error parsing

class_name DWExceptions

## Error Code Constants - Organized by category
## Reference: Unity_Developerworks_SDK/Core/DW_Exceptions.cs

# Authentication Errors (AUTH_*)
const AUTH_MISSING_HEADER = "AUTH_MISSING_HEADER"
const AUTH_INVALID_TOKEN = "AUTH_INVALID_TOKEN"
const AUTH_TOKEN_GAME_MISMATCH = "AUTH_TOKEN_GAME_MISMATCH"
const INVALID_TOKEN = "INVALID_TOKEN"
const TOKEN_EXPIRED = "TOKEN_EXPIRED"
const UNAUTHORIZED = "UNAUTHORIZED"

# Game Errors (GAME_*)
const GAME_NOT_FOUND = "GAME_NOT_FOUND"
const GAME_ACCESS_DENIED = "GAME_ACCESS_DENIED"
const GAME_SUSPENDED = "GAME_SUSPENDED"

# Endpoint Errors (ENDPOINT_*, MODEL_*)
const ENDPOINT_NOT_FOUND = "ENDPOINT_NOT_FOUND"
const ENDPOINT_SUSPENDED = "ENDPOINT_SUSPENDED"
const MODEL_NOT_FOUND = "MODEL_NOT_FOUND"
const INVALID_ENDPOINT = "INVALID_ENDPOINT"

# Provider Errors (PROVIDER_*)
const PROVIDER_ERROR = "PROVIDER_ERROR"
const PROVIDER_RATE_LIMIT = "PROVIDER_RATE_LIMIT"
const PROVIDER_PAYMENT_REQUIRED = "PROVIDER_PAYMENT_REQUIRED"
const PROVIDER_UNAVAILABLE = "PROVIDER_UNAVAILABLE"

# Request Errors (INVALID_*, MISSING_*, VALIDATION_*)
const INVALID_REQUEST = "INVALID_REQUEST"
const MISSING_PARAMETERS = "MISSING_PARAMETERS"
const MISSING_PARAMS = "MISSING_PARAMS"
const VALIDATION_ERROR = "VALIDATION_ERROR"

# Credit Errors (INSUFFICIENT_*, CREDIT_*)
const PLAYER_INSUFFICIENT_CREDIT = "PLAYER_INSUFFICIENT_CREDIT"
const INSUFFICIENT_CREDITS = "INSUFFICIENT_CREDITS"
const INSUFFICIENT_DEVELOPER_BALANCE = "INSUFFICIENT_DEVELOPER_BALANCE"

# Image Generation Errors (INVALID_SIZE_*, SIZE_*)
const INVALID_SIZE_FORMAT = "INVALID_SIZE_FORMAT"
const INVALID_SIZE_VALUE = "INVALID_SIZE_VALUE"
const SIZE_EXCEEDS_LIMIT = "SIZE_EXCEEDS_LIMIT"
const SIZE_NOT_MULTIPLE = "SIZE_NOT_MULTIPLE"
const SIZE_NOT_ALLOWED = "SIZE_NOT_ALLOWED"

# System Errors (INTERNAL_*, DATABASE_*, NETWORK_*)
const INTERNAL_ERROR = "INTERNAL_ERROR"
const DATABASE_ERROR = "DATABASE_ERROR"
const NETWORK_ERROR = "NETWORK_ERROR"

## ===== Base Exception Class =====

## Base exception class for all DeveloperWorks SDK exceptions
class DeveloperworksException extends RefCounted:
	var error_code: String = ""
	var message: String = ""
	var details: Dictionary = {}
	var http_status_code: int = 0

	func _init(code: String = "", msg: String = "", detail: Dictionary = {}, status: int = 0):
		error_code = code
		message = msg if msg != "" else get_default_message(code)
		details = detail
		http_status_code = status

	## Convert exception to dictionary
	func to_dict() -> Dictionary:
		return {
			"error_code": error_code,
			"message": message,
			"details": details,
			"http_status_code": http_status_code
		}

	## Convert exception to string
	func to_string() -> String:
		var result = "[DeveloperworksException"
		if error_code != "":
			result += " %s" % error_code
		result += "] %s" % message
		if http_status_code > 0:
			result += " (HTTP %d)" % http_status_code
		return result

	## Get default user-friendly message for error code
	static func get_default_message(code: String) -> String:
		match code:
			# Authentication
			AUTH_MISSING_HEADER:
				return "Authentication header is missing. Please ensure you're logged in."
			AUTH_INVALID_TOKEN:
				return "Invalid authentication token. Please log in again."
			AUTH_TOKEN_GAME_MISMATCH:
				return "Token does not match the game. Please verify your credentials."
			INVALID_TOKEN:
				return "Invalid token. Please authenticate again."
			TOKEN_EXPIRED:
				return "Your session has expired. Please log in again."
			UNAUTHORIZED:
				return "Unauthorized access. Please check your permissions."

			# Game
			GAME_NOT_FOUND:
				return "Game not found. Please check the game ID."
			GAME_ACCESS_DENIED:
				return "Access to this game is denied."
			GAME_SUSPENDED:
				return "This game has been suspended. Please contact support."

			# Endpoint
			ENDPOINT_NOT_FOUND:
				return "API endpoint not found."
			ENDPOINT_SUSPENDED:
				return "This endpoint is temporarily suspended."
			MODEL_NOT_FOUND:
				return "AI model not found. Please check the model name."
			INVALID_ENDPOINT:
				return "Invalid API endpoint."

			# Provider
			PROVIDER_ERROR:
				return "AI provider encountered an error. Please try again."
			PROVIDER_RATE_LIMIT:
				return "Rate limit exceeded. Please wait before retrying."
			PROVIDER_PAYMENT_REQUIRED:
				return "Payment required from provider. Please check your billing."
			PROVIDER_UNAVAILABLE:
				return "AI provider is temporarily unavailable. Please try again later."

			# Request
			INVALID_REQUEST:
				return "Invalid request. Please check your parameters."
			MISSING_PARAMETERS:
				return "Required parameters are missing."
			MISSING_PARAMS:
				return "Required parameters are missing."
			VALIDATION_ERROR:
				return "Request validation failed. Please check your input."

			# Credit
			PLAYER_INSUFFICIENT_CREDIT:
				return "You don't have enough credits. Please add more credits to continue."
			INSUFFICIENT_CREDITS:
				return "Insufficient credits. Please add more credits."
			INSUFFICIENT_DEVELOPER_BALANCE:
				return "Developer account balance is insufficient. Please add funds."

			# Image Generation
			INVALID_SIZE_FORMAT:
				return "Invalid image size format. Use 'widthxheight' (e.g., '1024x1024')."
			INVALID_SIZE_VALUE:
				return "Invalid image size value. Dimensions must be positive integers."
			SIZE_EXCEEDS_LIMIT:
				return "Image size exceeds maximum allowed dimensions."
			SIZE_NOT_MULTIPLE:
				return "Image dimensions must be multiples of the required value."
			SIZE_NOT_ALLOWED:
				return "This image size is not allowed for the selected model."

			# System
			INTERNAL_ERROR:
				return "Internal server error. Please try again or contact support."
			DATABASE_ERROR:
				return "Database error occurred. Please try again."
			NETWORK_ERROR:
				return "Network error. Please check your connection and try again."

			_:
				return "An error occurred: %s" % code

## ===== Specialized Exception Classes =====

## Exception for authentication-related errors
class AuthenticationException extends DeveloperworksException:
	func _init(code: String, msg: String = "", detail: Dictionary = {}):
		super._init(code, msg, detail, 401)

## Exception for game-related errors
class GameException extends DeveloperworksException:
	func _init(code: String, msg: String = "", detail: Dictionary = {}):
		super._init(code, msg, detail, 404)

## Exception for provider-related errors
class ProviderException extends DeveloperworksException:
	func _init(code: String, msg: String = "", detail: Dictionary = {}):
		super._init(code, msg, detail, 503)

## Exception for credit-related errors
class CreditException extends DeveloperworksException:
	func _init(code: String, msg: String = "", detail: Dictionary = {}):
		super._init(code, msg, detail, 402)

## Exception for image generation errors
class ImageGenerationException extends DeveloperworksException:
	var provided_size: String = ""
	var validation_mode: String = ""

	func _init(code: String, msg: String = "", detail: Dictionary = {}, size: String = "", mode: String = ""):
		super._init(code, msg, detail, 400)
		provided_size = size
		validation_mode = mode

	func to_dict() -> Dictionary:
		var dict = super.to_dict()
		if provided_size != "":
			dict["provided_size"] = provided_size
		if validation_mode != "":
			dict["validation_mode"] = validation_mode
		return dict

## Exception for validation errors
class ValidationException extends DeveloperworksException:
	func _init(code: String, msg: String = "", detail: Dictionary = {}):
		super._init(code, msg, detail, 400)

## Exception for API errors
class ApiErrorException extends DeveloperworksException:
	func _init(code: String, msg: String = "", status: int = 500):
		super._init(code, msg, {}, status)

## Exception for network errors
class NetworkException extends DeveloperworksException:
	func _init(code: String = NETWORK_ERROR, msg: String = "", detail: Dictionary = {}):
		super._init(code, msg, detail, 0)

## ===== Error Response Parsing =====

## Parse API error response and create appropriate exception
## Expected formats:
##   { "error": { "code": "ERROR_CODE", "message": "..." } }
##   { "error": "message" }
##   { "code": "ERROR_CODE", "message": "..." }
static func parse_api_error(response_body: String, http_code: int) -> DeveloperworksException:
	# Try to parse JSON
	var json_result = JSON.parse_string(response_body)

	# If parsing fails, return generic error
	if json_result == null:
		return ApiErrorException.new(
			INTERNAL_ERROR,
			"Failed to parse error response: %s" % response_body,
			http_code
		)

	var error_code = ""
	var error_message = ""

	# Format 1: { "error": { "code": "...", "message": "..." } }
	if json_result is Dictionary and json_result.has("error"):
		var error_obj = json_result["error"]

		# error is an object
		if error_obj is Dictionary:
			error_code = error_obj.get("code", "")
			error_message = error_obj.get("message", "")
		# error is a string
		elif error_obj is String:
			error_message = error_obj
			error_code = INTERNAL_ERROR

	# Format 2: { "code": "...", "message": "..." }
	elif json_result is Dictionary and json_result.has("code"):
		error_code = json_result.get("code", "")
		error_message = json_result.get("message", "")

	# If we couldn't extract anything, use generic error
	if error_code == "" and error_message == "":
		error_code = INTERNAL_ERROR
		error_message = response_body

	# If we have message but no code, extract code from message if possible
	if error_code == "" and error_message != "":
		error_code = INTERNAL_ERROR

	# Create appropriate exception type based on error code
	return create_exception_for_code(error_code, error_message, http_code)

## Create appropriate exception type based on error code
static func create_exception_for_code(code: String, message: String, http_code: int) -> DeveloperworksException:
	# Authentication errors
	if code in [AUTH_MISSING_HEADER, AUTH_INVALID_TOKEN, AUTH_TOKEN_GAME_MISMATCH, INVALID_TOKEN, TOKEN_EXPIRED, UNAUTHORIZED]:
		return AuthenticationException.new(code, message)

	# Game errors
	elif code in [GAME_NOT_FOUND, GAME_ACCESS_DENIED, GAME_SUSPENDED]:
		return GameException.new(code, message)

	# Provider errors
	elif code in [PROVIDER_ERROR, PROVIDER_RATE_LIMIT, PROVIDER_PAYMENT_REQUIRED, PROVIDER_UNAVAILABLE]:
		return ProviderException.new(code, message)

	# Credit errors
	elif code in [PLAYER_INSUFFICIENT_CREDIT, INSUFFICIENT_CREDITS, INSUFFICIENT_DEVELOPER_BALANCE]:
		return CreditException.new(code, message)

	# Image generation errors
	elif code in [INVALID_SIZE_FORMAT, INVALID_SIZE_VALUE, SIZE_EXCEEDS_LIMIT, SIZE_NOT_MULTIPLE, SIZE_NOT_ALLOWED]:
		return ImageGenerationException.new(code, message)

	# Validation errors
	elif code in [INVALID_REQUEST, MISSING_PARAMETERS, MISSING_PARAMS, VALIDATION_ERROR]:
		return ValidationException.new(code, message)

	# Network errors
	elif code == NETWORK_ERROR:
		return NetworkException.new(code, message)

	# Default to generic API error
	else:
		return ApiErrorException.new(code, message, http_code)

## Check if an error code is retryable
static func is_retryable_error(code: String) -> bool:
	return code in [
		PROVIDER_UNAVAILABLE,
		PROVIDER_RATE_LIMIT,
		NETWORK_ERROR,
		INTERNAL_ERROR,
		DATABASE_ERROR
	]

## Get HTTP status code for error code
static func get_http_status_for_code(code: String) -> int:
	# Authentication errors
	if code in [AUTH_MISSING_HEADER, AUTH_INVALID_TOKEN, AUTH_TOKEN_GAME_MISMATCH, INVALID_TOKEN, TOKEN_EXPIRED, UNAUTHORIZED]:
		return 401

	# Game/Endpoint errors
	elif code in [GAME_NOT_FOUND, ENDPOINT_NOT_FOUND, MODEL_NOT_FOUND]:
		return 404

	# Provider errors
	elif code in [PROVIDER_ERROR, PROVIDER_UNAVAILABLE]:
		return 503
	elif code == PROVIDER_RATE_LIMIT:
		return 429

	# Credit errors
	elif code in [PLAYER_INSUFFICIENT_CREDIT, INSUFFICIENT_CREDITS, PROVIDER_PAYMENT_REQUIRED]:
		return 402

	# Validation errors
	elif code in [INVALID_REQUEST, MISSING_PARAMETERS, MISSING_PARAMS, VALIDATION_ERROR, INVALID_SIZE_FORMAT, INVALID_SIZE_VALUE, SIZE_NOT_ALLOWED]:
		return 400

	# System errors
	elif code in [INTERNAL_ERROR, DATABASE_ERROR]:
		return 500

	else:
		return 500
