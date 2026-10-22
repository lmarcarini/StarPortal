class_name GateAddress
extends RefCounted
## An 8-seal address value: seven coordinate glyphs (seals 1..7, the destination's nearest
## anchors, nearest first) then the dialing Ring's origin glyph (seal 8). Just ints, so it
## depends on no content. A value may be malformed (e.g. a player's typed guess); check
## is_well_formed() before trusting it.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## technical-architecture.md#data-model

## Number of coordinate seals before the origin.
const COORDINATE_COUNT: int = 7
## Number of glyphs on a Ring; every seal is a glyph index from 0 to GLYPH_COUNT - 1.
const GLYPH_COUNT: int = 36
## Number of seals in a well-formed address.
const SEAL_COUNT: int = COORDINATE_COUNT + 1
## Dictionary key of the seal list in to_dict().
const _SEALS_KEY: String = "seals"

## Seals 1..7, nearest anchor first.
var coordinates: Array[int] = []
## Seal 8: the origin glyph of the dialing Ring.
var origin: int = 0


## Returns an address with a copy of [param coordinates] and [param origin]. The values are not
## checked; see is_well_formed().
static func create(coordinates: Array[int], origin: int) -> GateAddress:
	var address := GateAddress.new()
	address.coordinates = coordinates.duplicate()
	address.origin = origin
	return address


## Returns a new array of the seals in dialing order: the coordinates, then the origin.
func seals() -> Array[int]:
	var all: Array[int] = coordinates.duplicate()
	all.append(origin)
	return all


## True when there are exactly COORDINATE_COUNT coordinates and all eight seals are glyph
## indices (0..35) with no glyph used twice, the origin included.
func is_well_formed() -> bool:
	if coordinates.size() != COORDINATE_COUNT:
		return false
	var all: Array[int] = seals()
	for index: int in all.size():
		var glyph: int = all[index]
		if glyph < 0 or glyph >= GLYPH_COUNT or all.find(glyph) != index:
			return false
	return true


## True when [param other] has the same seals in the same order. False for null.
func equals(other: GateAddress) -> bool:
	if other == null:
		return false
	return seals() == other.seals()


## Returns a stable text key: the seals in order joined by "-", e.g. "3-17-0-22-9-14-30-5".
## Equal addresses have equal keys, so it can key a Dictionary.
func key() -> String:
	var parts: PackedStringArray = []
	for glyph: int in seals():
		parts.append(str(glyph))
	return "-".join(parts)


## Returns JSON-safe data for saving: {"seals": [the seals in order]}.
func to_dict() -> Dictionary:
	return {_SEALS_KEY: seals()}


## Builds an address from saved [param data]: the last seal is the origin, the others the
## coordinates; JSON floats are cast back to ints. A missing or unreadable seal list gives an
## empty, malformed address. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> GateAddress:
	var address := GateAddress.new()
	var seal_data: Variant = data.get(_SEALS_KEY)
	if not seal_data is Array:
		return address
	var seal_list: Array = seal_data
	if seal_list.is_empty():
		return address
	for seal: Variant in seal_list:
		address.coordinates.append(type_convert(seal, TYPE_INT))
	address.origin = address.coordinates.pop_back()
	return address


## Returns human-readable errors for saved [param data], empty when it is valid: "seals" must be
## an array of exactly SEAL_COUNT whole numbers from 0 to 35 with no glyph repeated, the origin
## included.
static func validate_dict(data: Dictionary) -> Array[String]:
	if not data.has(_SEALS_KEY):
		return ["missing '%s'" % _SEALS_KEY]
	if not data[_SEALS_KEY] is Array:
		return ["'%s' is not an array" % _SEALS_KEY]
	var seal_list: Array = data[_SEALS_KEY]
	var errors: Array[String] = []
	if seal_list.size() != SEAL_COUNT:
		errors.append("'%s' has %d seals, not %d" % [_SEALS_KEY, seal_list.size(), SEAL_COUNT])
	for index: int in seal_list.size():
		errors.append_array(_validate_seal(seal_list, index))
	return errors


## Errors for seal [param index] of [param seal_list]: not a glyph index, or a repeat of an
## earlier seal.
static func _validate_seal(seal_list: Array, index: int) -> Array[String]:
	var seal: Variant = seal_list[index]
	if not JsonLimits.is_exact_int(seal):
		return ["seal %d is not a whole number" % (index + 1)]
	var glyph: int = type_convert(seal, TYPE_INT)
	if glyph < 0 or glyph >= GLYPH_COUNT:
		return ["seal %d is %d, not a glyph from 0 to %d" % [index + 1, glyph, GLYPH_COUNT - 1]]
	for earlier: int in index:
		var other: Variant = seal_list[earlier]
		if JsonLimits.is_exact_int(other) and type_convert(other, TYPE_INT) == glyph:
			return ["seal %d repeats glyph %d from seal %d" % [index + 1, glyph, earlier + 1]]
	return []
