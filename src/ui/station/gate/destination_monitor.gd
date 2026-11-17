class_name DestinationMonitor
extends Control
## The destination CRT (interface-reference.md section 5, dest_crt): on a steel plate, a green
## screen with the selected destination's picture in green, its name (38), up to four status
## icons and its seven address glyphs; NEW ADDRESS while composing; blank when nothing is
## selected. Scanlines and a thick rounded bezel.
## Bible: docs/content/interface-reference.md section 5

## What the monitor shows.
enum Show { BLANK, DESTINATION, COMPOSING }

## Most status icons shown.
const MAX_ICONS: int = 4
## The screen inside the plate.
const SCREEN: Rect2 = Rect2(12, 12, 376, 144)
## Glyph box side and pitch, in pixels.
const GLYPH: float = 24.0
const GLYPH_PITCH: float = 27.0

var _show: Show = Show.BLANK
var _title: String = ""
var _icons: Array[StringName] = []
var _picture: WorldThumb = WorldThumb.new()
var _glyphs: Array[GlyphIcon] = []


func _ready() -> void:
	_picture.position = SCREEN.position + Vector2(14, 14)
	_picture.size = Vector2(146, SCREEN.size.y - 28)
	_picture.modulate = Color(0.45, 1.0, 0.55)
	add_child(_picture)
	for k: int in 7:
		var icon: GlyphIcon = GlyphIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_theme_color_override(&"line_color", RefPaint.GREEN)
		icon.add_theme_color_override(&"star_color", RefPaint.GREEN)
		icon.position = SCREEN.position + Vector2(178 + k * GLYPH_PITCH, SCREEN.size.y - 36)
		icon.size = Vector2(GLYPH, GLYPH)
		add_child(icon)
		_glyphs.append(icon)
	_render(null)


## Shows [param destination], or blank when null.
func show_destination(destination: GateDestination) -> void:
	_show = Show.BLANK if destination == null else Show.DESTINATION
	_render(destination)


## Shows NEW ADDRESS (an address being composed).
func show_composing() -> void:
	_show = Show.COMPOSING
	_render(null)


## What is shown.
func get_show() -> Show:
	return _show


## The name shown (a translation key while composing).
func get_name_text() -> String:
	return _title


func _render(destination: GateDestination) -> void:
	_icons.clear()
	_title = ""
	match _show:
		Show.COMPOSING:
			_title = "STATION_NEW_ADDRESS"
		Show.DESTINATION:
			_title = destination.title
			_icons = destination.icons.slice(0, MAX_ICONS)
	if not is_node_ready():
		return
	_picture.show_world(destination.world_id if destination != null else &"")
	_picture.visible = _show == Show.DESTINATION
	var seals: Array[int] = []
	if destination != null:
		seals = destination.address.seals()
	for k: int in _glyphs.size():
		_glyphs[k].visible = k < seals.size()
		_glyphs[k].glyph_index = seals[k] if k < seals.size() else -1
	queue_redraw()


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	draw_rect(SCREEN, RefPaint.CRT_BG)
	var o: Vector2 = SCREEN.position
	if _picture.visible:
		draw_rect(
			Rect2(o + Vector2(12, 12), Vector2(150, SCREEN.size.y - 24)), RefPaint.GREEN, false, 2.0
		)
	var name_style: RefText = RefText.make(RefText.LABEL, 38, RefPaint.GREEN, 4.0)
	name_style.draw(self, o + Vector2(178, 18), tr(_title).to_upper())
	for i: int in _icons.size():
		var ink: Color = RefPaint.AMBER if _icons[i] == &"threat" else RefPaint.GREEN
		RefIcons.draw(self, _icons[i], Rect2(o + Vector2(178 + i * 40, 74), Vector2(24, 24)), ink)
	for k: int in _glyphs.size():
		if _glyphs[k].visible:
			draw_rect(
				Rect2(_glyphs[k].position - Vector2(1, 1), Vector2(GLYPH + 2, GLYPH + 2)),
				RefPaint.GREEN,
				false,
				2.0
			)
	for y: int in range(int(SCREEN.position.y), int(SCREEN.end.y), 3):
		draw_line(Vector2(SCREEN.position.x, y), Vector2(SCREEN.end.x, y), Color(0, 0, 0, 0.35))
	var bezel: StyleBoxFlat = StyleBoxFlat.new()
	bezel.draw_center = false
	bezel.border_color = RefPaint.EDGE
	bezel.set_border_width_all(4)
	bezel.set_corner_radius_all(10)
	draw_style_box(bezel, SCREEN)
