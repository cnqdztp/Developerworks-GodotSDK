@tool
extends EditorPlugin

func _enter_tree():
	print("[DeveloperWorks SDK] Plugin loaded")

func _exit_tree():
	print("[DeveloperWorks SDK] Plugin unloaded")