class_name AddressConstraint
extends RefCounted
## One constraint on an address's seven coordinates; a clue is a set of these. Plain data
## (ints), so it saves through to_dict(). pos(g) below is glyph g's seal number 1..7, or absent.
##
## | Kind         | Satisfied when                                              |
## | GLYPH_AT     | pos(glyphs[0]) == seal                                      |
## | GLYPH_NOT_AT | pos(glyphs[0]) != seal                                      |
## | EXCLUDED     | glyphs[0] is absent                                         |
## | INCLUDED     | glyphs[0] is present                                        |
## | EXACT_SET    | the coordinates, as a set, equal glyphs                     |
## | NEARER_THAN  | glyphs[1] absent, or glyphs[0] present and nearer (earlier) |
##
## is_satisfied_by() applies the table literally to any coordinate list, so the counter can use
## a small alphabet in tests; a constraint with the wrong number of glyphs for its kind, or an
## unknown kind, is satisfied by nothing.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#player-tools

enum Kind { GLYPH_AT, GLYPH_NOT_AT, EXCLUDED, INCLUDED, EXACT_SET, NEARER_THAN }

## Lowest seal a GLYPH_AT / GLYPH_NOT_AT constraint names.
const FIRST_SEAL: int = 1
## Saved name of each Kind, in enum order.
const KIND_NAMES: Array[String] = [
	"glyph_at", "glyph_not_at", "excluded", "included", "exact_set", "nearer_than"
]
## Number of glyphs each Kind takes, in enum order.
const GLYPH_COUNTS: Array[int] = [1, 1, 1, 1, GateAddress.COORDINATE_COUNT, 2]
const _KIND_KEY: String = "kind"
const _SEAL_KEY: String = "seal"
const _GLYPHS_KEY: String = "glyphs"

## What the constraint says.
var kind: Kind = Kind.GLYPH_AT
## Seal 1..7 for GLYPH_AT / GLYPH_NOT_AT, else 0.
var seal: int = 0
## The glyphs it names; see the table above. EXACT_SET keeps them sorted.
var glyphs: Array[int] = []


## Glyph [param glyph] is at seal [param seal].
static func glyph_at(seal: int, glyph: int) -> AddressConstraint:
	return _make(Kind.GLYPH_AT, seal, [glyph])


## Glyph [param glyph] is not at seal [param seal] (it may be absent).
static func glyph_not_at(seal: int, glyph: int) -> AddressConstraint:
	return _make(Kind.GLYPH_NOT_AT, seal, [glyph])


## Glyph [param glyph] is not among the coordinates.
static func excluded(glyph: int) -> AddressConstraint:
	return _make(Kind.EXCLUDED, 0, [glyph])


## Glyph [param glyph] is among the coordinates, at any seal.
static func included(glyph: int) -> AddressConstraint:
	return _make(Kind.INCLUDED, 0, [glyph])


## The coordinates are exactly [param glyphs] in some order (a sky chart). Stores a sorted copy.
static func exact_set(glyphs: Array[int]) -> AddressConstraint:
	var sorted: Array[int] = glyphs.duplicate()
	sorted.sort()
	return _make(Kind.EXACT_SET, 0, sorted)


## If [param farther] is present, [param nearer] is present at an earlier seal.
static func nearer_than(nearer: int, farther: int) -> AddressConstraint:
	return _make(Kind.NEARER_THAN, 0, [nearer, farther])


static func _make(kind: Kind, seal: int, glyphs: Array[int]) -> AddressConstraint:
	var constraint := AddressConstraint.new()
	constraint.kind = kind
	constraint.seal = seal
	constraint.glyphs = glyphs
	return constraint


## True for a known kind with a seal of 1..7 (GLYPH_AT / GLYPH_NOT_AT) or 0 (others), and the
## right number of distinct glyphs, each from 0 to 35.
func is_well_formed() -> bool:
	if kind < 0 or kind >= KIND_NAMES.size():
		return false
	if not _seal_is_valid():
		return false
	if glyphs.size() != GLYPH_COUNTS[kind]:
		return false
	for index: int in glyphs.size():
		var glyph: int = glyphs[index]
		if glyph < 0 or glyph >= GateAddress.GLYPH_COUNT or glyphs.find(glyph) != index:
			return false
	return true


func _seal_is_valid() -> bool:
	if _has_seal(kind):
		return seal >= FIRST_SEAL and seal <= GateAddress.COORDINATE_COUNT
	return seal == 0


## True when [param address]'s coordinates satisfy this constraint (see the table above).
## False for null, an unknown kind or the wrong glyph count.
func is_satisfied_by(address: GateAddress) -> bool:
	if address == null:
		return false
	return is_satisfied_by_coordinates(address.coordinates)


## Same as is_satisfied_by() on a bare coordinate list, of any length.
func is_satisfied_by_coordinates(coordinates: Array[int]) -> bool:
	if kind < 0 or kind >= KIND_NAMES.size():
		return false
	if kind != Kind.EXACT_SET and glyphs.size() != GLYPH_COUNTS[kind]:
		return false
	if kind == Kind.EXACT_SET:
		return _same_multiset(coordinates, glyphs)
	return _fits_glyph_rule(coordinates)


