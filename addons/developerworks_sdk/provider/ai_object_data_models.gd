# AI Object Data Models - Data structures for AI structured object generation
# These mirror the Unity SDK's AI_ObjectDataModels.cs

class_name AIObjectDataModels

## ObjectGenerationRequest - Request for structured object generation
class ObjectGenerationRequest:
	var model: String  # AI model to use
	var schema: Dictionary  # JSON schema (as Dictionary)
	var prompt: String = ""  # Optional: single prompt
	var messages: Array = []  # Optional: conversation history (Array of DWDefinitions.ChatMessage)
	var temperature: float = 0.7  # Temperature (0.0 to 2.0)
	var output: String = "object"  # Always "object"
	var schema_name: String = ""  # Optional: schema name for logging
	var schema_description: String = ""  # Optional: schema description
	var max_tokens: int = -1  # Optional: maximum tokens (-1 means not set)
	var system_message: String = ""  # Optional: system message

	func _init():
		pass

	## Convert to dictionary for JSON serialization
	func to_dict() -> Dictionary:
		var result = {
			"model": model,
			"schema": schema,
			"output": output,
			"temperature": temperature
		}

		# Add prompt or messages (mutually exclusive)
		if not prompt.is_empty():
			result["prompt"] = prompt
		elif messages.size() > 0:
			var msg_array = []
			for msg in messages:
				if msg is DWDefinitions.ChatMessage:
					msg_array.append(msg.to_dict())
			result["messages"] = msg_array

		# Add optional fields
		if not schema_name.is_empty():
			result["schemaName"] = schema_name

		if not schema_description.is_empty():
			result["schemaDescription"] = schema_description

		if max_tokens > 0:
			result["maxTokens"] = max_tokens

		if not system_message.is_empty():
			result["system"] = system_message

		return result

## ObjectGenerationResponse - Response from structured object generation
class ObjectGenerationResponse:
	var object_data: Dictionary = {}  # The generated object
	var finish_reason: String = ""  # Reason for completion
	var usage: ObjectUsage = null  # Token usage information
	var model: String = ""  # Model used
	var id: String = ""  # Response ID
	var timestamp: String = ""  # Timestamp

	func _init(data: Dictionary = {}):
		if data.is_empty():
			return

		if data.has("object"):
			if data["object"] is Dictionary:
				object_data = data["object"]
			else:
				# Try to convert to dictionary if it's not already
				push_warning("[ObjectGenerationResponse] object field is not a Dictionary")
				object_data = {}

		finish_reason = data.get("finishReason", "")
		model = data.get("model", "")
		id = data.get("id", "")
		timestamp = data.get("timestamp", "")

		if data.has("usage"):
			usage = ObjectUsage.new(data["usage"])

## ObjectUsage - Token usage information
class ObjectUsage:
	var input_tokens: int = 0
	var output_tokens: int = 0
	var total_tokens: int = 0
	var cost: float = 0.0  # Cost in dollars

	func _init(data: Dictionary = {}):
		if data.is_empty():
			return

		input_tokens = data.get("inputTokens", 0)
		output_tokens = data.get("outputTokens", 0)
		total_tokens = data.get("totalTokens", 0)
		cost = data.get("cost", 0.0)

	## Get cost in cents
	func get_cost_in_cents() -> float:
		return cost * 100.0