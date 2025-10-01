# Public definitions for DeveloperWorks SDK
# Contains data structures used across the SDK

class_name DWDefinitions

## AIResult - Generic result wrapper for AI operations
class AIResult:
	var success: bool = false
	var response: String = ""
	var error_message: String = ""

	func _init(data: String = "", error_msg: String = ""):
		if error_msg == "":
			success = true
			response = data
			error_message = ""
		else:
			success = false
			response = ""
			error_message = error_msg

## ChatMessage - Represents a single message in a conversation
class ChatMessage:
	var role: String  # "system", "user", "assistant"
	var content: String

	func _init(msg_role: String = "user", msg_content: String = ""):
		role = msg_role
		content = msg_content

	func to_dict() -> Dictionary:
		return {
			"role": role,
			"content": content
		}

## ChatConfigBase - Base configuration for chat requests
class ChatConfigBase:
	var messages: Array = []  # Array of ChatMessage
	var temperature: float = 0.7

	func _init(user_message: String = "", msg_array: Array = []):
		if user_message != "":
			messages = [ChatMessage.new("user", user_message)]
		elif msg_array.size() > 0:
			messages = msg_array
		else:
			messages = []

## ChatConfig - Configuration for non-streaming chat
class ChatConfig extends ChatConfigBase:
	func _init(user_message: String = "", msg_array: Array = []):
		super(user_message, msg_array)

## ChatStreamConfig - Configuration for streaming chat
class ChatStreamConfig extends ChatConfigBase:
	func _init(user_message: String = "", msg_array: Array = []):
		super(user_message, msg_array)