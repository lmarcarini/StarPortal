class_name OrdinalClues
extends RefCounted
## Ordinal clue: glyph a lies nearer than glyph b, where a is in the address and b is later in
## it or absent.
## Bible: gate-and-address-spec.md#clue-types-and-reliability


## Returns an ordinal clue for the context's target.
static func make(context: ClueContext) -> ClueRecord:
	var coordinates: Array[int] = context.address.coordinates
	var near_index: int = context.rng.randi_range(0, coordinates.size() - 1)
	var far_glyph: int = _farther_glyph(context, near_index)
	var near_glyph: int = coordinates[near_index]
	var constraints: Array[AddressConstraint] = [
		AddressConstraint.nearer_than(near_glyph, far_glyph)
	]
	var text: Dictionary = {
		"key": "CLUE_ORDINAL", "args": {"glyph_a": near_glyph, "glyph_b": far_glyph}
	}
	return ClueCommon.make_record(context, ClueRecord.Kind.ORDINAL, constraints, text)


## A glyph later in the address than [param near_index], or when that is not possible or by
## chance, a glyph that is not in the address and is not the origin.
static func _farther_glyph(context: ClueContext, near_index: int) -> int:
	var coordinates: Array[int] = context.address.coordinates
	var rng: RandomNumberGenerator = context.rng
	var has_later: bool = near_index < coordinates.size() - 1
	if has_later and rng.randi_range(0, 1) == 0:
		return coordinates[rng.randi_range(near_index + 1, coordinates.size() - 1)]
	var absent: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != context.origin and not coordinates.has(glyph):
			absent.append(glyph)
	return absent[rng.randi_range(0, absent.size() - 1)]
