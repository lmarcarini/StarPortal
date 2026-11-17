class_name GateLayout
extends RefCounted
## The Gate station's regions at 1920 x 1080 (docs/reference/layout.json,
## interface-reference.md sections 2 and 5). The scene is centred, so a wider window moves
## what stands on the floor (send rail, mission sheet) by half the extra width; the right
## panel and the charge gauge and Shutter keep to the right edge; the team card, the CRT and
## the dial block keep to the left.
## Bible: docs/content/interface-reference.md sections 2 and 5

## Design width, in pixels.
const WIDTH: float = 1920.0
## The Gate station's regions as x, y, w, h.
const REGIONS: Dictionary[StringName, Rect2] = {
	&"team_card": Rect2(16, 716, 368, 148),
	&"right_panel": Rect2(1536, 92, 368, 772),
	&"send_rail": Rect2(1004, 764, 520, 100),
	&"mission_sheet": Rect2(1184, 400, 336, 352),
	&"console": Rect2(656, 896, 1248, 168),
}


## How far the floor moves right in a window [param width] wide.
static func centre_shift(width: float) -> float:
	return maxf(0.0, width - WIDTH) * 0.5


## Puts [param control] on region [param id], moved right by [param shift].
static func put(control: Control, id: StringName, shift: float) -> void:
	var region: Rect2 = REGIONS[id]
	control.position = region.position + Vector2(shift, 0)
	control.size = region.size


## Places the right panel [param rack] and the console [param console] in [param view].
static func place(view: Control, rack: Control, console: Control) -> void:
	var extra: float = maxf(0.0, view.size.x - WIDTH)
	put(rack, &"right_panel", extra)
	console.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var region: Rect2 = REGIONS[&"console"]
	console.position = region.position
	console.size = region.size + Vector2(extra, 0)
