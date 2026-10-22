class_name ContentCheckGalaxy
extends RefCounted
## Content check 5: one generated galaxy against the real data: the right number of worlds, the
## early-reach guarantee and unique addresses from every origin. Pure functions over a list of
## world records; they return one line per problem.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy


## Returns the problems of [param worlds] (as WorldGenerator.generate() returns them): not
## params.world_count procedural worlds, fewer than params.min_reach_worlds reachable ones, an
## origin glyph outside 0..35, or two worlds with the same address from one origin.
static func check(
	worlds: Array[WorldRecord],
	anchors_ly: Array[Vector3i],
	params: GeneratorParams,
	balance: BalanceConfig
) -> Array[String]:
	var errors: Array[String] = []
	var procedural: int = (
		worlds.filter(func(w: WorldRecord) -> bool: return not w.is_authored).size()
	)
	if procedural != params.world_count:
		errors.append(
			"generated %d procedural worlds, expected %d" % [procedural, params.world_count]
		)
	var reach: int = reachable(worlds, anchors_ly, params, balance).size()
	if reach < params.min_reach_worlds:
		errors.append(
			(
				"only %d worlds are open, unguarded and within %s MWh of home, expected %d"
				% [reach, params.reach_energy_mwh, params.min_reach_worlds]
			)
		)
	errors.append_array(_check_addresses(worlds, anchors_ly))
	return errors


## Returns the procedural worlds the early-reach guarantee counts: Ring OPEN, not guarded, and a
## lock energy from the home Ring of at most params.reach_energy_mwh. Empty without a home world.
static func reachable(
	worlds: Array[WorldRecord],
	anchors_ly: Array[Vector3i],
	params: GeneratorParams,
	balance: BalanceConfig
) -> Array[WorldRecord]:
	var found: Array[WorldRecord] = []
	var homes: Array[WorldRecord] = worlds.filter(func(w: WorldRecord) -> bool: return w.is_home)
	if homes.size() != 1 or anchors_ly.size() != GateAddress.GLYPH_COUNT:
		return found
	var home: WorldRecord = homes[0]
	for world: WorldRecord in worlds:
		var is_candidate: bool = (
			not world.is_authored
			and world.ring_status == WorldDef.RingStatus.OPEN
			and not world.is_guarded
		)
		if not is_candidate:
			continue
		var address: GateAddress = AddressRule.address_of(
			world.position_ly, anchors_ly, home.origin_glyph
		)
		var energy: float = EnergyMath.lock_energy_mwh(
			address, home.position_ly, anchors_ly, balance
		)
		if energy <= params.reach_energy_mwh:
			found.append(world)
	return found


## Returns one line per origin glyph and pair of worlds that share an address. The 36 addresses
## of a world come from one sort of the anchors.
static func _check_addresses(
	worlds: Array[WorldRecord], anchors_ly: Array[Vector3i]
) -> Array[String]:
	var errors: Array[String] = []
	var taken: Array[Dictionary] = []
	for _origin: int in GateAddress.GLYPH_COUNT:
		taken.append({})
	for world: WorldRecord in worlds:
		if world.origin_glyph < 0 or world.origin_glyph >= GateAddress.GLYPH_COUNT:
			errors.append(
				"world %s has origin glyph %d, expected 0..35" % [world.id, world.origin_glyph]
			)
		var sorted: Array[int] = AddressRule.nearest_anchors(
			world.position_ly, anchors_ly, -1, GateAddress.GLYPH_COUNT
		)
		for origin: int in GateAddress.GLYPH_COUNT:
			var key: String = _key(sorted, origin)
			if taken[origin].has(key):
				errors.append(
					(
						"worlds %s and %s share address %s from origin %d"
						% [taken[origin][key], world.id, key, origin]
					)
				)
			taken[origin][key] = world.id
	return errors


## The address key (GateAddress.key()) from [param origin], given every anchor nearest first.
static func _key(sorted: Array[int], origin: int) -> String:
	var parts: PackedStringArray = []
	for glyph: int in sorted:
		if glyph != origin and parts.size() < GateAddress.COORDINATE_COUNT:
			parts.append(str(glyph))
	parts.append(str(origin))
	return "-".join(parts)
