class_name GateRoomView
extends GameView
## The Gate Room view: the player sees the charge the address needs, dials it with a
## hold-to-confirm, watches the seals engage, reads the outcome, closes an open wormhole and
## checks the Dial Log. The address is the one placed in the Analysis view's Workbench, read
## from an address source each time the view is shown: a throwaway bridge until the dial
## console card. The view only composes the panels; every panel reads the simulation and posts
## its own commands, and nothing here changes state.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#dialing-outcomes-and-energy,
## technical-architecture.md#input-accessibility-and-localisation

const _TITLE_KEY: StringName = &"GATE_ROOM_TITLE"

@onready var _ring: RingDisplay = %RingDisplay
@onready var _gauge: CapacitorGauge = %CapacitorGauge
@onready var _controls: DialControls = %DialControls
@onready var _banner: OutcomeBanner = %OutcomeBanner
@onready var _wormhole: WormholePanel = %WormholePanel
@onready var _log: DialLogPanel = %DialLogPanel


## Returns the address to dial, or null: a Callable() -> GateAddress (null for none).
var _address_source: Callable = Callable()


func _enter_tree() -> void:
	EventBus.wormhole_closed.connect(_on_focus_may_be_lost)
	EventBus.dial_started.connect(_on_dial_started)
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.wormhole_closed.disconnect(_on_focus_may_be_lost)
	EventBus.dial_started.disconnect(_on_dial_started)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and is_visible_in_tree():
		refresh_address()


## Passes [param simulation] to every panel; no address is selected until the view is shown
## again or refresh_address() runs.
func setup(simulation: Simulation) -> void:
	_controls.setup(simulation)
	_gauge.setup(simulation)
	_ring.setup(simulation)
	_banner.setup(simulation)
	_wormhole.setup(simulation)
	_log.setup(simulation)
	_gauge.set_marker_address(null)


## Sets where the address to dial comes from: [param source] is a Callable() -> GateAddress
## that returns null for none (the Workbench's address, until the dial console).
func set_address_source(source: Callable) -> void:
	_address_source = source
	if is_node_ready() and is_visible_in_tree():
		refresh_address()


## Reads the address source again and selects its address (or none) for the Dial button and
## the charge marker.
func refresh_address() -> void:
	var address: GateAddress = null
	if _address_source.is_valid():
		address = _address_source.call()
	_controls.set_address(address)
	_gauge.set_marker_address(address)


## Returns the Dial button while it can be pressed, else the first Dial Log row, else the
## Dial button.
func get_default_focus() -> Control:
	var dial: HoldButton = _controls.get_dial_button()
	if dial.disabled:
		var first_row: Control = _log.get_first_focus()
		if first_row != null:
			return first_row
	return dial


## Returns [code]GATE_ROOM_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY


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


func _on_dial_started(_address_key: String) -> void:
	_ensure_focus.call_deferred()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_ensure_focus.call_deferred()
