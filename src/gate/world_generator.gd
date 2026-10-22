class_name WorldGenerator
extends RefCounted
## Places the procedural Ring worlds of the home domain from a seed. Pure static: the galaxy is
## derived data, regenerated from (seed, GENERATOR_VERSION, anchors, authored worlds, params),
## so every random draw comes from one local generator seeded from the argument, positions are
## integers, and no output depends on Dictionary order (dictionaries are only membership sets).
##
## Steps, in this fixed order:
## 1. Authored worlds are registered first (their addresses must already be unique).
## 2. Early reach: min_reach_worlds worlds are sampled in a box around the home Ring, keeping only
##    those whose lock energy from home (EnergyMath) fits reach_energy_mwh. The box half-size is
##    the distance at which that budget runs out, d = (E_reach / (E_base * M_8) - 1) * d_ref.
## 3. The remaining worlds are sampled uniformly within +/- half_extents_ly.
## 4. Origin glyphs, Ring statuses and guards are drawn. Reach worlds stay OPEN and unguarded;
##    exact counts (fraction * world_count, rounded) of BURIED, SHIELDED and guarded worlds are
##    picked among the others. Finally the order is shuffled before numbering, so designations
##    say nothing about distance from home.
## A candidate is rejected when it is closer than min_spacing_ly to a world or an anchor, or when
## its address from any of the 36 origins equals another world's address from that origin.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## gate-and-address-spec.md#dialing-outcomes-and-energy, overview.md#locked-decisions,
## technical-architecture.md#determinism-and-numbers

## Version of the placement algorithm: bump it whenever the same seed would give another galaxy.
const GENERATOR_VERSION: int = 1
## Candidates tried per world before generation gives up (asserts) on an impossible request.
const MAX_ATTEMPTS_PER_WORLD: int = 10_000
const _ID_FORMAT: String = "world_%04d"
const _DESIGNATION_FORMAT: String = "R-%04d"


## Mutable state of one generate() call.
class Placement:
	extends RefCounted
	## Anchor positions, indexed by glyph.
	var anchors_ly: Array[Vector3i] = []
	## The one random source of the call.
	var rng := RandomNumberGenerator.new()
	## min_spacing_ly squared.
	var spacing_squared: int = 0
	## Every placed world, authored first, in placement order.
	var positions: Array[Vector3i] = []
	## Per origin glyph: set of the address keys (GateAddress.key()) already used.
	var taken: Array[Dictionary] = []


## Returns the galaxy for [param seed]: records of the [param authored] worlds (in the order
## given), then [member GeneratorParams.world_count] procedural worlds in numbering order.
## [param anchors_ly] holds the 36 anchors, indexed by glyph. Exactly one authored world must be
## the home Ring (asserted); without it, or with bad inputs, returns only the authored records.
@warning_ignore("shadowed_global_identifier")
static func generate(  # gdlint: ignore=function-arguments-number
	seed: int,
	anchors_ly: Array[Vector3i],
	authored: Array[WorldDef],
	params: GeneratorParams,
	balance: BalanceConfig
) -> Array[WorldRecord]:
	var worlds: Array[WorldRecord] = []
	for def: WorldDef in authored:
		worlds.append(WorldRecord.from_def(def))
	var home: WorldDef = _find_home(authored)
	var is_valid: bool = (
		home != null
		and anchors_ly.size() == GateAddress.GLYPH_COUNT
		and params != null
		and balance != null
	)
	assert(is_valid, "WorldGenerator: needs one home world, 36 anchors, params and balance")
	if not is_valid:
		return worlds
	var state: Placement = _new_placement(seed, anchors_ly, params)
	for def: WorldDef in authored:
		var is_unique: bool = _try_place(state, def.position_ly, false)
		assert(is_unique, "WorldGenerator: authored world %s repeats an address" % def.id)
	var first_procedural: int = state.positions.size()
	var reach_count: int = _place_reach_worlds(state, home, params, balance)
	_place_uniform_worlds(state, params, params.world_count - reach_count)
	var placed: Array[Vector3i] = state.positions.slice(first_procedural)
	worlds.append_array(_make_records(state, placed, reach_count, params))
	return worlds


