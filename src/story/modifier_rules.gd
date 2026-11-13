class_name ModifierRules
extends RefCounted
## Sums every lasting modifier by key: the ModifierEffects of finished research and of
## artefacts housed in a built, switched-on room. Percent keys are clamped to −90..300. The sum
## is cached on GameState.modifiers and recomputed only when its sources change.
## Bible: docs/content/m4-core-systems.md section 6

## Lowest and highest total of a percent key.
const PERCENT_MIN: int = -90
const PERCENT_MAX: int = 300


## The total of [param key] (0 when no source gives it).
static func total(state: GameState, key: StringName) -> int:
	return totals(state).get(key, 0)


## [param base] changed by the percent total of [param key]: base × (100 + total) / 100.
static func percent(state: GameState, key: StringName, base: float) -> float:
	return base * float(100 + total(state, key)) / 100.0


## Every total, from the cache, rebuilt first when a source changed.
static func totals(state: GameState) -> Dictionary[StringName, int]:
	var signature: Array = _signature(state)
	if state.modifiers.signature != signature:
		state.modifiers.totals = compute(state)
		state.modifiers.signature = signature
		state.modifiers.rebuilds += 1
	return state.modifiers.totals


## The totals summed from scratch (no cache).
static func compute(state: GameState) -> Dictionary[StringName, int]:
	var sums: Dictionary[StringName, int] = {}
	for project_id: StringName in state.research.done:
		var project: ResearchDef = state.research_defs.get(project_id)
		if project != null:
			for effect: EffectDef in project.effects:
				if effect is ModifierEffect:
					_add(sums, effect as ModifierEffect)
	for record: ArtefactRecord in state.artefacts.items:
		var artefact: ArtefactDef = state.artefact_defs.get(record.artefact)
		if artefact != null and is_room_working(state, record.room_uid):
			for modifier: ModifierEffect in artefact.modifiers:
				_add(sums, modifier)
	for key: StringName in sums:
		if is_percent(key):
			sums[key] = clampi(sums[key], PERCENT_MIN, PERCENT_MAX)
	return sums


## True for a key whose name ends in "_pct".
static func is_percent(key: StringName) -> bool:
	return String(key).ends_with("_pct")


## The room id of room uid [param room_uid] (room ids are "room_<n>").
static func room_id_of(room_uid: int) -> StringName:
	return StringName("room_%d" % room_uid)


## True when room uid [param room_uid] is built, not being demolished and switched on.
static func is_room_working(state: GameState, room_uid: int) -> bool:
	if room_uid < 0:
		return false
	var room: RoomState = state.base.find_room(room_id_of(room_uid))
	if room == null:
		return false
	return room.build_ticks_left == 0 and room.demolish_ticks_left == 0 and room.powered_on


static func _add(sums: Dictionary[StringName, int], modifier: ModifierEffect) -> void:
	sums[modifier.key] = sums.get(modifier.key, 0) + modifier.amount


## Everything the totals depend on, cheap to build: room changes, research done and where
## each artefact is.
static func _signature(state: GameState) -> Array:
	var placed: PackedInt64Array = []
	for record: ArtefactRecord in state.artefacts.items:
		placed.append(record.uid)
		placed.append(record.room_uid)
	return [
		RoomState.revision,
		state.base.get_instance_id(),
		state.base.rooms.size(),
		state.base.next_room_number,
		state.research.done.size(),
		state.research_defs.size(),
		state.artefact_defs.size(),
		placed,
	]
