class_name AlienPanel
extends Control
## The alien panel, full screen over the Gate station: the 36 glyphs as stone keys in three
## rings of twelve round a centre DIAL key, the seven seal lamps across the top (the eighth,
## CAIRN's mark, fixed), a pencil for guesses and the clue clip at the side. A key lights and
## fills the next seal; a lit key or a lamp clears it. Typing finds a glyph by name; the left
## stick points at a key. Esc or (B) goes back, keeping what was entered.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## The centre key asked to dial [param address].
signal dial_requested(address: GateAddress)
## The panel closed.
signal closed

## The panel's station def (placeholder plate until the owner supplies plate 2).
const STATION_ID: StringName = &"station_alien_panel"
## Seconds a typed name stays in the search.
const TYPE_SECONDS: float = 1.2
## Gap kept round the key rings, in pixels.
const MARGIN: float = 12.0
## Largest side of the centre DIAL key, before the interface scale.
const DIAL_SIZE: Vector2 = Vector2(128.0, 128.0)
## The stone disc behind the keys and its rim.
const DISC_COLOUR: Color = Color("#232220")
const DISC_RIM: Color = Color("#5a564e")

var _simulation: Simulation = null
var _compose: AddressDraft = AddressDraft.new()
var _keys: Array[GlyphKey] = []
var _typed: String = ""
var _typed_left: float = 0.0
var _found: int = -1
## The stone disc behind the keys: centre x, y and radius.
var _disc: Vector3 = Vector3.ZERO

@onready var _station: StationScene = %Station
@onready var _key_area: Control = %Keys
@onready var _dial: BigKey = %DialKey
@onready var _lamps: SealSlots = %SealSlots
@onready var _clue: ClueClip = %ClueClip
@onready var _back: IconKey = %BackKey
@onready var _pencil: IconKey = %PencilKey


func _ready() -> void:
	add_to_group(Wire.COVER_GROUP)
	z_index = 5
	_station.setup(Registry.get_def(STATION_ID) as StationSceneDef)
	for glyph: int in GateAddress.GLYPH_COUNT:
		var key: GlyphKey = GlyphKey.new()
		key.name = "Glyph%02d" % glyph
		_key_area.add_child(key)
		var def: GlyphDef = (
			Registry.get_def(StringName(GlyphIcon.GLYPH_ID_FORMAT % glyph)) as GlyphDef
		)
		key.setup(glyph, String(def.name_key) if def != null else "")
		key.glyph_pressed.connect(press_glyph)
		_keys.append(key)
	_dial.activated.connect(_on_dial)
	HoverCard.attach(_dial, "STATION_PANEL_DIAL")
	_back.icon_id = &"close"
	_back.set_help("STATION_PANEL_BACK")
	_back.pressed.connect(close)
	_pencil.icon_id = &"pencil"
	_pencil.toggle_mode = true
	_pencil.set_help("STATION_PANEL_PENCIL")
	_lamps.seal_pressed.connect(clear_seal)
	resized.connect(_place_keys)
	_key_area.draw.connect(_draw_disc)
	_place_keys.call_deferred()


## Reads [param simulation] (CAIRN's mark, the clue documents).
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_compose = AddressDraft.new()
	_compose.firm = simulation.state.address_book.draft_firm.duplicate()
	_compose.pencil = simulation.state.address_book.draft_pencil.duplicate()
	_clue.setup(simulation)
	_render()


## Opens the panel; what was entered before is still there.
func open() -> void:
	show()
	if _simulation != null:
		_clue.setup(_simulation)
	_render()
	_dial.grab_focus()


## Closes the panel, keeping the entered glyphs and guesses.
func close() -> void:
	hide()
	closed.emit()


## Presses glyph [param glyph]: a lit glyph is cleared, else it fills the next seal (in
## pencil while the pencil is down).
func press_glyph(glyph: int) -> void:
	_compose.press(glyph, _pencil.button_pressed)
	_keep()
	_render()


## Clears seal [param seal] (firm glyph and guess).
func clear_seal(seal: int) -> void:
	_compose.clear(seal)
	_keep()
	_render()


## Keeps the draft in the state (SetAddressDraftCommand), so it survives a save.
func _keep() -> void:
	if _simulation != null:
		_simulation.submit(SetAddressDraftCommand.create(_compose.firm, _compose.pencil))


## The draft being composed.
func get_draft() -> AddressDraft:
	return _compose


