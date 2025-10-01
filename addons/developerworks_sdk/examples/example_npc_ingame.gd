# Example: NPC Client In-Game Integration
# Demonstrates how to attach NPC client to game objects for in-game NPCs
# This example works for both 2D and 3D games

extends CharacterBody2D
# For 3D games, use: extends CharacterBody3D

## NPC Configuration
@export var npc_name: String = "Merchant"
@export_multiline var character_prompt: String = "You are a merchant named Marcus in a medieval fantasy town. You sell weapons and armor. You are gruff but fair."
@export var npc_model: String = ""  # Empty = use default

## Interaction Settings
@export var interaction_key: String = "ui_accept"  # Default to Space/Enter
@export var interaction_range: float = 100.0

## Visual Feedback
@export var show_interaction_prompt: bool = true
@export var interaction_prompt_text: String = "[E] Talk"

## Internal State
var npc_client: Node
var is_player_nearby: bool = false
var dialogue_ui: Control = null  # Reference to your dialogue UI

func _ready():
	print("[NPC %s] Initializing..." % npc_name)

	# Wait for SDK
	while not DW_SDK.is_ready():
		await get_tree().process_frame

	print("[NPC %s] SDK ready, creating NPC client..." % npc_name)

	# Attach NPC client as child of this game object
	npc_client = DW_SDK.Factory.create_npc_client_for_node(
		self,
		character_prompt,
		npc_model
	)

	# Wait for NPC client to be ready
	while not npc_client.is_ready():
		await get_tree().process_frame

	# Connect signals
	npc_client.talking_started.connect(_on_talking_started)
	npc_client.talking_finished.connect(_on_talking_finished)
	npc_client.chunk_received.connect(_on_chunk_received)

	print("[NPC %s] NPC client ready!" % npc_name)

	# Setup interaction area (if not already in scene)
	_setup_interaction_area()

func _process(_delta):
	# Show interaction prompt when player nearby
	if show_interaction_prompt and is_player_nearby:
		_show_interaction_prompt()

func _input(event):
	# Handle interaction input
	if event.is_action_pressed(interaction_key) and is_player_nearby:
		if not npc_client.is_talking():
			_start_interaction()

## ==========================================================================
## INTERACTION SYSTEM
## ==========================================================================

func _start_interaction():
	print("[NPC %s] Starting interaction" % npc_name)

	# Get player input (from dialogue UI or predefined)
	var player_message = await _get_player_input()

	if player_message.is_empty():
		return

	# Send message to NPC with streaming for better UX
	await _talk_to_npc_streaming(player_message)

func _talk_to_npc_streaming(message: String):
	print("[NPC %s] Player: %s" % [npc_name, message])

	# Show dialogue UI
	_show_dialogue_ui()

	# Stream response for better UX
	var on_chunk = func(chunk: String):
		_update_dialogue_ui_chunk(chunk)

	var on_complete = func(response: String):
		_finalize_dialogue_ui(response)
		print("[NPC %s] Response complete" % npc_name)

	await npc_client.talk_stream(message, on_chunk, on_complete)

func _talk_to_npc_basic(message: String):
	print("[NPC %s] Player: %s" % [npc_name, message])

	# Show dialogue UI with "thinking" indicator
	_show_dialogue_ui()

	# Get response
	var response = await npc_client.talk(message)

	if response != "":
		print("[NPC %s] NPC: %s" % [npc_name, response])
		_update_dialogue_ui_full(response)
	else:
		push_error("[NPC %s] Failed to get response" % npc_name)
		_hide_dialogue_ui()

## ==========================================================================
## PLAYER INPUT
## ==========================================================================

## Get player input (customize this for your game)
## This is a placeholder - in a real game, you'd show a text input UI
func _get_player_input() -> String:
	# Example: Return predefined messages for demo
	# In real game, you'd show a dialogue UI with text input
	var demo_messages = [
		"Hello! What do you sell?",
		"How much for a sword?",
		"Tell me about yourself",
		"Do you have any armor?",
		"Thanks, goodbye!"
	]

	# For demo, cycle through messages
	var history_length = npc_client.get_history_length()
	var message_index = (history_length / 2) % demo_messages.size()

	await get_tree().create_timer(0.1).timeout  # Small delay for realism

	return demo_messages[message_index]