## The one authored world with is_home, or null when there is none or more than one.
static func _find_home(authored: Array[WorldDef]) -> WorldDef:
	var homes: Array[WorldDef] = authored.filter(func(def: WorldDef) -> bool: return def.is_home)
	if homes.size() != 1:
		return null
	return homes[0]


@warning_ignore("shadowed_global_identifier")
static func _new_placement(
	seed: int, anchors_ly: Array[Vector3i], params: GeneratorParams
) -> Placement:
	var state := Placement.new()
	state.rng.seed = seed
	state.anchors_ly = anchors_ly
	state.spacing_squared = params.min_spacing_ly * params.min_spacing_ly
	for _origin: int in GateAddress.GLYPH_COUNT:
		state.taken.append({})
	return state


## Places the early-reach worlds around [param home]; returns how many it placed.
static func _place_reach_worlds(
	state: Placement, home: WorldDef, params: GeneratorParams, balance: BalanceConfig
) -> int:
	var quota: int = mini(params.min_reach_worlds, params.world_count)
	if quota <= 0:
		return 0
	var radius: int = _reach_radius_ly(params, balance)
	var extents: Vector3i = params.half_extents_ly
	var low: Vector3i = (home.position_ly - Vector3i.ONE * radius).clamp(-extents, extents)
	var high: Vector3i = (home.position_ly + Vector3i.ONE * radius).clamp(-extents, extents)
	var placed: int = 0
	var attempts: int = quota * MAX_ATTEMPTS_PER_WORLD
	while placed < quota and attempts > 0 and radius >= 0:
		attempts -= 1
		var candidate: Vector3i = _sample(state.rng, low, high)
		var address: GateAddress = AddressRule.address_of(
			candidate, state.anchors_ly, home.origin_glyph
		)
		var energy: float = EnergyMath.lock_energy_mwh(
			address, home.position_ly, state.anchors_ly, balance
		)
		if energy <= params.reach_energy_mwh and _try_place(state, candidate, true):
			placed += 1
	assert(placed == quota, "WorldGenerator: early reach quota not met")
	return placed


## Distance from home at which a seal-1 anchor's lock energy reaches reach_energy_mwh, rounded
## down; -1 when even distance 0 costs more.
static func _reach_radius_ly(params: GeneratorParams, balance: BalanceConfig) -> int:
	var energy_at_zero: float = balance.lock_energy_base_mwh * balance.seal_multiplier_8
	var ratio: float = params.reach_energy_mwh / energy_at_zero - 1.0
	if ratio < 0.0:
		return -1
	return floori(ratio * balance.lock_reference_distance_ly)


## Places [param count] more worlds uniformly within the bounds.
static func _place_uniform_worlds(state: Placement, params: GeneratorParams, count: int) -> void:
	var target: int = state.positions.size() + count
	var attempts: int = count * MAX_ATTEMPTS_PER_WORLD
	var extents: Vector3i = params.half_extents_ly
	while state.positions.size() < target and attempts > 0:
		attempts -= 1
		_try_place(state, _sample(state.rng, -extents, extents), true)
	assert(state.positions.size() == target, "WorldGenerator: could not place every world")


## A uniform integer position in the box from [param low] to [param high], inclusive.
static func _sample(rng: RandomNumberGenerator, low: Vector3i, high: Vector3i) -> Vector3i:
	var x: int = rng.randi_range(low.x, high.x)
	var y: int = rng.randi_range(low.y, high.y)
	var z: int = rng.randi_range(low.z, high.z)
	return Vector3i(x, y, z)


## Registers a world at [param position_ly] when it is far enough from every world and anchor
## (only if [param check_spacing]) and its 36 addresses are all unused. Returns whether it did.
static func _try_place(state: Placement, position_ly: Vector3i, check_spacing: bool) -> bool:
	if check_spacing and not _is_spaced(state, position_ly):
		return false
	var keys: PackedStringArray = _free_keys(state, position_ly)
	if keys.is_empty():
		return false
	state.positions.append(position_ly)
	for origin: int in GateAddress.GLYPH_COUNT:
		state.taken[origin][keys[origin]] = true
	return true


