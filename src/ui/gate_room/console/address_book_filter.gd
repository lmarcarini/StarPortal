class_name AddressBookFilter
extends RefCounted
## What the Address Book shows: the entries holding every picked glyph, whose note or world
## name contains the search text (ignoring case), from the chosen source. View state only.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book)

## Value of [member source] that lets every source through.
const ANY_SOURCE: int = -1

## Glyphs every shown address must contain, in the order picked.
var glyphs: Array[int] = []
## Text the note or the world name must contain; empty lets every entry through.
var text: String = ""
## AddressEntry.Source value to show, or ANY_SOURCE.
var source: int = ANY_SOURCE


## Adds [param glyph] to the glyph filter, or removes it when already there.
func toggle_glyph(glyph: int) -> void:
	if glyphs.has(glyph):
		glyphs.erase(glyph)
	else:
		glyphs.append(glyph)


## True when no part of the filter is set.
func is_empty() -> bool:
	return glyphs.is_empty() and text.strip_edges().is_empty() and source == ANY_SOURCE


## Back to letting every entry through.
func clear() -> void:
	glyphs.clear()
	text = ""
	source = ANY_SOURCE


## Returns the entries of [param book] that pass, in book order (newest first). [param state]
## names the worlds for the text search.
func apply(book: AddressBookState, state: GameState) -> Array[AddressEntry]:
	var found: Array[AddressEntry] = []
	var needle: String = text.strip_edges()
	for entry: AddressEntry in book.search_by_glyphs(glyphs):
		if source != ANY_SOURCE and entry.source != source:
			continue
		if not needle.is_empty() and not _has_text(entry, state, needle):
			continue
		found.append(entry)
	return found


static func _has_text(entry: AddressEntry, state: GameState, needle: String) -> bool:
	if entry.note.findn(needle) >= 0:
		return true
	return AddressBookText.world_text(entry, state).findn(needle) >= 0
