class_name AddressStrip
extends HBoxContainer
## One address as a row of eight glyph icons: the seven coordinates, a gap, then the origin.
## Purely a display; it takes neither focus nor the mouse.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math

const _ICON_SCENE: PackedScene = preload("res://src/ui/widgets/glyph_icon.tscn")
const _SEPARATION: int = 2
const _ORIGIN_GAP: int = 8

## Side of each glyph icon, in pixels.
@export var icon_size: int = 32

var _address: GateAddress = null


func _ready() -> void:
	add_theme_constant_override(&"separation", _SEPARATION)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param address]; null clears the row.
func setup(address: GateAddress) -> void:
	_address = address
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if address == null:
		return
	var seals: Array[int] = address.seals()
	for index: int in seals.size():
		if index == GateAddress.COORDINATE_COUNT:
			_add_gap()
		_add_icon(seals[index])


## Returns the address shown, or null.
func get_address() -> GateAddress:
	return _address


## Returns the glyph indices drawn, in order.
func get_glyph_indices() -> Array[int]:
	var found: Array[int] = []
	for child: Node in get_children():
		if child is GlyphIcon:
			found.append((child as GlyphIcon).glyph_index)
	return found


func _add_icon(glyph: int) -> void:
	var icon: GlyphIcon = _ICON_SCENE.instantiate() as GlyphIcon
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.glyph_index = glyph
	add_child(icon)


func _add_gap() -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(_ORIGIN_GAP, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)
