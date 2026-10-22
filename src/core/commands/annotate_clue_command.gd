class_name AnnotateClueCommand
extends Command
## Replaces the player's whole note on one clue of the Analysis Board: suspect mark, tags,
## links and board position. A note equal to the default is removed, so IntelState.notes
## keeps only clues that have one. Posts clue_note_changed(clue_id) once when applied.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"annotate_clue"

## The clue the note is about.
var clue_id: StringName
## The new note, replacing the old one.
var note: ClueNote

## Returns a command that sets the note on [param clue_id] to a copy of [param note].
@warning_ignore("shadowed_variable")
static func create(clue_id: StringName, note: ClueNote) -> AnnotateClueCommand:
	var command := AnnotateClueCommand.new()
	command.clue_id = clue_id
	command.note = ClueNote.from_dict(note.to_dict()) if note != null else null
	return command


## Rebuilds a command from its to_dict() [param data], e.g. after a JSON round trip. Fails
## with &"malformed_command" when "clue_id" is not a string or "note" is not an object
## passing ClueNote.validate_dict(). Whether the clue and the links exist is left for
## validate().
static func from_dict(data: Dictionary) -> Result:
	var id_data: Variant = data.get("clue_id")
	if not (id_data is String or id_data is StringName):
		return Result.fail(&"malformed_command", "annotate_clue needs a string clue_id")
	var note_data: Variant = data.get("note")
	if not note_data is Dictionary:
		return Result.fail(&"malformed_command", "annotate_clue needs a note object")
	var note_dict: Dictionary = note_data
	var errors := ClueNote.validate_dict(note_dict)
	if not errors.is_empty():
		return Result.fail(&"malformed_command", "note: " + "; ".join(errors))
	return Result.ok(create(StringName(str(id_data)), ClueNote.from_dict(note_dict)))


## Returns &"annotate_clue".
func get_type() -> StringName:
	return TYPE


## Rejects a clue id [param state] does not know (&"unknown_clue"), a missing note or one
## failing ClueNote.validate_dict(), such as too many or too long tags, repeated links or a
## position off the board (&"invalid_note"), and links to unknown clues or to the clue
## itself (&"invalid_link").
func validate(state: GameState) -> CommandResult:
	if state.intel.get_clue(clue_id) == null:
		return CommandResult.fail(&"unknown_clue", String(clue_id))
	if note == null:
		return CommandResult.fail(&"invalid_note", "no note")
	var errors := ClueNote.validate_dict(note.to_dict())
	if not errors.is_empty():
		return CommandResult.fail(&"invalid_note", "; ".join(errors))
	var known_ids := state.intel.known_clue_ids()
	var link_errors := IntelState.link_errors(String(clue_id), note.links, known_ids)
	if not link_errors.is_empty():
		return CommandResult.fail(&"invalid_link", "; ".join(link_errors))
	return CommandResult.ok()


## Stores a copy of the note in [param state] (or removes the note when it is the default)
## and posts clue_note_changed.
func apply(state: GameState) -> void:
	if note.is_default():
		state.intel.notes.erase(clue_id)
	else:
		state.intel.notes[clue_id] = ClueNote.from_dict(note.to_dict())
	state.events.post(&"clue_note_changed", [clue_id])


## Returns JSON-safe data: type, clue id and the note.
func to_dict() -> Dictionary:
	var note_data: Dictionary = note.to_dict() if note != null else {}
	return {"type": String(TYPE), "clue_id": String(clue_id), "note": note_data}
