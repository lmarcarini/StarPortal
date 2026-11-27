class_name PortraitPainter
extends RefCounted
## Paints the 96×96 staff portrait of an appearance record (docs/content/portraits.md):
## pixel art built from shaded masks with five-step ramps, dark outlines, light from the
## upper left and a smooth navy background. Layers, back to front: hair behind, neck and
## uniform, head and face, hair in front, accessory. The same record always gives the same
## pixels. UI side only: the simulation keeps the record, never the image.
## Bible: docs/content/portraits.md

## Portrait side, in pixels.
const SIZE: int = PortraitCanvas.SIZE


## The portrait of [param record] (an AppearanceRules record) as an RGB8 image.
static func paint(record: Dictionary) -> Image:
	var canvas := PortraitCanvas.new(record)
	PortraitPartsHair.draw_back(canvas)
	PortraitPartsFace.draw_neck(canvas)
	PortraitPartsOutfit.draw(canvas)
	var head: PortraitMask = PortraitPartsFace.draw_head(canvas)
	PortraitPartsFace.draw_face(canvas, head)
	PortraitPartsHair.draw_front(canvas, head)
	PortraitPartsFace.draw_accessory(canvas)
	return canvas.image
