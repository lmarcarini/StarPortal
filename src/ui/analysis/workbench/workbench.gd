class_name Workbench
extends Control
## The Address Workbench of the Analysis view: eight seal slots, the 36-glyph palette, actions
## on a picked glyph, the constraint list, the candidate counter and, when few remain, the
## candidates with "Send to dial queue".
##
## The view never mutates state. Every edit builds the full new constraint list
## (WorkbenchEdits) and submits one SetWorkbenchCommand; the draft is redrawn, and the count
## recomputed, only on EventBus.workbench_changed and in setup(). An edit made before the last
## one has applied (the clock running) builds on that pending command, so quick edits are not
## lost. Click-to-pick is view-local state (WorkbenchPicker).
##
## "Send to dial queue" reports "Sent" only once the address is in the queue: at once while
## paused, else when dial_queue_changed shows it; a refusal at the tick arrives as
## EventBus.command_rejected and is shown translated (SendTracker).
##
## Focus: the root takes focus as one stop in the Analysis view; accept or down enters it (the
## first seal slot), and cancel drops a pick while focus is inside.
## Bible: gate-and-address-spec.md#player-tools,
## gate-and-address-spec.md#clue-types-and-reliability,
## game-design.md#difficulty-and-accessibility,
## technical-architecture.md#architecture-overview

## Hint key per WorkbenchPicker.Mode, in enum order.
const HINT_KEYS: Array[StringName] = [
	&"WORKBENCH_HINT_IDLE",
	&"WORKBENCH_HINT_PICKED",
	&"WORKBENCH_HINT_NOT_AT",
	&"WORKBENCH_HINT_NEARER",
]
## Message key per QueueAddressCommand rejection code; others use WORKBENCH_QUEUE_FAILED.
const QUEUE_MESSAGE_KEYS: Dictionary[StringName, StringName] = {
	&"already_queued": &"WORKBENCH_QUEUE_ALREADY",
	&"queue_full": &"WORKBENCH_QUEUE_FULL",
}

var _simulation: Simulation = null
var _picker: WorkbenchPicker = WorkbenchPicker.new()
## The last SetWorkbenchCommand submitted and not yet applied, or null.
var _pending: SetWorkbenchCommand = null
var _summary: CandidateSummary = CandidateSummary.new()
## Sends accepted while the clock runs, waiting for their tick.
var _sends: SendTracker = SendTracker.new()
## True while this view's own submit() runs: its refusal comes back as the result, so the
## command_rejected that also reports it is not matched to a waiting send.
var _submitting_send: bool = false

@onready var _count: CountDisplay = %Count
@onready var _seals: SealRow = %SealRow
@onready var _hint: Label = %Hint
@onready var _actions: ActionBar = %ActionBar
@onready var _edit_message: Label = %EditMessage
@onready var _palette: GlyphPalette = %Palette
@onready var _constraints: ConstraintList = %Constraints
@onready var _candidates: CandidateList = %Candidates


func _ready() -> void:
	_seals.slot_chosen.connect(_on_slot_chosen)
	_seals.glyph_dropped.connect(_on_glyph_dropped)
	_seals.origin_reset.connect(_on_origin_reset)
	_palette.glyph_chosen.connect(_on_glyph_chosen)
	_actions.action_chosen.connect(_on_action_chosen)
	_constraints.remove_requested.connect(_on_remove_requested)
	_constraints.clear_confirmed.connect(_on_clear_confirmed)
	_candidates.send_requested.connect(_on_send_requested)
	_refresh()


func _enter_tree() -> void:
	EventBus.workbench_changed.connect(_on_workbench_changed)
	EventBus.dial_queue_changed.connect(_on_dial_queue_changed)
	EventBus.command_rejected.connect(_on_command_rejected)


func _exit_tree() -> void:
	EventBus.workbench_changed.disconnect(_on_workbench_changed)
	EventBus.dial_queue_changed.disconnect(_on_dial_queue_changed)
	EventBus.command_rejected.disconnect(_on_command_rejected)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


