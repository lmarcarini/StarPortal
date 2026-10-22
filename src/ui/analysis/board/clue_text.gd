class_name ClueText
extends RefCounted
## Fills a translated clue template with the clue's arguments. Pure and static. The argument
## name chooses how a value reads: "glyph*" shows a glyph name, "picture*" a picture
## description, "address*" the glyph names of an address key joined by " · ", any other name
## the value as given. A placeholder with no usable argument stays visible as "{name}" and
## pushes a warning.
## Bible: gate-and-address-spec.md#clue-types-and-reliability

## Argument name prefix whose values are glyph indices shown as names.
const GLYPH_PREFIX: String = "glyph"
## Argument name prefix whose values are glyph indices shown as picture descriptions.
const PICTURE_PREFIX: String = "picture"
## Argument name prefix whose values are address keys shown as glyph names.
const ADDRESS_PREFIX: String = "address"
## Between the glyph names of an address.
const ADDRESS_SEPARATOR: String = " · "
## Between the seals of an address key ([method GateAddress.key]).
const SEAL_SEPARATOR: String = "-"

const _PLACEHOLDER_PATTERN: String = "\\{([A-Za-z_][A-Za-z0-9_]*)\\}"

static var _placeholder_regex: RegEx = RegEx.create_from_string(_PLACEHOLDER_PATTERN)


## Returns [param template] with each "{name}" replaced from [param args] (name -> int or
## String). [param glyph_names] and [param picture_texts] are indexed by glyph index.
static func format(
	template: String, args: Dictionary, glyph_names: Array[String], picture_texts: Array[String]
) -> String:
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _placeholder_regex.search_all(template):
		result += template.substr(cursor, found.get_start() - cursor)
		cursor = found.get_end()
		var arg_name: String = found.get_string(1)
		var value: Variant = _resolve(arg_name, args, glyph_names, picture_texts)
		if value == null:
			push_warning("ClueText: no usable argument for '{%s}'" % arg_name)
			result += found.get_string()
		else:
			result += str(value)
	return result + template.substr(cursor)


# The text for argument [param arg_name], or null when it is missing or unusable.
static func _resolve(
	arg_name: String, args: Dictionary, glyph_names: Array[String], picture_texts: Array[String]
) -> Variant:
	if not args.has(arg_name):
		return null
	var value: Variant = args[arg_name]
	if arg_name.begins_with(GLYPH_PREFIX):
		return _lookup(value, glyph_names)
	if arg_name.begins_with(PICTURE_PREFIX):
		return _lookup(value, picture_texts)
	if arg_name.begins_with(ADDRESS_PREFIX):
		return _address_text(value, glyph_names)
	return str(value)


static func _lookup(value: Variant, table: Array[String]) -> Variant:
	if not (value is int or value is float):
		return null
	var number: float = value
	var index: int = floori(number)
	if index < 0 or index >= table.size():
		return null
	return table[index]


static func _address_text(value: Variant, glyph_names: Array[String]) -> Variant:
	if not value is String:
		return null
	var names: Array[String] = []
	for seal: String in str(value).split(SEAL_SEPARATOR):
		if not seal.is_valid_int():
			return null
		var name: Variant = _lookup(seal.to_int(), glyph_names)
		if name == null:
			return null
		names.append(str(name))
	return ADDRESS_SEPARATOR.join(names)
