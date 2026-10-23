class_name AddressBookState
extends RefCounted
## The Address Book: every address the player has found or dialed, one entry per address,
## newest first. A dial updates its entry in place; a new address goes to the top.
## Saved shape: {"entries": [AddressEntry]}.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## gate-and-address-spec.md#where-addresses-come-from, technical-architecture.md#data-model

## Every entry, unique by address_key, newest first.
var entries: Array[AddressEntry] = []


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
	return {"entries": entry_data}


## Builds a book from saved [param data]; items that are not objects are skipped. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> AddressBookState:
	var book := AddressBookState.new()
	var entry_data: Variant = data.get("entries")
	if not entry_data is Array:
		return book
	var list: Array = entry_data
	for item: Variant in list:
		if item is Dictionary:
			var item_dict: Dictionary = item
			book.entries.append(AddressEntry.from_dict(item_dict))
	return book


## Returns human-readable errors for saved [param data], empty when it is valid: "entries" an
## array of objects that pass AddressEntry.validate_dict(), no two with the same
## "address_key".
static func validate_dict(data: Dictionary) -> Array[String]:
	if not data.has("entries"):
		return ["missing 'entries'"]
	if not data["entries"] is Array:
		return ["'entries' is not an array"]
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
