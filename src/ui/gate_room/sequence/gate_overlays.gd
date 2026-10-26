class_name GateOverlays
extends Control
## Hosts the Gate Room's overlays and decides which one shows, mirroring the Ring: the dialing
## sequence while it dials (it plays on the Ring view, beside the overlays: see [method attach]),
## then the result card for No gate, Blocked and Origin rejected, or the wormhole screen for a
## lock or hostile lock, until the wormhole closes. The wormhole screen opens below the Ring
## view, never over it ([method keep_clear_above]), so the open horizon stays in sight. At most
## one overlay shows at a time. After a load it shows what the loaded Ring is doing. Changes no
## state itself: only the sequence's hold and clock steps and the wormhole screen's Close and
## Read console. When the wormhole screen steps aside for the Address Book or the Archive, it
## says so.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#state-machines (presentation machines mirror simulation state)

## An overlay opened or closed; the view moves focus.
signal changed
## The wormhole screen stepped aside so the player can see the Address Book.
signal address_book_requested
## The wormhole screen stepped aside so the player can read [param document_id] in the Archive.
signal archive_requested(document_id: StringName)

var _simulation: Simulation = null
var _sequence: DialSequence = null

@onready var _result: ResultCard = %ResultCard
@onready var _wormhole: WormholeScreen = %WormholeScreen


func _ready() -> void:
	_result.dismissed.connect(_on_dismissed)
	_wormhole.dismissed.connect(_on_dismissed)
	_wormhole.address_book_requested.connect(address_book_requested.emit)
	_wormhole.archive_requested.connect(archive_requested.emit)


func _enter_tree() -> void:
	EventBus.dial_started.connect(_on_dial_started)


func _exit_tree() -> void:
	EventBus.dial_started.disconnect(_on_dial_started)


## Takes [param sequence], which lives on the Ring view, as the dialing sequence and makes it
## light [param ring]'s seals. Call once, before [method setup].
func attach(sequence: DialSequence, ring: RingView) -> void:
	_sequence = sequence
	_sequence.set_ring_view(ring)
	_sequence.finished.connect(_on_sequence_finished)


## Keeps the wormhole screen below [param top] pixels from this control's top edge, where the
## Ring view ends.
func keep_clear_above(top: float) -> void:
	_wormhole.offset_top = top


## True when [param control] is inside an overlay or the dialing sequence.
func holds(control: Control) -> bool:
	return is_ancestor_of(control) or (_sequence != null and _sequence.is_ancestor_of(control))


## Connects every overlay to [param simulation] and shows the one its Ring calls for: the
## sequence while it dials (it resumes and resolves the dial), the wormhole screen while one
## is open, otherwise none.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_sequence.setup(simulation)
	_result.close()
	_wormhole.setup(simulation)
	match simulation.state.gate.mode:
		GateState.RingMode.DIALING:
			_sequence.begin()
		GateState.RingMode.LOCKED:
			_wormhole.open()
	changed.emit()


## True while any overlay shows.
func is_open() -> bool:
	return _sequence.is_open() or _result.is_open() or _wormhole.is_open()


## Returns the control the open overlay focuses, or null when none shows.
func get_default_focus() -> Control:
	if _sequence.is_open():
		return _sequence.get_skip_button()
	if _result.is_open():
		return _result.get_ok_button()
	return _wormhole.get_default_focus()


## Returns the dialing sequence.
func get_sequence() -> DialSequence:
	return _sequence


## Returns the result card.
func get_result_card() -> ResultCard:
	return _result


## Returns the wormhole screen.
func get_wormhole_screen() -> WormholeScreen:
	return _wormhole


func _on_dial_started(_address_key: String) -> void:
	_result.close()
	_wormhole.close()
	_sequence.begin()
	changed.emit()


func _on_sequence_finished(outcome: int) -> void:
	var gate: GateState = _simulation.state.gate
	if gate.mode == GateState.RingMode.LOCKED:
		_wormhole.open()
	elif outcome >= 0 and not gate.dial_log.is_empty():
		_result.show_entry(gate.dial_log[gate.dial_log.size() - 1])
	changed.emit()


func _on_dismissed() -> void:
	changed.emit()