## ==========================================================================
## DIALOGUE UI MANAGEMENT
## ==========================================================================

## Show dialogue UI (customize for your game)
func _show_dialogue_ui():
	print("[UI] Showing dialogue UI")
	# In real game: show your dialogue UI panel
	# dialogue_ui.visible = true
	# dialogue_ui.show_npc_name(npc_name)

## Hide dialogue UI
func _hide_dialogue_ui():
	print("[UI] Hiding dialogue UI")
	# In real game: hide your dialogue UI panel
	# dialogue_ui.visible = false

## Update dialogue UI with streaming chunk
func _update_dialogue_ui_chunk(chunk: String):
	# In real game: append chunk to dialogue text
	# dialogue_ui.append_text(chunk)
	pass

## Update dialogue UI with full response
func _update_dialogue_ui_full(response: String):
	print("[UI] Updating dialogue UI: %s" % response)
	# In real game: set full dialogue text
	# dialogue_ui.set_dialogue_text(response)

## Finalize dialogue UI after streaming complete
func _finalize_dialogue_ui(response: String):
	print("[UI] Dialogue complete: %s" % response)
	# In real game: enable continue button, etc.
	# dialogue_ui.enable_continue_button()

## Show interaction prompt above NPC
func _show_interaction_prompt():
	# In real game: show floating text above NPC
	# For example, using Label3D or Sprite2D
	pass

## ==========================================================================
## SIGNAL HANDLERS
## ==========================================================================

func _on_talking_started():
	print("[NPC %s] Started talking (thinking...)" % npc_name)
	# Show "thinking" indicator in UI
	# dialogue_ui.show_thinking_indicator()

func _on_talking_finished(response: String):
	print("[NPC %s] Finished talking" % npc_name)
	# Hide "thinking" indicator
	# dialogue_ui.hide_thinking_indicator()

func _on_chunk_received(chunk: String):
	# Each chunk of streaming response
	pass

## ==========================================================================
## INTERACTION AREA SETUP
## ==========================================================================

func _setup_interaction_area():
	# Create interaction area if not already in scene
	# This is an example - adjust for your game

	var area = Area2D.new()
	area.name = "InteractionArea"
	add_child(area)

	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = interaction_range
	collision.shape = shape
	area.add_child(collision)

	# Connect signals
	area.body_entered.connect(_on_player_entered_area)
	area.body_exited.connect(_on_player_exited_area)

	print("[NPC %s] Interaction area setup complete" % npc_name)

func _on_player_entered_area(body):
	# Check if it's the player (adjust tag/group check for your game)
	if body.is_in_group("player"):
		is_player_nearby = true
		print("[NPC %s] Player entered interaction range" % npc_name)

func _on_player_exited_area(body):
	# Check if it's the player
	if body.is_in_group("player"):
		is_player_nearby = false
		print("[NPC %s] Player left interaction range" % npc_name)
		_hide_dialogue_ui()

## ==========================================================================
## UTILITY FUNCTIONS
## ==========================================================================

## Get current conversation history length (for debugging)
func get_conversation_length() -> int:
	if npc_client != null:
		return npc_client.get_history_length()
	return 0

## Save conversation (for persistence)
func save_conversation():
	if npc_client != null:
		var save_path = "user://npc_%s_conversation.json" % npc_name.to_lower()
		return npc_client.save_history(save_path)
	return false

## Load conversation (for persistence)
func load_conversation():
	if npc_client != null:
		var save_path = "user://npc_%s_conversation.json" % npc_name.to_lower()
		return npc_client.load_history(save_path)
	return false

## Reset NPC conversation
func reset_conversation():
	if npc_client != null:
		npc_client.clear_history()
		print("[NPC %s] Conversation reset" % npc_name)

## Print conversation history (debugging)
func print_conversation_history():
	if npc_client != null:
		npc_client.print_pretty_chat_messages("NPC %s Conversation" % npc_name)