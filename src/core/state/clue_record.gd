class_name ClueRecord
extends RefCounted
## One clue the base has received: what it claims (constraints), whether that is true, where
## it came from and the analyst's grade, plus the text key and arguments the view renders.
## What a clue says is data; how it reads is the view's job. Text argument names choose how
## the view shows a value: "glyph*" and "picture*" hold glyph indices, "seal*" and "count*"
## numbers, "world*" world designations and "address*" GateAddress.key() strings.
## Saved shape: {"id", "kind": kind name, "dossier_id", "target_world_id", "constraints":
## [AddressConstraint], "is_true", "source_key", "grade", "text_key", "text_args": {name:
## String or whole number}, "image_glyphs": [glyph], "received_tick"}.
## Bible: gate-and-address-spec.md#clue-types-and-reliability, technical-architecture.md#data-model

## Clue types of M1.
enum Kind { FRAGMENT, PICTORIAL, SKY_CHART, ORDINAL, NEIGHBOUR }

## Saved name of each Kind, in enum order.
const KIND_NAMES: Array[String] = ["fragment", "pictorial", "sky_chart", "ordinal", "neighbour"]
## Highest analyst grade: 0..4 read as A..E.
const MAX_GRADE: int = 4
## Text argument name prefixes whose values are glyph indices.
const _GLYPH_ARG_PREFIXES: Array[String] = ["glyph", "picture"]
## Text argument name prefixes whose values are whole numbers.
const _NUMBER_ARG_PREFIXES: Array[String] = ["seal", "count"]
## Text argument name prefixes whose values are Strings.
const _STRING_ARG_PREFIXES: Array[String] = ["world", "address"]
## Saved keys that hold a non-empty id or key string.
const _ID_KEYS: Array[String] = ["id", "dossier_id", "target_world_id", "source_key", "text_key"]

## Unique id, e.g. &"clue_0001".
var id: StringName
## What kind of clue this is.
var kind: Kind
## Groups the clues delivered together.
var dossier_id: StringName
## The world the clue points at. Secret.
var target_world_id: StringName
## What the clue claims. Secret.
var constraints: Array[AddressConstraint] = []
## False for a planted clue. Secret; every M1 clue is true.
var is_true: bool = true
## Translation key of the source, e.g. &"CLUE_SOURCE_DIRECTORATE".
var source_key: StringName
## The analyst's estimate, 0..4 = A..E.
var grade: int
## Translation key of the clue text.
var text_key: StringName
## Arguments of the clue text: String name -> int or String (see the class description).
var text_args: Dictionary
## Glyphs to draw: sky charts, pictorial sketches.
var image_glyphs: Array[int] = []
## Tick the clue arrived.
var received_tick: int


## Returns JSON-safe data for saving. The kind is its lowercase name.
func to_dict() -> Dictionary:
	var constraint_data: Array[Dictionary] = []
	for constraint: AddressConstraint in constraints:
		constraint_data.append(constraint.to_dict())
	var arg_data: Dictionary = {}
	for name: Variant in text_args:
		arg_data[str(name)] = text_args[name]
	return {
		"id": String(id),
		"kind": KIND_NAMES[kind] if kind >= 0 and kind < KIND_NAMES.size() else "",
		"dossier_id": String(dossier_id),
		"target_world_id": String(target_world_id),
		"constraints": constraint_data,
		"is_true": is_true,
		"source_key": String(source_key),
		"grade": grade,
		"text_key": String(text_key),
		"text_args": arg_data,
		"image_glyphs": image_glyphs.duplicate(),
		"received_tick": received_tick,
	}


## Builds a record from saved [param data]; JSON floats become ints. Unreadable values keep
## their defaults, unreadable list items and text arguments are skipped. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> ClueRecord:
	var record := ClueRecord.new()
	record.id = StringName(str(data.get("id", "")))
	record.kind = maxi(KIND_NAMES.find(str(data.get("kind", ""))), 0) as Kind
	record.dossier_id = StringName(str(data.get("dossier_id", "")))
	record.target_world_id = StringName(str(data.get("target_world_id", "")))
	for item: Variant in _array_or_empty(data.get("constraints")):
		if item is Dictionary:
			var constraint_data: Dictionary = item
			record.constraints.append(AddressConstraint.from_dict(constraint_data))
	var truth: Variant = data.get("is_true")
	record.is_true = truth if truth is bool else true
	record.source_key = StringName(str(data.get("source_key", "")))
	record.grade = type_convert(data.get("grade", 0), TYPE_INT)
	record.text_key = StringName(str(data.get("text_key", "")))
	record.text_args = _read_text_args(data.get("text_args"))
	for glyph: Variant in _array_or_empty(data.get("image_glyphs")):
		record.image_glyphs.append(type_convert(glyph, TYPE_INT))
	record.received_tick = type_convert(data.get("received_tick", 0), TYPE_INT)
	return record


