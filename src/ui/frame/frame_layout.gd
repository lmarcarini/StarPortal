class_name FrameLayout
extends RefCounted
## The frame's regions at 1920 x 1080 (docs/reference/layout.json, interface-reference.md
## section 2). The interface scales uniformly with the window height (canvas_items, expand);
## a wider window shifts the right-hand group right by the extra width, nothing stretches.
## Bible: docs/content/interface-reference.md sections 1 and 2

## Design width, in pixels.
const WIDTH: float = 1920.0
## Every frame region as x, y, w, h.
const REGIONS: Dictionary[StringName, Rect2] = {
	&"top_bar": Rect2(0, 0, 1920, 76),
	&"top_site": Rect2(8, 8, 392, 60),
	&"top_clock": Rect2(408, 8, 304, 60),
	&"top_resources": Rect2(720, 8, 760, 60),
	&"top_call": Rect2(1488, 8, 212, 60),
	&"top_speed": Rect2(1708, 8, 204, 60),
	&"wire": Rect2(16, 92, 368, 600),
	&"bottom_bar": Rect2(0, 880, 1920, 200),
	&"station_keys": Rect2(16, 896, 624, 168),
	&"station_console": Rect2(656, 896, 848, 168),
	&"gate_monitor": Rect2(1520, 896, 384, 168),
	&"station_area": Rect2(400, 92, 1120, 772),
}


## Puts [param control] on region [param id], moved right by [param shift] pixels.
static func place(control: Control, id: StringName, shift: float) -> void:
	var region: Rect2 = REGIONS[id]
	control.position = region.position + Vector2(shift, 0)
	control.size = region.size


## The station area for a window [param width] wide: between the wire and the right column,
## growing with the extra width.
static func station_area(width: float) -> Rect2:
	var area: Rect2 = REGIONS[&"station_area"]
	area.size.x += maxf(0.0, width - WIDTH)
	return area
