class_name SealSlots
extends HBoxContainer
## The alien panel's eight seals across the top, as the dial block's lamps under steel keys
## (interface-reference.md sections 3 and 5): seven showing the address so far (a firm glyph
## lights its amber lamp, a pencilled guess is drawn faint over an unlit lamp), the eighth
## CAIRN's mark, fixed and lit. Pressing one of the seven clears it.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## Seal [param seal] was pressed.
signal seal_pressed(seal: int)

## Seal key size, in pixels.
const SLOT: Vector2 = Vector2(80, 104)
## Lamp radius, as the dial block's.
const LAMP: float = 10.0

var _slots: Array[Button] = []
var _icons: Array[GlyphIcon] = []
var _lit: Array[bool] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 12)
	for seal: int in AddressDraft.SEALS + 1:
		var slot: Button = Button.new()
		slot.name = "Seal%d" % seal
		RefKeyLook.clear_boxes(slot)
		slot.custom_minimum_size = SLOT
		slot.focus_mode = Control.FOCUS_ALL if seal < AddressDraft.SEALS else Control.FOCUS_NONE
		slot.disabled = seal == AddressDraft.SEALS
		slot.pressed.connect(seal_pressed.emit.bind(seal))
		slot.draw.connect(_draw_slot.bind(seal))
		var icon: GlyphIcon = GlyphIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(12, 8)
		icon.size = Vector2(SLOT.x - 24, SLOT.x - 24)
		slot.add_child(icon)
		add_child(slot)
		_slots.append(slot)
		_icons.append(icon)
		_lit.append(false)
	sort_children.connect(queue_redraw)


## Shows [param draft] with CAIRN's mark [param origin] in the eighth lamp.
func show_draft(draft: AddressDraft, origin: int) -> void:
	for seal: int in AddressDraft.SEALS:
		var glyph: int = draft.firm[seal]
		var guess: bool = glyph < 0 and draft.pencil[seal] >= 0
		_icons[seal].glyph_index = glyph if glyph >= 0 else draft.pencil[seal]
		_icons[seal].modulate = Color(1, 1, 1, 0.4) if guess else Color.WHITE
		_lit[seal] = glyph >= 0
	_icons[AddressDraft.SEALS].glyph_index = origin
	_lit[AddressDraft.SEALS] = true
	for seal: int in _slots.size():
		_tint(seal)
		_slots[seal].queue_redraw()


## The glyph shown in seal [param seal], or -1.
func shown_glyph(seal: int) -> int:
	return _icons[seal].glyph_index


func _tint(seal: int) -> void:
	var ink: Color = RefPaint.AMBER_HI if _lit[seal] else RefPaint.TEXT
	_icons[seal].add_theme_color_override(&"line_color", Color(ink, 0.8))
	_icons[seal].add_theme_color_override(&"star_color", ink)


func _draw_slot(seal: int) -> void:
	var slot: Button = _slots[seal]
	var rect: Rect2 = Rect2(Vector2.ZERO, slot.size)
	var style: RefPaint.KeyStyle = (
		RefPaint.KeyStyle.OFF if slot.disabled else RefPaint.KeyStyle.STEEL
	)
	RefPaint.key(slot, rect, style)
	var lamp: Vector2 = Vector2(slot.size.x * 0.5, slot.size.y - 16.0)
	if _lit[seal]:
		RefPaint.lamp_on(slot, lamp, LAMP, RefPaint.AMBER)
	else:
		RefPaint.lamp_off(slot, lamp, LAMP, false)
	if slot.has_focus():
		RefPaint.outline(slot, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)


func _draw() -> void:
	if _slots.is_empty():
		return
	var span: Rect2 = Rect2(_slots[0].position, Vector2.ZERO)
	for slot: Button in _slots:
		span = span.merge(Rect2(slot.position, slot.size))
	RefPaint.steel_plate(self, span.grow(12.0), false, true)
