class_name DialResolver
extends RefCounted
## Decides what the Ring reports for a dial. Pure static, read only over the galaxy. The
## answer depends only on the whole address, never on which seal is wrong: all eight seals
## always engage before any failure, so a failed dial cannot be narrowed seal by seal.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy


## Returns {"outcome": DialOutcome.Kind, "world_id": StringName} for dialing the well-formed
## [param address] from the home Ring of [param galaxy]. Checked in this order:
## [br]1. No world has these seven coordinates from the home origin, or the match is the
## home Ring itself: NO_GATE, with an empty world id.
## [br]2. Seal 8 is not the home Ring's origin glyph: ORIGIN_REJECTED.
## [br]3. The world's Ring is BURIED or SHIELDED: BLOCKED.
## [br]4. The world is guarded: HOSTILE_LOCK.
## [br]5. Otherwise LOCK.
## [br]From step 2 on, "world_id" is the matched world.
static func resolve(address: GateAddress, galaxy: GalaxyCatalogue) -> Dictionary:
	assert(address != null and galaxy != null, "DialResolver.resolve(): no address or galaxy")
	if address == null or galaxy == null:
		return _answer(DialOutcome.Kind.NO_GATE, &"")
	var home: WorldRecord = galaxy.home()
	var world: WorldRecord = galaxy.find_by_coordinates(address.coordinates, home.origin_glyph)
	if world == null or world.is_home:
		return _answer(DialOutcome.Kind.NO_GATE, &"")
	if address.origin != home.origin_glyph:
		return _answer(DialOutcome.Kind.ORIGIN_REJECTED, world.id)
	if world.ring_status != WorldDef.RingStatus.OPEN:
		return _answer(DialOutcome.Kind.BLOCKED, world.id)
	if world.is_guarded:
		return _answer(DialOutcome.Kind.HOSTILE_LOCK, world.id)
	return _answer(DialOutcome.Kind.LOCK, world.id)


static func _answer(outcome: DialOutcome.Kind, world_id: StringName) -> Dictionary:
	return {"outcome": outcome, "world_id": world_id}
