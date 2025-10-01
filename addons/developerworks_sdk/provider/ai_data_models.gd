# AI Data Models - Internal data structures for AI API communication
# These mirror the Unity SDK's data models

class_name AIDataModels

## ChatMessage - Internal message format
class ChatMessage:
	var role: String
	var content: String

	func _init(msg_role: String = "user", msg_content: String = ""):
		role = msg_role
		content = msg_content

	func to_dict() -> Dictionary:
		return {
			"role": role,
			"content": content
		}

## ChatCompletionRequest
class ChatCompletionRequest:
	var model: String
	var messages: Array  # Array of ChatMessage
	var temperature: float = 0.7
	var stream: bool = false
	var max_tokens: int = -1  # -1 means not set

	func to_dict() -> Dictionary:
		var msg_array = []
		for msg in messages:
			if msg is ChatMessage:
				msg_array.append(msg.to_dict())

		var result = {
			"model": model,
			"messages": msg_array,
			"temperature": temperature,
			"stream": stream
		}

		if max_tokens > 0:
			result["max_tokens"] = max_tokens

		return result

## ChatCompletionResponse
class ChatCompletionResponse:
	var id: String
	var object: String
	var created: int
	var model: String
	var choices: Array  # Array of Choice
	var usage: Dictionary

	func _init(data: Dictionary = {}):
		if data.is_empty():
			return

		id = data.get("id", "")
		object = data.get("object", "")
		created = data.get("created", 0)
		model = data.get("model", "")

		choices = []
		if data.has("choices"):
			for choice_data in data["choices"]:
				choices.append(Choice.new(choice_data))

		usage = data.get("usage", {})

	class Choice:
		var index: int
		var message: ChatMessage
		var finish_reason: String

		func _init(data: Dictionary = {}):
			if data.is_empty():
				return

			index = data.get("index", 0)
			finish_reason = data.get("finish_reason", "")

			if data.has("message"):
				var msg_data = data["message"]
				message = ChatMessage.new(
					msg_data.get("role", "assistant"),
					msg_data.get("content", "")
				)

## StreamCompletionResponse - For streaming responses
class StreamCompletionResponse:
	var id: String
	var object: String
	var created: int
	var model: String
	var choices: Array  # Array of StreamChoice

	func _init(data: Dictionary = {}):
		if data.is_empty():
			return

		id = data.get("id", "")
		object = data.get("object", "")
		created = data.get("created", 0)
		model = data.get("model", "")

		choices = []
		if data.has("choices"):
			for choice_data in data["choices"]:
				choices.append(StreamChoice.new(choice_data))

	class StreamChoice:
		var index: int
		var delta: Delta
		var finish_reason: String

		func _init(data: Dictionary = {}):
			if data.is_empty():
				return

			index = data.get("index", 0)
			finish_reason = data.get("finish_reason", "")

			if data.has("delta"):
				delta = Delta.new(data["delta"])

	class Delta:
		var role: String
		var content: String

		func _init(data: Dictionary = {}):
			if data.is_empty():
				return

			role = data.get("role", "")
			content = data.get("content", "")

## UIMessageStreamResponse - New UI Message Stream format
class UIMessageStreamResponse:
	var type: String  # "text-delta", "start", "finish", etc.
	var id: String
	var delta: String

	func _init(data: Dictionary = {}):
		if data.is_empty():
			return

		type = data.get("type", "")
		id = data.get("id", "")
		delta = data.get("delta", "")