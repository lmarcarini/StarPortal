class_name PictorialClues
extends RefCounted
## Pictorial clue: one seal of the address, shown as a sketch of its glyph.
## Bible: gate-and-address-spec.md#clue-types-and-reliability


## Returns a pictorial clue for the context's target.
static func make(context: ClueContext) -> ClueRecord:
	var seal: int = ClueCommon.random_seals(context.rng, 1)[0]
	var glyph: int = context.address.coordinates[seal - 1]
	var constraints: Array[AddressConstraint] = [AddressConstraint.glyph_at(seal, glyph)]
	var text: Dictionary = {"key": "CLUE_PICTORIAL", "args": {"seal": seal, "picture": glyph}}
	var record: ClueRecord = ClueCommon.make_record(
		context, ClueRecord.Kind.PICTORIAL, constraints, text
	)
	record.image_glyphs = [glyph]
	return record
