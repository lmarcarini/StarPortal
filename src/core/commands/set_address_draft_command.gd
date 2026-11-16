class_name SetAddressDraftCommand
extends Command
## The alien panel's address being composed: the firm glyph and the pencilled guess of each
## of the seven seals (-1 for none), kept in the Address Book state so it survives a save.
## Posts nothing (the panel already shows it).
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## The command's stable type id.
const TYPE: StringName = &"set_address_draft"

## Firm glyph per seal.
var firm: Array[int] = [-1, -1, -1, -1, -1, -1, -1]
## Pencilled guess per seal.
var pencil: Array[int] = [-1, -1, -1, -1, -1, -1, -1]


## Returns a command that sets the draft to [param firm_glyphs] and [param pencil_glyphs].
static func create(firm_glyphs: Array[int], pencil_glyphs: Array[int]) -> SetAddressDraftCommand:
	var command := SetAddressDraftCommand.new()
	command.firm = firm_glyphs.duplicate()
	command.pencil = pencil_glyphs.duplicate()
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "firm" or "pencil" is not a draft row (AddressBookState.is_draft_row).
static func from_dict(data: Dictionary) -> Result:
	var rows: Array = [data.get("firm"), data.get("pencil")]
	if not AddressBookState.is_draft_row(rows[0]) or not AddressBookState.is_draft_row(rows[1]):
		return Result.fail(&"malformed_command", "%s needs two rows of 7 glyphs" % TYPE)
	var to_int: Callable = func(value: Variant) -> int: return type_convert(value, TYPE_INT)
	var firm_rows: Array = rows[0]
	var pencil_rows: Array = rows[1]
	var firm_glyphs: Array[int] = []
	firm_glyphs.assign(firm_rows.map(to_int))
	var pencil_glyphs: Array[int] = []
	pencil_glyphs.assign(pencil_rows.map(to_int))
	return Result.ok(create(firm_glyphs, pencil_glyphs))


## Returns &"set_address_draft".
func get_type() -> StringName:
	return TYPE


## Rejects rows that are not 7 glyphs from -1 to 35 (&"bad_draft").
func validate(_state: GameState) -> CommandResult:
	if not AddressBookState.is_draft_row(firm) or not AddressBookState.is_draft_row(pencil):
		return CommandResult.fail(&"bad_draft")
	return CommandResult.ok()


## Stores the draft.
func apply(state: GameState) -> void:
	state.address_book.draft_firm = firm.duplicate()
	state.address_book.draft_pencil = pencil.duplicate()


## Returns JSON-safe data: type, firm and pencil.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "firm": firm.duplicate(), "pencil": pencil.duplicate()}