func _gui_input(event: InputEvent) -> void:
	var enters: bool = event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_down")
	if has_focus() and enters:
		_seals.get_slot(1).grab_focus()
		accept_event()


# Key events go to the focused control only, so cancel is caught here: it drops a pick while
# focus is anywhere in the workbench.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or not _picker.has_glyph():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not (focused == self or is_ancestor_of(focused)):
		return
	_picker.cancel()
	_render_picker()
	get_viewport().set_input_as_handled()


## Shows the workbench of [param simulation] and sends edits to it (from _ready() when called
## before it). Call again after a load: anything read from the previous simulation, and any
## pick, is dropped.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_pending = null
	_picker.cancel()
	_sends.clear()
	if not is_node_ready():
		return
	_show_edit_message("")
	_candidates.show_message("")
	_refresh()


## Returns the click-to-pick state, for tests and focus hints.
func get_picker() -> WorkbenchPicker:
	return _picker


## Returns what the counter and candidate list show, computed at the last workbench change.
func get_summary() -> CandidateSummary:
	return _summary


func _refresh() -> void:
	_summary = (
		CandidateSummary.of(_simulation.state) if _simulation != null else CandidateSummary.new()
	)
	_render()


func _render() -> void:
	if _simulation == null:
		return
	var draft: WorkbenchState = _simulation.state.workbench
	_count.show_count(_summary.count)
	var is_home: bool = draft.origin_glyph == WorkbenchState.HOME_ORIGIN
	_seals.show_draft(draft.constraints, _summary.origin, is_home, tr)
	_constraints.show_constraints(draft.constraints)
	_candidates.show_summary(_summary, _simulation.state.gate.dial_queue, tr)
	_render_picker()


func _render_picker() -> void:
	if _simulation == null:
		return
	var constraints: Array[AddressConstraint] = _simulation.state.workbench.constraints
	_palette.show_draft(constraints, _picker.glyph, tr)
	_actions.show_state(_picker.mode, WorkbenchEdits.can_group(constraints))
	var picked: String = WorkbenchText.glyph_name(_picker.glyph, tr) if _picker.has_glyph() else ""
	_hint.text = tr(HINT_KEYS[_picker.mode]).format({"glyph": picked})


func _on_workbench_changed() -> void:
	_pending = null
	_refresh()


func _on_dial_queue_changed() -> void:
	if _simulation == null:
		return
	_candidates.show_queue(_simulation.state.gate.dial_queue)
	_sends.on_queue_changed(_simulation.state.gate.dial_queue)
	_show_send_result()


func _on_command_rejected(type: StringName, code: StringName) -> void:
	if _simulation == null or type != QueueAddressCommand.TYPE or _submitting_send:
		return
	_sends.on_rejected(code, _simulation.state.gate.dial_queue)
	_show_send_result()


func _on_glyph_chosen(glyph: int) -> void:
	if _picker.mode == WorkbenchPicker.Mode.AWAIT_FARTHER:
		var nearer: int = _picker.glyph
		_picker.cancel()
		if glyph != nearer:
			_edit(WorkbenchEdits.with_added(_draft(), AddressConstraint.nearer_than(nearer, glyph)))
	else:
		_picker.pick(glyph)
	_render_picker()


func _on_slot_chosen(seal: int) -> void:
	var glyph: int = _picker.glyph
	var mode: WorkbenchPicker.Mode = _picker.mode
	var is_origin: bool = seal > GateAddress.COORDINATE_COUNT
	if mode == WorkbenchPicker.Mode.GLYPH_PICKED and is_origin:
		_submit(glyph, _draft())
	elif mode == WorkbenchPicker.Mode.GLYPH_PICKED:
		_edit(WorkbenchEdits.placed(_draft(), seal, glyph))
	elif mode == WorkbenchPicker.Mode.AWAIT_NOT_AT and not is_origin:
		_edit(WorkbenchEdits.with_added(_draft(), AddressConstraint.glyph_not_at(seal, glyph)))
	else:
		return
	_picker.cancel()
	_render_picker()


