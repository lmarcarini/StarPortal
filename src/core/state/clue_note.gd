class_name ClueNote
extends RefCounted
## The player's own notes on one clue card of the Analysis Board: marked suspect, free-text
## tags (player text, never translated), links to other clues and the card's place on the
## board. Saved shape: {"is_suspect": bool, "tags": [String], "links": [clue id],
## "board_position": [x, y]}. Links are checked against the known clues by IntelState.
## Bible: gate-and-address-spec.md#player-tools, technical-architecture.md#data-model

## Most tags one card can carry.
const MAX_TAGS: int = 8
## Longest tag, in characters.
const MAX_TAG_LENGTH: int = 32
## Largest board coordinate on each axis; the smallest is 0.
const MAX_BOARD_COORDINATE: int = 4000

## True when the player marked the clue as suspect.
var is_suspect: bool = false
## Free text the player typed, 1 to MAX_TAG_LENGTH characters each, no control characters.
var tags: Array[String] = []
## Ids of other clues this card is linked to.
var links: Array[StringName] = []
## Card position on the board, 0..MAX_BOARD_COORDINATE on each axis.
var board_position: Vector2i = Vector2i.ZERO


## True when this note says nothing: not suspect, no tags, no links, at the origin.
func is_default() -> bool:
	return (
		not is_suspect and tags.is_empty() and links.is_empty() and board_position == Vector2i.ZERO
	)


## Returns JSON-safe data for saving; the position is an [x, y] array of ints.
func to_dict() -> Dictionary:
	var link_data: Array[String] = []
	for link: StringName in links:
		link_data.append(String(link))
	return {
		"is_suspect": is_suspect,
		"tags": tags.duplicate(),
		"links": link_data,
		"board_position": [board_position.x, board_position.y],
	}


## Builds a note from saved [param data]; JSON floats become ints. Unreadable values keep
## their defaults and unreadable list items are skipped. Call validate_dict() first for
## untrusted data.
static func from_dict(data: Dictionary) -> ClueNote:
	var note := ClueNote.new()
	var suspect: Variant = data.get("is_suspect")
	if suspect is bool:
		note.is_suspect = suspect
	for item: Variant in _array_or_empty(data.get("tags")):
		if item is String:
			note.tags.append(item)
	for item: Variant in _array_or_empty(data.get("links")):
		if item is String:
			note.links.append(StringName(str(item)))
	var position: Array = _array_or_empty(data.get("board_position"))
	if position.size() == 2:
		var x: int = type_convert(position[0], TYPE_INT)
		var y: int = type_convert(position[1], TYPE_INT)
		note.board_position = Vector2i(x, y)
	return note


## Returns human-readable errors for saved [param data], empty when it is valid:
## "is_suspect" a bool; "tags" an array of at most MAX_TAGS strings of 1 to MAX_TAG_LENGTH
## characters with no control characters; "links" an array of distinct non-empty strings;
## "board_position" an array of two whole numbers from 0 to MAX_BOARD_COORDINATE. Whether
## the links name known clues is checked by IntelState.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.get("is_suspect") is bool:
		errors.append("'is_suspect' is not a bool")
	errors.append_array(_tag_errors(data.get("tags")))
	errors.append_array(_link_errors(data.get("links")))
	errors.append_array(_position_errors(data.get("board_position")))
	return errors


static func _tag_errors(value: Variant) -> Array[String]:
	if not value is Array:
		return ["'tags' is not an array"]
	var tag_list: Array = value
	var errors: Array[String] = []
	if tag_list.size() > MAX_TAGS:
		errors.append("%d tags, more than %d" % [tag_list.size(), MAX_TAGS])
	for index: int in tag_list.size():
		var tag: Variant = tag_list[index]
		if not tag is String:
			errors.append("tag %d is not a string" % index)
			continue
		var text: String = tag
		if text.is_empty() or text.length() > MAX_TAG_LENGTH:
			errors.append("tag %d is not 1 to %d characters" % [index, MAX_TAG_LENGTH])
		elif _has_control_character(text):
			errors.append("tag %d has a control character" % index)
	return errors


## True when [param text] holds a C0 or C1 control character or DEL.
static func _has_control_character(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code < 0x20 or (code >= 0x7f and code <= 0x9f):
			return true
	return false


static func _link_errors(value: Variant) -> Array[String]:
	if not value is Array:
		return ["'links' is not an array"]
	var link_list: Array = value
	var errors: Array[String] = []
	for index: int in link_list.size():
		var link: Variant = link_list[index]
		if not link is String or str(link).is_empty():
			errors.append("link %d is not a clue id" % index)
		elif link_list.find(link) != index:
			errors.append("link %d repeats '%s'" % [index, link])
	return errors


static func _position_errors(value: Variant) -> Array[String]:
	var message := "'board_position' is not two whole numbers from 0 to %d" % MAX_BOARD_COORDINATE
	if not value is Array:
		return [message]
	var position: Array = value
	if position.size() != 2:
		return [message]
	for coordinate: Variant in position:
		if not JsonLimits.is_exact_int(coordinate):
			return [message]
		var number: float = coordinate
		if number < 0.0 or number > float(MAX_BOARD_COORDINATE):
			return [message]
	return []


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value
	return []
