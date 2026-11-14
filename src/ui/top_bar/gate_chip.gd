class_name GateChip
extends Button
## The top bar's gate chip: IDLE, DIALLING, OPEN (world and time left) or INCOMING, each with
## its own shape (ring, half disc, filled disc, triangle). The Ring blue is used only while
## OPEN. Pressing it opens the Gate Room (the top bar connects it).
## Bible: docs/content/interface-pass.md section 3

## Side of the shape icon, in pixels.
const ICON_SIZE: int = 14

var _status: StringName = &""


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ReadoutButton"
	expand_icon = false


## Shows the gate of [param state].
func show_state(state: GameState) -> void:
	text = TopBarText.gate_text(state)
	var status: StringName = TopBarText.gate_status(state)
	if status == _status:
		return
	_status = status
	icon = shape_icon(status)
	var color: Color = color_of(status)
	for name: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		add_theme_color_override(name, color)


## The status shown now.
func get_status() -> StringName:
	return _status


## The colour of [param status]: Ring blue only while open.
static func color_of(status: StringName) -> Color:
	match status:
		TopBarText.GATE_OPEN:
			return UiPalette.RING
		TopBarText.GATE_INCOMING:
			return UiPalette.WARN
		TopBarText.GATE_DIALLING:
			return UiPalette.SELECT
	return UiPalette.TEXT_DIM


## The shape name of [param status].
static func shape_of(status: StringName) -> StringName:
	match status:
		TopBarText.GATE_OPEN:
			return &"disc"
		TopBarText.GATE_INCOMING:
			return &"triangle"
		TopBarText.GATE_DIALLING:
			return &"half"
	return &"ring"


## A small icon of [param status]'s shape in its colour.
static func shape_icon(status: StringName) -> ImageTexture:
	var image := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var shape: StringName = shape_of(status)
	var color: Color = color_of(status)
	var half: float = ICON_SIZE / 2.0
	for y: int in ICON_SIZE:
		for x: int in ICON_SIZE:
			var point := Vector2(x + 0.5 - half, y + 0.5 - half)
			if _inside(shape, point, half - 1.0):
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


static func _inside(shape: StringName, point: Vector2, radius: float) -> bool:
	var distance: float = point.length()
	match shape:
		&"disc":
			return distance <= radius
		&"half":
			return distance <= radius and (point.x <= 0.0 or distance >= radius - 2.0)
		&"triangle":
			var depth: float = (point.y + radius) / (2.0 * radius)
			return depth >= 0.0 and depth <= 1.0 and absf(point.x) <= depth * radius
	return distance <= radius and distance >= radius - 2.0
