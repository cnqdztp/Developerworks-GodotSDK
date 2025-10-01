# Example: Structured Output (AI Object Generation)
# This example demonstrates how to use the structured output feature
# to generate JSON objects based on predefined schemas

extends Node

## IMPORTANT: Set these in the inspector or replace with your actual credentials
@export var game_id: String = "YOUR_GAME_ID"
@export var developer_token: String = ""  # Optional: for testing

## Load the schema library resource
@export var schema_library: DWSchemaLibrary

func _ready():
	print("\n=== Structured Output Example ===\n")

	# If no schema library is assigned, try to load the example one
	if schema_library == null:
		schema_library = load("res://addons/developerworks_sdk/examples/example_schemas.tres")
		if schema_library == null:
			push_error("Failed to load schema library!")
			return

	# Start the example
	await run_example()

func run_example():
	print("[Example] Initializing SDK...")

	# Initialize SDK
	var success = await DW_SDK.initialize_async(game_id, developer_token)

	if not success:
		push_error("[Example] SDK initialization failed!")
		return

	print("[Example] SDK initialized successfully!\n")

	# Example 1: Simple response with schema library
	await example_simple_response()

	await get_tree().create_timer(2.0).timeout

	# Example 2: Character generation with schema library
	await example_character_generation()

	await get_tree().create_timer(2.0).timeout

	# Example 3: Direct schema JSON (no library needed)
	await example_direct_schema()

	await get_tree().create_timer(2.0).timeout

	# Example 4: Structured output with conversation history
	await example_with_history()

	print("\n=== All examples completed! ===\n")

## Example 1: Simple response with confidence
func example_simple_response():
	print("\n--- Example 1: Simple Response ---")

	# Create chat client with schemas
	var chat_client = DW_SDK.Factory.create_chat_client_with_schemas("gpt-4.1-mini", schema_library)

	# Check available schemas
	var available = chat_client.get_available_schemas()
	print("[Example] Available schemas: ", available)

	# Generate structured output
	var result = await chat_client.generate_structured_async(
		"simple_response",
		"What is the capital of France?"
	)

	if result.success:
		print("[Example] Success! Generated object:")
		print("  Answer: ", result.object_data.get("answer", "N/A"))
		print("  Confidence: ", result.object_data.get("confidence", 0.0))
	else:
		push_error("[Example] Failed: ", result.error)

## Example 2: Character generation
func example_character_generation():
	print("\n--- Example 2: Character Generation ---")

	# Create chat client with schemas
	var chat_client = DW_SDK.Factory.create_chat_client_with_schemas("gpt-4.1-mini", schema_library)

	# Generate a character
	var result = await chat_client.generate_structured_async(
		"character_info",
		"Create a fierce warrior character for a fantasy RPG game. Make them level 45."
	)

	if result.success:
		print("[Example] Success! Generated character:")
		print("  Name: ", result.object_data.get("name", "N/A"))
		print("  Class: ", result.object_data.get("class", "N/A"))
		print("  Level: ", result.object_data.get("level", 0))

		if result.object_data.has("stats"):
			var stats = result.object_data["stats"]
			print("  Stats:")
			print("    Strength: ", stats.get("strength", 0))
			print("    Intelligence: ", stats.get("intelligence", 0))
			print("    Agility: ", stats.get("agility", 0))

		if result.object_data.has("backstory"):
			print("  Backstory: ", result.object_data["backstory"])
	else:
		push_error("[Example] Failed: ", result.error)

## Example 3: Direct schema JSON (no library)
func example_direct_schema():
	print("\n--- Example 3: Direct Schema JSON ---")

	# Create regular chat client (no schema library needed)
	var chat_client = DW_SDK.Factory.create_chat_client("gpt-4.1-mini")

	# Define schema inline
	var schema_json = """{
		"type": "object",
		"properties": {
			"item_name": {
				"type": "string",
				"description": "Name of the item"
			},
			"rarity": {
				"type": "string",
				"enum": ["common", "uncommon", "rare", "epic", "legendary"],
				"description": "Item rarity"
			},
			"price": {
				"type": "integer",
				"description": "Price in gold coins"
			}
		},
		"required": ["item_name", "rarity", "price"]
	}"""

	var result = await chat_client.generate_structured_with_schema_async(
		schema_json,
		"Generate a magical sword item for a fantasy RPG"
	)

	if result.success:
		print("[Example] Success! Generated item:")
		print("  Name: ", result.object_data.get("item_name", "N/A"))
		print("  Rarity: ", result.object_data.get("rarity", "N/A"))
		print("  Price: ", result.object_data.get("price", 0), " gold")
	else:
		push_error("[Example] Failed: ", result.error)

## Example 4: Structured output with conversation history
func example_with_history():
	print("\n--- Example 4: With Conversation History ---")

	# Create chat client with schemas
	var chat_client = DW_SDK.Factory.create_chat_client_with_schemas("gpt-4.1-mini", schema_library)

	# Build conversation history
	var messages = [
		DWDefinitions.ChatMessage.new("system", "You are a game character creator expert."),
		DWDefinitions.ChatMessage.new("user", "I want to create a mage character"),
		DWDefinitions.ChatMessage.new("assistant", "Great! I can help you create a mage. What level should they be?"),
		DWDefinitions.ChatMessage.new("user", "Make them level 60 and give them high intelligence")
	]

	var result = await chat_client.generate_structured_with_history_async(
		"character_info",
		messages
	)

	if result.success:
		print("[Example] Success! Generated character from conversation:")
		print("  Name: ", result.object_data.get("name", "N/A"))
		print("  Class: ", result.object_data.get("class", "N/A"))
		print("  Level: ", result.object_data.get("level", 0))

		if result.object_data.has("stats"):
			var stats = result.object_data["stats"]
			print("  Stats:")
			print("    Strength: ", stats.get("strength", 0))
			print("    Intelligence: ", stats.get("intelligence", 0))
			print("    Agility: ", stats.get("agility", 0))
	else:
		push_error("[Example] Failed: ", result.error)