class_name GateRoomView
extends GameView
## The Gate Room view: the dial console (slots, palette and the hold-to-dial button) over the
## capacitor gauge (stored charge and capacity only), beside the records: the Address Book and
## the Dial Log. Loading an Address Book entry fills the console's slots. On top, the overlays
## (dialing sequence, result card, wormhole screen) cover the view while one is open and take
## focus. The view only composes the panels; every panel reads the simulation and posts its
## own commands, and nothing here changes state.
## Bible: gate-and-address-spec.md#the-dial-console,
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole, game-design.md#core-loop,
## technical-architecture.md#input-accessibility-and-localisation

const _TITLE_KEY: StringName = &"GATE_ROOM_TITLE"
## Tab title keys of the records, in tab order.
const _RECORD_TITLE_KEYS: Array[StringName] = [&"BOOK_TITLE", &"GATE_LOG_TITLE"]

@onready var _console: DialConsole = %DialConsole
@onready var _gauge: CapacitorGauge = %CapacitorGauge
@onready var _records: TabContainer = %Records
@onready var _book: AddressBookPanel = %AddressBookPanel
@onready var _log: DialLogPanel = %DialLogPanel
@onready var _overlays: GateOverlays = %GateOverlays


func _ready() -> void:
	for index: int in _RECORD_TITLE_KEYS.size():
		_records.set_tab_title(index, _RECORD_TITLE_KEYS[index])
	_book.load_requested.connect(_on_load_requested)
	_overlays.changed.connect(_on_overlays_changed)


func _enter_tree() -> void:
	EventBus.wormhole_closed.connect(_on_focus_may_be_lost)
	EventBus.dial_started.connect(_on_dial_started)
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.wormhole_closed.disconnect(_on_focus_may_be_lost)
	EventBus.dial_started.disconnect(_on_dial_started)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


## Passes [param simulation] to every panel; the console's slots are emptied.
func setup(simulation: Simulation) -> void:
	_gauge.setup(simulation)
	_console.setup(simulation)
	_book.setup(simulation)
	_log.setup(simulation)
	_overlays.setup(simulation)


## Returns the dial console.
func get_console() -> DialConsole:
	return _console


## Returns the Address Book panel.
func get_address_book() -> AddressBookPanel:
	return _book


## Returns the overlays (dialing sequence, result card, wormhole screen).
func get_overlays() -> GateOverlays:
	return _overlays


## Returns the open overlay's button; else the Dial button while it can be pressed, else the
## first glyph of the palette.
func get_default_focus() -> Control:
	var overlay_focus: Control = _overlays.get_default_focus()
	if overlay_focus != null:
		return overlay_focus
	return _console.get_default_focus()


## Returns [code]GATE_ROOM_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY


## The focused control may have been removed or disabled (a closed wormhole's button, a dial
## button that locks while the Ring is busy) or be left behind an overlay: move focus to the
## default control. Focus on anything outside this view (the tab bar, the time bar) is left
## alone.
func _ensure_focus() -> void:
	if not is_visible_in_tree():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		var is_stuck: bool = focused is BaseButton and (focused as BaseButton).disabled
		if _overlays.is_open():
			is_stuck = not _overlays.is_ancestor_of(focused)
		if not is_ancestor_of(focused) or not is_stuck:
			return
	get_default_focus().grab_focus()


func _on_load_requested(address: GateAddress) -> void:
	_console.load_address(address)
	_ensure_focus.call_deferred()


func _on_overlays_changed() -> void:
	_ensure_focus.call_deferred()


func _on_focus_may_be_lost(_reason: StringName) -> void:
	_ensure_focus.call_deferred()


func _on_dial_started(_address_key: String) -> void:
	_ensure_focus.call_deferred()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_ensure_focus.call_deferred()