## True when [param position_ly] is at least min_spacing_ly from every placed world and anchor.
static func _is_spaced(state: Placement, position_ly: Vector3i) -> bool:
	for other: Vector3i in state.anchors_ly:
		if AddressRule.squared_distance(position_ly, other) < state.spacing_squared:
			return false
	for other: Vector3i in state.positions:
		if AddressRule.squared_distance(position_ly, other) < state.spacing_squared:
			return false
	return true


## The address keys of [param position_ly] from each origin 0..35, in origin order; empty when
## any of them is already taken. One sort of all 36 anchors serves every origin.
static func _free_keys(state: Placement, position_ly: Vector3i) -> PackedStringArray:
	var sorted: Array[int] = AddressRule.nearest_anchors(
		position_ly, state.anchors_ly, -1, GateAddress.GLYPH_COUNT
	)
	var keys := PackedStringArray()
	for origin: int in GateAddress.GLYPH_COUNT:
		var address := GateAddress.create(_coordinates_without(sorted, origin), origin)
		var key: String = address.key()
		if state.taken[origin].has(key):
			return PackedStringArray()
		keys.append(key)
	return keys


## The first seven glyphs of [param sorted] (all anchors, nearest first) other than
## [param origin]: the address coordinates from that origin.
static func _coordinates_without(sorted: Array[int], origin: int) -> Array[int]:
	var coordinates: Array[int] = []
	for glyph: int in sorted:
		if glyph == origin:
			continue
		coordinates.append(glyph)
		if coordinates.size() == GateAddress.COORDINATE_COUNT:
			break
	return coordinates


## Builds the procedural records for [param placed] (the first [param reach_count] are the
## early-reach worlds): origins, statuses, guards, then shuffled numbering.
static func _make_records(
	state: Placement, placed: Array[Vector3i], reach_count: int, params: GeneratorParams
) -> Array[WorldRecord]:
	var records: Array[WorldRecord] = []
	for position_ly: Vector3i in placed:
		var record := WorldRecord.new()
		record.position_ly = position_ly
		record.origin_glyph = state.rng.randi_range(0, GateAddress.GLYPH_COUNT - 1)
		records.append(record)
	var others: Array[int] = []
	for index: int in range(reach_count, records.size()):
		others.append(index)
	_assign_statuses(state.rng, records, others, params)
	var guarded: Array[int] = _shuffled(state.rng, others)
	var guard_count: int = mini(roundi(params.guarded_fraction * records.size()), guarded.size())
	for index: int in guarded.slice(0, guard_count):
		records[index].is_guarded = true
	return _numbered(state.rng, records)


## Marks exact shares of [param others] (indices into [param records]) BURIED, then SHIELDED.
static func _assign_statuses(
	rng: RandomNumberGenerator,
	records: Array[WorldRecord],
	others: Array[int],
	params: GeneratorParams
) -> void:
	var order: Array[int] = _shuffled(rng, others)
	var buried: int = mini(roundi(params.buried_fraction * records.size()), order.size())
	var shielded: int = mini(
		roundi(params.shielded_fraction * records.size()), order.size() - buried
	)
	for rank: int in buried + shielded:
		var status := WorldDef.RingStatus.BURIED if rank < buried else WorldDef.RingStatus.SHIELDED
		records[order[rank]].ring_status = status


## Returns [param records] in a shuffled order, numbered 1..n: ids and designations.
static func _numbered(
	rng: RandomNumberGenerator, records: Array[WorldRecord]
) -> Array[WorldRecord]:
	var indices: Array[int] = []
	for index: int in records.size():
		indices.append(index)
	var numbered: Array[WorldRecord] = []
	for index: int in _shuffled(rng, indices):
		var record: WorldRecord = records[index]
		var number: int = numbered.size() + 1
		record.id = StringName(_ID_FORMAT % number)
		record.designation = _DESIGNATION_FORMAT % number
		numbered.append(record)
	return numbered


## A Fisher-Yates shuffle of a copy of [param values] driven by [param rng]; Array's built-in
## shuffle would draw from the global generator.
static func _shuffled(rng: RandomNumberGenerator, values: Array[int]) -> Array[int]:
	var result: Array[int] = values.duplicate()
	for index: int in range(result.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: int = result[index]
		result[index] = result[other]
		result[other] = swap
	return result
