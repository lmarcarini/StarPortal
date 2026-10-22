class_name SkyChartClues
extends RefCounted
## Sky chart clue: the seven coordinates drawn in a shuffled order that is never the address
## order, so the picture does not leak the sequence.
## Bible: gate-and-address-spec.md#clue-types-and-reliability


## Returns a sky chart clue for the context's target.
static func make(context: ClueContext) -> ClueRecord:
	var coordinates: Array[int] = context.address.coordinates
	var constraints: Array[AddressConstraint] = [AddressConstraint.exact_set(coordinates)]
	var text: Dictionary = {"key": "CLUE_SKY_CHART"}
	var record: ClueRecord = ClueCommon.make_record(
		context, ClueRecord.Kind.SKY_CHART, constraints, text
	)
	var order: Array[int] = ClueCommon.shuffled(context.rng, coordinates)
	while order == coordinates:
		order = ClueCommon.shuffled(context.rng, coordinates)
	record.image_glyphs = order
	return record
