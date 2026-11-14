extends Node
@warning_ignore_start("unused_signal")
## Autoload. Domain events for the presentation layer: views subscribe here and redraw.
## The simulation never references this node; bind_simulation() forwards its signals,
## and re-emits each outbox event (Simulation.event_posted) as the signal of the same name
## declared here, with the same arguments.
## Bible: technical-architecture.md#architecture-overview

## Emitted after each simulation tick, by the clock.
signal tick_advanced(tick: int)
## Emitted at the first tick of each day, with the new day's index.
signal day_started(day_index: int)
## Emitted when a submitted command fails validation.
signal command_rejected(type: StringName, code: StringName)
## Emitted when the simulation asks the clock to pause.
signal pause_requested(reason: StringName)
## Emitted when the clock speed changes.
signal speed_changed(speed_index: int)
## Emitted when the clock pauses or resumes.
signal paused_changed(is_paused: bool)
## Emitted when the clock's time-control mode changes, with the new ClockState.Mode.
signal time_mode_changed(mode: int)
## Emitted after a save completes.
signal game_saved(slot: StringName)
## Emitted after a load completes.
signal game_loaded(slot: StringName)
## Emitted when the Ring starts dialing, with the dialed address's key (GateAddress.key())
## (posted through the outbox).
signal dial_started(address_key: String)
## Emitted when a dial resolves, with its DialOutcome.Kind and the address key; nothing else,
## so a failure never tells which seal was wrong (posted through the outbox).
signal dial_resolved(outcome: int, address_key: String)
## Emitted when the open wormhole closes: &"player", &"timeout" or &"power" (posted through
## the outbox).
signal wormhole_closed(reason: StringName)
## Emitted when a document arrives in the Archive, with its DocumentDef id (posted through
## the outbox).
signal document_received(document_id: StringName)
## Emitted when the Address Book changes: a dial recorded or a note set (posted through the
## outbox).
signal address_book_changed
## Emitted when a Capacitor Bank room is completed and starts charging, with the new capacity
## in MWh (posted through the outbox).
signal capacitors_installed(capacity_mwh: float)
## Emitted when the power allocation changes: a room switched, a charge rate set, a new bank
## or rooms switched off to fit the supply (posted through the outbox).
signal power_allocation_changed
## Emitted when the pole camera takes a world's horizon record, with the world id (posted
## through the outbox).
signal horizon_record_taken(world_id: StringName)
## Emitted when the budget changes, with the new balance in $k (posted through the outbox).
signal budget_changed(budget_k: int)
## Emitted when the player reads a far Ring's console, with that world's id (posted through
## the outbox).
signal console_read(world_id: StringName)
## Emitted when a world's state rises (WorldProgress), with the world id and the new
## WorldsState.WorldStatus (posted through the outbox).
signal world_status_changed(world_id: StringName, status: int)
## Emitted when a World Report fact's confidence rises (WorldProgress), with the world id, the
## WorldReport.Fact and the new WorldReport.Confidence (posted through the outbox).
signal world_fact_raised(world_id: StringName, fact: int, confidence: int)
## Emitted when a target's saved state rises (WorldProgress.raise_target), with the world id,
## target id and TargetStates.State (posted through the outbox).
signal world_target_changed(world_id: StringName, target_id: StringName, state: int)
## Emitted when a sample canister is thrown through, with the world id (posted through the
## outbox).
signal canister_launched(world_id: StringName)
## Emitted when the canister is reeled back, with the world id and its WorldDef.Biohazard
## (posted through the outbox).
signal canister_returned(world_id: StringName, biohazard: int)
## Emitted when the wormhole closes with the canister out, with the world id (posted through
## the outbox).
signal canister_lost(world_id: StringName)
## Emitted when a MOTH is sent through, with the world id (posted through the outbox).
signal moth_launched(world_id: StringName)
## Emitted when the MOTH starts a scan, with the MothRules.Scan and the target id (posted
## through the outbox).
signal moth_scan_started(scan: int, target_id: StringName)
## Emitted when the MOTH finishes a scan, with the MothRules.Scan and the target id (posted
## through the outbox).
signal moth_scan_finished(scan: int, target_id: StringName)
## Emitted when a recalled MOTH is back in the rack, with the world id (posted through the
## outbox).
signal moth_recalled(world_id: StringName)
## Emitted when the MOTH is lost ("SIGNAL LOST"), with the world id and the reason:
## &"shot_down", &"battery" or &"wormhole_closed" (posted through the outbox).
signal moth_lost(world_id: StringName, reason: StringName)
## Emitted when a replacement MOTH arrives, with the drones now in the rack (posted through
## the outbox).
signal moth_delivered(rack: int)
## Emitted when an expedition is planned, with the world id (posted through the outbox).
signal expedition_planned(world_id: StringName)
## Emitted when a team goes through the Ring, with the world id, the objective
## (ExpeditionState.Objective) and the team's names in slot order (posted through the outbox).
signal team_sent(world_id: StringName, objective: int, team: Array)
## Emitted when a team comes home, with the world id, its ExpeditionState.Objective and whether
## the objective succeeded, and the team's names in slot order (posted through the outbox).
signal team_returned(world_id: StringName, objective: int, success: bool, team: Array)
## Emitted at a check-in that is not the return, with the world id and the team's light and
## serious injuries and what the day brought ("finding", "injury" or "wasted") (posted through
## the outbox).
signal team_checked_in(world_id: StringName, light: int, serious: int, day: String)
## Emitted when a field event resolves at a check-in, with the world id, the event id and the
## outcome ("finding" or a FieldEventDef setback name) and the name of who rolled ("" if no one)
## (posted through the outbox).
signal field_event_resolved(
	world_id: StringName, event_id: StringName, outcome: String, person_name: String
)
## Emitted when the player recalls the team, with the world id (posted through the outbox).
signal team_recalled(world_id: StringName)
## Emitted when a team misses a check-in and the rescue window opens, with the world id
## (posted through the outbox).
signal check_in_missed(world_id: StringName)
## Emitted when Signal T-1 is sent, with the world id (posted through the outbox).
signal rescue_signal_sent(world_id: StringName)
## Emitted when the wormhole closes before the signalled team reached the Ring, with the world
## id (posted through the outbox).
signal rescue_signal_failed(world_id: StringName)
## Emitted for each team member who did not survive a rescue, with the name and the world id
## (posted through the outbox).
signal member_deceased(person_name: String, world_id: StringName)
## Emitted when a rescued team comes through, with the world id and the survivors (posted
## through the outbox).
signal team_rescued(world_id: StringName, survivors: int)
## Emitted once, when the first team comes home through its own check-ins (not a rescue), with
## the world id: the Prologue ends (posted through the outbox).
signal prologue_completed(world_id: StringName)
## Emitted when a team is lost, with the world id and the reason, &"window" or &"no_answer"
## (posted through the outbox).
signal team_lost(world_id: StringName, reason: StringName)

