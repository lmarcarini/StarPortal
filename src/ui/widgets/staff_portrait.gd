class_name StaffPortrait
extends TextureRect
## A staff member's portrait (docs/content/portraits.md, "Sizes"), shown only at whole-number
## scales with nearest filtering. [member crop] shows a square window of the portrait at 1:1
## (the face on a 48 px list row) instead of the whole of it.
## Bible: docs/content/portraits.md

## The face window of the portrait: 48 px square round the head.
const FACE := Rect2i(24, 12, 48, 48)

## Whole-number scale (1 = 96 px).
var portrait_scale: int = 1:
	set = set_portrait_scale
## The part of the portrait shown; empty for the whole portrait.
var crop: Rect2i = Rect2i():
	set = set_crop

var _id: StringName = &""


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


## Shows the portrait of [param id] drawn from [param record] (from the cache); an empty
## record clears it.
func show_record(id: StringName, record: Dictionary) -> void:
	_id = id
	if record.is_empty():
		texture = null
		return
	var full: ImageTexture = PortraitCache.texture_for(id, record)
	if crop.has_area():
		var window := AtlasTexture.new()
		window.atlas = full
		window.region = Rect2(crop)
		texture = window
	else:
		texture = full
	_resize()


## The id shown, or &"".
func get_id() -> StringName:
	return _id


## Sets the scale; values below 1 become 1.
func set_portrait_scale(value: int) -> void:
	portrait_scale = maxi(1, value)
	_resize()


## Sets the crop window.
func set_crop(value: Rect2i) -> void:
	crop = value
	_resize()


## The side of the control in pixels: the shown part times [member portrait_scale].
func side() -> int:
	var base: int = crop.size.x if crop.has_area() else PortraitPainter.SIZE
	return base * portrait_scale


func _resize() -> void:
	var length: float = side()
	custom_minimum_size = Vector2(length, length)
	size = custom_minimum_size
