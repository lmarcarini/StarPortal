class_name GateRoomView
extends GameView
## The Gate Room view: the player picks an address from the dial queue or types one in, sees
## the charge it needs, dials with a hold-to-confirm, watches the seals engage, reads the
## outcome, closes an open wormhole and checks the Dial Log. It only composes the panels and
## wires their selection; every panel reads the simulation and posts its own commands, and
## nothing here changes state.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#player-tools,
## technical-architecture.md#input-accessibility-and-localisation

const _TITLE_KEY: StringName = &"GATE_ROOM_TITLE"

@onready var _queue: DialQueuePanel = %DialQueuePanel
@onready var _entry: AddressEntry = %AddressEntry
@onready var _ring: RingDisplay = %RingDisplay
@onready var _gauge: CapacitorGauge = %CapacitorGauge
@onready var _controls: DialControls = %DialControls
@onready var _banner: OutcomeBanner = %OutcomeBanner
@onready var _wormhole: WormholePanel = %WormholePanel
@onready var _log: DialLogPanel = %DialLogPanel


func _ready() -> void:
	_queue.selection_changed.connect(_on_selection_changed)
	_entry.queued.connect(_queue.select_address)


func _enter_tree() -> void:
	EventBus.wormhole_closed.connect(_on_focus_may_be_lost)
	EventBus.dial_queue_changed.connect(_on_queue_changed)
	EventBus.dial_started.connect(_on_dial_started)
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.wormhole_closed.disconnect(_on_focus_may_be_lost)
	EventBus.dial_queue_changed.disconnect(_on_queue_changed)
	EventBus.dial_started.disconnect(_on_dial_started)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


## Passes [param simulation] to every panel; nothing is selected until the queue says so.
func setup(simulation: Simulation) -> void:
	_controls.setup(simulation)
	_gauge.setup(simulation)
	_ring.setup(simulation)
	_banner.setup(simulation)
	_wormhole.setup(simulation)
	_log.setup(simulation)
	_entry.setup(simulation)
	_queue.setup(simulation)


## Returns the first queued address, or the first glyph picker when the queue is empty.
func get_default_focus() -> Control:
	var first: Control = _queue.get_first_focus()
	if first != null:
		return first
	return _entry.get_first_focus()


## Returns [code]GATE_ROOM_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY


func _on_selection_changed(address: GateAddress) -> void:
	_controls.set_address(address)
	_gauge.set_marker_address(address)


## The focused control may have been removed or disabled (a closed wormhole's button, a dial
## button that locks while the Ring is busy): move focus to the default control. Focus on
## anything outside this view (the tab bar, the time bar) is left alone.
func _ensure_focus() -> void:
	if not is_visible_in_tree():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		var is_stuck: bool = (
			is_ancestor_of(focused) and focused is BaseButton and (focused as BaseButton).disabled
		)
		if not is_stuck:
			return
	get_default_focus().grab_focus()


func _on_focus_may_be_lost(_reason: StringName) -> void:
	_ensure_focus.call_deferred()


func _on_queue_changed() -> void:
	_ensure_focus.call_deferred()


func _on_dial_started(_address_key: String) -> void:
	_ensure_focus.call_deferred()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_ensure_focus.call_deferred()
