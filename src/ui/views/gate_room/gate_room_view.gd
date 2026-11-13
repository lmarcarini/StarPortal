class_name GateRoomView
extends GameView
## The Gate Room view, in the hybrid layout. On the left, the window onto the Gate Room floor with
## the Ring view, the centrepiece, in the middle (the dialing sequence's caption to its left, the
## capacitor gauge to its right) and, below it, the dial console desk (seals and palette, then hint,
## charge and the hold-to-dial button), taking the full width. On the right edge, the Address Book
## drawer, collapsed to a tab by default; opened, it lies over the right side of the view (dials and
## their outcomes are in the Archive's operations log). Loading an entry fills the console's slots
## and collapses the drawer. The dialing sequence plays on the Ring; the result card covers the view
## and takes focus. While a wormhole is open its status strip sits right of the Ring and left of the
## drawer's tab, and clicking the portal (or A with the Ring focused) opens the action panel below
## the strip, which takes focus; hiding it gives focus back to the Ring. The drawer lies above the
## strip: the tab always shows, and the open Address Book covers the strip and its actions until it
## is closed. The dialing sequence and the result card stay above the drawer: while either shows,
## the drawer is collapsed and hidden. The view only composes the panels; every panel reads the
## simulation and posts its own commands, and nothing here changes state. When the wormhole actions
## ask to read a new document in the Archive, the view passes the request on to the switcher.
## Left of the Ring (where the dialing caption shows while dialing) it hosts the horizon photo;
## extending the pole camera plays a short cue on the Ring and refreshes the photo at once.
## While a MOTH is out (or its SIGNAL LOST waits to be closed) the MOTH scan screen covers the
## view and holds focus.
## Bible: gate-and-address-spec.md#the-dial-console,
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole, game-design.md#core-loop,
## technical-architecture.md#input-accessibility-and-localisation

## The wormhole actions asked to read [param document_id] in the Archive.
signal archive_requested(document_id: StringName)
## The capacitor gauge asked to build the first Capacitor Bank in the Base tab.
signal capacitor_bank_requested

const _TITLE_KEY: StringName = &"GATE_ROOM_TITLE"

var _photo := HorizonPhoto.new()
var _camera_cue := CameraCue.new()
var _moth := MothScreen.new()
var _incoming := IncomingBanner.new()

@onready var _console: DialConsole = %DialConsole
@onready var _gauge: CapacitorGauge = %CapacitorGauge
@onready var _drawer: AddressBookDrawer = %AddressBookDrawer
@onready var _book: AddressBookPanel = _drawer.get_panel()
@onready var _overlays: GateOverlays = %GateOverlays
@onready var _ring: RingView = %RingView
@onready var _sequence: DialSequence = %DialSequence


func _ready() -> void:
	_overlays.attach(_sequence, _ring)
	_ring.resized.connect(_on_ring_resized)
	_on_ring_resized.call_deferred()
	_overlays.get_wormhole_screen().offset_right = -AddressBookDrawer.TAB_WIDTH
	_book.load_requested.connect(_on_load_requested)
	_overlays.changed.connect(_on_overlays_changed)
	_overlays.address_book_requested.connect(_on_address_book_requested)
	_overlays.archive_requested.connect(archive_requested.emit)
	_gauge.build_bank_requested.connect(capacitor_bank_requested.emit)
	_sequence.get_parent().add_child(_photo)
	_ring.add_child(_camera_cue)
	var wormhole: WormholeScreen = _overlays.get_wormhole_screen()
	wormhole.camera_extended.connect(_on_camera_extended)
	wormhole.photo_requested.connect(_photo.toggle_enlarged)
	add_child(_moth)
	_incoming.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	add_child(_incoming)
	_moth.changed.connect(_on_moth_changed)


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
	_drawer.setup(simulation)
	_ring.setup(simulation.state.gate.mode)
	_overlays.setup(simulation)
	_photo.setup(simulation)
	_moth.setup(simulation)
	_incoming.setup(simulation)


## Returns the incoming wormhole banner.
func get_incoming_banner() -> IncomingBanner:
	return _incoming


## Returns the dial console.
func get_console() -> DialConsole:
	return _console


## Returns the Address Book panel.
func get_address_book() -> AddressBookPanel:
	return _book


## Returns the Address Book drawer.
func get_address_drawer() -> AddressBookDrawer:
	return _drawer


## Returns the Ring view.
func get_ring_view() -> RingView:
	return _ring


## Returns the horizon photo beside the Ring.
func get_horizon_photo() -> HorizonPhoto:
	return _photo


## Returns the pole camera's cue on the Ring.
func get_camera_cue() -> CameraCue:
	return _camera_cue


## Returns the MOTH scan screen.
func get_moth_screen() -> MothScreen:
	return _moth


## Returns the overlays (dialing sequence, result card, wormhole screen).
func get_overlays() -> GateOverlays:
	return _overlays


## Returns the open overlay's button; else the Ring while a wormhole is open; else the Dial
## button while it can be pressed, else the first glyph of the palette.
func get_default_focus() -> Control:
	if _moth.is_open():
		return _moth.get_default_focus()
	var overlay_focus: Control = _overlays.get_default_focus()
	if overlay_focus != null:
		return overlay_focus
	if _overlays.get_wormhole_screen().is_showing_open():
		return _ring
	return _console.get_default_focus()


## Returns [code]GATE_ROOM_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY


## The focused control may have been removed or disabled (a closed wormhole's button, a dial
## button that locks while the Ring is busy, a hidden wormhole action, the Ring gone dark) or be
## left behind an overlay: move focus to the
## default control. Focus on anything outside this view (the tab bar, the time bar) is left
## alone.
func _ensure_focus() -> void:
	if not is_visible_in_tree():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		var is_stuck: bool = focused is BaseButton and (focused as BaseButton).disabled
		is_stuck = is_stuck or not focused.is_visible_in_tree()
		is_stuck = is_stuck or focused.focus_mode == Control.FOCUS_NONE
		if _moth.is_open():
			is_stuck = is_stuck or not _moth.is_ancestor_of(focused)
		elif _overlays.is_open():
			is_stuck = not _overlays.holds(focused)
		if not is_ancestor_of(focused) or not is_stuck:
			return
	get_default_focus().grab_focus()


func _on_ring_resized() -> void:
	_overlays.keep_clear_left_of(_ring.get_global_rect().end.x - get_global_rect().position.x)


func _on_load_requested(address: GateAddress) -> void:
	_console.load_address(address)
	_ensure_focus.call_deferred()


## The wormhole actions asked for the Address Book: open the drawer and focus it.
func _on_address_book_requested() -> void:
	_drawer.open()


func _on_overlays_changed() -> void:
	var overlays: GateOverlays = _overlays
	_drawer.set_blocked(overlays.get_sequence().is_open() or overlays.get_result_card().is_open())
	_ensure_focus.call_deferred()


func _on_focus_may_be_lost(_reason: StringName) -> void:
	_ensure_focus.call_deferred()


func _on_camera_extended() -> void:
	_photo.refresh()
	_photo.flash()
	_camera_cue.play()


func _on_dial_started(_address_key: String) -> void:
	_ensure_focus.call_deferred()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_ensure_focus.call_deferred()


func _on_moth_changed() -> void:
	_ensure_focus.call_deferred()
