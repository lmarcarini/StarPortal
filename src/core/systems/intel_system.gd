class_name IntelSystem
extends SimSystem
## Delivers the scheduled dossiers, after GateSystem. Each tick, every dossier whose arrival
## tick has come is written by ClueGenerator from the &"intel" stream, numbered
## (&"dossier_01"..., clues &"clue_0001"...), stamped with the delivery tick and added to the
## intel state in arrival order (by tick, then world id). Posts clue_received(clue id) per
## clue, then one pause_requested(&"dossier_received") for the tick. Reads the transient
## galaxy on the state.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#puzzle-tuning-rules, game-design.md#time-real-time-with-pause

## Random stream the dossiers are written from.
const STREAM_ID: StringName = &"intel"
## Reason of the pause asked for when a dossier arrives.
const PAUSE_REASON: StringName = &"dossier_received"

var _params: ClueSetParams


## Creates the system; dossiers are tuned by [param params] (OpeningScenario.clue_params()
## when null).
func _init(params: ClueSetParams = null) -> void:
	_params = params if params != null else OpeningScenario.clue_params()


## Returns the system id, &"intel".
func get_id() -> StringName:
	return &"intel"


## Delivers every dossier due at or before the clock's tick.
func tick(state: GameState) -> void:
	var due: Array[StringName] = _due_dossiers(state.intel.scheduled_dossiers, state.clock.tick)
	if due.is_empty():
		return
	assert(state.galaxy != null, "IntelSystem: no galaxy")
	if state.galaxy == null:
		return
	for world_id: StringName in due:
		state.intel.scheduled_dossiers.erase(world_id)
		_deliver(state, world_id)
	state.events.post(Simulation.PAUSE_EVENT, [PAUSE_REASON])


## Writes, numbers and adds the dossier on [param world_id], posting clue_received per clue.
func _deliver(state: GameState, world_id: StringName) -> void:
	var intel: IntelState = state.intel
	var rng: RandomNumberGenerator = state.random.stream(STREAM_ID)
	var clues: Array[ClueRecord] = ClueGenerator.generate_dossier(
		world_id, state.galaxy, rng, _params
	)
	var dossier_id := StringName("dossier_%02d" % intel.next_dossier_number)
	intel.next_dossier_number += 1
	for clue: ClueRecord in clues:
		clue.id = StringName("clue_%04d" % intel.next_clue_number)
		intel.next_clue_number += 1
		clue.dossier_id = dossier_id
		clue.received_tick = state.clock.tick
		intel.add_clue(clue)
		state.events.post(&"clue_received", [clue.id])


## World ids of the dossiers in [param schedule] due by [param now], by tick then id.
static func _due_dossiers(schedule: Dictionary[StringName, int], now: int) -> Array[StringName]:
	var due: Array[StringName] = []
	for world_id: StringName in schedule:
		if schedule[world_id] <= now:
			due.append(world_id)
	due.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			if schedule[a] != schedule[b]:
				return schedule[a] < schedule[b]
			return String(a) < String(b)
	)
	return due
