class_name AddressEntry
extends RefCounted
## One address in the Address Book: where it came from, the world's id once known, the last
## dial's outcome and tick, and the player's own note. A failed dial never records a world:
## the world id comes only from a lock (GateSystem sets it on nothing else) or from the
## document that gave the address. Once learned through a lock it stays known, whatever later
## dials of the address report.
## Saved shape: {"address_key": GateAddress.key(), "source": "document" | "console" | "dialed",
## "source_id", "world_id", "last_outcome": DialOutcome key or "" when never dialed,
## "last_dialed_tick": -1 when never dialed, "note"}.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## gate-and-address-spec.md#where-addresses-come-from, technical-architecture.md#data-model

## Where the address came from. DOCUMENT: a document's puzzle. CONSOLE: a far Ring's console
## log. DIALED: the player dialed it without a source.
enum Source { DOCUMENT, CONSOLE, DIALED }

## Longest note, in characters.
const MAX_NOTE_LENGTH: int = 140
## Value of last_dialed_tick and last_outcome when the address was never dialed.
const NEVER: int = -1
## Saved names of the sources, indexed by Source value.
const _SOURCE_NAMES: Array[String] = ["document", "console", "dialed"]
## Saved fields, in to_dict() order.
const _KEYS: Array[String] = [
	"address_key", "source", "source_id", "world_id", "last_outcome", "last_dialed_tick", "note"
]

## The address's GateAddress.key(), e.g. "3-17-0-22-9-14-30-5".
var address_key: String
## Where the address came from.
var source: Source
## The document id, or the world id of the console; &"" for DIALED.
var source_id: StringName
## The world at this address: known once locked or told by a document.
var world_id: StringName = &""
## DialOutcome.Kind of the last dial, -1 when never dialed.
var last_outcome: int = -1
## Tick the last dial resolved, -1 when never dialed.
var last_dialed_tick: int = -1
## The player's own note, at most MAX_NOTE_LENGTH characters with no control characters.
var note: String = ""


## Returns a never-dialed entry for [param key] from [param from_source] and
## [param from_id].
static func create(key: String, from_source: Source, from_id: StringName) -> AddressEntry:
	var entry := AddressEntry.new()
	entry.address_key = key
	entry.source = from_source
	entry.source_id = from_id
	return entry


## Returns JSON-safe data for saving. The source is a lowercase name and the outcome its
## DialOutcome key, "" when never dialed.
func to_dict() -> Dictionary:
	var outcome_key: String = ""
	if last_outcome != NEVER:
		outcome_key = String(DialOutcome.to_key(last_outcome as DialOutcome.Kind))
	return {
		"address_key": address_key,
		"source": _SOURCE_NAMES[source],
		"source_id": String(source_id),
		"world_id": String(world_id),
		"last_outcome": outcome_key,
		"last_dialed_tick": last_dialed_tick,
		"note": note,
	}


## Builds an entry from saved [param data]; JSON floats become ints. Missing or unreadable
## values keep their defaults (an unknown source reads as DIALED). Call validate_dict() first
## for untrusted data.
static func from_dict(data: Dictionary) -> AddressEntry:
	var entry := AddressEntry.new()
	entry.address_key = str(data.get("address_key", ""))
	var source_index: int = _SOURCE_NAMES.find(str(data.get("source", "")))
	entry.source = (source_index if source_index >= 0 else Source.DIALED) as Source
	entry.source_id = StringName(str(data.get("source_id", "")))
	entry.world_id = StringName(str(data.get("world_id", "")))
	entry.last_outcome = DialOutcome.from_key(StringName(str(data.get("last_outcome", ""))))
	entry.last_dialed_tick = type_convert(data.get("last_dialed_tick", NEVER), TYPE_INT)
	entry.note = str(data.get("note", ""))
	return entry


## Returns human-readable errors for saved [param data], empty when it is valid: every field
## present; "address_key" the key of a well-formed address; "source" a source name;
## "source_id" a string, empty exactly for "dialed"; "world_id" a string, and on a "dialed"
## entry set only once it has been dialed (whatever the last outcome: a world learned through
## a lock stays known); "last_outcome" "" or a DialOutcome key;
## "last_dialed_tick" -1 when never dialed, otherwise a whole number from 0 to 2^53; "note"
## valid per note_errors().
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif key != "last_dialed_tick" and not data[key] is String:
			errors.append("'%s' is not a string" % key)
	if not errors.is_empty():
		return errors
	var key: String = data["address_key"]
	if not is_valid_key(key):
		errors.append("'address_key' is not the key of a well-formed address")
	errors.append_array(_source_errors(data))
	errors.append_array(_dial_errors(data))
	var text: String = data["note"]
	for error: String in note_errors(text):
		errors.append("'note' " + error)
	return errors


## Returns errors for player text [param text] as a note: longer than MAX_NOTE_LENGTH
## characters, or holding a control character (C0, DEL or C1, line breaks included).
static func note_errors(text: String) -> Array[String]:
	var errors: Array[String] = []
	if text.length() > MAX_NOTE_LENGTH:
		errors.append("is %d characters, over %d" % [text.length(), MAX_NOTE_LENGTH])
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code < 0x20 or (code >= 0x7f and code <= 0x9f):
			errors.append("has a control character at %d" % index)
			break
	return errors


## True when [param key] is exactly GateAddress.key() of a well-formed address.
static func is_valid_key(key: String) -> bool:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != GateAddress.SEAL_COUNT:
		return false
	var seals: Array[int] = []
	for part: String in parts:
		if not part.is_valid_int() or str(part.to_int()) != part:
			return false
		seals.append(part.to_int())
	var origin: int = seals.pop_back()
	var address := GateAddress.create(seals, origin)
	return address.is_well_formed() and address.key() == key


## Returns the glyphs of [param key], a valid address key, in seal order.
static func glyphs_of(key: String) -> Array[int]:
	var glyphs: Array[int] = []
	for part: String in key.split("-"):
		glyphs.append(part.to_int())
	return glyphs


## Errors for "source" and "source_id" of string-typed [param data].
static func _source_errors(data: Dictionary) -> Array[String]:
	var source_name: String = data["source"]
	if not _SOURCE_NAMES.has(source_name):
		return ["'source' is not one of %s" % str(_SOURCE_NAMES)]
	var has_id: bool = not str(data["source_id"]).is_empty()
	if source_name == "dialed" and has_id:
		return ["'source_id' is not empty for a \"dialed\" entry"]
	if source_name != "dialed" and not has_id:
		return ["'source_id' is empty for a \"%s\" entry" % source_name]
	return []


## Errors for "last_outcome", "last_dialed_tick" and a dialed entry's "world_id".
static func _dial_errors(data: Dictionary) -> Array[String]:
	var outcome_key: String = data["last_outcome"]
	var kind: int = DialOutcome.from_key(StringName(outcome_key))
	if not outcome_key.is_empty() and kind < 0:
		return ["'last_outcome' is not \"\" or a dial outcome key"]
	if not JsonLimits.is_exact_int(data["last_dialed_tick"]):
		return ["'last_dialed_tick' is not -1 or a whole number from 0 to 2^53"]
	var tick: float = data["last_dialed_tick"]
	if tick < NEVER:
		return ["'last_dialed_tick' is not -1 or a whole number from 0 to 2^53"]
	var dialed: bool = kind >= 0
	if dialed != (tick != NEVER):
		return ["'last_dialed_tick' and 'last_outcome' disagree on whether it was dialed"]
	if data["source"] == "dialed" and not str(data["world_id"]).is_empty() and not dialed:
		return ["'world_id' is set on a \"dialed\" entry that was never dialed"]
	return []