func _on_glyph_dropped(seal: int, glyph: int) -> void:
	_picker.cancel()
	if seal > GateAddress.COORDINATE_COUNT:
		_submit(glyph, _draft())
	else:
		_edit(WorkbenchEdits.placed(_draft(), seal, glyph))
	_render_picker()


func _on_action_chosen(action: ActionBar.Action) -> void:
	var glyph: int = _picker.glyph
	match action:
		ActionBar.Action.RULE_OUT:
			_picker.cancel()
			_edit(WorkbenchEdits.toggled_excluded(_draft(), glyph))
		ActionBar.Action.INCLUDE:
			_picker.cancel()
			_edit(WorkbenchEdits.toggled_included(_draft(), glyph))
		ActionBar.Action.NOT_AT:
			_picker.await_not_at()
		ActionBar.Action.NEARER:
			_picker.await_farther()
		ActionBar.Action.GROUP:
			_edit(WorkbenchEdits.grouped_as_set(_draft()))
		ActionBar.Action.CANCEL:
			_picker.cancel()
	_render_picker()


func _on_origin_reset() -> void:
	_submit(WorkbenchState.HOME_ORIGIN, _draft())


func _on_remove_requested(constraint: AddressConstraint) -> void:
	_edit(WorkbenchEdits.without(_draft(), constraint))


func _on_clear_confirmed() -> void:
	_edit([])


func _on_send_requested(address: GateAddress) -> void:
	if _simulation == null or address == null:
		return
	_submitting_send = true
	var result: CommandResult = _simulation.submit(QueueAddressCommand.create(address))
	_submitting_send = false
	if not result.is_ok:
		_show_send_message(result.error_code)
	elif SendTracker.contains(_simulation.state.gate.dial_queue, address):
		_show_send_message(SendTracker.SENT)
	else:
		_sends.add(address)
		_show_send_result()


## Shows "Queuing…" while a send waits for its tick, then the latest send's result.
func _show_send_result() -> void:
	if _sends.is_waiting():
		_candidates.show_message(tr(&"WORKBENCH_QUEUE_PENDING"))
		return
	var outcome: StringName = _sends.take_result()
	if not outcome.is_empty():
		_show_send_message(outcome)


func _show_send_message(outcome: StringName) -> void:
	if outcome == SendTracker.SENT:
		_candidates.show_message(tr(&"WORKBENCH_QUEUE_SENT"))
		return
	var key: StringName = QUEUE_MESSAGE_KEYS.get(outcome, &"WORKBENCH_QUEUE_FAILED")
	_candidates.show_message(tr(key).format({"max": QueueAddressCommand.MAX_QUEUE}))


## The draft edits build on: the pending command's, else the state's.
func _draft() -> Array[AddressConstraint]:
	if _pending != null:
		return WorkbenchEdits.copy(_pending.constraints)
	if _simulation == null:
		return []
	return WorkbenchEdits.copy(_simulation.state.workbench.constraints)


func _draft_origin() -> int:
	if _pending != null:
		return _pending.origin_glyph
	if _simulation == null:
		return WorkbenchState.HOME_ORIGIN
	return _simulation.state.workbench.origin_glyph


func _edit(constraints: Array[AddressConstraint]) -> void:
	_submit(_draft_origin(), constraints)


## Submits one SetWorkbenchCommand. It is pending until workbench_changed, which a paused
## clock emits before submit() returns.
func _submit(origin: int, constraints: Array[AddressConstraint]) -> void:
	if _simulation == null:
		return
	var previous: SetWorkbenchCommand = _pending
	var command: SetWorkbenchCommand = SetWorkbenchCommand.create(origin, constraints)
	_pending = command
	var result: CommandResult = _simulation.submit(command)
	if result.is_ok:
		_show_edit_message("")
		return
	_pending = previous
	var key: StringName = (
		&"WORKBENCH_EDIT_TOO_MANY"
		if result.error_code == &"too_many_constraints"
		else &"WORKBENCH_EDIT_FAILED"
	)
	_show_edit_message(tr(key).format({"max": WorkbenchState.MAX_CONSTRAINTS}))


func _show_edit_message(text: String) -> void:
	_edit_message.text = text
	_edit_message.visible = not text.is_empty()
