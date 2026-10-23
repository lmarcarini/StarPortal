class_name MarkDocumentReadCommand
extends Command
## The player has read a document in the Archive. Reading it again changes nothing.
## Bible: gate-and-address-spec.md#where-addresses-come-from,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"mark_document_read"

## Id of the document read.
var document_id: StringName = &""


## Returns a command that marks document [param id] read.
static func create(id: StringName) -> MarkDocumentReadCommand:
	var command := MarkDocumentReadCommand.new()
	command.document_id = id
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "document_id" is not a string.
static func from_dict(data: Dictionary) -> Result:
	var id_data: Variant = data.get("document_id")
	if not (id_data is String or id_data is StringName):
		return Result.fail(&"malformed_command", "%s needs a string document_id" % TYPE)
	return Result.ok(create(StringName(str(id_data))))


## Returns &"mark_document_read".
func get_type() -> StringName:
	return TYPE


## Rejects a document that is not in the Archive (&"unknown_document").
func validate(state: GameState) -> CommandResult:
	if not state.archive.has_document(document_id):
		return CommandResult.fail(&"unknown_document", String(document_id))
	return CommandResult.ok()


## Marks the document read.
func apply(state: GameState) -> void:
	state.archive.read[document_id] = true


## Returns JSON-safe data: type and document_id.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "document_id": String(document_id)}
