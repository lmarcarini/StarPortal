class_name AddressBookText
extends RefCounted
## Pure text helpers of the Address Book: where an entry came from and the name of its world,
## both translated. A world is named only when the entry records it (a lock, or the document
## that gave the address), so a failed dial never reveals one.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## gate-and-address-spec.md#where-addresses-come-from

## Translation keys of the source filter's choices: every source, then one per
## AddressEntry.Source value.
const SOURCE_FILTER_KEYS: Array[StringName] = [
	&"BOOK_FILTER_ALL_SOURCES",
	&"BOOK_FILTER_DOCUMENTS",
	&"BOOK_FILTER_CONSOLES",
	&"BOOK_FILTER_DIALED",
]


## Returns where [param entry] came from, e.g. the document's title, "Console of R-0042" or
## "Dialed". [param state] gives the galaxy for a console's world.
static func source_text(entry: AddressEntry, state: GameState) -> String:
	match entry.source:
		AddressEntry.Source.DOCUMENT:
			var document: DocumentDef = Registry.get_def(entry.source_id) as DocumentDef
			if document == null:
				return _translate(&"BOOK_SOURCE_DOCUMENT")
			return _translate(document.title_key)
		AddressEntry.Source.CONSOLE:
			var world: String = name_of_world(entry.source_id, state)
			return _translate(&"BOOK_SOURCE_CONSOLE").format({"world": world})
	return _translate(&"BOOK_SOURCE_DIALED")


## Returns the name of [param entry]'s world, or "" while the book does not know it.
static func world_text(entry: AddressEntry, state: GameState) -> String:
	if entry.world_id.is_empty():
		return ""
	return name_of_world(entry.world_id, state)


## Returns the name of world [param world_id]: the authored world's translated name, else its
## designation, else "unnamed world".
static func name_of_world(world_id: StringName, state: GameState) -> String:
	var def: WorldDef = Registry.get_def(world_id) as WorldDef
	if def != null and not def.name_key.is_empty():
		return _translate(def.name_key)
	var record: WorldRecord = null
	if state != null and state.galaxy != null:
		record = state.galaxy.get_world(world_id)
	if record != null and not record.designation.is_empty():
		return record.designation
	return _translate(&"GATE_WORMHOLE_UNNAMED")


static func _translate(key: StringName) -> String:
	return String(TranslationServer.translate(key))