## The address the firm glyphs make with CAIRN's mark, or null while incomplete.
func get_address() -> GateAddress:
	return _compose.address(_origin())


## The key of glyph [param glyph].
func get_key(glyph: int) -> GlyphKey:
	return _keys[glyph]


## Feeds typed text [param text] to the name search; returns the glyph found or -1.
func type_text(text: String) -> int:
	_typed += text.to_lower()
	_typed_left = TYPE_SECONDS
	_found = AddressDraft.find_by_name(_typed, _names())
	if _found >= 0:
		_keys[_found].pulse()
	return _found


## Shows a refusal from the dial on the centre key: hover reason and a shake.
func show_refusal(reason_key: String) -> void:
	var card: HoverCard = _dial.find_child("HoverCard", false, false) as HoverCard
	if card != null:
		card.set_text(reason_key)
	var tween: Tween = create_tween()
	var x: float = _dial.position.x
	for dx: float in [6.0, -6.0, 3.0, 0.0]:
		tween.tween_property(_dial, "position:x", x + dx, 0.04)


func _process(delta: float) -> void:
	if not visible:
		return
	_typed_left = maxf(0.0, _typed_left - delta)
	if _typed_left <= 0.0:
		_typed = ""
	var stick: Vector2 = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	var glyph: int = RadialLayout.glyph_at_stick(stick)
	if glyph >= 0 and not _keys[glyph].has_focus():
		_keys[glyph].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_accept") and _found >= 0 and _typed_left > 0.0:
		press_glyph(_found)
		_found = -1
		get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.unicode >= 65:
		type_text(char(key.unicode))
		get_viewport().set_input_as_handled()


func _place_keys() -> void:
	if not is_node_ready():
		return
	var area: Rect2 = key_area()
	var base: float = HwMetrics.target(self, Vector2(GlyphKey.SIDE, GlyphKey.SIDE)).x
	var radius: float = RadialLayout.radius_for(area.size, base)
	var side: float = RadialLayout.key_side(radius, base)
	var centre: Vector2 = area.get_center()
	_disc = Vector3(centre.x, centre.y, radius * RadialLayout.RADII[2] + side * 0.5 + MARGIN)
	_key_area.queue_redraw()
	for key: GlyphKey in _keys:
		key.custom_minimum_size = Vector2(side, side)
		key.size = key.custom_minimum_size
		var at: Vector2 = RadialLayout.position_of(key.get_glyph(), centre, radius)
		key.position = at - key.size * 0.5
	var inner: float = radius * RadialLayout.RADII[0] * 2.0 - side - MARGIN * 2.0
	var dial_side: float = minf(HwMetrics.target(self, DIAL_SIZE).x, inner)
	_dial.custom_minimum_size = Vector2(dial_side, dial_side)
	_dial.size = _dial.custom_minimum_size
	_dial.position = centre - _dial.size * 0.5


## The free area the key rings fit in: below the seal lamps, right of the side keys, left of
## the clue clip, above the bottom edge.
func key_area() -> Rect2:
	var top: float = _lamps.position.y + _lamps.size.y + MARGIN
	var left: float = _pencil.position.x + _pencil.size.x + MARGIN
	var right: float = _clue.position.x - MARGIN
	return Rect2(left, top, maxf(0.0, right - left), maxf(0.0, size.y - MARGIN - top))


func _draw_disc() -> void:
	var centre: Vector2 = Vector2(_disc.x, _disc.y)
	_key_area.draw_circle(centre, _disc.z, DISC_COLOUR)
	_key_area.draw_arc(centre, _disc.z, 0.0, TAU, 96, DISC_RIM, 4.0)


func _render() -> void:
	if not is_node_ready():
		return
	for key: GlyphKey in _keys:
		key.set_lit(_compose.has(key.get_glyph()))
	_lamps.show_draft(_compose, _origin())


func _names() -> Array[String]:
	var out: Array[String] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		var def: GlyphDef = (
			Registry.get_def(StringName(GlyphIcon.GLYPH_ID_FORMAT % glyph)) as GlyphDef
		)
		out.append(tr(def.name_key) if def != null else "")
	return out


func _origin() -> int:
	if _simulation == null or _simulation.state.galaxy == null:
		return -1
	return _simulation.state.galaxy.home().origin_glyph


func _on_dial() -> void:
	var address: GateAddress = get_address()
	if address == null:
		show_refusal("GATE_REASON_INCOMPLETE")
		return
	dial_requested.emit(address)
