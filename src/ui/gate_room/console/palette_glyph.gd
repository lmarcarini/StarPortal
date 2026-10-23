class_name PaletteGlyph
extends Button
## One glyph of the Address Workbench palette: its constellation and its name. Pressing it
## picks the glyph (the button shows pressed while picked); dragging it carries the glyph to a
## seal slot.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## game-design.md#difficulty-and-accessibility (click-to-pick, dragging, gamepad)

## The player pressed this glyph.
signal chosen(glyph: int)

## Key of the drag data that carries a glyph index.
const DRAG_KEY: String = "workbench_glyph"
## Space kept around the content, in pixels.
const PADDING: Vector2 = Vector2(4, 4)
## Narrowest the button gets, in pixels.
const MIN_WIDTH: float = 56.0
## Size of the drag preview, in pixels.
const PREVIEW_SIZE: Vector2 = Vector2(48, 48)

## The glyph shown, 0..35.
var glyph: int = -1

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
	var preview: GlyphIcon = GlyphIcon.new()
	preview.size = PREVIEW_SIZE
	preview.glyph_index = glyph
	set_drag_preview(preview)
	return make_drag_data(glyph)


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


## Shows whether the glyph is [param picked], and [param tooltip].
func show_picked(picked: bool, tooltip: String) -> void:
	set_pressed_no_signal(picked)
	tooltip_text = tooltip


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
