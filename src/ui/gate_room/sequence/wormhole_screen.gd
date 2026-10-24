class_name WormholeScreen
extends Control
## The open wormhole, on top of the Gate Room until it closes: the destination, a plain line
## on what is going on, a hostile warning when the far side is guarded, the time left of the
## maximum open time (live with sim time), the drain and the bank's state, then what the
## player can do now: Close wormhole (posts CloseWormholeCommand), Read the far Ring's console
## and Send MOTH (both shown, disabled, with when they arrive). When the wormhole closes, for
## any reason, the screen says why until the player goes back to the console.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#state-machines

## The player went back to the console after the wormhole closed.
signal dismissed

## Phases: HIDDEN, OPEN (a wormhole is open), CLOSED (it closed; the reason is shown).
enum Phase { HIDDEN, OPEN, CLOSED }

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
@onready var _close_button: Button = %CloseButton
@onready var _closed_box: VBoxContainer = %ClosedBox
@onready var _closed_label: Label = %ClosedLabel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_back_button.pressed.connect(dismiss)
	OverlayFocus.trap(_close_button)
	OverlayFocus.trap(_back_button)
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
	if _phase != Phase.CLOSED or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss()


## Connects the screen to [param simulation] and hides it.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_set_phase(Phase.HIDDEN)


## Shows the open wormhole and focuses Close. Does nothing unless the Ring is LOCKED.
func open() -> void:
	if _simulation == null or _simulation.state.gate.mode != GateState.RingMode.LOCKED:
		return
	_set_phase(Phase.OPEN)


## Hides the closed message and emits [signal dismissed]. Only after the wormhole closed.
func dismiss() -> void:
	if _phase != Phase.CLOSED:
		return
	_set_phase(Phase.HIDDEN)
	dismissed.emit()


## Hides the screen without emitting, e.g. when a new dial starts.
func close() -> void:
	_set_phase(Phase.HIDDEN)


## True while the screen is shown, open or closed.
func is_open() -> bool:
	return _phase != Phase.HIDDEN


## True while the wormhole is shown open.
func is_showing_open() -> bool:
	return _phase == Phase.OPEN


## Returns the button to focus: Close while open, Back after the wormhole closed; null while
## hidden.
func get_default_focus() -> Control:
	match _phase:
		Phase.OPEN:
			return _close_button
		Phase.CLOSED:
			return _back_button
	return null


## Returns the Close wormhole button.
func get_close_button() -> Button:
	return _close_button


## Returns the Back to the console button.
func get_back_button() -> Button:
	return _back_button


## Returns the destination line; empty unless open.
func get_destination_text() -> String:
	return _destination.text if _phase == Phase.OPEN else ""


## Returns the time-left line.
func get_time_left_text() -> String:
	return _time_left.text


## Returns the drain line.
func get_drain_text() -> String:
	return _drain.text


## Returns the bank line.
func get_bank_text() -> String:
	return _bank.text


## Returns why the wormhole closed; empty unless the closed message is shown.
func get_closed_text() -> String:
	return _closed_label.text if _phase == Phase.CLOSED else ""


func _set_phase(phase: Phase) -> void:
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
	_open_box.visible = _phase == Phase.OPEN
	_closed_box.visible = _phase == Phase.CLOSED
	_title.text = tr("GATE_WORMHOLE_CLOSED_TITLE" if _phase == Phase.CLOSED else "GATE_RING_LOCKED")
	if _phase == Phase.CLOSED:
		_closed_label.text = WormholeText.closed(_closed_reason)
	elif _phase == Phase.OPEN and _simulation.state.gate.mode == GateState.RingMode.LOCKED:
		_show_open(_simulation.state)


func _show_open(state: GameState) -> void:
	_destination.text = WormholeText.destination(state)
	_hostile.visible = state.gate.is_hostile
	_time_left.text = WormholeText.time_left(state)
	_drain.text = WormholeText.drain(state)
	_bank.text = WormholeText.bank(state)


func _on_close_pressed() -> void:
	if _simulation != null and _phase == Phase.OPEN:
		_simulation.submit(CloseWormholeCommand.new())


func _on_tick_advanced(_tick: int) -> void:
	if _phase == Phase.OPEN:
		_render()


func _on_wormhole_closed(reason: StringName) -> void:
	if _phase != Phase.OPEN:
		return
	_closed_reason = reason
	_set_phase(Phase.CLOSED)