## Emitted when a construction site starts, with its site id (posted through the outbox).
signal room_build_started(site_id: StringName)
## Emitted when a construction site finishes, with its site id (posted through the outbox).
signal room_built(site_id: StringName)
## Emitted when a demolished room (all its levels) is gone, with its site id (posted through
## the outbox).
signal room_demolished(site_id: StringName)
## Emitted when a new level is dug, with its number (posted through the outbox).
signal level_dug(level: int)
## Emitted when a finished room switched on by lowering charging, with its id and the total
## charge rate left in MW (posted through the outbox).
signal charging_lowered(room_id: StringName, charge_mw: int)
## Emitted when a finished room stays off because even zero charging is not enough, with its
## id, its draw and the spare supply in MW (posted through the outbox).
signal room_finished_off(room_id: StringName, need_mw: int, spare_mw: int)
## Emitted when a plant went away (switched off or demolished) and the shed took its supply
## from charging first, then rooms: the plant's id, the total charge rate left in MW and the
## rooms switched off (posted through the outbox).
signal supply_dropped(room_id: StringName, charge_mw: int, rooms_off: int)
## Emitted when a dug level's lift segment is refused for lack of funds, with the level and
## the segment's cost in $k (posted through the outbox).
signal lift_segment_refused(level: int, cost_k: int)
## Emitted when a research project starts, with its id (posted through the outbox).
signal research_started(project_id: StringName)
## Emitted when the running research project is cancelled, with its id (posted through the
## outbox).
signal research_cancelled(project_id: StringName)
## Emitted when a research project finishes and its unlocks apply, with its id (posted
## through the outbox).
signal research_done(project_id: StringName)
## Emitted when people change rooms or join or leave the roster, with the reason
## (StaffChanges: &"assigned", &"unassigned", &"auto_assigned", &"released"; RecruitmentRules:
## &"hired", &"dismissed"), the def id of the room concerned and how many people moved
## (posted through the outbox).
signal staff_changed(reason: StringName, room_def_id: StringName, count: int)
# M4 factions, conversations, requests and artefacts (posted through the outbox).
## A story effect offered a request (uid).
signal request_offered(uid: int)
## A debug story command ran (action, id; logged "(debug)").
signal debug_story(action: StringName, id: StringName)
## The active slow reasons changed (keys "reason" or "reason/source"; empty when none).
signal slow_changed(reasons: Array[StringName])
## A cheat ran (action, id, value; logged "(cheat)").
signal debug_cheat(action: StringName, id: StringName, value: int)
## A request changed state (RequestRecord.RequestState as int).
signal request_changed(uid: int, state: int)
## An artefact arrived, in holding or waiting at the gate (uid).
signal artefact_arrived(uid: int)
## An artefact was housed, taken back to holding or retrieved from the gate.
signal artefact_moved(uid: int)
## The research queue changed (queued, removed or reordered).
signal research_queue_changed
## The queue started its next project (logged).
signal research_queue_started(project_id: StringName)
## An artefact's hazard struck (logged, non-pausing message).
signal artefact_hazard(artefact_id: StringName)
## A hidden research project was revealed.
signal research_revealed(project_id: StringName)
## A story effect set a flag.
signal flag_changed(flag: StringName)
## Emitted when an artefact is handed over, with its id (outbox).
signal artefact_taken(artefact_id: StringName)
## Every held instance of an artefact became Studied.
signal artefact_studied(artefact_id: StringName)
## Emitted when a faction's standing changes, with its id, the new standing and the change.
signal standing_changed(faction: StringName, standing: int, delta: int)
## Emitted the first time the player meets a faction, with its id (posted through the outbox;.
signal faction_met(faction: StringName)
## Emitted when a conversation starts, with its id and channel (outbox).
signal conversation_started(conversation_id: StringName, channel: StringName)
## Emitted when the running conversation shows a line, with the node id (outbox).
signal conversation_line(node_id: StringName)
## Emitted when the running conversation waits at a choice (outbox).
signal conversation_choices
## Emitted when a conversation ends, with its transcript uid and whether it was cut off (outbox).
signal conversation_ended(transcript_uid: int, cut_off: bool)
## Emitted when a hail gets no answer, with the world id (outbox; logged "No answer.").
signal hail_unanswered(world_id: StringName)
## Emitted when a faction queues a contact, with its id (outbox).
signal contact_pending(faction: StringName)
## Emitted when an unanswered phone call expires, with the faction id (outbox; logged).
signal call_missed(faction: StringName)
## Emitted when an incoming wormhole activates the Ring, with the faction id (outbox).
signal incoming_wormhole(faction: StringName)
## Emitted when an incoming wormhole is answered, with the faction id (outbox).
signal incoming_answered(faction: StringName)
## Emitted when an incoming wormhole is ignored or gives up, with the faction id (outbox; logged).
signal incoming_ignored(faction: StringName)
## Emitted whenever Committee Confidence changes (an event or the daily settlement's drift),
## with the new value in tenths (posted through the outbox).
signal confidence_changed(confidence_tenths: int)
## Emitted when analysts file their reports (every 15th day), with how many filed (posted
## through the outbox; logged).
signal reports_filed(analysts: int)
## Emitted when the Committee pays its commendation, with the amount in $k (posted through
## the outbox; logged).
signal committee_commendation(amount_k: int)
## Emitted when the Committee warns (DailySettlement: &"red_days" every 7 settlements in a
## row in the red, &"confidence_zero" when Confidence first reaches 0). A warning only: the
## game goes on (posted through the outbox; logged).
signal committee_warning(reason: StringName)
## Emitted on the tick a hired person arrives on base (RecruitmentSystem; logged).
signal staff_arrived(person_id: StringName)
## Emitted when the Directorate lends a soldier, at the Expeditions unlock or as a replacement
## (ExpeditionUnlock; logged).
signal soldier_lent(person_id: StringName)
## Emitted when an injured person heals and goes back to work (StaffCareSystem).
signal staff_healed(person_id: StringName)
## Emitted when the candidate list changes: an arrival, a leaver or a hire.
signal candidates_changed

# M4c incursions and failure states (docs/content/m4c-incursions.md).
## The Ring opened from outside with the incursion [param def_id] on the way.
signal incursion_warning(def_id: StringName)
## The warning ran out: intruders are in the Gate Room.
signal incursion_breached
## The incursion ended; [param report] is the after-action report.
signal incursion_ended(report: Dictionary)
## A squad changed (order, place or strength).
signal squad_changed(squad_id: StringName)
## The blast door at [param cell] on [param level] changed.
signal door_changed(level: int, cell: Vector2i)
## A room was damaged or repaired.
signal room_damaged(room_uid: StringName)
signal room_repaired(room_uid: StringName)
## Intruders moved this tick.
signal intruders_moved
## The game ended with [param cause].
signal game_failed(cause: StringName)
## An installation of room (or door key) [param room_uid] was started, finished or removed.
signal installation_changed(room_uid: StringName)

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
