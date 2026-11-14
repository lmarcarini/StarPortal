class_name WormholeScreen
extends Control
## The open wormhole, beside the Ring and never over it, and never a modal. A status strip shows,
## the whole time a wormhole is open, the destination (or "Unknown world"), a hostile warning when
## the far side is guarded, the time left (live with sim time), the drain, the bank's state and the
## documents this wormhole brought ("New in the Archive: …"). The action panel is the gate
## operations panel: showing it operates the gate (slow) and hiding it stands by. Clicking the
## portal on the Ring (or A with it focused) shows or hides the action panel under the strip
## (WormholeActions); Stand by, B or Escape hides it, and dismisses the closed message. Open the
## Address Book and Read in the Archive hide it and pass the request on. When the wormhole closes,
## for any reason, the strip says why until the player dismisses it or dials again. Below the strip
## the screen lets clicks through.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#state-machines

## The player dismissed the closed message.
signal dismissed
## The player asked to see the Address Book; the actions are hidden.
signal address_book_requested
## The player asked to read [param document_id], the first document this lock delivered, in
## the Archive; the actions are hidden.
signal archive_requested(document_id: StringName)
## The pole camera was just sent through (same frame as the press).
signal camera_extended
## The player asked to see the horizon photo enlarged.
signal photo_requested
## The action panel was hidden by the player; the view gives focus back to the Ring.
signal actions_hidden

## Phases: HIDDEN, STATUS (open, strip only), ACTIONS (open, strip and action panel), CLOSED
## (it closed; the strip says why).
enum Phase { HIDDEN, STATUS, ACTIONS, CLOSED }

var _simulation: Simulation = null
var _phase: Phase = Phase.HIDDEN
var _closed_reason: StringName = &""

