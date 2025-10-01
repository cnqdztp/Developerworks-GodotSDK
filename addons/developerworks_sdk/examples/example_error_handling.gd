# Example: Error Handling in DeveloperWorks SDK
# Demonstrates how to handle different types of errors gracefully

extends Node

## This example demonstrates:
## 1. Handling schema validation errors
## 2. Handling image size validation errors
## 3. Handling API errors
## 4. Checking if errors are retryable
## 5. Formatting errors for user display

func _ready():
	print("=== DeveloperWorks SDK Error Handling Examples ===\n")

	# Initialize SDK
	await DW_SDK.initialize_async("your-game-id")

	# Run examples
	await example_schema_not_found()
	print("\n" + "=".repeat(50) + "\n")

	await example_invalid_image_size()
	print("\n" + "=".repeat(50) + "\n")

	await example_missing_prompt()
	print("\n" + "=".repeat(50) + "\n")

	await example_error_helper_utilities()
	print("\n" + "=".repeat(50) + "\n")

	await example_retryable_errors()
	print("\n" + "=".repeat(50) + "\n")

	print("Examples complete!")

## Example 1: Handle schema not found error
func example_schema_not_found():
	print("=== Example 1: Schema Not Found Error ===")

	var chat_client = DW_SDK.Factory.create_chat_client()

	# Try to use a non-existent schema
	var result = await chat_client.generate_structured_async(
		"nonexistent_schema",
		"Generate a character"
	)

	if not result.success:
		print("Error occurred!")
		print("  Error Code: %s" % result.error_code)
		print("  Error Message: %s" % result.error)

		# Check available schemas
		var available = chat_client.get_available_schemas()
		if available.size() > 0:
			print("  Available schemas: %s" % ", ".join(available))
		else:
			print("  No schemas available. Did you set a schema library?")

## Example 2: Handle invalid image size error
func example_invalid_image_size():
	print("=== Example 2: Invalid Image Size Error ===")

	var image_client = DW_SDK.Factory.create_image_client()

	# Try to use an invalid size format
	var result = await image_client.generate_image_async(
		"a beautiful landscape",
		"999x999"  # Invalid size - not in supported list
	)

	if not result.success:
		print("Error occurred!")
		print("  Error Code: %s" % result.error_code)
		print("  Error Message: %s" % result.error)

		# Show user-friendly message
		if result.has("error_details") and not result.error_details.is_empty():
			print("  Details: %s" % JSON.stringify(result.error_details))

		# Suggest valid sizes
		print("  Try using: 1024x1024, 1792x1024, or 1024x1792")

## Example 3: Handle missing prompt error
func example_missing_prompt():
	print("=== Example 3: Missing Required Parameter ===")

	var image_client = DW_SDK.Factory.create_image_client()

	# Try to generate image with empty prompt
	var result = await image_client.generate_image_async("")

	if not result.success:
		print("Error occurred!")
		print("  Error Code: %s" % result.error_code)
		print("  Error Message: %s" % result.error)

		# This is a validation error
		if result.error_code == DWExceptions.MISSING_PARAMETERS:
			print("  This is a validation error - user needs to provide required data")

## Example 4: Using error helper utilities
func example_error_helper_utilities():
	print("=== Example 4: Error Helper Utilities ===")

	# Create a mock error for demonstration
	var error = DWExceptions.CreditException.new(
		DWExceptions.INSUFFICIENT_CREDITS,
		"You don't have enough credits to complete this operation"
	)

	print("Original error: %s" % error.to_string())
	print("")

	# Format for user display
	var user_message = DWErrorHelpers.format_error_for_user(error)
	print("User-friendly message: %s" % user_message)
	print("")

	# Check error properties
	print("Error category: %s" % DWErrorHelpers.get_error_category(error))
	print("Error severity: %s" % DWErrorHelpers.get_error_severity(error))
	print("Is retryable: %s" % DWErrorHelpers.is_retryable(error))
	print("Is credit error: %s" % DWErrorHelpers.is_credit_error(error))
	print("")

	# Create error dialog data
	var dialog_data = DWErrorHelpers.create_error_dialog_data(error)
	print("Dialog data:")
	print("  Title: %s" % dialog_data.title)
	print("  Message: %s" % dialog_data.message)
	print("  Show retry button: %s" % dialog_data.show_retry)
	print("  Show contact support: %s" % dialog_data.show_contact_support)

## Example 5: Handling retryable errors
func example_retryable_errors():
	print("=== Example 5: Retryable Errors ===")

	# Simulate different error types
	var errors = [
		DWExceptions.ProviderException.new(
			DWExceptions.PROVIDER_RATE_LIMIT,
			"Rate limit exceeded"
		),
		DWExceptions.NetworkException.new(
			DWExceptions.NETWORK_ERROR,
			"Network connection failed"
		),
		DWExceptions.ValidationException.new(
			DWExceptions.INVALID_REQUEST,
			"Invalid request format"
		)
	]

	for error in errors:
		print("\nError: %s" % error.error_code)
		print("  Message: %s" % error.message)

		if DWErrorHelpers.is_retryable(error):
			var retry_delay = DWErrorHelpers.get_retry_delay(error)
			print("  -> This error is RETRYABLE")
			print("  -> Suggested retry delay: %.1f seconds" % retry_delay)

			# In a real app, you would implement retry logic here
			# Example:
			# await get_tree().create_timer(retry_delay).timeout
			# retry_operation()
		else:
			print("  -> This error is NOT retryable")
			print("  -> User action required or operation cannot be completed")

## Example 6: Full error handling flow
func example_full_error_handling_flow():
	print("=== Example 6: Full Error Handling Flow ===")

	var chat_client = DW_SDK.Factory.create_chat_client()

	# Set up retry logic
	var max_retries = 3
	var retry_count = 0

	while retry_count < max_retries:
		var result = await chat_client.text_generation_async(
			DWDefinitions.ChatConfig.new("Tell me a joke")
		)

		if result.success:
			print("Success! Response: %s" % result.response)
			break
		else:
			print("Attempt %d failed" % (retry_count + 1))

			# Parse the error (if we had the error object)
			# In a real scenario, you'd get the actual error from the provider
			# For now, we just check the error message

			if result.error_message.contains("rate limit"):
				print("  Rate limited - waiting before retry...")
				await get_tree().create_timer(5.0).timeout
				retry_count += 1
			elif result.error_message.contains("network"):
				print("  Network error - waiting before retry...")
				await get_tree().create_timer(2.0).timeout
				retry_count += 1
			else:
				print("  Non-retryable error: %s" % result.error_message)
				break

	if retry_count >= max_retries:
		print("Failed after %d retries" % max_retries)

## Example 7: Creating custom error dialog
func example_create_error_dialog(error: DWExceptions.DeveloperworksException):
	# Get dialog data
	var dialog_data = DWErrorHelpers.create_error_dialog_data(error)

	# In a real app, you would create a UI dialog here
	# Example with AcceptDialog:
	# var dialog = AcceptDialog.new()
	# dialog.title = dialog_data.title
	# dialog.dialog_text = dialog_data.message
	#
	# if dialog_data.show_retry:
	#     dialog.add_button("Retry", true, "retry")
	#
	# if dialog_data.show_contact_support:
	#     dialog.add_button("Contact Support", true, "support")
	#
	# add_child(dialog)
	# dialog.popup_centered()

	print("Would show dialog:")
	print("  Title: %s" % dialog_data.title)
	print("  Message: %s" % dialog_data.message)