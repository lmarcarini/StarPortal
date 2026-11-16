class_name AddressBookState
extends RefCounted
## The Address Book: every address the player has found or dialed, one entry per address,
## newest first. A dial updates its entry in place; a new address goes to the top.
## Also the address being composed on the alien panel: its firm glyphs and pencilled guesses,
## one per seal 1 to 7 (-1 for none).
## Saved shape: {"entries": [AddressEntry], "draft": {"firm": [7 ints], "pencil": [7 ints]}}.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## gate-and-address-spec.md#where-addresses-come-from, technical-architecture.md#data-model

## Seals in a draft (the seven coordinates).
const DRAFT_SEALS: int = 7

## Every entry, unique by address_key, newest first.
var entries: Array[AddressEntry] = []
## The alien panel's firm glyph per seal (-1 for none).
var draft_firm: Array[int] = [-1, -1, -1, -1, -1, -1, -1]
## The alien panel's pencilled guess per seal (-1 for none).
var draft_pencil: Array[int] = [-1, -1, -1, -1, -1, -1, -1]


## Returns the entry for [param address_key], or null when the book has none.
func find(address_key: String) -> AddressEntry:
	for entry: AddressEntry in entries:
		if entry.address_key == address_key:
			return entry
	return null


## Returns the entries whose address contains every glyph of [param glyphs] (in any seal, in
## any order), in book order. Every entry matches an empty [param glyphs].
func search_by_glyphs(glyphs: Array[int]) -> Array[AddressEntry]:
	var found: Array[AddressEntry] = []
	for entry: AddressEntry in entries:
		var seals: Array[int] = AddressEntry.glyphs_of(entry.address_key)
		if glyphs.all(func(glyph: int) -> bool: return seals.has(glyph)):
			found.append(entry)
	return found


## Records the resolved dial [param log_entry]: adds a DIALED entry at the top when its address
## is new, then sets the outcome and tick. The world id is recorded only on a lock, so a failed
## dial never tells which world it hit. Returns the entry.
func record_dial(log_entry: DialLogEntry) -> AddressEntry:
	var key: String = log_entry.address.key()
	var entry: AddressEntry = find(key)
	if entry == null:
		entry = AddressEntry.create(key, AddressEntry.Source.DIALED, &"")
		entries.push_front(entry)
	entry.last_outcome = log_entry.outcome
	entry.last_dialed_tick = log_entry.tick
	if DialOutcome.is_lock(log_entry.outcome):
		entry.world_id = log_entry.world_id
	return entry


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var entry_data: Array[Dictionary] = []
	for entry: AddressEntry in entries:
		entry_data.append(entry.to_dict())
	return {
		"entries": entry_data,
		"draft": {"firm": draft_firm.duplicate(), "pencil": draft_pencil.duplicate()}
	}


## Builds a book from saved [param data]; items that are not objects are skipped. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> AddressBookState:
	var book := AddressBookState.new()
	var draft: Variant = data.get("draft")
	if draft is Dictionary:
		var draft_dict: Dictionary = draft
		book.draft_firm.assign(_seals_of(draft_dict.get("firm")))
		book.draft_pencil.assign(_seals_of(draft_dict.get("pencil")))
	var entry_data: Variant = data.get("entries")
	if not entry_data is Array:
		return book
	var list: Array = entry_data
	for item: Variant in list:
		if item is Dictionary:
			var item_dict: Dictionary = item
			book.entries.append(AddressEntry.from_dict(item_dict))
	return book


## True when [param glyphs] is a draft row: DRAFT_SEALS whole numbers from -1 to the last
## glyph.
static func is_draft_row(glyphs: Variant) -> bool:
	if not glyphs is Array:
		return false
	var list: Array = glyphs
	if list.size() != DRAFT_SEALS:
		return false
	for value: Variant in list:
		if not JsonLimits.is_exact_int(value) or value < -1 or value >= GateAddress.GLYPH_COUNT:
			return false
	return true


static func _seals_of(glyphs: Variant) -> Array[int]:
	var out: Array[int] = [-1, -1, -1, -1, -1, -1, -1]
	if is_draft_row(glyphs):
		var list: Array = glyphs
		for index: int in DRAFT_SEALS:
			out[index] = type_convert(list[index], TYPE_INT)
	return out


## Returns human-readable errors for saved [param data], empty when it is valid: "entries" an
## array of objects that pass AddressEntry.validate_dict(), no two with the same
## "address_key"; "draft" an object whose "firm" and "pencil" pass is_draft_row().
static func validate_dict(data: Dictionary) -> Array[String]:
	if not data.has("entries"):
		return ["missing 'entries'"]
	if not data["entries"] is Array:
		return ["'entries' is not an array"]
	var draft_data: Variant = data.get("draft")
	if not draft_data is Dictionary:
		return ["missing 'draft'"]
	var draft: Dictionary = draft_data
	for key: String in ["firm", "pencil"]:
		if not is_draft_row(draft.get(key)):
			return ["'draft.%s' is not 7 glyphs from -1 to 35" % key]
	var errors: Array[String] = []
	var seen: Dictionary[String, int] = {}
	var list: Array = data["entries"]
	for index: int in list.size():
		if not list[index] is Dictionary:
			errors.append("entries %d is not an object" % index)
			continue
		var item: Dictionary = list[index]
		for error: String in AddressEntry.validate_dict(item):
			errors.append("entries %d: %s" % [index, error])
		var key: Variant = item.get("address_key")
		if not key is String:
			continue
		if seen.has(key):
			errors.append("entries %d repeats the address of entries %d" % [index, seen[key]])
		else:
			seen[key] = index
	return errors
