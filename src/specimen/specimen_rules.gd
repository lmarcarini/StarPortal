class_name SpecimenRules
extends RefCounted
## Specimens of alien life (docs/content/research-and-progression.md sections 3 and 10):
## what a world gives (plants, or animals where animals or people live; nothing on a dead
## world), the three ways they come home (a returning team, the sample canister once Sample
## canister is researched, the MOTH's sampler once MOTH Mk II is), spoiling after SPOIL_DAYS
## unless a Bio Lab's cold store is running, and spending the oldest first. Changes the state
## only in add(), spoil() and spend(), called from systems and commands.
## Bible: docs/content/research-and-progression.md sections 3, 9 and 10

## Days a specimen keeps without a cold store.
const SPOIL_DAYS: int = 10
## Flag set by Sample canister (E15): the canister brings back a specimen.
const CANISTER_FLAG: StringName = &"specimen_canister"
## Flag set by MOTH Mk II (E16): a MOTH scan brings back a specimen.
const SAMPLER_FLAG: StringName = &"moth_sampler"
## The cold store installation (M7-06) and its host.
const COLD_STORE: StringName = &"installation_cold_store"
const BIO_LAB: StringName = &"room_bio_lab"


## The kind of specimen world [param world_id] gives, or &"" for none (no life, or unknown).
static func kind_of(state: GameState, world_id: StringName) -> StringName:
	var facts: WorldFacts = WorldFactRules.facts_for_id(state.galaxy, world_id)
	if facts == null:
		return &""
	match facts.life:
		WorldDef.Life.PLANTS:
			return &"plants"
		WorldDef.Life.ANIMALS, WorldDef.Life.PEOPLE:
			return &"animals"
	return &""


## Adds a specimen from [param world_id] when it has life; posts specimen_arrived(uid).
## Returns its uid, or -1 when the world gives none.
static func add(state: GameState, world_id: StringName) -> int:
	var kind: StringName = kind_of(state, world_id)
	if kind.is_empty():
		return -1
	var record := SpecimenRecord.new()
	record.uid = state.artefacts.next_specimen_uid
	state.artefacts.next_specimen_uid += 1
	record.world_id = world_id
	record.kind = kind
	record.arrived_tick = state.clock.tick
	state.artefacts.specimens.append(record)
	state.events.post(&"specimen_arrived", [record.uid, world_id])
	return record.uid


## True when a Bio Lab of [param state] has a built cold store and is running.
static func has_cold_store(state: GameState) -> bool:
	for room: RoomState in state.base.rooms:
		if room.def_id == BIO_LAB and InstallationRules.active(state, room.id, COLD_STORE):
			return true
	return false


## Days [param record] has left before it spoils in [param state] (-1 while kept cold).
static func days_left(state: GameState, record: SpecimenRecord) -> int:
	if has_cold_store(state):
		return -1
	var age: int = state.clock.tick - record.arrived_tick
	return maxi(0, SPOIL_DAYS - age / TimeMath.TICKS_PER_DAY)


## Removes the specimens that have spoiled (none while a cold store runs), posting
## specimen_spoiled(uid, world id) for each. Returns how many spoiled.
static func spoil(state: GameState) -> int:
	if has_cold_store(state):
		return 0
	var limit: int = SPOIL_DAYS * TimeMath.TICKS_PER_DAY
	var count: int = 0
	for record: SpecimenRecord in state.artefacts.specimens.duplicate():
		if state.clock.tick - record.arrived_tick >= limit:
			state.artefacts.specimens.erase(record)
			state.events.post(&"specimen_spoiled", [record.uid, record.world_id])
			count += 1
	return count


## Removes [param count] specimens, the oldest first.
static func spend(state: GameState, count: int) -> void:
	for index: int in mini(count, state.artefacts.specimens.size()):
		state.artefacts.specimens.remove_at(0)
