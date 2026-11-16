class_name UiThemeBuilder
extends RefCounted
## Builds the one interface Theme in code: palette, fonts, bezelled panels, raised key
## buttons and the type variations later screens use. Screens style nothing by hand.
## Variations: PanelBezel (PanelContainer), HeaderStrip, DataLabel, StencilLabel (Label),
## KeyButton, KeyButtonSelected, ReadoutButton (Button); the hardware kit's variations come
## from UiThemeHardware.
## Bible: docs/content/interface-pass.md section 2, art-and-audio.md#ui-and-typography

## Labels and headings.
const LABEL_FONT_PATH: String = "res://art/fonts/barlow_condensed/BarlowCondensed-Medium.ttf"
## Headers and stencilled labels.
const STENCIL_FONT_PATH: String = "res://art/fonts/barlow_condensed/BarlowCondensed-SemiBold.ttf"
## Numbers and data.
const DATA_FONT_PATH: String = "res://art/fonts/ibm_plex_mono/IBMPlexMono-Regular.ttf"
## Body text size at 100% UI scale, in pixels at 1080p.
const BODY_SIZE: int = 18
## Data text size at 100% UI scale.
const DATA_SIZE: int = 16
## Header strip text size at 100% UI scale.
const HEADER_SIZE: int = 15
## Smallest and largest UI scale the theme supports.
const MIN_SCALE: float = 0.8
const MAX_SCALE: float = 1.5


## The interface Theme at UI scale [param scale] (clamped to 0.8..1.5).
static func build(scale: float) -> Theme:
	var s: float = clampf(scale, MIN_SCALE, MAX_SCALE)
	var theme := Theme.new()
	theme.default_font = label_font()
	theme.default_font_size = roundi(BODY_SIZE * s)
	_add_colors(theme)
	_add_panels(theme, s)
	_add_buttons(theme, s)
	_add_labels(theme, s)
	UiThemeHardware.add_to(theme, s)
	return theme


## The label font (Barlow Condensed Medium).
static func label_font() -> Font:
	return load(LABEL_FONT_PATH) as Font


## The stencil font (Barlow Condensed SemiBold).
static func stencil_font() -> Font:
	return load(STENCIL_FONT_PATH) as Font


## The data font (IBM Plex Mono).
static func data_font() -> Font:
	return load(DATA_FONT_PATH) as Font


static func _add_colors(theme: Theme) -> void:
	for type: StringName in [&"Label", &"Button", &"LineEdit", &"ItemList", &"RichTextLabel"]:
		theme.set_color(&"font_color", type, UiPalette.TEXT)
	theme.set_color(&"default_color", &"RichTextLabel", UiPalette.TEXT)
	theme.set_color(&"font_hover_color", &"Button", UiPalette.TEXT)
	theme.set_color(&"font_pressed_color", &"Button", UiPalette.SELECT)
	theme.set_color(&"font_focus_color", &"Button", UiPalette.TEXT)
	theme.set_color(&"font_disabled_color", &"Button", Color(UiPalette.TEXT_DIM, 0.6))
	theme.set_color(&"font_selected_color", &"ItemList", UiPalette.SELECT)


static func _add_panels(theme: Theme, s: float) -> void:
	var flat := _box(UiPalette.PANEL, UiPalette.RULE, 1, s)
	theme.set_stylebox(&"panel", &"Panel", flat)
	theme.set_stylebox(&"panel", &"PanelContainer", flat)
	var bezel := _box(UiPalette.PANEL, UiPalette.RULE, 2, s)
	bezel.border_color = UiPalette.RULE
	bezel.shadow_color = UiPalette.KEYCAP_EDGE
	bezel.shadow_size = roundi(3 * s)
	bezel.shadow_offset = Vector2(0, 2 * s)
	theme.set_type_variation(&"PanelBezel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PanelBezel", bezel)
	var field := _box(UiPalette.GROUND, UiPalette.RULE, 1, s)
	theme.set_stylebox(&"normal", &"LineEdit", field)
	theme.set_stylebox(&"panel", &"ItemList", field)


static func _add_buttons(theme: Theme, s: float) -> void:
	var raised := _key(UiPalette.KEYCAP, UiPalette.RULE, s)
	var hover := _key(UiPalette.KEYCAP_HOVER, UiPalette.RULE, s)
	var pressed := _key(UiPalette.KEYCAP, UiPalette.RULE, s)
	pressed.border_width_bottom = 1
	pressed.border_width_top = roundi(3 * s)
	pressed.border_color = UiPalette.KEYCAP_EDGE
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(roundi(2 * s))
	focus.border_color = UiPalette.SELECT
	focus.set_corner_radius_all(2)
	var disabled := _key(UiPalette.PANEL, UiPalette.RULE, s)
	for type: StringName in [&"Button", &"KeyButton"]:
		theme.set_stylebox(&"normal", type, raised)
		theme.set_stylebox(&"hover", type, hover)
		theme.set_stylebox(&"pressed", type, pressed)
		theme.set_stylebox(&"hover_pressed", type, pressed)
		theme.set_stylebox(&"focus", type, focus)
		theme.set_stylebox(&"disabled", type, disabled)
	theme.set_type_variation(&"KeyButton", &"Button")
	theme.set_type_variation(&"KeyButtonSelected", &"Button")
	var lit := _key(UiPalette.KEYCAP_HOVER, UiPalette.SELECT, s)
	lit.shadow_color = Color(UiPalette.SELECT, 0.35)
	lit.shadow_size = roundi(6 * s)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		theme.set_stylebox(state, &"KeyButtonSelected", lit)
	theme.set_color(&"font_color", &"KeyButtonSelected", UiPalette.SELECT)
	theme.set_color(&"font_hover_color", &"KeyButtonSelected", UiPalette.SELECT)
	theme.set_color(&"font_focus_color", &"KeyButtonSelected", UiPalette.SELECT)
	_add_readout_button(theme, s, focus)
	_add_tabs(theme, s, focus)


