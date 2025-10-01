# Public definitions for DeveloperWorks SDK
# Contains data structures used across the SDK

class_name DWDefinitions

## AIResult - Generic result wrapper for AI operations
class AIResult:
	var success: bool = false
	var response: String = ""
	var error_message: String = ""
	var error_code: String = ""  # Error code from DWExceptions
	var error_details: Dictionary = {}  # Additional error information

	func _init(data: String = "", error_msg: String = "", code: String = "", details: Dictionary = {}):
		if error_msg == "":
			success = true
			response = data
			error_message = ""
			error_code = ""
			error_details = {}
		else:
			success = false
			response = ""
			error_message = error_msg
			error_code = code
			error_details = details

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

## ObjectResult - Result wrapper for structured object generation
class ObjectResult:
	var success: bool = false
	var object_data: Dictionary = {}
	var error_message: String = ""
	var error_code: String = ""  # Error code from DWExceptions
	var error_details: Dictionary = {}  # Additional error information

	func _init(data: Dictionary = {}, error: String = "", code: String = "", details: Dictionary = {}):
		if error == "" and not data.is_empty():
			success = true
			object_data = data
			error_message = ""
			error_code = ""
			error_details = {}
		else:
			success = false
			object_data = {}
			error_message = error
			error_code = code
			error_details = details

## ImageResult - Result wrapper for single image generation
class ImageResult:
	var success: bool = false
	var image: Image = null  # Godot Image object
	var generated_image = null  # GeneratedImage with metadata (AIImageDataModels.GeneratedImage)
	var error_message: String = ""
	var error_code: String = ""  # Error code from DWExceptions
	var error_details: Dictionary = {}  # Additional error information

	func _init(img: Image = null, gen_img = null, error: String = "", code: String = "", details: Dictionary = {}):
		if error == "" and img != null:
			success = true
			image = img
			generated_image = gen_img
			error_message = ""
			error_code = ""
			error_details = {}
		else:
			success = false
			image = null
			generated_image = null
			error_message = error
			error_code = code
			error_details = details

## ImagesResult - Result wrapper for multiple image generation
class ImagesResult:
	var success: bool = false
	var images: Array = []  # Array of Image objects
	var generated_images: Array = []  # Array of GeneratedImage with metadata
	var error_message: String = ""
	var error_code: String = ""  # Error code from DWExceptions
	var error_details: Dictionary = {}  # Additional error information

	func _init(imgs: Array = [], gen_imgs: Array = [], error: String = "", code: String = "", details: Dictionary = {}):
		if error == "" and imgs.size() > 0:
			success = true
			images = imgs
			generated_images = gen_imgs
			error_message = ""
			error_code = ""
			error_details = {}
		else:
			success = false
			images = []
			generated_images = []
			error_message = error
			error_code = code
			error_details = details