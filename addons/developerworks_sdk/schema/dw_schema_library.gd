# DWSchemaLibrary - Resource-based schema library for structured output
# Contains a collection of JSON schemas for AI object generation
# This is the Godot equivalent of Unity's ScriptableObject-based schema library

@tool
extends Resource
class_name DWSchemaLibrary

## Array of schema entries
@export var schemas: Array[SchemaEntry] = []

## SchemaEntry - Individual schema definition
class SchemaEntry extends Resource:
	## Name of the schema
	@export var name: String = ""

	## Description of what this schema represents
	@export_multiline var description: String = ""

	## JSON schema definition (as string)
	@export_multiline var json_schema: String = ""

	## Validate that this schema entry has valid JSON
	func is_valid() -> bool:
		if name.is_empty():
			push_error("[SchemaEntry] Schema entry missing name")
			return false

		if json_schema.is_empty():
			push_error("[SchemaEntry] Schema '%s' missing JSON schema" % name)
			return false

		var json_test = JSON.new()
		var error = json_test.parse(json_schema)
		if error != OK:
			push_error("[SchemaEntry] Schema '%s' has invalid JSON: %s" % [name, json_test.get_error_message()])
			return false

		return true

	## Get the parsed JSON schema as Dictionary
	func get_parsed_schema() -> Dictionary:
		if not is_valid():
			return {}

		var json_parser = JSON.new()
		var error = json_parser.parse(json_schema)
		if error != OK:
			push_error("[SchemaEntry] Failed to parse schema '%s': %s" % [name, json_parser.get_error_message()])
			return {}

		var result = json_parser.get_data()
		if result is Dictionary:
			return result
		else:
			push_error("[SchemaEntry] Schema '%s' did not parse to a Dictionary" % name)
			return {}

## Get all schema entries
func get_all_schemas() -> Array[SchemaEntry]:
	return schemas

## Find a schema by name
## @param schema_name: Name of the schema to find
## @return: SchemaEntry or null if not found
func find_schema(schema_name: String) -> SchemaEntry:
	if schema_name.is_empty():
		return null

	for schema in schemas:
		if schema.name == schema_name:
			return schema

	return null

## Get the JSON schema string for a given schema name
## @param schema_name: Name of the schema
## @return: JSON schema string or empty string if not found
func get_schema_json(schema_name: String) -> String:
	var schema = find_schema(schema_name)
	if schema == null:
		return ""
	return schema.json_schema

## Get the parsed JSON schema as Dictionary
## @param schema_name: Name of the schema
## @return: Dictionary representing the schema or empty dict if not found/invalid
func get_parsed_schema(schema_name: String) -> Dictionary:
	var schema = find_schema(schema_name)
	if schema == null:
		return {}
	return schema.get_parsed_schema()

## Check if a schema exists and is valid
## @param schema_name: Name of the schema
## @return: True if schema exists and is valid
func has_valid_schema(schema_name: String) -> bool:
	var schema = find_schema(schema_name)
	if schema == null:
		return false
	return schema.is_valid()

## Get all valid schema names
## @return: Array of schema names that are valid
func get_valid_schema_names() -> Array:
	var valid_names: Array = []
	for schema in schemas:
		if schema.is_valid():
			valid_names.append(schema.name)
	return valid_names

## Add a new schema entry (runtime)
## @param schema_name: Schema name
## @param schema_description: Schema description
## @param schema_json: JSON schema string
func add_schema(schema_name: String, schema_description: String, schema_json: String) -> void:
	var new_entry = SchemaEntry.new()
	new_entry.name = schema_name
	new_entry.description = schema_description
	new_entry.json_schema = schema_json

	schemas.append(new_entry)

	if Engine.is_editor_hint():
		changed.emit()

## Remove a schema by name
## @param schema_name: Name of schema to remove
func remove_schema(schema_name: String) -> void:
	var index = -1
	for i in range(schemas.size()):
		if schemas[i].name == schema_name:
			index = i
			break

	if index >= 0:
		schemas.remove_at(index)
		if Engine.is_editor_hint():
			changed.emit()

## Validate all schemas (for editor use)
func validate_all() -> void:
	if not Engine.is_editor_hint():
		return

	for schema in schemas:
		if not schema.json_schema.is_empty():
			schema.is_valid()  # This will log errors if invalid