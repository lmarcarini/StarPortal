class_name OpeningScenario
extends RefCounted
## The M1 opening: three reachable procedural worlds become the first targets (preferring
## different seal-1 glyphs; see pick_targets()), and their dossiers arrive at the start of
## days 1, 2 and 3. Pure static; randomness comes only from the rng passed in or the state's
## &"scenario" stream. Runs for a new game only, never on load.
## Bible: roadmap.md (M1 milestone check), gate-and-address-spec.md#puzzle-tuning-rules,
## gate-and-address-spec.md#dialing-outcomes-and-energy

## Number of opening targets, one dossier each.
const TARGET_COUNT: int = 3
## Random stream the targets are drawn from.
const STREAM_ID: StringName = &"scenario"
## Most candidates an opening dossier may leave: rule 2, "last step by dialing".
const MAX_CANDIDATES: int = 3


## Returns up to [param count] target ids, drawn with [param rng] from the procedural worlds
## that are OPEN, unguarded and dialable from the home Ring with a full starting bank
## ([member BalanceConfig.starting_capacity_mwh]). Worlds whose seal-1 glyph no earlier pick
## has come first; when too few distinct glyphs are reachable, repeats fill the rest (product
## owner ruling, option 3). Lock energy depends only on how far seal 1's anchor is from home,
## and with today's content and the 400 MWh bank only anchor 35 is close enough, so all three
## targets start with glyph 35: neighbouring worlds looking alike is a designed theme, and
## M2's bigger banks widen the reach. Fewer targets when too few worlds qualify (warns).
## Same inputs, same ids.
static func pick_targets(
	galaxy: GalaxyCatalogue, balance: BalanceConfig, rng: RandomNumberGenerator, count: int
) -> Array[StringName]:
	var eligible: Array[WorldRecord] = _eligible_worlds(galaxy, balance)
	var indices: Array[int] = []
	for index: int in eligible.size():
		indices.append(index)
	var origin: int = galaxy.home().origin_glyph
	var used_first_glyphs: Dictionary[int, bool] = {}
	var picked: Array[StringName] = []
	var repeats: Array[StringName] = []
	for index: int in ClueCommon.shuffled(rng, indices):
		var world: WorldRecord = eligible[index]
		var first_glyph: int = galaxy.address_of(world.id, origin).coordinates[0]
		if used_first_glyphs.has(first_glyph):
			repeats.append(world.id)
		elif picked.size() < count:
			used_first_glyphs[first_glyph] = true
			picked.append(world.id)
	for world_id: StringName in repeats:
		if picked.size() >= count:
			break
		picked.append(world_id)
	if picked.size() < count:
		push_warning("OpeningScenario: only %d of %d targets found" % [picked.size(), count])
	return picked


## Plans the opening of the new game [param state], whose balance and galaxy GameSetup has
## set: picks TARGET_COUNT targets from the &"scenario" stream and schedules dossier n at the
## start of day n, counted from the clock's tick (tick 0, 1440 and 2880 on a new game).
static func plan(state: GameState) -> void:
	assert(state.galaxy != null and state.balance != null, "OpeningScenario: no galaxy or balance")
	if state.galaxy == null or state.balance == null:
		return
	var rng: RandomNumberGenerator = state.random.stream(STREAM_ID)
	var targets: Array[StringName] = pick_targets(state.galaxy, state.balance, rng, TARGET_COUNT)
	for index: int in targets.size():
		var arrival: int = state.clock.tick + index * TimeMath.TICKS_PER_DAY
		state.intel.scheduled_dossiers[targets[index]] = arrival


## Returns the tuning of an opening dossier: the default ClueSetParams with at most
## MAX_CANDIDATES candidates left, so the last step is settled by at most three dials.
static func clue_params() -> ClueSetParams:
	var params := ClueSetParams.new()
	params.max_candidates = MAX_CANDIDATES
	return params


## Procedural worlds in generation order that are OPEN, unguarded and dialable with a full
## starting bank.
static func _eligible_worlds(galaxy: GalaxyCatalogue, balance: BalanceConfig) -> Array[WorldRecord]:
	var eligible: Array[WorldRecord] = []
	var origin: int = galaxy.home().origin_glyph
	var home_ly: Vector3i = galaxy.home().position_ly
	var anchors_ly: Array[Vector3i] = galaxy.anchors_ly()
	for world: WorldRecord in galaxy.all_worlds():
		if world.is_authored or world.is_guarded:
			continue
		if world.ring_status != WorldDef.RingStatus.OPEN:
			continue
		var address: GateAddress = galaxy.address_of(world.id, origin)
		var energy: float = EnergyMath.lock_energy_mwh(address, home_ly, anchors_ly, balance)
		if energy <= balance.starting_capacity_mwh:
			eligible.append(world)
	return eligible
