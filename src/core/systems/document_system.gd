class_name DocumentSystem
extends SimSystem
## Delivers documents to the Archive when the story says so, after GateSystem, and moves the
## pole camera. A document with Arrival.ON_FIRST_LOCK arrives with the first horizon record of
## its world: when the pole camera (ExtendPoleCameraCommand) finishes extending into that world
## through the open wormhole. The record is taken once per world (WorldsState.horizon_records),
## and a document the Archive already holds is skipped, so nothing is ever delivered twice.
## AT_START documents are delivered once by GameSetup.build_new(), through
## [method deliver_start_documents].
## [br][br]
## The camera: each tick it is out, it is pulled back with nothing taken when the Ring no longer
## holds a wormhole to its world (closed this tick or earlier, by the player, a time-out or the
## power); otherwise one tick of its extension passes, and on the last one the record is taken.
## A camera sent at the start of tick T takes the record on tick T + EXTEND_TICKS - 1.
## [br][br]
## The record raises the world's report through WorldProgress.record_horizon (atmosphere,
## temperature, radiation; threat to POOR). Posts horizon_record_taken(world id) for each
## record, then document_received(document id) for each delivery, and one
## pause_requested(&"document_received") on a tick with any.
## Bible: technical-architecture.md#narrative-and-event-scripting,
## gate-and-address-spec.md#where-addresses-come-from,
## game-design.md#base-building-and-power (the pole camera, horizon record)

## Reason of the pause request a delivery posts.
const PAUSE_REASON: StringName = &"document_received"

var _documents: Array[DocumentDef] = []


## Creates the system over [param documents], the DocumentDefs of the game.
func _init(documents: Array[DocumentDef] = []) -> void:
	_documents = documents.duplicate()
	_documents.sort_custom(
		func(a: DocumentDef, b: DocumentDef) -> bool: return String(a.id) < String(b.id)
	)


## Returns the system id, &"documents".
func get_id() -> StringName:
	return &"documents"


## Moves the pole camera when it is out; when it reaches the horizon, takes the record and
## delivers the world's ON_FIRST_LOCK documents in id order that the Archive does not hold yet,
## requesting one pause when any arrived.
func tick(state: GameState) -> void:
	var worlds: WorldsState = state.worlds
	if not worlds.is_pole_camera_out():
		return
	var world_id: StringName = worlds.pole_camera_world_id
	var gate: GateState = state.gate
	if gate.mode != GateState.RingMode.LOCKED or gate.connected_world_id != world_id:
		worlds.retract_pole_camera()
		return
	worlds.pole_camera_ticks_left -= 1
	if worlds.pole_camera_ticks_left > 0:
		return
	worlds.retract_pole_camera()
	worlds.horizon_records[world_id] = true
	state.events.post(&"horizon_record_taken", [world_id])
	WorldProgress.record_horizon(state, world_id)
	if ResearchPerks.has(state, ResearchPerks.ATMOSPHERIC_SAMPLING):
		WorldProgress.record_hazards(state, world_id)
	if _deliver_first_lock_documents(state, world_id):
		state.events.post(&"pause_requested", [PAUSE_REASON])


## Delivers every AT_START document of [param documents] that the Archive does not hold, in
## id order, at the clock's tick. Posts document_received for each, no pause request: a new
## game starts paused.
static func deliver_start_documents(state: GameState, documents: Array[DocumentDef]) -> void:
	var starting: Array[DocumentDef] = documents.filter(
		func(def: DocumentDef) -> bool: return def.arrival == DocumentDef.Arrival.AT_START
	)
	starting.sort_custom(
		func(a: DocumentDef, b: DocumentDef) -> bool: return String(a.id) < String(b.id)
	)
	for def: DocumentDef in starting:
		if not state.archive.has_document(def.id):
			DeliverDocumentCommand.deliver(state, def.id)


## Delivers the ON_FIRST_LOCK documents of [param world_id] that the Archive does not hold, in
## id order; true when any arrived.
func _deliver_first_lock_documents(state: GameState, world_id: StringName) -> bool:
	var delivered: bool = false
	for def: DocumentDef in _documents:
		if def.arrival != DocumentDef.Arrival.ON_FIRST_LOCK or def.arrival_world_id != world_id:
			continue
		if state.archive.has_document(def.id):
			continue
		DeliverDocumentCommand.deliver(state, def.id)
		delivered = true
	return delivered
