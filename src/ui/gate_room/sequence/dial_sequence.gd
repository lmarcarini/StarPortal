class_name DialSequence
extends PanelContainer
## The dialing sequence, played on the Gate Room's Ring view: a caption beside the Ring (the
## dialed glyphs, the seals engaged so far and Skip) shows when the Ring starts dialing. It
## adds the &"cutscene" time hold, lights the Ring's eight seals one by one
## ([constant SEAL_SECONDS] of real time each, one steady light per seal), then steps the
## clock itself, one tick at a time, only while the Ring is still DIALING, so the dial
## resolves and nothing runs past it. It then releases the hold (time returns to the player's
## own Running or Paused), tells the Ring view how the dial ended (a lock opens its horizon)
## and emits [signal finished] with the outcome. Skip (the button, ui_cancel, gamepad B) jumps
## straight to the stepping, so skipping gives the same result as watching. A dial resolved
## by someone else's ticks (tools, tests) ends the sequence at once. Leaving the Gate Room
## mid-sequence (hidden, processing stopped or leaving the tree) acts as Skip, so the hold
## never outlives the screen; the result waits for the player's return. Mirrors the Ring;
## never changes it.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#state-machines, game-design.md#time-real-time-with-pause

## The sequence ended: [param outcome] is the DialOutcome.Kind, or -1 if the dial did not
## resolve (no clock bound to this simulation).
signal finished(outcome: int)

## Phases: CLOSED (hidden), LIGHTING (seals lighting in real time), RESOLVING (stepping the
## clock until the dial resolves).
enum Phase { CLOSED, LIGHTING, RESOLVING }

## Real seconds each seal takes to light.
const SEAL_SECONDS: float = 0.5
## The SimClock hold reason the sequence adds and releases.
const HOLD_REASON: StringName = &"cutscene"
const _EPSILON: float = 1e-6

var _simulation: Simulation = null
var _phase: Phase = Phase.CLOSED
var _elapsed: float = 0.0
var _outcome: int = -1
var _ring: RingView = null

@onready var _address: Label = %Address
@onready var _status: Label = %Status
@onready var _skip: Button = %SkipButton


func _ready() -> void:
	_skip.pressed.connect(skip)
	OverlayFocus.trap(_skip)
	set_process(false)
	hide()


func _enter_tree() -> void:
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	skip()
	EventBus.dial_resolved.disconnect(_on_dial_resolved)
	if _phase != Phase.CLOSED:
		SimClock.release(HOLD_REASON)


func _process(delta: float) -> void:
	advance(delta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			if is_node_ready():
				_render()
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_inside_tree() and not is_visible_in_tree():
				skip()
		NOTIFICATION_DISABLED:
			skip()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.LIGHTING or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()


## Makes the sequence light the seals of [param ring].
func set_ring_view(ring: RingView) -> void:
	_ring = ring


## Connects the sequence to [param simulation] and closes it without emitting, releasing
## the hold if a sequence was playing.
func setup(simulation: Simulation) -> void:
	if _phase != Phase.CLOSED:
		SimClock.release(HOLD_REASON)
	_simulation = simulation
	_phase = Phase.CLOSED
	_outcome = -1
	set_process(false)
	hide()


## Opens the sequence for the dial in progress and holds time. Does nothing unless the Ring
## is DIALING or while the sequence already plays. Off screen (the Gate Room hidden) it skips
## at once.
func begin() -> void:
	if _phase != Phase.CLOSED or not _is_dialing():
		return
	_phase = Phase.LIGHTING
	_elapsed = 0.0
	_outcome = -1
	SimClock.hold(HOLD_REASON)
	if _ring != null:
		_ring.begin_dialing()
	show()
	set_process(true)
	_render()
	if is_inside_tree() and (not is_visible_in_tree() or not can_process()):
		skip()
	elif is_visible_in_tree():
		_skip.grab_focus()


## Adds [param delta] real seconds to the lighting; resolves once all eight seals are lit.
## Called every frame while lighting; tests call it to skip real waiting.
func advance(delta: float) -> void:
	if _phase != Phase.LIGHTING:
		return
	_elapsed += delta
	_render()
	if get_lit_seals() >= GateAddress.SEAL_COUNT:
		_resolve()


## Lights every seal at once and resolves the dial. Only while lighting.
func skip() -> void:
	if _phase != Phase.LIGHTING:
		return
	_elapsed = SEAL_SECONDS * GateAddress.SEAL_COUNT
	_render()
	_resolve()


## Returns the seals lit so far, 0 to 8; 0 while closed.
func get_lit_seals() -> int:
	if _phase == Phase.CLOSED:
		return 0
	return mini(floori(_elapsed / SEAL_SECONDS + _EPSILON), GateAddress.SEAL_COUNT)


## True from begin() until the sequence finishes.
func is_open() -> bool:
	return _phase != Phase.CLOSED


## Returns the Skip button.
func get_skip_button() -> Button:
	return _skip


## Returns the status line, e.g. "Seals engaging: 3 of 8".
func get_status_text() -> String:
	return _status.text


## Returns the line naming the dialed glyphs.
func get_address_text() -> String:
	return _address.text


func _resolve() -> void:
	_phase = Phase.RESOLVING
	set_process(false)
	_step_until_resolved()
	_phase = Phase.CLOSED
	hide()
	SimClock.release(HOLD_REASON)
	if _ring != null:
		_ring.end_dialing(_simulation.state.gate.mode == GateState.RingMode.LOCKED)
	finished.emit(_outcome)


## Steps the clock one tick at a time while the Ring is DIALING, at most one dial's duration
## and one more tick, and only when SimClock drives this simulation.
func _step_until_resolved() -> void:
	var budget: int = 1
	if _simulation.state.balance != null:
		budget += _simulation.state.balance.dial_duration_ticks
	while _is_dialing() and budget > 0 and SimClock.simulation == _simulation:
		SimClock.step_ticks(1)
		budget -= 1


func _is_dialing() -> bool:
	return _simulation != null and _simulation.state.gate.mode == GateState.RingMode.DIALING


func _render() -> void:
	var lit: int = get_lit_seals()
	if _ring != null and _phase != Phase.CLOSED:
		_ring.set_lit(lit)
	_status.text = tr("GATE_RING_DIALING").format({"lit": lit, "total": GateAddress.SEAL_COUNT})
	var address: GateAddress = null
	if _simulation != null:
		address = _simulation.state.gate.current_address
	_address.visible = address != null
	if address != null:
		var glyphs: String = GateRoomFormat.address_text(address)
		_address.text = tr("GATE_SEQ_ADDRESS").format({"address": glyphs})


func _on_dial_resolved(outcome: int, _address_key: String) -> void:
	_outcome = outcome
	if _phase == Phase.LIGHTING:
		_elapsed = SEAL_SECONDS * GateAddress.SEAL_COUNT
		_render()
		_resolve()
