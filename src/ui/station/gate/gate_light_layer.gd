class_name GateLightLayer
extends Control
## The open gate's light on the hall: the plate dimmed slightly, then additive blue over the
## `floor_glow` polygon and a soft wash round the Ring. Strength follows the [RingLayer]'s
## open amount, so the hall brightens on a lock and returns on a close.
## Bible: docs/content/interface-rethink.md section 7

## Dimming of the plate at full open.
const DIM: float = 0.18
## Peak light strength.
const GLOW: float = 0.35

var _ring: RingLayer = null
var _station: StationScene = null
var _light: Control = Control.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_light.draw.connect(_draw_light)
	add_child(_light)


## Follows [param ring] over [param station].
func bind(ring: RingLayer, station: StationScene) -> void:
	_ring = ring
	_station = station


## Light strength now, 0 to 1.
func strength() -> float:
	return _ring.open_amount if _ring != null else 0.0


func _process(_delta: float) -> void:
	queue_redraw()
	_light.queue_redraw()


func _draw() -> void:
	var k: float = strength()
	if k <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, DIM * k))


func _draw_light() -> void:
	var k: float = strength()
	if k <= 0.0 or _station == null:
		return
	var blue: Color = UiPalette.RING
	var floor_pts: PackedVector2Array = _station.shape(&"floor_glow")
	if floor_pts.size() >= 3:
		var colours: PackedColorArray = PackedColorArray()
		for i: int in floor_pts.size():
			var near: bool = i < 2
			colours.append(Color(blue, GLOW * k * (1.0 if near else 0.25)))
		_light.draw_polygon(floor_pts, colours)
	var c: Vector2 = _station.anchor(&"ring_outer")
	var r: float = _station.radius(&"ring_outer")
	for step: int in 6:
		var f: float = 1.0 + 0.25 * step
		_light.draw_circle(c, r * f, Color(blue, GLOW * k * 0.08))
