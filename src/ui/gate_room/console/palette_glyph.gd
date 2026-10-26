class_name PaletteGlyph
extends Button
## One glyph of the dial console's palette: its constellation and its name. Pressing it asks
## to place the glyph in the next empty seal; dragging it carries the glyph to a seal slot. A
## glyph placed in a slot is highlighted by a frame and a corner dot, so it reads by shape as
## well as colour. CAIRN's origin glyph is locked: greyed out, marked with a padlock
## and never placed or dragged, since seal 8 already holds it.
## Bible: gate-and-address-spec.md#the-dial-console,
## game-design.md#difficulty-and-accessibility (one-click placing, dragging, gamepad, shapes)

## The player pressed this glyph.
signal chosen(glyph: int)

## Key of the drag data that carries a glyph index.
const DRAG_KEY: String = "console_glyph"
## Space kept around the content, in pixels.
const PADDING: Vector2 = Vector2(3, 3)
## Narrowest the button gets, in pixels.
const MIN_WIDTH: float = 48.0
## Size of the drag preview, in pixels.
const PREVIEW_SIZE: Vector2 = Vector2(48, 48)
## Theme type of the colour items `placed_color` and `locked_color`.
const THEME_TYPE: StringName = &"PaletteGlyph"
## Colours used when the theme defines none.
const DEFAULT_PLACED_COLOR: Color = Color(0.35, 0.8, 1.0)
const DEFAULT_LOCKED_COLOR: Color = Color(0.55, 0.55, 0.55)
## Opacity of a locked glyph.
const LOCKED_ALPHA: float = 0.45
const _FRAME_WIDTH: float = 3.0
const _DOT_RADIUS: float = 5.0
const _LOCK_SIZE: float = 12.0

## The glyph shown, 0..35.
var glyph: int = -1

var _is_placed: bool = false
var _is_locked: bool = false

@onready var _content: VBoxContainer = %Content
@onready var _icon: GlyphIcon = %Icon
@onready var _name: Label = %GlyphName


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(glyph))
	_content.minimum_size_changed.connect(_fit_content)
	_fit_content()
	_apply_glyph()


# Button sizes itself from its own text only, so the content's size is passed on as the
# custom minimum.
func _fit_content() -> void:
	var needed: Vector2 = _content.get_combined_minimum_size() + PADDING * 2.0
	custom_minimum_size = Vector2(maxf(MIN_WIDTH, needed.x), needed.y)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _is_locked:
		return null
	var preview: GlyphIcon = GlyphIcon.new()
	preview.size = PREVIEW_SIZE
	preview.glyph_index = glyph
	set_drag_preview(preview)
	return make_drag_data(glyph)


func _draw() -> void:
	if _is_placed:
		var color: Color = _theme_color(&"placed_color", DEFAULT_PLACED_COLOR)
		var half: float = _FRAME_WIDTH / 2.0
		draw_rect(
			Rect2(Vector2(half, half), size - Vector2(_FRAME_WIDTH, _FRAME_WIDTH)),
			color,
			false,
			_FRAME_WIDTH
		)
		var dot: Vector2 = Vector2(
			size.x - _DOT_RADIUS - _FRAME_WIDTH - 1.0, _DOT_RADIUS + _FRAME_WIDTH + 1.0
		)
		draw_circle(dot, _DOT_RADIUS, color)
	if _is_locked:
		_draw_padlock(_theme_color(&"locked_color", DEFAULT_LOCKED_COLOR))


## Returns drag data carrying [param dragged].
static func make_drag_data(dragged: int) -> Dictionary:
	return {DRAG_KEY: dragged}


## Returns the glyph carried by drag [param data], or -1 when it carries none.
static func glyph_from_drag(data: Variant) -> int:
	if not data is Dictionary:
		return -1
	var dictionary: Dictionary = data
	var value: Variant = dictionary.get(DRAG_KEY)
	if not value is int:
		return -1
	var index: int = value
	return index if index >= 0 and index < GateAddress.GLYPH_COUNT else -1


## Shows glyph [param index].
func set_glyph(index: int) -> void:
	glyph = index
	if is_node_ready():
		_apply_glyph()


## Shows whether the glyph is [param placed] in a slot, with [param tooltip].
func show_state(placed: bool, tooltip: String) -> void:
	_is_placed = placed
	tooltip_text = tooltip
	queue_redraw()


## Locks the glyph ([param locked] true) as CAIRN's origin: greyed out, marked with a padlock,
## disabled and never dragged.
func set_locked(locked: bool) -> void:
	_is_locked = locked
	disabled = locked
	modulate.a = LOCKED_ALPHA if locked else 1.0
	queue_redraw()


## True while the glyph is highlighted as placed in a slot.
func is_placed() -> bool:
	return _is_placed


## True while the glyph is locked as CAIRN's origin.
func is_locked() -> bool:
	return _is_locked


## Returns glyph [param index]'s translation key for its name (GlyphDef.name_key), or &""
## for no glyph.
static func name_key_of(index: int) -> StringName:
	if index < 0 or index >= GateAddress.GLYPH_COUNT:
		return &""
	var def: GlyphDef = Registry.get_def(StringName(GlyphIcon.GLYPH_ID_FORMAT % index)) as GlyphDef
	return def.name_key if def != null else &""


func _apply_glyph() -> void:
	_icon.glyph_index = glyph
	_name.text = name_key_of(glyph)


func _theme_color(item: StringName, fallback: Color) -> Color:
	if has_theme_color(item, THEME_TYPE):
		return get_theme_color(item, THEME_TYPE)
	return fallback


## A padlock in the top-right corner: a shackle arc over a filled body.
func _draw_padlock(color: Color) -> void:
	var corner: Vector2 = Vector2(size.x - _LOCK_SIZE - 3.0, 3.0)
	var body: Rect2 = Rect2(
		corner + Vector2(0.0, _LOCK_SIZE * 0.45), Vector2(_LOCK_SIZE, _LOCK_SIZE * 0.55)
	)
	var shackle_center: Vector2 = corner + Vector2(_LOCK_SIZE / 2.0, _LOCK_SIZE * 0.45)
	draw_arc(shackle_center, _LOCK_SIZE * 0.3, PI, TAU, 12, color, 2.0)
	draw_rect(body, color)
