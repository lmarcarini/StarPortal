class_name FragmentClues
extends RefCounted
## Fragment clue: one or two seals of the address, read out directly.
## Bible: gate-and-address-spec.md#clue-types-and-reliability


## Returns a fragment clue for the context's target.
static func make(context: ClueContext) -> ClueRecord:
	var seals: Array[int] = ClueCommon.random_seals(context.rng, context.rng.randi_range(1, 2))
	var constraints: Array[AddressConstraint] = []
	var glyphs: Array[int] = []
	for seal: int in seals:
		var glyph: int = context.address.coordinates[seal - 1]
		glyphs.append(glyph)
		constraints.append(AddressConstraint.glyph_at(seal, glyph))
	var text: Dictionary = {
		"key": "CLUE_FRAGMENT_ONE", "args": {"seal": seals[0], "glyph": glyphs[0]}
	}
	if seals.size() == 2:
		text = {
			"key": "CLUE_FRAGMENT_TWO",
			"args":
			{"seal_a": seals[0], "glyph_a": glyphs[0], "seal_b": seals[1], "glyph_b": glyphs[1]},
		}
	return ClueCommon.make_record(context, ClueRecord.Kind.FRAGMENT, constraints, text)