## The single-glyph kinds and NEARER_THAN; find() gives -1 for an absent glyph.
func _fits_glyph_rule(coordinates: Array[int]) -> bool:
	var position: int = coordinates.find(glyphs[0])
	match kind:
		Kind.GLYPH_AT:
			return position >= 0 and position + 1 == seal
		Kind.GLYPH_NOT_AT:
			return position < 0 or position + 1 != seal
		Kind.EXCLUDED:
			return position < 0
		Kind.INCLUDED:
			return position >= 0
	var farther: int = coordinates.find(glyphs[1])
	return farther < 0 or (position >= 0 and position < farther)


static func _same_multiset(left: Array[int], right: Array[int]) -> bool:
	var left_sorted: Array[int] = left.duplicate()
	var right_sorted: Array[int] = right.duplicate()
	left_sorted.sort()
	right_sorted.sort()
	return left_sorted == right_sorted


## True when [param other] says the same thing: same kind, seal and glyphs (EXACT_SET glyphs in
## any order). False for null.
func equals(other: AddressConstraint) -> bool:
	if other == null or other.kind != kind or other.seal != seal:
		return false
	if kind == Kind.EXACT_SET:
		return _same_multiset(glyphs, other.glyphs)
	return glyphs == other.glyphs


## Returns JSON-safe data, e.g. {"kind": "glyph_at", "seal": 2, "glyphs": [14]}. Only
## GLYPH_AT and GLYPH_NOT_AT carry "seal".
func to_dict() -> Dictionary:
	var data: Dictionary = {_KIND_KEY: _kind_name(kind), _GLYPHS_KEY: glyphs.duplicate()}
	if _has_seal(kind):
		data[_SEAL_KEY] = seal
	return data


static func _kind_name(value: int) -> String:
	if value < 0 or value >= KIND_NAMES.size():
		return ""
	return KIND_NAMES[value]


static func _has_seal(value: int) -> bool:
	return value == Kind.GLYPH_AT or value == Kind.GLYPH_NOT_AT


## Builds a constraint from saved [param data]; JSON floats are cast back to ints. Unreadable
## parts give a malformed constraint (unknown kind -1, or no glyphs). Call validate_dict()
## first for untrusted data.
static func from_dict(data: Dictionary) -> AddressConstraint:
	var constraint := AddressConstraint.new()
	constraint.kind = KIND_NAMES.find(str(data.get(_KIND_KEY, ""))) as Kind
	constraint.seal = type_convert(data.get(_SEAL_KEY, 0), TYPE_INT)
	var glyph_data: Variant = data.get(_GLYPHS_KEY)
	if glyph_data is Array:
		var glyph_list: Array = glyph_data
		for glyph: Variant in glyph_list:
			constraint.glyphs.append(type_convert(glyph, TYPE_INT))
	return constraint


## Returns human-readable errors for saved [param data], empty when it is valid: a known
## "kind"; "seal" a whole number 1..7 for glyph_at / glyph_not_at, absent or 0 otherwise;
## "glyphs" an array of the kind's count of distinct whole numbers from 0 to 35.
static func validate_dict(data: Dictionary) -> Array[String]:
	var kind_value: int = KIND_NAMES.find(str(data.get(_KIND_KEY, "")))
	if not data.get(_KIND_KEY) is String or kind_value < 0:
		return ["unknown kind '%s'" % str(data.get(_KIND_KEY, ""))]
	var errors: Array[String] = _validate_seal(data, kind_value)
	errors.append_array(_validate_glyphs(data, kind_value))
	return errors


static func _validate_seal(data: Dictionary, kind_value: int) -> Array[String]:
	if not _has_seal(kind_value):
		var unused: Variant = data.get(_SEAL_KEY, 0)
		if JsonLimits.is_exact_int(unused) and type_convert(unused, TYPE_INT) == 0:
			return []
		return ["'%s' takes no seal" % KIND_NAMES[kind_value]]
	var seal_value: Variant = data.get(_SEAL_KEY)
	if not JsonLimits.is_exact_int(seal_value):
		return ["seal is not a whole number"]
	var seal_number: int = type_convert(seal_value, TYPE_INT)
	if seal_number < FIRST_SEAL or seal_number > GateAddress.COORDINATE_COUNT:
		return ["seal %d is not from 1 to %d" % [seal_number, GateAddress.COORDINATE_COUNT]]
	return []


static func _validate_glyphs(data: Dictionary, kind_value: int) -> Array[String]:
	if not data.get(_GLYPHS_KEY) is Array:
		return ["'%s' is not an array" % _GLYPHS_KEY]
	var glyph_list: Array = data[_GLYPHS_KEY]
	var errors: Array[String] = []
	var expected: int = GLYPH_COUNTS[kind_value]
	if glyph_list.size() != expected:
		errors.append("%d glyphs, not %d" % [glyph_list.size(), expected])
	for index: int in glyph_list.size():
		errors.append_array(_validate_glyph(glyph_list, index))
	return errors


static func _validate_glyph(glyph_list: Array, index: int) -> Array[String]:
	var value: Variant = glyph_list[index]
	if not JsonLimits.is_exact_int(value):
		return ["glyph %d is not a whole number" % (index + 1)]
	var glyph: int = type_convert(value, TYPE_INT)
	if glyph < 0 or glyph >= GateAddress.GLYPH_COUNT:
		return [
			"glyph %d is %d, not from 0 to %d" % [index + 1, glyph, GateAddress.GLYPH_COUNT - 1]
		]
	for earlier: int in index:
		var other: Variant = glyph_list[earlier]
		if JsonLimits.is_exact_int(other) and type_convert(other, TYPE_INT) == glyph:
			return ["glyph %d repeats glyph %d" % [index + 1, earlier + 1]]
	return []
