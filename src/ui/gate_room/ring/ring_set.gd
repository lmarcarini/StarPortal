class_name RingSet
extends RoomSet
## The Gate Room seen head-on from the control room glass: the Ring standing on its ramp,
## eight seal chevrons that light in sequence, the horizon as a flat disc and a blue light
## that floods the room while a wormhole is open. The camera is orthographic and framed so
## the Ring's outer edge meets RingView's 2D overlay (glyph marks, seal lamps, horizon), so
## both line up at any size.
## Bible: docs/content/interface-pass.md section 6

## The Ring's outer radius and centre height, in metres.
const RING_RADIUS: float = 2.5
const RING_CENTRE: Vector3 = Vector3(0, 3.0, -2.0)
const CHEVRON_OFF: Color = Color("#4a3a2a")
const CHEVRON_ON: Color = Color("#e8a33d")

## The Ring, the horizon disc and the open-wormhole light.
var ring: MeshInstance3D = null
var horizon: MeshInstance3D = null
var horizon_light: OmniLight3D = null

var _chevrons: Array[MeshInstance3D] = []
var _outer_pixels: float = 100.0
var _height_pixels: float = 240.0


func _init() -> void:
	super()
	room_size = Vector2(12, 10)
	wall_height = 7.0


func _build_props(props: Node3D) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = RING_RADIUS * (1.0 - RingView.BAND_RATIO)
	torus.outer_radius = RING_RADIUS
	torus.rings = 48
	torus.ring_segments = 10
	torus.material = SetKit.material(Color("#6b7072"))
	ring = MeshInstance3D.new()
	ring.name = &"Ring"
	ring.mesh = torus
	ring.position = RING_CENTRE
	ring.rotation_degrees = Vector3(90, 0, 0)
	props.add_child(ring)
	props.add_child(SetKit.box(Vector3(2.6, 0.5, 3.0), Vector3(0, 0.25, -0.6), SetKit.METAL))
	_build_chevrons(props)
	_build_horizon(props)


func _build_chevrons(props: Node3D) -> void:
	for index: int in GateAddress.SEAL_COUNT:
		var angle: float = -PI / 2.0 + TAU * float(index) / GateAddress.SEAL_COUNT
		var at := Vector2.from_angle(angle) * RING_RADIUS
		var chevron := SetKit.box(
			Vector3(0.35, 0.35, 0.3), RING_CENTRE + Vector3(at.x, -at.y, 0.15), CHEVRON_OFF, true
		)
		chevron.rotation.z = -angle
		props.add_child(chevron)
		_chevrons.append(chevron)


func _build_horizon(props: Node3D) -> void:
	var disc := CylinderMesh.new()
	disc.height = 0.02
	disc.top_radius = RING_RADIUS * (1.0 - RingView.BAND_RATIO)
	disc.bottom_radius = disc.top_radius
	disc.radial_segments = 32
	var material: StandardMaterial3D = SetKit.material(UiPalette.RING, true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material = material
	horizon = MeshInstance3D.new()
	horizon.name = &"Horizon"
	horizon.mesh = disc
	horizon.position = RING_CENTRE
	horizon.rotation_degrees = Vector3(90, 0, 0)
	props.add_child(horizon)
	horizon_light = OmniLight3D.new()
	horizon_light.light_color = UiPalette.RING
	horizon_light.omni_range = 9.0
	horizon_light.position = RING_CENTRE + Vector3(0, 0, 1.0)
	props.add_child(horizon_light)
	set_horizon(0.0)


## Lights the first [param count] chevrons.
func set_lit(count: int) -> void:
	for index: int in _chevrons.size():
		var box := _chevrons[index].mesh as BoxMesh
		var material := box.material as StandardMaterial3D
		material.albedo_color = CHEVRON_ON if index < count else CHEVRON_OFF


## The number of lit chevrons.
func lit_count() -> int:
	var count: int = 0
	for chevron: MeshInstance3D in _chevrons:
		var material := (chevron.mesh as BoxMesh).material as StandardMaterial3D
		if material.albedo_color == CHEVRON_ON:
			count += 1
	return count


## Shows the horizon at [param level] (0 dark to 1 open) and its light.
func set_horizon(level: float) -> void:
	if horizon == null:
		return
	var material := (horizon.mesh as CylinderMesh).material as StandardMaterial3D
	material.albedo_color = Color(UiPalette.RING, 0.55 * level)
	horizon.visible = level > 0.0
	horizon_light.visible = level > 0.0
	horizon_light.light_energy = 2.5 * level


## Frames the camera so the Ring's outer edge is [param outer] pixels from the centre of a
## view [param height] pixels tall.
func frame(outer: float, height: float) -> void:
	_outer_pixels = maxf(outer, 1.0)
	_height_pixels = maxf(height, 1.0)
	_place_camera(camera)


func _ready() -> void:
	super()
	light.position = RING_CENTRE + Vector3(0, 2.5, 5.0)
	light.omni_range = 9.0
	light.light_energy = 2.2


func _place_camera(cam: Camera3D) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = RING_RADIUS * _height_pixels / _outer_pixels
	cam.position = Vector3(RING_CENTRE.x, RING_CENTRE.y, RING_CENTRE.z + 8.0)
	cam.rotation = Vector3.ZERO
	cam.near = 0.1
	cam.far = 30.0
