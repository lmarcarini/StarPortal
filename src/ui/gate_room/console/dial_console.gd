class_name Workbench
extends Control
## The Address Workbench of the Analysis view, a placeholder until the dial console: eight
## seal slots and the 36-glyph palette. The player places glyphs in seals 1 to 7 by picking a
## glyph and then a seal, or by dragging a glyph onto a seal; seal 8 always shows CAIRN's
## origin. Placing a glyph moves it out of any other seal. The placed glyphs are view-local:
## nothing here is game state, nothing is saved, and the view never submits a command.
## get_address() hands the placed address to the Gate Room's Dial button.
##
## Focus: the root takes focus as one stop in the Analysis view; accept or down enters it (the
## first seal slot), and cancel drops a pick while focus is inside.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math (seal 8 is the origin),
## game-design.md#difficulty-and-accessibility (click-to-pick, dragging, gamepad)

## Hint key per WorkbenchPicker.Mode used here: IDLE, then GLYPH_PICKED.
const HINT_IDLE: StringName = &"WORKBENCH_HINT_IDLE"
const HINT_PICKED: StringName = &"WORKBENCH_HINT_PICKED"

var _simulation: Simulation = null
var _picker: WorkbenchPicker = WorkbenchPicker.new()
## Glyph placed at each coordinate seal, index 0 for seal 1; -1 while empty.
var _placed: Array[int] = []

@onready var _seals: SealRow = %SealRow
@onready var _hint: Label = %Hint
@onready var _palette: GlyphPalette = %Palette


func _init() -> void:
	_clear_seals()


func _ready() -> void:
	_seals.slot_chosen.connect(_on_slot_chosen)
	_seals.glyph_dropped.connect(_on_glyph_dropped)
	_palette.glyph_chosen.connect(_on_glyph_chosen)
	_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


func _gui_input(event: InputEvent) -> void:
	var enters: bool = event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_down")
	if has_focus() and enters:
		_seals.get_slot(1).grab_focus()
		accept_event()


# Key events go to the focused control only, so cancel is caught here: it drops a pick while
# focus is anywhere in the workbench.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or not _picker.has_glyph():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not (focused == self or is_ancestor_of(focused)):
		return
	_picker.cancel()
	_render()
	get_viewport().set_input_as_handled()


## Shows the workbench for [param simulation] (from _ready() when called before it). Call
## again after a load: the seals are emptied and any pick is dropped.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_picker.cancel()
	_clear_seals()
	if is_node_ready():
		_render()


## Returns the click-to-pick state, for tests and focus hints.
func get_picker() -> WorkbenchPicker:
	return _picker


## Returns the glyph placed at [param seal], 1..7, or -1 when it is empty or out of range.
func get_placed(seal: int) -> int:
	if seal < 1 or seal > _placed.size():
		return -1
	return _placed[seal - 1]


## Returns the address in the slots, the seven placed glyphs then CAIRN's origin, or null
## until all seven are filled (or with no simulation). It may still be malformed, e.g. with
## the origin glyph among the seven; the Dial button checks.
func get_address() -> GateAddress:
	if _simulation == null or _placed.has(-1):
		return null
	return GateAddress.create(_placed, _origin())


func _clear_seals() -> void:
	_placed.clear()
	_placed.resize(GateAddress.COORDINATE_COUNT)
	_placed.fill(-1)


## CAIRN's origin glyph, or -1 before a simulation with a galaxy is set.
func _origin() -> int:
	if _simulation == null or _simulation.state.galaxy == null:
		return -1
	return _simulation.state.galaxy.home().origin_glyph


## Puts [param glyph] at coordinate [param seal], taking it out of any other seal.
func _place(seal: int, glyph: int) -> void:
	var previous: int = _placed.find(glyph)
	if previous >= 0:
		_placed[previous] = -1
	_placed[seal - 1] = glyph


func _render() -> void:
	var shown: Array[int] = _placed.duplicate()
	shown.append(_origin())
	_seals.show_glyphs(shown, tr)
	_palette.show_picked(_picker.glyph if _picker.has_glyph() else -1, tr)
	if _picker.has_glyph():
		_hint.text = tr(HINT_PICKED).format({"glyph": tr(PaletteGlyph.name_key_of(_picker.glyph))})
	else:
		_hint.text = tr(HINT_IDLE)


func _on_glyph_chosen(glyph: int) -> void:
	_picker.pick(glyph)
	_render()


func _on_slot_chosen(seal: int) -> void:
	if not _picker.has_glyph() or seal > GateAddress.COORDINATE_COUNT:
		return
	_place(seal, _picker.glyph)
	_picker.cancel()
	_render()


func _on_glyph_dropped(seal: int, glyph: int) -> void:
	_picker.cancel()
	if seal <= GateAddress.COORDINATE_COUNT:
		_place(seal, glyph)
	_render()