static func _read_text_args(value: Variant) -> Dictionary:
	var args: Dictionary = {}
	if not value is Dictionary:
		return args
	var arg_data: Dictionary = value
	for name: Variant in arg_data:
		var arg: Variant = arg_data[name]
		if arg is String:
			args[str(name)] = arg
		elif JsonLimits.is_exact_int(arg):
			args[str(name)] = type_convert(arg, TYPE_INT)
	return args


## Returns human-readable errors for saved [param data], empty when it is valid: "id",
## "dossier_id", "target_world_id", "source_key" and "text_key" non-empty strings; "kind" a
## kind name; "constraints" an array of objects passing AddressConstraint.validate_dict();
## "is_true" a bool; "grade" a whole number 0..4; "text_args" an object whose values are
## Strings or whole numbers up to 2^53 (glyph and picture arguments glyph indices 0..35,
## seal and count arguments whole numbers, world and address arguments Strings);
## "image_glyphs" an array of glyph indices 0..35; "received_tick" a whole number 0..2^53.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _ID_KEYS:
		var text: Variant = data.get(key)
		if not text is String or str(text).is_empty():
			errors.append("'%s' is not a non-empty string" % key)
	if not data.get("kind") is String or not KIND_NAMES.has(data.get("kind")):
		errors.append("'kind' is not one of %s" % str(KIND_NAMES))
	errors.append_array(_constraint_errors(data.get("constraints")))
	if not data.get("is_true") is bool:
		errors.append("'is_true' is not a bool")
	if not _is_whole_in(data.get("grade"), 0, MAX_GRADE):
		errors.append("'grade' is not a whole number from 0 to %d" % MAX_GRADE)
	errors.append_array(_text_arg_errors(data.get("text_args")))
	errors.append_array(_image_glyph_errors(data.get("image_glyphs")))
	if not _is_whole_in(data.get("received_tick"), 0, JsonLimits.MAX_EXACT_INT):
		errors.append("'received_tick' is not a whole number from 0 to 2^53")
	return errors


static func _constraint_errors(value: Variant) -> Array[String]:
	if not value is Array:
		return ["'constraints' is not an array"]
	var list: Array = value
	var errors: Array[String] = []
	for index: int in list.size():
		if not list[index] is Dictionary:
			errors.append("constraint %d is not an object" % index)
			continue
		var constraint_data: Dictionary = list[index]
		for error: String in AddressConstraint.validate_dict(constraint_data):
			errors.append("constraint %d: %s" % [index, error])
	return errors


static func _text_arg_errors(value: Variant) -> Array[String]:
	if not value is Dictionary:
		return ["'text_args' is not an object"]
	var arg_data: Dictionary = value
	var errors: Array[String] = []
	for name: Variant in arg_data:
		var arg_name := str(name)
		var problem := _text_arg_problem(arg_name, arg_data[name])
		if arg_name.is_empty():
			errors.append("a text arg has an empty name")
		elif not problem.is_empty():
			errors.append("text arg '%s' is not %s" % [arg_name, problem])
	return errors


## What [param arg] should be for argument [param arg_name], or "" when it fits.
static func _text_arg_problem(arg_name: String, arg: Variant) -> String:
	if _has_prefix(arg_name, _GLYPH_ARG_PREFIXES):
		var last_glyph: int = GateAddress.GLYPH_COUNT - 1
		return "" if _is_whole_in(arg, 0, last_glyph) else "a glyph from 0 to %d" % last_glyph
	if _has_prefix(arg_name, _NUMBER_ARG_PREFIXES):
		return "" if JsonLimits.is_exact_int(arg) else "a whole number"
	if _has_prefix(arg_name, _STRING_ARG_PREFIXES):
		return "" if arg is String else "a String"
	if arg is String or JsonLimits.is_exact_int(arg):
		return ""
	return "a String or whole number"


static func _has_prefix(arg_name: String, prefixes: Array[String]) -> bool:
	for prefix: String in prefixes:
		if arg_name.begins_with(prefix):
			return true
	return false


static func _image_glyph_errors(value: Variant) -> Array[String]:
	if not value is Array:
		return ["'image_glyphs' is not an array"]
	var list: Array = value
	var errors: Array[String] = []
	for index: int in list.size():
		if not _is_whole_in(list[index], 0, GateAddress.GLYPH_COUNT - 1):
			errors.append(
				"image glyph %d is not a glyph from 0 to %d" % [index, GateAddress.GLYPH_COUNT - 1]
			)
	return errors


## True for an int, or a whole float, from [param low] to [param high].
static func _is_whole_in(value: Variant, low: int, high: int) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= float(low) and number <= float(high)


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value
	return []
