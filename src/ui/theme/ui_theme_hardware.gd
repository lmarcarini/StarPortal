class_name UiThemeHardware
extends RefCounted
## Type variations for the industrial hardware kit, added to the one Theme by UiThemeBuilder:
## SteelPanel and RecessedPanel (riveted and sunk steel, PanelContainer), CrtScreen (green
## screen), PaperCard (off-white card), BigKey and IconKey (Button), HwStencil (Label).
## Textures come from art/ui/hardware (tools/gen_hardware_textures.gd) and are nine-sliced.
## Bible: docs/content/interface-rethink.md section 7 (interface hardware)

## Folder of the generated textures.
const DIR: String = "res://art/ui/hardware/"
## CRT phosphor green.
const CRT_GREEN: Color = Color("#7fd68a")
## CRT screen glass.
const CRT_GLASS: Color = Color("#0b1a10")
## Paper.
const PAPER: Color = Color("#e6e0cc")
## Ink on paper.
const INK: Color = Color("#24221d")
## Amber key light.
const AMBER: Color = Color("#e8a33d")


## Adds the kit's variations to [param theme] at UI scale [param s].
static func add_to(theme: Theme, s: float) -> void:
	theme.set_type_variation(&"SteelPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SteelPanel", nine(&"steel_plate", 14, 14 * s))
	theme.set_type_variation(&"RecessedPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"RecessedPanel", nine(&"recessed", 6, 8 * s))
	theme.set_type_variation(&"CrtScreen", &"PanelContainer")
	var crt := StyleBoxFlat.new()
	crt.bg_color = CRT_GLASS
	crt.border_color = Color("#0a0b0a")
	crt.set_border_width_all(roundi(4 * s))
	crt.set_corner_radius_all(roundi(10 * s))
	crt.set_content_margin_all(12 * s)
	theme.set_stylebox(&"panel", &"CrtScreen", crt)
	theme.set_type_variation(&"PaperCard", &"PanelContainer")
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_width_left = roundi(6 * s)
	paper.border_color = AMBER
	paper.set_content_margin_all(10 * s)
	paper.shadow_color = Color(0, 0, 0, 0.5)
	paper.shadow_size = roundi(4 * s)
	theme.set_stylebox(&"panel", &"PaperCard", paper)
	_add_keys(theme, s)
	theme.set_type_variation(&"HwStencil", &"Label")
	theme.set_font(&"font", &"HwStencil", UiThemeBuilder.stencil_font())
	theme.set_color(&"font_color", &"HwStencil", Color("#d8d2bd"))


## A nine-slice style from texture [param texture_name] with [param margin] px slices and
## [param content] px content margins.
static func nine(texture_name: StringName, margin: int, content: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(DIR + String(texture_name) + ".png") as Texture2D
	box.set_texture_margin_all(margin)
	box.set_content_margin_all(content)
	return box


static func _add_keys(theme: Theme, s: float) -> void:
	var up: StyleBoxTexture = nine(&"key_up", 8, 10 * s)
	up.content_margin_bottom = 14 * s
	var down: StyleBoxTexture = nine(&"key_down", 8, 10 * s)
	down.content_margin_top = 14 * s
	down.content_margin_bottom = 10 * s
	var off: StyleBoxTexture = up.duplicate() as StyleBoxTexture
	off.modulate_color = Color(0.55, 0.55, 0.55)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(roundi(3 * s))
	focus.border_color = AMBER
	focus.set_expand_margin_all(3 * s)
	for type: StringName in [&"BigKey", &"IconKey"]:
		theme.set_type_variation(type, &"Button")
		theme.set_stylebox(&"normal", type, up)
		theme.set_stylebox(&"hover", type, up)
		theme.set_stylebox(&"pressed", type, down)
		theme.set_stylebox(&"hover_pressed", type, down)
		theme.set_stylebox(&"disabled", type, off)
		theme.set_stylebox(&"focus", type, focus)
		theme.set_font(&"font", type, UiThemeBuilder.stencil_font())
		theme.set_color(&"font_color", type, Color("#ece6d2"))
		theme.set_color(&"font_hover_color", type, Color.WHITE)
		theme.set_color(&"font_pressed_color", type, AMBER)
	theme.set_font_size(&"font_size", &"BigKey", roundi(28 * s))
