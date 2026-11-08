extends Node
## Autoload. Domain events for the presentation layer: views subscribe here and redraw.
## The simulation never references this node; bind_simulation() forwards its signals,
## and re-emits each outbox event (Simulation.event_posted) as the signal of the same name
## declared here, with the same arguments.
## Bible: technical-architecture.md#architecture-overview

## Emitted after each simulation tick, by the clock.
@warning_ignore("unused_signal")
signal tick_advanced(tick: int)
## Emitted at the first tick of each day, with the new day's index.
signal day_started(day_index: int)
## Emitted when a submitted command fails validation.
signal command_rejected(type: StringName, code: StringName)
## Emitted when the simulation asks the clock to pause.
signal pause_requested(reason: StringName)
## Emitted when the clock speed changes.
@warning_ignore("unused_signal")
signal speed_changed(speed_index: int)
## Emitted when the clock pauses or resumes.
@warning_ignore("unused_signal")
signal paused_changed(is_paused: bool)
## Emitted when the clock's time-control mode changes, with the new ClockState.Mode.
@warning_ignore("unused_signal")
signal time_mode_changed(mode: int)
## Emitted after a save completes.
@warning_ignore("unused_signal")
signal game_saved(slot: StringName)
## Emitted after a load completes.
@warning_ignore("unused_signal")
signal game_loaded(slot: StringName)
## Emitted when the Ring starts dialing, with the dialed address's key (GateAddress.key())
## (posted through the outbox).
@warning_ignore("unused_signal")
signal dial_started(address_key: String)
## Emitted when a dial resolves, with its DialOutcome.Kind and the address key; nothing else,
## so a failure never tells which seal was wrong (posted through the outbox).
@warning_ignore("unused_signal")
signal dial_resolved(outcome: int, address_key: String)
## Emitted when the open wormhole closes: &"player", &"timeout" or &"power" (posted through
## the outbox).
@warning_ignore("unused_signal")
signal wormhole_closed(reason: StringName)
## Emitted when a document arrives in the Archive, with its DocumentDef id (posted through
## the outbox).
@warning_ignore("unused_signal")
signal document_received(document_id: StringName)
## Emitted when the Address Book changes: a dial recorded or a note set (posted through the
## outbox).
@warning_ignore("unused_signal")
signal address_book_changed
## Emitted when a Capacitor Bank room is completed and starts charging, with the new capacity
## in MWh (posted through the outbox).
@warning_ignore("unused_signal")
signal capacitors_installed(capacity_mwh: float)
## Emitted when the power allocation changes: a room switched, a charge rate set, a new bank
## or rooms switched off to fit the supply (posted through the outbox).
@warning_ignore("unused_signal")
signal power_allocation_changed
## Emitted when the pole camera takes a world's horizon record, with the world id (posted
## through the outbox).
@warning_ignore("unused_signal")
signal horizon_record_taken(world_id: StringName)
## Emitted when the budget changes, with the new balance in $k (posted through the outbox).
@warning_ignore("unused_signal")
signal budget_changed(budget_k: int)
## Emitted when the player reads a far Ring's console, with that world's id (posted through
## the outbox).
@warning_ignore("unused_signal")
signal console_read(world_id: StringName)
## Emitted when a world's state rises (WorldProgress), with the world id and the new
## WorldsState.WorldStatus (posted through the outbox).
@warning_ignore("unused_signal")
signal world_status_changed(world_id: StringName, status: int)
## Emitted when a World Report fact's confidence rises (WorldProgress), with the world id, the
## WorldReport.Fact and the new WorldReport.Confidence (posted through the outbox).
@warning_ignore("unused_signal")
signal world_fact_raised(world_id: StringName, fact: int, confidence: int)
## Emitted when a target's saved state rises (WorldProgress.raise_target), with the world id,
## target id and TargetStates.State (posted through the outbox).
@warning_ignore("unused_signal")
signal world_target_changed(world_id: StringName, target_id: StringName, state: int)
## Emitted when a sample canister is thrown through, with the world id (posted through the
## outbox).
@warning_ignore("unused_signal")
signal canister_launched(world_id: StringName)
## Emitted when the canister is reeled back, with the world id and its WorldDef.Biohazard
## (posted through the outbox).
@warning_ignore("unused_signal")
signal canister_returned(world_id: StringName, biohazard: int)
## Emitted when the wormhole closes with the canister out, with the world id (posted through
## the outbox).
@warning_ignore("unused_signal")
signal canister_lost(world_id: StringName)
## Emitted when a MOTH is sent through, with the world id (posted through the outbox).
@warning_ignore("unused_signal")
signal moth_launched(world_id: StringName)
## Emitted when the MOTH starts a scan, with the MothRules.Scan and the target id (posted
## through the outbox).
@warning_ignore("unused_signal")
signal moth_scan_started(scan: int, target_id: StringName)
## Emitted when the MOTH finishes a scan, with the MothRules.Scan and the target id (posted
## through the outbox).
@warning_ignore("unused_signal")
signal moth_scan_finished(scan: int, target_id: StringName)
## Emitted when a recalled MOTH is back in the rack, with the world id (posted through the
## outbox).
@warning_ignore("unused_signal")
signal moth_recalled(world_id: StringName)
## Emitted when the MOTH is lost ("SIGNAL LOST"), with the world id and the reason:
## &"shot_down", &"battery" or &"wormhole_closed" (posted through the outbox).
@warning_ignore("unused_signal")
signal moth_lost(world_id: StringName, reason: StringName)
## Emitted when a replacement MOTH arrives, with the drones now in the rack (posted through
## the outbox).
@warning_ignore("unused_signal")
signal moth_delivered(rack: int)

