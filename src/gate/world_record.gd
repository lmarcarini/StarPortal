class_name WorldRecord
extends RefCounted
## One Ring-bearing world in the generated galaxy: a procedural world made by WorldGenerator, or
## an authored world copied from its WorldDef. Derived data: the galaxy is regenerated from its
## seed and WorldGenerator.GENERATOR_VERSION, never saved.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy

## &"world_0001"... for procedural worlds; authored worlds keep their definition id.
var id: StringName
## "R-0001"... for procedural worlds; "" for authored worlds (their names come from content).
var designation: String = ""
## Position in light years, in the same space as the anchors.
var position_ly: Vector3i
## This world's Ring's origin glyph, 0..35.
var origin_glyph: int = 0
## State of this world's Ring; BURIED and SHIELDED answer a dial with Blocked.
var ring_status: WorldDef.RingStatus = WorldDef.RingStatus.OPEN
## True when the far side is guarded: a lock here is a Hostile lock.
var is_guarded: bool = false
## True for a world copied from an authored WorldDef.
var is_authored: bool = false
## True only for the home Ring (CAIRN), which is always authored.
var is_home: bool = false
## The authored facts of an authored world; null for a procedural world, whose facts
## WorldFactRules derives from its id. Read facts through WorldFactRules.facts_of().
var authored_facts: WorldFacts = null


## Returns a record copying the authored world [param def].
static func from_def(def: WorldDef) -> WorldRecord:
	var record := WorldRecord.new()
	record.id = def.id
	record.position_ly = def.position_ly
	record.origin_glyph = def.origin_glyph
	record.ring_status = def.ring_status
	record.is_guarded = def.is_guarded
	record.is_authored = true
	record.is_home = def.is_home
	record.authored_facts = WorldFacts.from_def(def)
	return record