## ReadoutButton: a flat button in the data font for the top bar's figures.
static func _add_readout_button(theme: Theme, s: float, focus: StyleBox) -> void:
	theme.set_type_variation(&"ReadoutButton", &"Button")
	theme.set_font(&"font", &"ReadoutButton", data_font())
	theme.set_font_size(&"font_size", &"ReadoutButton", roundi(DATA_SIZE * s))
	var flat := StyleBoxFlat.new()
	flat.draw_center = false
	flat.set_content_margin_all(6 * s)
	var hover := flat.duplicate() as StyleBoxFlat
	hover.draw_center = true
	hover.bg_color = UiPalette.KEYCAP
	for state: StringName in [&"normal", &"disabled"]:
		theme.set_stylebox(state, &"ReadoutButton", flat)
	for state: StringName in [&"hover", &"pressed", &"hover_pressed"]:
		theme.set_stylebox(state, &"ReadoutButton", hover)
	theme.set_stylebox(&"focus", &"ReadoutButton", focus)


## TabBar: tabs are keys; the current one is lit orange with a glow.
static func _add_tabs(theme: Theme, s: float, focus: StyleBox) -> void:
	var tab := _key(UiPalette.KEYCAP, UiPalette.RULE, s)
	tab.content_margin_left = 14 * s
	tab.content_margin_right = 14 * s
	tab.content_margin_top = 8 * s
	tab.content_margin_bottom = 8 * s
	var hover := tab.duplicate() as StyleBoxFlat
	hover.bg_color = UiPalette.KEYCAP_HOVER
	var lit := tab.duplicate() as StyleBoxFlat
	lit.bg_color = UiPalette.KEYCAP_HOVER
	lit.border_color = UiPalette.SELECT
	lit.shadow_color = Color(UiPalette.SELECT, 0.35)
	lit.shadow_size = roundi(6 * s)
	theme.set_stylebox(&"tab_unselected", &"TabBar", tab)
	theme.set_stylebox(&"tab_hovered", &"TabBar", hover)
	theme.set_stylebox(&"tab_selected", &"TabBar", lit)
	theme.set_stylebox(&"tab_disabled", &"TabBar", tab)
	theme.set_stylebox(&"tab_focus", &"TabBar", focus)
	theme.set_color(&"font_selected_color", &"TabBar", UiPalette.SELECT)
	theme.set_color(&"font_unselected_color", &"TabBar", UiPalette.TEXT_DIM)
	theme.set_color(&"font_hovered_color", &"TabBar", UiPalette.TEXT)
	theme.set_constant(&"h_separation", &"TabBar", roundi(8 * s))


static func _add_labels(theme: Theme, s: float) -> void:
	theme.set_type_variation(&"DataLabel", &"Label")
	theme.set_font(&"font", &"DataLabel", data_font())
	theme.set_font_size(&"font_size", &"DataLabel", roundi(DATA_SIZE * s))
	theme.set_type_variation(&"StencilLabel", &"Label")
	theme.set_font(&"font", &"StencilLabel", stencil_font())
	theme.set_color(&"font_color", &"StencilLabel", UiPalette.TEXT_DIM)
	theme.set_type_variation(&"HeaderStrip", &"Label")
	theme.set_font(&"font", &"HeaderStrip", stencil_font())
	theme.set_font_size(&"font_size", &"HeaderStrip", roundi(HEADER_SIZE * s))
	theme.set_color(&"font_color", &"HeaderStrip", UiPalette.TEXT_DIM)
	var strip := _box(UiPalette.HEADER, UiPalette.RULE, 0, s)
	strip.border_width_bottom = 1
	strip.content_margin_top = 4 * s
	strip.content_margin_bottom = 4 * s
	theme.set_stylebox(&"normal", &"HeaderStrip", strip)
	theme.set_type_variation(&"StatusStrip", &"PanelContainer")
	var status := _box(UiPalette.HEADER, UiPalette.RULE, 0, s)
	status.border_width_top = 1
	status.content_margin_top = 2 * s
	status.content_margin_bottom = 2 * s
	theme.set_stylebox(&"panel", &"StatusStrip", status)


## A flat box with a [param width]-pixel border and content margins.
static func _box(fill: Color, border: Color, width: int, s: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(8 * s)
	return box


## A raised key: lit top edge, dark bottom edge.
static func _key(fill: Color, border: Color, s: float) -> StyleBoxFlat:
	var key := _box(fill, border, 1, s)
	key.border_width_bottom = roundi(3 * s)
	key.border_color = border
	key.shadow_color = Color(UiPalette.KEYCAP_EDGE, 0.6)
	key.shadow_size = 1
	key.shadow_offset = Vector2(0, 1)
	key.content_margin_top = 4 * s
	key.content_margin_bottom = 4 * s
	key.content_margin_left = 10 * s
	key.content_margin_right = 10 * s
	return key
