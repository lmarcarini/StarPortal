class_name DialConsole
extends VBoxContainer
## The dial console of the Gate Room: seven seal slots, CAIRN's locked origin in seal 8, the
## 36-glyph palette, the charge line and the hold-to-dial button. Clicking a glyph (or accept on
## the gamepad) puts it in the lowest-numbered empty seal; dragging it onto a slot puts it
## there, overwriting what the slot held. Placing a glyph by drag moves it out of any other
## slot, and a click on a glyph already placed changes nothing, so a glyph is never in two
## seals. A filled slot is cleared by a click or accept on it, right-click, Delete or Backspace,
## or cancel (Escape, gamepad B); "Clear all" empties the seven. The palette highlights the
## placed glyphs and nothing else.
## The slots are view state: nothing here is saved, and the only command posted is the
## DialControls' DialCommand.
## Bible: gate-and-address-spec.md#the-dial-console,
## game-design.md#difficulty-and-accessibility (one-click placing, dragging, gamepad)

## The address in the slots changed: the seven glyphs with CAIRN's origin, or null while a
## slot is empty.
signal address_changed(address: GateAddress)

## Hint key shown while no notice is up.
const HINT_IDLE: StringName = &"CONSOLE_HINT_IDLE"
## Notice key when a glyph is clicked with all seven seals set.
const NOTICE_ALL_SET: StringName = &"CONSOLE_ALL_SET"
## Notice key when a glyph already in a seal is clicked.
const NOTICE_ALREADY_SET: StringName = &"CONSOLE_GLYPH_ALREADY_SET"
## How long a notice replaces the hint, in real seconds.
const NOTICE_SECONDS: float = 2.5

var _simulation: Simulation = null
## Text of the notice shown in place of the hint, or "" for none.
var _notice: String = ""
var _notice_timer: Timer = null
## Glyph placed at each coordinate seal, index 0 for seal 1; -1 while empty.
var _placed: Array[int] = []

@onready var _seals: SealRow = %SealRow
@onready var _hint: Label = %Hint
@onready var _clear_all: Button = %ClearAllButton
@onready var _palette: GlyphPalette = %Palette
@onready var _controls: DialControls = %DialControls
@onready var _side: VBoxContainer = %Side


func _init() -> void:
	_clear_seals()


func _ready() -> void:
	_move_origin_caption()
	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(_clear_notice)
	add_child(_notice_timer)
	_seals.slot_chosen.connect(_on_slot_chosen)
	_seals.glyph_dropped.connect(_on_glyph_dropped)
	_seals.clear_requested.connect(clear_seal)
	_palette.glyph_chosen.connect(_on_glyph_chosen)
	_clear_all.pressed.connect(clear_all)
	_render()


