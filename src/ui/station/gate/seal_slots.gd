class_name SealSlots
extends HBoxContainer
## The alien panel's eight seal lamps across the top: seven showing the address so far (a
## firm glyph lit, a pencilled guess drawn faint), the eighth CAIRN's mark, fixed. Pressing
## one of the seven clears it.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Composing)

## Seal [param seal] was pressed.
signal seal_pressed(seal: int)

var _slots: Array[Button] = []
var _icons: Array[GlyphIcon] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 10)
	for seal: int in AddressDraft.SEALS + 1:
		var slot: Button = Button.new()
		slot.name = "Seal%d" % seal
		slot.theme_type_variation = &"IconKey"
		slot.custom_minimum_size = HwMetrics.target(self, Vector2(64, 64))
		slot.focus_mode = Control.FOCUS_ALL if seal < AddressDraft.SEALS else Control.FOCUS_NONE
		slot.disabled = seal == AddressDraft.SEALS
		slot.pressed.connect(seal_pressed.emit.bind(seal))
		var icon: GlyphIcon = GlyphIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8
		)
		slot.add_child(icon)
		add_child(slot)
		_slots.append(slot)
		_icons.append(icon)


## Shows [param draft] with CAIRN's mark [param origin] in the eighth lamp.
func show_draft(draft: AddressDraft, origin: int) -> void:
	for seal: int in AddressDraft.SEALS:
		var glyph: int = draft.firm[seal]
		var guess: bool = glyph < 0 and draft.pencil[seal] >= 0
		_icons[seal].glyph_index = glyph if glyph >= 0 else draft.pencil[seal]
		_icons[seal].modulate = Color(0.75, 0.75, 0.7, 0.45) if guess else Color("#ffd28a")
	_icons[AddressDraft.SEALS].glyph_index = origin
	_icons[AddressDraft.SEALS].modulate = Color("#ffd28a")


## The glyph shown in seal [param seal], or -1.
func shown_glyph(seal: int) -> int:
	return _icons[seal].glyph_index
