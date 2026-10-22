class_name NeighbourClues
extends RefCounted
## Neighbour clue: the target shares its first n seals (n >= 2) with a known reference world and
## differs at seal n + 1. The clue names the reference and its address, never the target.
## Bible: gate-and-address-spec.md#clue-types-and-reliability


## Returns a neighbour clue for the context's target, or null when no world shares enough seals.
static func make(context: ClueContext) -> ClueRecord:
	context.ensure_references()
	if context.ref_worlds.is_empty():
		return null
	var pick: int = context.rng.randi_range(0, context.ref_worlds.size() - 1)
	var reference: WorldRecord = context.ref_worlds[pick]
	var other: Array[int] = context.ref_addresses[pick].coordinates
	var shared: int = context.ref_shared[pick]
	var constraints: Array[AddressConstraint] = []
	for seal: int in range(1, shared + 1):
		constraints.append(AddressConstraint.glyph_at(seal, other[seal - 1]))
	constraints.append(AddressConstraint.glyph_not_at(shared + 1, other[shared]))
	var text: Dictionary = {
		"key": "CLUE_NEIGHBOUR",
		"args":
		{
			"world": reference.designation,
			"count": shared,
			"address": context.ref_addresses[pick].key()
		},
	}
	return ClueCommon.make_record(context, ClueRecord.Kind.NEIGHBOUR, constraints, text)
