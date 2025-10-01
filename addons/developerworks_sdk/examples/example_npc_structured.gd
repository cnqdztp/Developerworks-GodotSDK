# Example: NPC Client with Structured Output
# Demonstrates structured output integration with conversation history

extends Node

var npc_client: Node
var schema_library: DWSchemaLibrary

func _ready():
	print("\n" + "=".repeat(80))
	print("NPC CLIENT STRUCTURED OUTPUT EXAMPLE")
	print("=".repeat(80))

	# Initialize SDK
	print("\n[1] Initializing SDK...")
	var success = await DW_SDK.initialize_async("game-id")

	if not success:
		push_error("Failed to initialize SDK")
		return

	print("SDK initialized successfully!")

	# Load schema library
	print("\n[2] Loading schema library...")
	schema_library = load("res://addons/developerworks_sdk/examples/example_schemas.tres")

	if schema_library == null:
		push_error("Failed to load schema library")
		return

	print("Schema library loaded!")
	print("Available schemas: ", schema_library.get_valid_schema_names())

	# Create NPC with structured output support
	print("\n[3] Creating NPC client with structured output support...")
	npc_client = DW_SDK.Factory.create_npc_client(
		"You are a quest giver named Theron in an RPG game. You give quests to adventurers. You are wise and mysterious.",
		"",  # Default model
		schema_library
	)

	# Wait for NPC to be ready
	while not npc_client.is_ready():
		await get_tree().process_frame

	print("NPC client ready!")

	# Run examples
	await example_structured_quest()
	await example_mixed_conversation()
	await example_structured_with_history()

	print("\n" + "=".repeat(80))
	print("EXAMPLE COMPLETED")
	print("=".repeat(80))

## Example 1: Structured Quest Generation
func example_structured_quest():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 1: Structured Quest Generation")
	print("-".repeat(80))

	# Note: This uses a character_info schema as a placeholder
	# In a real game, you'd have a quest_info schema
	print("\nUser: I need a quest to complete")

	# Use structured output (assuming character_info schema exists)
	var result = await npc_client.talk_structured(
		"I need a quest to complete. Give me a quest with details.",
		"character_info"  # Using character_info as example
	)

	if result.success:
		print("\n[NPC Response]")
		print("Theron: ", result.response_text)

		print("\n[Structured Data]")
		print(JSON.stringify(result.object_data, "\t"))

		print("\n[Info] Conversation history length: %d" % npc_client.get_history_length())
	else:
		push_error("Failed to get structured response: %s" % result.error)

## Example 2: Mixed Conversation (Structured + Regular)
func example_mixed_conversation():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 2: Mixed Conversation (Structured + Regular)")
	print("-".repeat(80))

	# Regular conversation
	print("\nUser: That sounds difficult!")
	var response = await npc_client.talk("That sounds difficult!")
	print("Theron: ", response)

	# Another regular message
	print("\nUser: What rewards will I get?")
	response = await npc_client.talk("What rewards will I get?")
	print("Theron: ", response)

	# Back to structured
	print("\nUser: Tell me about yourself")
	var result = await npc_client.talk_structured(
		"Tell me about yourself",
		"character_info"
	)

	if result.success:
		print("\n[NPC Response]")
		print("Theron: ", result.response_text)

		print("\n[Character Data]")
		print(JSON.stringify(result.object_data, "\t"))
	else:
		push_error("Failed to get structured response: %s" % result.error)

	# Show conversation history
	print("\n[Conversation History]")
	npc_client.print_pretty_chat_messages()

## Example 3: Structured Output with Full History Context
func example_structured_with_history():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 3: Structured Output with Full History")
	print("-".repeat(80))

	print("\n[Info] Using talk_structured_with_history() for better context...")
	print("User: Based on our conversation, what would you recommend?")

	var result = await npc_client.talk_structured_with_history(
		"Based on our conversation, what would you recommend?",
		"character_info"
	)

	if result.success:
		print("\n[NPC Response]")
		print("Theron: ", result.response_text)

		print("\n[Structured Data]")
		print(JSON.stringify(result.object_data, "\t"))
	else:
		push_error("Failed to get structured response: %s" % result.error)

	# Final conversation history
	print("\n[Final Conversation History]")
	npc_client.print_pretty_chat_messages()

## Example 4: Direct Schema (without library)
func example_direct_schema():
	print("\n" + "-".repeat(80))
	print("EXAMPLE 4: Direct Schema (without library)")
	print("-".repeat(80))

	# Define schema directly
	var quest_schema = {
		"type": "object",
		"properties": {
			"quest_name": {
				"type": "string",
				"description": "Name of the quest"
			},
			"difficulty": {
				"type": "string",
				"enum": ["Easy", "Medium", "Hard", "Epic"],
				"description": "Quest difficulty level"
			},
			"talk": {
				"type": "string",
				"description": "What the NPC says when giving this quest"
			},
			"objective": {
				"type": "string",
				"description": "Main objective of the quest"
			},
			"reward_gold": {
				"type": "integer",
				"description": "Gold reward for completing the quest"
			}
		},
		"required": ["quest_name", "difficulty", "talk", "objective", "reward_gold"]
	}

	var schema_json = JSON.stringify(quest_schema)

	print("\nUser: Give me an epic quest!")
	var result = await npc_client.talk_structured_direct(
		"Give me an epic quest!",
		schema_json
	)

	if result.success:
		print("\n[NPC Response]")
		print("Theron: ", result.response_text)

		print("\n[Quest Data]")
		print(JSON.stringify(result.object_data, "\t"))
	else:
		push_error("Failed to get structured response: %s" % result.error)