## Emitted when a construction site starts, with its site id (posted through the outbox).
@warning_ignore("unused_signal")
signal room_build_started(site_id: StringName)
## Emitted when a construction site finishes, with its site id (posted through the outbox).
@warning_ignore("unused_signal")
signal room_built(site_id: StringName)
## Emitted when a demolished room (all its levels) is gone, with its site id (posted through
## the outbox).
@warning_ignore("unused_signal")
signal room_demolished(site_id: StringName)
## Emitted when a new level is dug, with its number (posted through the outbox).
@warning_ignore("unused_signal")
signal level_dug(level: int)
## Emitted when a finished room switched on by lowering charging, with its id and the total
## charge rate left in MW (posted through the outbox).
@warning_ignore("unused_signal")
signal charging_lowered(room_id: StringName, charge_mw: int)
## Emitted when a finished room stays off because even zero charging is not enough, with its
## id, its draw and the spare supply in MW (posted through the outbox).
@warning_ignore("unused_signal")
signal room_finished_off(room_id: StringName, need_mw: int, spare_mw: int)
## Emitted when a plant went away (switched off or demolished) and the shed took its supply
## from charging first, then rooms: the plant's id, the total charge rate left in MW and the
## rooms switched off (posted through the outbox).
@warning_ignore("unused_signal")
signal supply_dropped(room_id: StringName, charge_mw: int, rooms_off: int)
## Emitted when a dug level's lift segment is refused for lack of funds, with the level and
## the segment's cost in $k (posted through the outbox).
@warning_ignore("unused_signal")
signal lift_segment_refused(level: int, cost_k: int)
## Emitted when a research project starts, with its id (posted through the outbox).
@warning_ignore("unused_signal")
signal research_started(project_id: StringName)
## Emitted when the running research project is cancelled, with its id (posted through the
## outbox).
@warning_ignore("unused_signal")
signal research_cancelled(project_id: StringName)
## Emitted when a research project finishes and its unlocks apply, with its id (posted
## through the outbox).
@warning_ignore("unused_signal")
signal research_done(project_id: StringName)
## Emitted when people change rooms or join or leave the roster, with the reason
## (StaffChanges: &"assigned", &"unassigned", &"auto_assigned", &"released"; RecruitmentRules:
## &"hired", &"dismissed"), the def id of the room concerned and how many people moved
## (posted through the outbox).
@warning_ignore("unused_signal")
signal staff_changed(reason: StringName, room_def_id: StringName, count: int)
## Emitted whenever Committee Confidence changes (an event or the daily settlement's drift),
## with the new value in tenths (posted through the outbox).
@warning_ignore("unused_signal")
signal confidence_changed(confidence_tenths: int)
## Emitted when analysts file their reports (every 15th day), with how many filed (posted
## through the outbox; logged).
@warning_ignore("unused_signal")
signal reports_filed(analysts: int)
## Emitted when the Committee pays its commendation, with the amount in $k (posted through
## the outbox; logged).
@warning_ignore("unused_signal")
signal committee_commendation(amount_k: int)
## Emitted when the Committee warns (DailySettlement: &"red_days" every 7 settlements in a
## row in the red, &"confidence_zero" when Confidence first reaches 0). A warning only: the
## game goes on (posted through the outbox; logged).
@warning_ignore("unused_signal")
signal committee_warning(reason: StringName)
## Emitted on the tick a hired person arrives on base (RecruitmentSystem; logged).
@warning_ignore("unused_signal")
signal staff_arrived(person_id: StringName)
## Emitted when the Directorate lends a soldier, at the Expeditions unlock or as a replacement
## (ExpeditionUnlock; logged).
@warning_ignore("unused_signal")
signal soldier_lent(person_id: StringName)
## Emitted when an injured person heals and goes back to work (StaffCareSystem).
@warning_ignore("unused_signal")
signal staff_healed(person_id: StringName)
## Emitted when the candidate list changes: an arrival, a leaver or a hire.
@warning_ignore("unused_signal")
signal candidates_changed

