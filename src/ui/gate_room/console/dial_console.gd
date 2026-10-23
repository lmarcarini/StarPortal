class_name DialConsole
extends VBoxContainer
## The dial console of the Gate Room: seven seal slots, CAIRN's locked origin in seal 8, the
## 36-glyph palette, the charge line and the hold-to-dial button. The player places a glyph by
## dragging it onto a slot, by clicking it then a slot, or with the gamepad (accept on a glyph,
## then on a slot). Placing a glyph moves it out of any other slot; a placed slot is cleared by
## right-click, Delete or Backspace, or cancel (Escape, gamepad B) while no glyph is picked;
## "Clear all" empties the seven. The palette highlights the placed glyphs and nothing else.
## The slots are view state: nothing here is saved, and the only command posted is the
## DialControls' DialCommand.
## Bible: gate-and-address-spec.md#the-dial-console,
## game-design.md#difficulty-and-accessibility (click-to-pick, dragging, gamepad)

## The address in the slots changed: the seven glyphs with CAIRN's origin, or null while a
## slot is empty.
signal address_changed(address: GateAddress)

## Hint key per GlyphPicker.Mode: IDLE, then GLYPH_PICKED.
const HINT_IDLE: StringName = &"CONSOLE_HINT_IDLE"
const HINT_PICKED: StringName = &"CONSOLE_HINT_PICKED"

var _simulation: Simulation = null
var _picker: GlyphPicker = GlyphPicker.new()
## Glyph placed at each coordinate seal, index 0 for seal 1; -1 while empty.
var _placed: Array[int] = []

@onready var _seals: SealRow = %SealRow
@onready var _hint: Label = %Hint
@onready var _clear_all: Button = %ClearAllButton
@onready var _palette: GlyphPalette = %Palette
@onready var _controls: DialControls = %DialControls


func _init() -> void:
	_clear_seals()


func _ready() -> void:
	_seals.slot_chosen.connect(_on_slot_chosen)
	_seals.glyph_dropped.connect(_on_glyph_dropped)
	_seals.clear_requested.connect(clear_seal)
	_palette.glyph_chosen.connect(_on_glyph_chosen)
	_clear_all.pressed.connect(clear_all)
	_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


# Key events go to the focused control only, so cancel is caught here: while focus is in the
# console it drops a pick, or else clears the focused slot.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		return
	if _picker.has_glyph():
		_picker.cancel()
		_render()
	elif focused is SealSlot and (focused as SealSlot).get_glyph() >= 0:
		clear_seal((focused as SealSlot).seal)
	else:
		return
	get_viewport().set_input_as_handled()


## Connects the console to [param simulation] (from _ready() when called before it). Call
## again after a load: the slots are emptied and any pick is dropped.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_controls.setup(simulation)
	_picker.cancel()
	_clear_seals()
	_changed()


## Returns the click-to-pick state, for tests and focus hints.
func get_picker() -> GlyphPicker:
	return _picker


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


## Empties [param seal], 1..7.
func clear_seal(seal: int) -> void:
	if seal < 1 or seal > GateAddress.COORDINATE_COUNT:
		return
	_placed[seal - 1] = -1
	_changed()


## Empties the seven slots and drops any pick.
func clear_all() -> void:
	_picker.cancel()
	_clear_seals()
	_changed()
	if _clear_all.has_focus():
		_palette.get_first_focus().grab_focus()


## Fills the seven slots with [param address]'s coordinates. A coordinate that is CAIRN's
## origin glyph cannot be placed, so its slot stays empty.
func load_address(address: GateAddress) -> void:
	if address == null:
		return
	_picker.cancel()
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
	var address: GateAddress = get_address()
	_controls.set_address(address)
	_render()
	address_changed.emit(address)


func _render() -> void:
	var shown: Array[int] = _placed.duplicate()
	shown.append(_origin())
	_seals.show_glyphs(shown, tr)
	var picked: int = _picker.glyph if _picker.has_glyph() else -1
	_palette.show_state(picked, _placed, _origin(), tr)
	_clear_all.disabled = _placed.all(func(glyph: int) -> bool: return glyph < 0)
	if _picker.has_glyph():
		_hint.text = tr(HINT_PICKED).format({"glyph": tr(PaletteGlyph.name_key_of(_picker.glyph))})
	else:
		_hint.text = tr(HINT_IDLE)


func _on_glyph_chosen(glyph: int) -> void:
	if glyph == _origin():
		return
	_picker.pick(glyph)
	_render()


func _on_slot_chosen(seal: int) -> void:
	if not _picker.has_glyph() or seal > GateAddress.COORDINATE_COUNT:
		return
	var glyph: int = _picker.glyph
	_picker.cancel()
	place(seal, glyph)


func _on_glyph_dropped(seal: int, glyph: int) -> void:
	_picker.cancel()
	if seal <= GateAddress.COORDINATE_COUNT:
		place(seal, glyph)
	_render()
