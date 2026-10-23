class_name DeliverDocumentCommand
extends Command
## A system or the scenario hands the player a document: adds it to the end of the Archive,
## unread, at the clock's tick, and posts document_received(document id). Not a player
## command; the document's id is a DocumentDef id, checked by whoever submits it.
## Bible: gate-and-address-spec.md#where-addresses-come-from,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"deliver_document"

## Id of the DocumentDef to deliver.
var document_id: StringName = &""


## Returns a command that delivers document [param id].
static func create(id: StringName) -> DeliverDocumentCommand:
	var command := DeliverDocumentCommand.new()
	command.document_id = id
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "document_id" is not a string.
static func from_dict(data: Dictionary) -> Result:
	var id_data: Variant = data.get("document_id")
	if not (id_data is String or id_data is StringName):
		return Result.fail(&"malformed_command", "%s needs a string document_id" % TYPE)
	return Result.ok(create(StringName(str(id_data))))


## Returns &"deliver_document".
func get_type() -> StringName:
	return TYPE


## Rejects an empty id (&"empty_document_id") and a document already in the Archive
## (&"already_received").
func validate(state: GameState) -> CommandResult:
	if document_id.is_empty():
		return CommandResult.fail(&"empty_document_id")
	if state.archive.has_document(document_id):
		return CommandResult.fail(&"already_received", String(document_id))
	return CommandResult.ok()


## Adds the document at the clock's tick and posts document_received.
func apply(state: GameState) -> void:
	deliver(state, document_id)


## Adds document [param id] to the Archive at the clock's tick and posts document_received.
## The one delivery path: a system calls it too, so both stay consistent. The caller checks
## the Archive does not hold the document yet.
static func deliver(state: GameState, id: StringName) -> void:
	state.archive.add(id, state.clock.tick)
	state.events.post(&"document_received", [id])


## Returns JSON-safe data: type and document_id.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "document_id": String(document_id)}
