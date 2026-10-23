class_name SealRow
extends VBoxContainer
## The Address Workbench's eight seal slots, seven coordinates then the origin, with a caption
## naming the origin. Shows glyphs; never changes them.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math (seal 8 is the origin),
## game-design.md#difficulty-and-accessibility (click-to-pick and click-to-place)

## The player clicked or accepted slot [param seal] (8 is the origin).
signal slot_chosen(seal: int)
## The player dropped [param glyph] on slot [param seal].
signal glyph_dropped(seal: int, glyph: int)

const _SLOT_SCENE: PackedScene = preload("res://src/ui/gate_room/console/seal_slot.tscn")

var _slots: Array[SealSlot] = []

@onready var _slot_box: HBoxContainer = %Slots
@onready var _caption: Label = %OriginCaption


func _ready() -> void:
	for seal: int in range(1, GateAddress.SEAL_COUNT + 1):
		var slot: SealSlot = _SLOT_SCENE.instantiate() as SealSlot
		slot.name = "Seal%d" % seal
		slot.set_seal(seal)
		slot.chosen.connect(slot_chosen.emit)
		slot.glyph_dropped.connect(glyph_dropped.emit)
		_slot_box.add_child(slot)
		_slots.append(slot)


## Shows [param glyphs], one per seal 1..8 (-1 for an empty seal); the last is CAIRN's
## origin. [param translate] is the caller's tr.
func show_glyphs(glyphs: Array[int], translate: Callable) -> void:
	for slot: SealSlot in _slots:
		var glyph: int = glyphs[slot.seal - 1] if slot.seal <= glyphs.size() else -1
		slot.show_glyph(glyph, _slot_tooltip(slot.seal, glyph, translate))
	var origin: int = (
		glyphs[GateAddress.COORDINATE_COUNT] if glyphs.size() > GateAddress.COORDINATE_COUNT else -1
	)
	_caption.text = str(translate.call("WORKBENCH_ORIGIN_HOME")).format(
		{"glyph": _glyph_name(origin, translate)}
	)


## Returns the slot for [param seal], 1..8, or null.
func get_slot(seal: int) -> SealSlot:
	if seal < 1 or seal > _slots.size():
		return null
	return _slots[seal - 1]


func _slot_tooltip(seal: int, glyph: int, translate: Callable) -> String:
	if glyph < 0:
		return str(translate.call("WORKBENCH_SLOT_EMPTY")).format({"seal": seal})
	var template: String = str(translate.call("WORKBENCH_SLOT_FILLED"))
	return template.format({"seal": seal, "glyph": _glyph_name(glyph, translate)})


static func _glyph_name(glyph: int, translate: Callable) -> String:
	return str(translate.call(PaletteGlyph.name_key_of(glyph)))