## Bus signals owned by the clock, the save service and the Simulation's own forwards. A
## posted domain event may not use one of these names: it is rejected like an undeclared
## name, so a system can never fake a tick, a day, a pause or a save. pause_requested is
## not listed: the Simulation routes that event to its own pause_requested signal.
const RESERVED_EVENT_NAMES: Array[StringName] = [
	&"tick_advanced",
	&"day_started",
	&"command_rejected",
	&"speed_changed",
	&"paused_changed",
	&"time_mode_changed",
	&"game_saved",
	&"game_loaded",
]

var _simulation: Simulation = null
## Declared argument count per event name, -1 when no such signal is declared here.
var _arg_counts: Dictionary[StringName, int] = {}


## Forwards [param simulation]'s signals to this bus, including its outbox events, and
## disconnects any previously bound simulation. Passing null only unbinds. A posted event
## whose name is in [constant RESERVED_EVENT_NAMES], is not a signal declared here, or whose
## argument count differs from the signal's, is a programmer error: it asserts in debug,
## otherwise reports an error, and is not emitted.
func bind_simulation(simulation: Simulation) -> void:
	_unbind_simulation()
	if simulation == null:
		return
	_simulation = simulation
	simulation.day_started.connect(_on_day_started)
	simulation.command_rejected.connect(_on_command_rejected)
	simulation.pause_requested.connect(_on_pause_requested)
	simulation.event_posted.connect(_on_event_posted)


func _unbind_simulation() -> void:
	if _simulation == null:
		return
	_simulation.day_started.disconnect(_on_day_started)
	_simulation.command_rejected.disconnect(_on_command_rejected)
	_simulation.pause_requested.disconnect(_on_pause_requested)
	_simulation.event_posted.disconnect(_on_event_posted)
	_simulation = null


func _on_day_started(day_index: int) -> void:
	day_started.emit(day_index)


func _on_command_rejected(type: StringName, code: StringName) -> void:
	command_rejected.emit(type, code)


func _on_pause_requested(reason: StringName) -> void:
	pause_requested.emit(reason)


func _on_event_posted(event_name: StringName, args: Array) -> void:
	if event_name in RESERVED_EVENT_NAMES:
		_report("EventBus: posted event '%s' uses a reserved bus signal name" % event_name)
		return
	var expected: int = _declared_arg_count(event_name)
	if expected < 0:
		_report("EventBus: no signal declared for posted event '%s'" % event_name)
		return
	if args.size() != expected:
		_report(
			(
				"EventBus: event '%s' posted with %d args, its signal declares %d"
				% [event_name, args.size(), expected]
			)
		)
		return
	emit_signal.callv([event_name] + args)


## Looks up the signal's argument count once per name. Signals inherited from Node, such
## as ready, are not domain events and count as undeclared.
func _declared_arg_count(event_name: StringName) -> int:
	if _arg_counts.has(event_name):
		return _arg_counts[event_name]
	var count: int = -1
	if not ClassDB.class_has_signal(get_class(), event_name):
		for info: Dictionary in get_signal_list():
			var signal_name: String = info["name"]
			if StringName(signal_name) == event_name:
				var signal_args: Array = info["args"]
				count = signal_args.size()
				break
	_arg_counts[event_name] = count
	return count


# In debug the assert stops here; release builds strip it and report through push_error.
func _report(message: String) -> void:
	assert(false, message)
	push_error(message)
