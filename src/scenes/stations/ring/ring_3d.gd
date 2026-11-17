class_name Ring3D
extends Node3D
## The Ring in 3D (M5-03): the band with the game's 36 glyphs, eight clamps whose lamps light
## with the seals (a failed dial flashes them and goes dark), the event horizon with its
## opening surge, a Ring-blue light that spills on the hall while open and flickers with the
## surface, and the Shutter as an iris of eight blades closing over the hole. Follows the
## [RingLayer]'s animation (open amount, shimmer, look, failure flash) so 2D and 3D agree.
## Reads the simulation's state only.
## Bible: docs/content/interface-reference.md sections 5 and 7

## Horizon light at full open: energy and range (metres).
const LIGHT_ENERGY: float = 10.0
const LIGHT_RANGE: float = 22.0
## Iris blades.
const BLADES: int = 8

var _ring: RingLayer = null
var _horizon: MeshInstance3D = MeshInstance3D.new()
var _horizon_material: ShaderMaterial = ShaderMaterial.new()
var _light: OmniLight3D = OmniLight3D.new()
var _lamps: Array[MeshInstance3D] = []
var _blades: Array[Node3D] = []
var _burst_age: float = -1.0
var _was_open: float = 0.0


func _init() -> void:
	name = &"Ring3D"
	Ring3DBuild.body(self)
	_lamps = Ring3DBuild.lamps(self)
	_blades = Ring3DBuild.iris(self, BLADES)
	_horizon_material.shader = preload("res://src/scenes/stations/ring/horizon_3d.gdshader")
	_horizon.mesh = Ring3DBuild.disc()
	_horizon.scale = Vector3.ONE * (RingMesh.R_IN + 0.02)
	_horizon.material_override = _horizon_material
	_horizon.visible = false
	add_child(_horizon)
	_light.light_color = Color(0.36, 0.66, 1.0)
	_light.omni_range = LIGHT_RANGE
	_light.position = Vector3(0, 0, 2.5)
	_light.light_bake_mode = Light3D.BAKE_DISABLED
	add_child(_light)


## Follows [param ring] (the 2D ring layer, which owns the animation).
func bind(ring: RingLayer) -> void:
	_ring = ring
	advance(0.0)


## The horizon's material (for tests).
func get_horizon_material() -> ShaderMaterial:
	return _horizon_material


## The horizon light.
func get_light() -> OmniLight3D:
	return _light


## Lamps lit now.
func lit_lamps() -> int:
	var count: int = 0
	for lamp: MeshInstance3D in _lamps:
		if lamp.material_override == Ring3DBuild.lamp_on:
			count += 1
	return count


## How far the iris is closed, 0 to 1.
func iris_amount() -> float:
	return 0.0 if _blades.is_empty() else _blades[0].get_meta(&"amount", 0.0)


func _process(delta: float) -> void:
	advance(delta)


## Moves the Ring on by [param delta] seconds from the ring layer's state.
func advance(delta: float) -> void:
	if _ring == null:
		return
	_step_burst(delta)
	var open: float = _ring.open_amount
	_horizon.visible = open > 0.0
	_horizon_material.set_shader_parameter(&"amount", open)
	_horizon_material.set_shader_parameter(&"time", _ring.shimmer)
	_horizon_material.set_shader_parameter(&"burst", HorizonLayer.burst_at(_burst_age))
	_horizon_material.set_shader_parameter(&"settle", settle_at(_burst_age))
	_horizon_material.set_shader_parameter(&"hostile", 1.0 if _ring.look.hostile else 0.0)
	var flicker: float = 0.9 + 0.1 * sin(_ring.shimmer * 7.0) * sin(_ring.shimmer * 2.3)
	var surge: float = 1.0 + 2.0 * HorizonLayer.burst_at(_burst_age)
	_light.light_energy = LIGHT_ENERGY * open * flicker * surge
	_light.visible = open > 0.0
	_light.light_color = Color(0.95, 0.4, 0.3) if _ring.look.hostile else Color(0.36, 0.66, 1.0)
	_show_lamps()
	Ring3DBuild.set_iris(_blades, _ring.shutter_amount)


func _show_lamps() -> void:
	for i: int in _lamps.size():
		var lit: bool = i < _ring.look.seals
		if _ring.look.phase == RingLook.Phase.INCOMING:
			lit = int(_ring.shimmer * 6.0) % RingLook.SEALS == i or i == 0
		if _ring.is_flashing_failure():
			lit = Ring3DBuild.flash_on(_ring)
		_lamps[i].material_override = Ring3DBuild.lamp_on if lit else Ring3DBuild.lamp_off


## Starts the surge as the horizon begins to open (not with reduced motion) and ages it.
func _step_burst(delta: float) -> void:
	var opening: bool = _was_open <= 0.0 and _ring.open_amount > 0.0
	_was_open = _ring.open_amount
	if opening and Settings.get_bool(&"display", &"ambient_movement"):
		_burst_age = 0.0
	elif _burst_age >= 0.0:
		_burst_age += delta
		if _burst_age >= HorizonLayer.BURST_SECONDS:
			_burst_age = -1.0


## The ripple ring's progress [param age] seconds into the surge: 0 until the surge peaks,
## then 0 to 1 as it settles; 0 outside it.
static func settle_at(age: float) -> float:
	var peak: float = HorizonLayer.BURST_SECONDS * 0.35
	if age < peak or age >= HorizonLayer.BURST_SECONDS:
		return 0.0
	return (age - peak) / (HorizonLayer.BURST_SECONDS - peak)


## The surge strength now, 0 to 1.
func burst() -> float:
	return HorizonLayer.burst_at(_burst_age)


## Puts a Ring into [param station]'s 3D scene at its ring_inner marker, following
## [param ring]; returns it, or null when the station is not 3D.
static func install(station: StationScene, ring: RingLayer) -> Ring3D:
	var view: Station3D = station.get_3d()
	if view == null:
		return null
	var marker: Node3D = view.marker(&"ring_inner")
	var ring_3d: Ring3D = Ring3D.new()
	view.get_root().add_child(ring_3d)
	ring_3d.global_position = marker.global_position if marker != null else Vector3(0, 4.9, -0.2)
	ring_3d.bind(ring)
	return ring_3d
