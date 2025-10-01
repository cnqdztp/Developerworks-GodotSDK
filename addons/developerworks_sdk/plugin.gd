@tool
extends EditorPlugin

func _enter_tree():
	print("[DeveloperWorks SDK] Plugin loaded")
	# Add menu item to Project -> Tools
	add_tool_menu_item("Clear DeveloperWorks Credentials", _clear_credentials)

func _exit_tree():
	print("[DeveloperWorks SDK] Plugin unloaded")
	# Remove menu item
	remove_tool_menu_item("Clear DeveloperWorks Credentials")

## Clear all stored credentials (player token and shared token)
func _clear_credentials():
	print("[DeveloperWorks SDK] Clearing local credentials...")

	# Load shared token script
	var DWLocalSharedToken = load("res://addons/developerworks_sdk/auth/dw_local_shared_token.gd")

	# Clear player token from local config
	var config = ConfigFile.new()
	if config.load("user://dw_sdk_config.cfg") == OK:
		config.erase_section_key("auth", "DW_SDK_PlayerToken")
		config.erase_section_key("auth", "DW_SDK_TokenExpiry")
		config.save("user://dw_sdk_config.cfg")
		print("[DeveloperWorks SDK] Player token cleared from local storage")

	# Clear shared token
	DWLocalSharedToken.erase_token()
	print("[DeveloperWorks SDK] Shared token cleared")

	# Show confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "DeveloperWorks credentials have been cleared.\nYou will need to log in again next time."
	dialog.title = "Credentials Cleared"
	dialog.ok_button_text = "OK"

	# Add to editor interface and show
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()

	# Clean up dialog after closing
	dialog.confirmed.connect(func():
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
