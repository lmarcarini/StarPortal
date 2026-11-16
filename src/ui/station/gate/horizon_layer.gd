class_name HorizonLayer
extends ColorRect
## The event horizon in the Ring's hole, drawn by a shader clipped to the `ring_inner`
## circle, so it fits the hole exactly at every resolution. Reads its amount, shimmer and tint
## from the [RingLayer]; still when motion is reduced.
## Bible: docs/content/interface-rethink.md section 7; docs/content/presentation-and-systems.md
## section 2

var _ring: RingLayer = null
var _station: StationScene = null
var _material: ShaderMaterial = ShaderMaterial.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_material.shader = preload("res://src/ui/station/gate/horizon.gdshader")
	material = _material


## Follows [param ring] over [param station].
func bind(ring: RingLayer, station: StationScene) -> void:
	_ring = ring
	_station = station


## The shader's material (for tests).
func get_shader_material() -> ShaderMaterial:
	return _material


func _process(_delta: float) -> void:
	if _ring == null or _station == null:
		return
	visible = _ring.open_amount > 0.0
	_material.set_shader_parameter(&"centre", _station.anchor(&"ring_inner"))
	_material.set_shader_parameter(&"radius", _station.radius(&"ring_inner"))
	_material.set_shader_parameter(&"amount", _ring.open_amount)
	_material.set_shader_parameter(&"time", _ring.shimmer)
	_material.set_shader_parameter(&"hostile", 1.0 if _ring.look.hostile else 0.0)
