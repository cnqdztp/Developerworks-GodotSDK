# Example: Basic NPC Client Usage
# Demonstrates basic conversation, streaming, and save/load features

extends Node

var npc_client: Node

func _ready():
	print("\n" + "=".repeat(80))
	print("NPC CLIENT BASIC EXAMPLE")
	print("=".repeat(80))

	# Initialize SDK
	print("\n[1] Initializing SDK...")
	var success = await DW_SDK.initialize_async("game-id")

	if not success:
		push_error("Failed to initialize SDK")
		return

	print("SDK initialized successfully!")

	# Create NPC with character design
	print("\n[2] Creating NPC client...")
	npc_client = DW_SDK.Factory.create_npc_client(
		"You are a friendly shopkeeper named Elara in a fantasy village. You sell potions and magical items. You are cheerful and helpful."
	)

	# Wait for NPC to be ready
	while not npc_client.is_ready():
		await get_tree().process_frame

	print("NPC client ready!")

	# Run examples
	await example_basic_conversation()
	await example_streaming_conversation()
	await example_save_load()
	await example_history_management()

	print("\n" + "=".repeat(80))
	print("EXAMPLE COMPLETED")
	print("=".repeat(80))

## Example 1: Basic Conversation (non-streaming)
func example_basic_conversation():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 1: Basic Conversation")
	print("-".repeat(80))

	# First message
	print("\nUser: Hello! What do you sell?")
	var response = await npc_client.talk("Hello! What do you sell?")
	print("Elara: ", response)

	# Second message
	print("\nUser: Do you have any healing potions?")
	response = await npc_client.talk("Do you have any healing potions?")
	print("Elara: ", response)

	# Third message
	print("\nUser: How much for a basic healing potion?")
	response = await npc_client.talk("How much for a basic healing potion?")
	print("Elara: ", response)

	# View history
	print("\n[Info] Conversation history has %d messages" % npc_client.get_history_length())

## Example 2: Streaming Conversation
func example_streaming_conversation():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 2: Streaming Conversation")
	print("-".repeat(80))

	print("\nUser: Tell me a story about your shop")
	print("Elara: ")

	var full_response = ""

	# Define chunk callback
	var on_chunk = func(chunk: String):
		full_response += chunk
		# Note: Godot's print() always adds newline, so streaming display is limited
		# In a real game, use RichTextLabel or similar for proper streaming text

	# Define complete callback
	var on_complete = func(response: String):
		print(full_response)
		print("\n[Complete]")

	# Send streaming request
	await npc_client.talk_stream(
		"Tell me a story about your shop",
		on_chunk,
		on_complete
	)

## Example 3: Save and Load
func example_save_load():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 3: Save and Load")
	print("-".repeat(80))

	# Save conversation
	print("\n[Saving] Saving conversation to file...")
	var saved = npc_client.save_history("user://npc_conversation_example.json")
	print("[Result] Saved: %s" % saved)

	# Show current history length
	var original_length = npc_client.get_history_length()
	print("[Info] Current history length: %d" % original_length)

	# Clear and reload
	print("\n[Clearing] Clearing history...")
	npc_client.clear_history()
	print("[Info] History length after clear: %d" % npc_client.get_history_length())

	# Load from file
	print("\n[Loading] Loading conversation from file...")
	var loaded = npc_client.load_history("user://npc_conversation_example.json")
	print("[Result] Loaded: %s" % loaded)
	print("[Info] History length after load: %d" % npc_client.get_history_length())

	# Verify conversation continues naturally
	print("\n[Testing] Verifying conversation continuity...")
	print("User: Thanks for the help!")
	var response = await npc_client.talk("Thanks for the help!")
	print("Elara: ", response)

## Example 4: History Management
func example_history_management():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 4: History Management")
	print("-".repeat(80))

	# Show current history
	print("\n[Current History]")
	npc_client.print_pretty_chat_messages()

	# Revert last exchange
	print("\n[Reverting] Reverting last exchange...")
	var reverted = npc_client.revert_history(1)
	print("[Result] Reverted: %s" % reverted)
	print("[Info] History length: %d" % npc_client.get_history_length())

	# Revert 2 more exchanges
	print("\n[Reverting] Reverting 2 more exchanges...")
	reverted = npc_client.revert_history(2)
	print("[Result] Reverted: %s" % reverted)
	print("[Info] History length: %d" % npc_client.get_history_length())

	# Show updated history
	print("\n[Updated History]")
	npc_client.print_pretty_chat_messages()

	# Test conversation after revert
	print("\n[Testing] Testing conversation after revert...")
	print("User: What's your favorite potion?")
	var response = await npc_client.talk("What's your favorite potion?")
	print("Elara: ", response)