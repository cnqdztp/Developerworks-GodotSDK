# DWErrorHelpers - Utility functions for error handling
# Provides helper methods for formatting, logging, and analyzing errors

class_name DWErrorHelpers

## Format error for user display
## Converts technical errors to user-friendly messages
static func format_error_for_user(error: DWExceptions.DeveloperworksException) -> String:
	if error == null:
		return "An unknown error occurred."

	match error.error_code:
		# Authentication - Clear action needed
		DWExceptions.INVALID_TOKEN, DWExceptions.TOKEN_EXPIRED, DWExceptions.AUTH_INVALID_TOKEN:
			return "Your session has expired. Please log in again."
		DWExceptions.UNAUTHORIZED:
			return "You don't have permission to perform this action."

		# Credits - Direct user action
		DWExceptions.INSUFFICIENT_CREDITS, DWExceptions.PLAYER_INSUFFICIENT_CREDIT:
			return "You don't have enough credits. Please add more credits to continue."
		DWExceptions.INSUFFICIENT_DEVELOPER_BALANCE:
			return "Account balance is low. Please contact support or add funds."

		# Provider - Temporary issues
		DWExceptions.PROVIDER_RATE_LIMIT:
			return "Too many requests. Please wait a moment and try again."
		DWExceptions.PROVIDER_UNAVAILABLE:
			return "AI service is temporarily unavailable. Please try again in a few moments."
		DWExceptions.PROVIDER_ERROR:
			return "AI service encountered an error. Please try again."

		# Image generation - Actionable feedback
		DWExceptions.INVALID_SIZE_FORMAT:
			return "Invalid image size format. Please use format like '1024x1024'."
		DWExceptions.SIZE_EXCEEDS_LIMIT:
			return "Image size is too large. Please use a smaller size."
		DWExceptions.SIZE_NOT_ALLOWED:
			return "This image size is not supported. Try standard sizes like 1024x1024."

		# Game errors
		DWExceptions.GAME_NOT_FOUND:
			return "Game not found. Please check your configuration."
		DWExceptions.GAME_SUSPENDED:
			return "This game is temporarily unavailable. Please contact support."

		# Validation
		DWExceptions.MISSING_PARAMETERS, DWExceptions.MISSING_PARAMS:
			return "Some required information is missing. Please check your input."
		DWExceptions.VALIDATION_ERROR:
			return "Invalid input. Please check your data and try again."

		# Network/System
		DWExceptions.NETWORK_ERROR:
			return "Network connection error. Please check your internet and try again."
		DWExceptions.INTERNAL_ERROR:
			return "A system error occurred. Please try again or contact support if the problem persists."

		_:
			# Use the default message from the error
			return error.message if error.message != "" else "An error occurred. Please try again."

## Format error with additional context for display
static func format_error_with_context(error: DWExceptions.DeveloperworksException, context: String = "") -> String:
	var user_message = format_error_for_user(error)

	if context != "":
		user_message = "%s (Context: %s)" % [user_message, context]

	# Add retry suggestion for retryable errors
	if is_retryable(error):
		user_message += " This issue may be temporary."

	return user_message

## Log error with context and details
static func log_error(error: DWExceptions.DeveloperworksException, context: String = "") -> void:
	if error == null:
		push_error("[DWError] Unknown error occurred")
		return

	var log_msg = "[DWError] %s" % error.to_string()

	if context != "":
		log_msg += " | Context: %s" % context

	# Log details if available
	if not error.details.is_empty():
		log_msg += " | Details: %s" % JSON.stringify(error.details)

	# Add retryable flag
	if is_retryable(error):
		log_msg += " | [RETRYABLE]"

	push_error(log_msg)

## Log error with warning level (for non-critical errors)
static func log_warning(error: DWExceptions.DeveloperworksException, context: String = "") -> void:
	if error == null:
		push_warning("[DWWarning] Unknown error occurred")
		return

	var log_msg = "[DWWarning] %s" % error.to_string()

	if context != "":
		log_msg += " | Context: %s" % context

	if not error.details.is_empty():
		log_msg += " | Details: %s" % JSON.stringify(error.details)

	push_warning(log_msg)

## Check if error is retryable
static func is_retryable(error: DWExceptions.DeveloperworksException) -> bool:
	if error == null:
		return false

	return DWExceptions.is_retryable_error(error.error_code)

## Check if error requires authentication
static func requires_authentication(error: DWExceptions.DeveloperworksException) -> bool:
	if error == null:
		return false

	return error.error_code in [
		DWExceptions.INVALID_TOKEN,
		DWExceptions.TOKEN_EXPIRED,
		DWExceptions.AUTH_INVALID_TOKEN,
		DWExceptions.AUTH_MISSING_HEADER,
		DWExceptions.UNAUTHORIZED
	]