# The desk keeps the seal row short: the row's origin caption is shown under the hint, in the
# right-hand column, so the seals and palette on the left take less height.
func _move_origin_caption() -> void:
	var caption: Control = _seals.find_child("OriginCaption", true, false) as Control
	caption.reparent(_side, false)
	_side.move_child(caption, 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


# Key events go to the focused control only, so cancel is caught here: while focus is on a
# filled slot of the console it clears that slot.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused) or not focused is SealSlot:
		return
	var slot: SealSlot = focused as SealSlot
	if slot.is_locked() or slot.get_glyph() < 0:
		return
	clear_seal(slot.seal)
	get_viewport().set_input_as_handled()


## Connects the console to [param simulation] (from _ready() when called before it). Call
## again after a load: the slots are emptied.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_controls.setup(simulation)
	_clear_seals()
	_changed()


## Returns the notice shown in place of the hint ("All seven seals are set." and the like), or
## "" while the hint shows.
func get_notice() -> String:
	return _notice


## Returns the dial controls (charge line, reasons and the Dial button).
func get_dial_controls() -> DialControls:
	return _controls


## Returns the glyph placed at [param seal], 1..7, or -1 when it is empty or out of range.
func get_placed(seal: int) -> int:
	if seal < 1 or seal > _placed.size():
		return -1
	return _placed[seal - 1]


## Returns the address in the slots, the seven placed glyphs then CAIRN's origin, or null
## until all seven are filled (or with no simulation).
func get_address() -> GateAddress:
	if _simulation == null or _placed.has(-1):
		return null
	return GateAddress.create(_placed, _origin())


## Returns CAIRN's origin glyph, shown locked in seal 8, or -1 before a simulation is set.
func get_address_origin() -> int:
	return _origin()


## Puts [param glyph] in [param seal], 1..7, taking it out of any other slot. CAIRN's origin
## glyph and seal 8 are refused.
func place(seal: int, glyph: int) -> void:
	if seal < 1 or seal > GateAddress.COORDINATE_COUNT or glyph == _origin():
		return
	if glyph < 0 or glyph >= GateAddress.GLYPH_COUNT:
		return
	var previous: int = _placed.find(glyph)
	if previous >= 0:
		_placed[previous] = -1
	_placed[seal - 1] = glyph
	_changed()


## Puts [param glyph] in the lowest-numbered empty seal of 1..7, as a click on the palette
## does. Changes nothing and shows a notice when all seven are set or the glyph is already in a
## seal; CAIRN's origin glyph is refused.
func place_next(glyph: int) -> void:
	if glyph < 0 or glyph >= GateAddress.GLYPH_COUNT or glyph == _origin():
		return
	var existing: int = _placed.find(glyph)
	if existing >= 0:
		var glyph_name: String = tr(PaletteGlyph.name_key_of(glyph))
		_show_notice(tr(NOTICE_ALREADY_SET).format({"glyph": glyph_name, "seal": existing + 1}))
		return
	var empty: int = _placed.find(-1)
	if empty < 0:
		_show_notice(tr(NOTICE_ALL_SET))
		return
	place(empty + 1, glyph)


## Empties [param seal], 1..7.
func clear_seal(seal: int) -> void:
	if seal < 1 or seal > GateAddress.COORDINATE_COUNT:
		return
	_placed[seal - 1] = -1
	_changed()


## Empties the seven slots.
func clear_all() -> void:
	_clear_seals()
	_changed()
	if _clear_all.has_focus():
		_palette.get_first_focus().grab_focus()


## Fills the seven slots with [param address]'s coordinates. A coordinate that is CAIRN's
## origin glyph cannot be placed, so its slot stays empty.
func load_address(address: GateAddress) -> void:
	if address == null:
		return
	_clear_seals()
	for index: int in mini(address.coordinates.size(), GateAddress.COORDINATE_COUNT):
		var glyph: int = address.coordinates[index]
		if glyph != _origin() and not _placed.has(glyph):
			_placed[index] = glyph
	_changed()


## Returns the control that takes focus first: the Dial button while it can be pressed, else
## the first glyph of the palette.
func get_default_focus() -> Control:
	var dial: HoldButton = _controls.get_dial_button()
	if not dial.disabled:
		return dial
	return _palette.get_first_focus()


func _clear_seals() -> void:
	_placed.clear()
	_placed.resize(GateAddress.COORDINATE_COUNT)
	_placed.fill(-1)


## CAIRN's origin glyph, or -1 before a simulation with a galaxy is set.
func _origin() -> int:
	if _simulation == null or _simulation.state.galaxy == null:
		return -1
	return _simulation.state.galaxy.home().origin_glyph


func _changed() -> void:
	if not is_node_ready():
		return
	_notice = ""
	var address: GateAddress = get_address()
	_controls.set_address(address)
	_render()
	address_changed.emit(address)


func _render() -> void:
	var shown: Array[int] = _placed.duplicate()
	shown.append(_origin())
	_seals.show_glyphs(shown, tr)
	_palette.show_state(_placed, _origin(), tr)
	_clear_all.disabled = _placed.all(func(glyph: int) -> bool: return glyph < 0)
	_hint.text = _notice if _notice != "" else tr(HINT_IDLE)


## Shows [param text] in place of the hint for NOTICE_SECONDS.
func _show_notice(text: String) -> void:
	_notice = text
	if _notice_timer != null:
		_notice_timer.start(NOTICE_SECONDS)
	if is_node_ready():
		_render()


func _clear_notice() -> void:
	_notice = ""
	_render()


func _on_glyph_chosen(glyph: int) -> void:
	place_next(glyph)


# A click or accept on a filled coordinate slot clears it; seal 8 never changes.
func _on_slot_chosen(seal: int) -> void:
	if seal > GateAddress.COORDINATE_COUNT or get_placed(seal) < 0:
		return
	clear_seal(seal)


func _on_glyph_dropped(seal: int, glyph: int) -> void:
	if seal <= GateAddress.COORDINATE_COUNT:
		place(seal, glyph)
