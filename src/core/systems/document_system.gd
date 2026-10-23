class_name DocumentSystem
extends SimSystem
## Delivers documents to the Archive when the story says so, after GateSystem. A document
## with Arrival.ON_FIRST_LOCK arrives on the tick its world is locked, unless the Archive
## already holds it, so locking the world again later, or after a save and reload, never
## delivers it twice. AT_START documents are delivered once by GameSetup.build_new(), through
## [method deliver_start_documents].
## [br][br]
## "Locked this tick" is read from the Dial Log: GateSystem stamps its entry with the tick
## the tick being run ends at (clock tick + 1), and logs a lock only on that tick, so the
## newest entry is the one to look at. Nothing is remembered between ticks.
## [br][br]
## Posts document_received(document id) for each delivery, and one
## pause_requested(&"document_received") on a tick with any.
## Bible: technical-architecture.md#narrative-and-event-scripting,
## gate-and-address-spec.md#where-addresses-come-from

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


## Delivers the ON_FIRST_LOCK documents of the world locked this tick, in id order, that the
## Archive does not hold yet, and requests one pause when any arrived.
func tick(state: GameState) -> void:
	var world_id: StringName = _world_locked_this_tick(state)
	if world_id.is_empty():
		return
	var delivered: bool = false
	for def: DocumentDef in _documents:
		if def.arrival != DocumentDef.Arrival.ON_FIRST_LOCK or def.arrival_world_id != world_id:
			continue
		if state.archive.has_document(def.id):
			continue
		DeliverDocumentCommand.deliver(state, def.id)
		delivered = true
	if delivered:
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


## The world a dial locked on the tick being run, or &"" when none did.
func _world_locked_this_tick(state: GameState) -> StringName:
	if state.gate.dial_log.is_empty():
		return &""
	var entry: DialLogEntry = state.gate.dial_log.back()
	if entry.tick != state.clock.tick + 1 or not DialOutcome.is_lock(entry.outcome):
		return &""
	return entry.world_id