@onready var _title: Label = %Title
@onready var _open_box: VBoxContainer = %OpenBox
@onready var _destination: Label = %Destination
@onready var _hostile: Label = %Hostile
@onready var _time_left: Label = %TimeLeft
@onready var _drain: Label = %Drain
@onready var _bank: Label = %Bank
@onready var _new_documents: Label = %NewDocuments
@onready var _hint: Label = %RingHint
@onready var _actions_panel: Control = %ActionsPanel
@onready var _actions: WormholeActions = %WormholeActions
@onready var _closed_box: Container = %ClosedBox
@onready var _closed_label: Label = %ClosedLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(dismiss)
	_actions.book_requested.connect(_on_book_requested)
	_actions.archive_requested.connect(_on_archive_requested)
	_actions.focus_changed.connect(_on_actions_focus_changed)
	_actions.camera_extended.connect(camera_extended.emit)
	_actions.photo_requested.connect(photo_requested.emit)
	_actions.stand_by_requested.connect(hide_actions)
	_render()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.wormhole_closed.connect(_on_wormhole_closed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.wormhole_closed.disconnect(_on_wormhole_closed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	if _phase == Phase.ACTIONS:
		get_viewport().set_input_as_handled()
		hide_actions()
	elif _phase == Phase.CLOSED and is_visible_in_tree():
		get_viewport().set_input_as_handled()
		dismiss()


## Connects the screen to [param simulation] and hides it.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_actions.setup(simulation)
	_set_phase(Phase.HIDDEN)


## Shows the status strip of the open wormhole, actions hidden. Does nothing unless the Ring is
## LOCKED.
func open() -> void:
	if _is_locked():
		_set_phase(Phase.ACTIONS if _simulation.state.gate.operating else Phase.STATUS)


## Shows the action panel if hidden, hides it if shown. Only while a wormhole is open.
func toggle_actions() -> void:
	if _phase == Phase.ACTIONS:
		hide_actions()
	elif _phase == Phase.STATUS and _is_locked():
		_set_phase(Phase.ACTIONS)


## Hides the action panel and emits [signal actions_hidden]. Only while it shows.
func hide_actions() -> void:
	if _phase != Phase.ACTIONS:
		return
	_set_phase(Phase.STATUS)
	actions_hidden.emit()


## Hides the closed message and emits [signal dismissed]. Only after the wormhole closed.
func dismiss() -> void:
	if _phase != Phase.CLOSED:
		return
	_set_phase(Phase.HIDDEN)
	dismissed.emit()


## Hides the screen without emitting, e.g. when a new dial starts.
func close() -> void:
	_set_phase(Phase.HIDDEN)


## True while the action panel shows (it holds focus).
func is_open() -> bool:
	return _phase == Phase.ACTIONS


## True while the wormhole is shown open, with or without its actions.
func is_showing_open() -> bool:
	return _phase == Phase.STATUS or _phase == Phase.ACTIONS


## True while the action panel shows.
func are_actions_shown() -> bool:
	return _phase == Phase.ACTIONS


## True while the strip says why the wormhole closed.
func is_showing_closed() -> bool:
	return _phase == Phase.CLOSED


## Returns the first action while the panel shows, else null.
func get_default_focus() -> Control:
	if _phase != Phase.ACTIONS:
		return null
	return _actions.get_focusables()[0]


## Returns the action panel.
func get_actions() -> WormholeActions:
	return _actions


## Returns the far Ring's console panel.
func get_console() -> ConsoleFinds:
	return _actions.get_console()


## Returns the strip's dismiss button for the closed message.
func get_back_button() -> Button:
	return _back_button


## Returns the destination line; empty unless open.
func get_destination_text() -> String:
	return _destination.text if is_showing_open() else ""


## Returns the time-left line.
func get_time_left_text() -> String:
	return _time_left.text


## Returns the drain line.
func get_drain_text() -> String:
	return _drain.text


## Returns the bank line.
func get_bank_text() -> String:
	return _bank.text


## Returns the "New in the Archive" line; empty when this lock delivered none.
func get_new_documents_text() -> String:
	return _new_documents.text if _new_documents.visible else ""


## Returns why the wormhole closed; empty unless the closed message is shown.
func get_closed_text() -> String:
	return _closed_label.text if _phase == Phase.CLOSED else ""


func _is_locked() -> bool:
	return _simulation != null and _simulation.state.gate.mode == GateState.RingMode.LOCKED


func _set_phase(phase: Phase) -> void:
	_operate(phase)
	_phase = phase
	if phase != Phase.CLOSED:
		_closed_reason = &""
	_render()
	var focus: Control = get_default_focus()
	if focus != null and is_visible_in_tree():
		focus.grab_focus()


func _render() -> void:
	if not is_node_ready():
		return
	visible = _phase != Phase.HIDDEN
	_open_box.visible = is_showing_open()
	_actions_panel.visible = _phase == Phase.ACTIONS
	_closed_box.visible = _phase == Phase.CLOSED
	_title.text = tr("GATE_WORMHOLE_CLOSED_TITLE" if _phase == Phase.CLOSED else "GATE_RING_LOCKED")
	if _phase == Phase.CLOSED:
		_closed_label.text = WormholeText.closed(_closed_reason)
	elif is_showing_open() and _is_locked():
		_show_open(_simulation.state)


func _show_open(state: GameState) -> void:
	_destination.text = WormholeText.destination(state)
	_hostile.visible = state.gate.is_hostile
	_time_left.text = WormholeText.time_left(state)
	_drain.text = WormholeText.drain(state)
	_bank.text = WormholeText.bank(state)
	_hint.text = tr(
		&"GATE_WORMHOLE_HIDE_HINT" if _phase == Phase.ACTIONS else &"GATE_WORMHOLE_RING_HINT"
	)
	_show_new_documents(state)
	_actions.render(state)
	if _phase == Phase.ACTIONS:
		OverlayFocus.trap_all(_actions.get_focusables())


## Names the documents this lock delivered; hides the line when it delivered none.
func _show_new_documents(state: GameState) -> void:
	var defs: Array[DocumentDef] = []
	for id: StringName in WormholeText.new_documents(state):
		defs.append(Registry.get_def(id) as DocumentDef)
	_new_documents.text = WormholeText.new_documents_line(defs)
	_new_documents.visible = not defs.is_empty()


func _on_book_requested() -> void:
	if _phase != Phase.ACTIONS:
		return
	_set_phase(Phase.STATUS)
	address_book_requested.emit()


func _on_archive_requested(document_id: StringName) -> void:
	if _phase != Phase.ACTIONS:
		return
	_set_phase(Phase.STATUS)
	archive_requested.emit(document_id)


## The focusable actions changed (the console was read, the camera went out): keep focus on
## the panel, on its last action of the same kind or its first.
func _on_actions_focus_changed() -> void:
	if _phase != Phase.ACTIONS:
		return
	_render()
	var focused: Control = get_viewport().gui_get_focus_owner()
	var buttons: Array[Control] = _actions.get_focusables()
	if is_visible_in_tree() and not buttons.has(focused):
		buttons[0].grab_focus()


func _on_tick_advanced(_tick: int) -> void:
	if not is_showing_open():
		return
	var operating: bool = _simulation.state.gate.operating
	if operating != (_phase == Phase.ACTIONS) and _is_locked():
		_set_phase(Phase.ACTIONS if operating else Phase.STATUS)
		return
	_render()


# The action panel is the gate operations panel (docs/content/event-time.md section 3):
# showing it operates the gate and hiding it, the wormhole still open, stands by.
func _operate(phase: Phase) -> void:
	if _simulation == null or not _is_locked():
		return
	var operating: bool = _simulation.state.gate.operating
	if phase == Phase.ACTIONS and not operating:
		_simulation.submit(OperateGateCommand.new())
	elif phase == Phase.STATUS and operating:
		_simulation.submit(StandByCommand.new())


func _on_wormhole_closed(reason: StringName) -> void:
	if not is_showing_open():
		return
	_closed_reason = reason
	_set_phase(Phase.CLOSED)