## Check if error is credit-related
static func is_credit_error(error: DWExceptions.DeveloperworksException) -> bool:
	if error == null:
		return false

	return error.error_code in [
		DWExceptions.INSUFFICIENT_CREDITS,
		DWExceptions.PLAYER_INSUFFICIENT_CREDIT,
		DWExceptions.INSUFFICIENT_DEVELOPER_BALANCE,
		DWExceptions.PROVIDER_PAYMENT_REQUIRED
	]

## Check if error is rate limit related
static func is_rate_limit_error(error: DWExceptions.DeveloperworksException) -> bool:
	if error == null:
		return false

	return error.error_code == DWExceptions.PROVIDER_RATE_LIMIT

## Get suggested retry delay in seconds
static func get_retry_delay(error: DWExceptions.DeveloperworksException) -> float:
	if error == null or not is_retryable(error):
		return 0.0

	match error.error_code:
		DWExceptions.PROVIDER_RATE_LIMIT:
			return 60.0  # 1 minute for rate limits
		DWExceptions.PROVIDER_UNAVAILABLE:
			return 30.0  # 30 seconds for provider issues
		DWExceptions.NETWORK_ERROR:
			return 5.0   # 5 seconds for network issues
		_:
			return 10.0  # Default 10 seconds

## Get error category for analytics/tracking
static func get_error_category(error: DWExceptions.DeveloperworksException) -> String:
	if error == null:
		return "unknown"

	if error is DWExceptions.AuthenticationException:
		return "authentication"
	elif error is DWExceptions.GameException:
		return "game"
	elif error is DWExceptions.ProviderException:
		return "provider"
	elif error is DWExceptions.CreditException:
		return "credit"
	elif error is DWExceptions.ImageGenerationException:
		return "image_generation"
	elif error is DWExceptions.ValidationException:
		return "validation"
	elif error is DWExceptions.NetworkException:
		return "network"
	else:
		return "api"

## Get error severity level
static func get_error_severity(error: DWExceptions.DeveloperworksException) -> String:
	if error == null:
		return "unknown"

	# Critical errors that stop functionality
	if error.error_code in [
		DWExceptions.GAME_SUSPENDED,
		DWExceptions.GAME_ACCESS_DENIED,
		DWExceptions.INSUFFICIENT_DEVELOPER_BALANCE
	]:
		return "critical"

	# High priority errors requiring immediate user action
	elif error.error_code in [
		DWExceptions.INSUFFICIENT_CREDITS,
		DWExceptions.PLAYER_INSUFFICIENT_CREDIT,
		DWExceptions.TOKEN_EXPIRED,
		DWExceptions.UNAUTHORIZED
	]:
		return "high"

	# Medium priority - temporary issues
	elif error.error_code in [
		DWExceptions.PROVIDER_RATE_LIMIT,
		DWExceptions.PROVIDER_UNAVAILABLE,
		DWExceptions.NETWORK_ERROR
	]:
		return "medium"

	# Low priority - validation or user errors
	elif error.error_code in [
		DWExceptions.INVALID_REQUEST,
		DWExceptions.VALIDATION_ERROR,
		DWExceptions.INVALID_SIZE_FORMAT
	]:
		return "low"

	else:
		return "medium"

## Create a user-friendly error dialog data
## Returns a dictionary with title, message, and buttons
static func create_error_dialog_data(error: DWExceptions.DeveloperworksException) -> Dictionary:
	if error == null:
		return {
			"title": "Error",
			"message": "An unknown error occurred.",
			"show_retry": false,
			"show_contact_support": false
		}

	var title = "Error"
	var show_retry = is_retryable(error)
	var show_contact_support = false

	# Customize based on error type
	match get_error_category(error):
		"authentication":
			title = "Authentication Required"
			show_contact_support = false
		"credit":
			title = "Insufficient Credits"
			show_contact_support = true
		"provider":
			title = "Service Unavailable"
			show_contact_support = get_error_severity(error) == "critical"
		"validation":
			title = "Invalid Input"
			show_contact_support = false
		"network":
			title = "Connection Error"
			show_contact_support = false
		_:
			title = "Error"
			show_contact_support = get_error_severity(error) == "critical"

	return {
		"title": title,
		"message": format_error_for_user(error),
		"show_retry": show_retry,
		"show_contact_support": show_contact_support,
		"error_code": error.error_code,
		"severity": get_error_severity(error)
	}

## Format error for API logging/reporting
static func format_error_for_reporting(error: DWExceptions.DeveloperworksException) -> Dictionary:
	if error == null:
		return {
			"error_code": "UNKNOWN",
			"message": "Unknown error",
			"category": "unknown",
			"severity": "unknown"
		}

	return {
		"error_code": error.error_code,
		"message": error.message,
		"http_status_code": error.http_status_code,
		"details": error.details,
		"category": get_error_category(error),
		"severity": get_error_severity(error),
		"retryable": is_retryable(error)
	}