# Example: Basic Chat Usage
# This example demonstrates how to use the DW_SDK for basic chat functionality

extends Node

# Replace with your actual credentials
const GAME_ID = "game_xxxxx"
const DEVELOPER_TOKEN = "dev_token_xxxxx"

func _ready():
	# Initialize SDK
	var success = await DW_SDK.initialize_async(GAME_ID, DEVELOPER_TOKEN)

	if not success:
		print("Failed to initialize SDK")
		return

	print("SDK initialized successfully!")

	# Example 1: Simple chat
	await example_simple_chat()

	# Example 2: Multi-turn conversation
	await example_multi_turn_chat()

	# Example 3: Streaming chat
	await example_streaming_chat()

	print("\n=== All examples completed ===")

## Example 1: Simple chat
func example_simple_chat():
	print("\n=== Example 1: Simple Chat ===")

	var chat_client = DW_SDK.Factory.create_chat_client()

	var config = DWDefinitions.ChatConfig.new("你好,请介绍一下你自己")
	var result = await chat_client.text_generation_async(config)

	if result.success:
		print("AI: ", result.response)
	else:
		print("Error: ", result.error_message)

## Example 2: Multi-turn conversation
func example_multi_turn_chat():
	print("\n=== Example 2: Multi-turn Conversation ===")

	var chat_client = DW_SDK.Factory.create_chat_client()

	# Create conversation history
	var messages = [
		DWDefinitions.ChatMessage.new("system", "你是一个友好的助手"),
		DWDefinitions.ChatMessage.new("user", "我的名字叫小明"),
		DWDefinitions.ChatMessage.new("assistant", "你好小明!很高兴认识你!"),
		DWDefinitions.ChatMessage.new("user", "我叫什么名字?")
	]

	var config = DWDefinitions.ChatConfig.new("", messages)
	var result = await chat_client.text_generation_async(config)

	if result.success:
		print("AI: ", result.response)
	else:
		print("Error: ", result.error_message)

## Example 3: Streaming chat
func example_streaming_chat():
	print("\n=== Example 3: Streaming Chat ===")

	var chat_client = DW_SDK.Factory.create_chat_client()

	var config = DWDefinitions.ChatStreamConfig.new("讲一个简短的故事")

	print("AI (streaming): ")

	await chat_client.text_chat_stream_async(
		config,
		# On chunk callback
		func(chunk: String):
			# In real usage, you'd update UI labels instead of printing
			pass,
		# On complete callback
		func(full_response: String):
			print("Full response: ", full_response)
			print("Length: ", full_response.length(), " characters")
	)

## Example 4: Get player info
func example_player_info():
	print("\n=== Example 4: Player Info ===")

	var player_client = DW_SDK.get_player_client()

	if player_client == null:
		print("Player client not available")
		return

	var result = await player_client.get_player_info_async()

	if result.success:
		var info = result.data
		print("User ID: ", info.user_id)
		print("Credits: ", info.credits)
	else:
		print("Error: ", result.error)

