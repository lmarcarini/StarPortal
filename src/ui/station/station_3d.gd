class_name Station3D
extends SubViewportContainer
## A station's 3D scene rendered full bleed behind the frame (M5-01): a SubViewport with its
## own 3D world, the station's scene, a WorldEnvironment and the fixed camera from the
## [StationSceneDef]. Projects named Marker3D and Path3D nodes to screen pixels (local to this
## control) so UI placement follows the camera. Applies the display/quality setting: medium
## renders at full resolution with shadows and glow; low at 75% resolution with no shadows
## from secondary lights (group [constant SECONDARY_LIGHTS]) and no glow.
## Bible: docs/content/interface-reference.md section 7

## Lights that lose their shadows on low quality.
const SECONDARY_LIGHTS: StringName = &"secondary_light"
## Resolution scale on low quality.
const LOW_SCALE: float = 0.75
## Design budget at medium quality (checked by tests and reported in PRs).
const MAX_TRIANGLES: int = 150000
const MAX_SHADOWED_LIGHTS: int = 6

## Tests set this to build 3D stations in a headless run (they are skipped headless by
## default, so the soak and the flow tests stay cheap).
static var force_enabled: bool = false
## Capture tools set this to drop the baked lightmap: software GL (llvmpipe, used for
## headless captures) renders lightmapped scenes too slowly. Static lights then light live.
static var skip_lightmaps: bool = false

var _viewport: SubViewport = SubViewport.new()
var _camera: Camera3D = Camera3D.new()
var _environment: WorldEnvironment = WorldEnvironment.new()
var _root: Node3D = null


func _init() -> void:
	name = &"Station3D"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.own_world_3d = true
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	add_child(_viewport)
	_camera.current = true
	_viewport.add_child(_camera)
	_environment.environment = Environment.new()
	_viewport.add_child(_environment)


func _enter_tree() -> void:
	Settings.setting_changed.connect(_on_setting_changed)


func _exit_tree() -> void:
	Settings.setting_changed.disconnect(_on_setting_changed)


## True when 3D stations are built in this run: the display/stations_3d setting is on and
## the run is not headless, or a test or the reference capture forces it.
static func is_enabled() -> bool:
	if force_enabled:
		return true
	return DisplayServer.get_name() != "headless" and Settings.get_bool(&"display", &"stations_3d")


## Shows [param def]'s scene from its camera, at the current quality.
func setup(def: StationSceneDef) -> void:
	if _root != null:
		_root.queue_free()
	_root = def.scene.instantiate() as Node3D
	_viewport.add_child(_root)
	var scene_env: WorldEnvironment = (
		_root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	)
	if scene_env != null:
		_environment.environment = scene_env.environment
		scene_env.environment = null
	if skip_lightmaps:
		for node: Node in _root.find_children("*", "LightmapGI", true, false):
			(node as LightmapGI).light_data = null
	_camera.fov = def.camera_fov
	_camera.position = def.camera_position
	_camera.look_at_from_position(def.camera_position, def.camera_target, Vector3.UP)
	var quality: String = str(Settings.get_value(&"display", &"quality"))
	apply_quality(quality)


## Applies quality [param quality] ("low" or "medium").
func apply_quality(quality: String) -> void:
	var low: bool = quality == "low"
	_viewport.scaling_3d_scale = LOW_SCALE if low else 1.0
	_environment.environment.glow_enabled = not low
	if _root == null:
		return
	for node: Node in _root.find_children("*", "Light3D", true, false):
		if not node.is_in_group(SECONDARY_LIGHTS):
			continue
		var light: Light3D = node as Light3D
		if not light.has_meta(&"shadow_wanted"):
			light.set_meta(&"shadow_wanted", light.shadow_enabled)
		var wanted: bool = light.get_meta(&"shadow_wanted") == true
		light.shadow_enabled = not low and wanted


## The station's 3D root, or null.
func get_root() -> Node3D:
	return _root


## The camera.
func get_camera() -> Camera3D:
	return _camera


## The viewport the scene renders into.
func get_viewport_3d() -> SubViewport:
	return _viewport


## The node called [param anchor_name] in the scene (a Marker3D or Path3D), or null.
func marker(anchor_name: StringName) -> Node3D:
	if _root == null:
		return null
	return _root.find_child(String(anchor_name), true, false) as Node3D


## Screen position (local) of world point [param world].
func project(world: Vector3) -> Vector2:
	var at: Vector2 = _camera.unproject_position(world)
	var scale_to: Vector2 = size / Vector2(maxf(_viewport.size.x, 1.0), maxf(_viewport.size.y, 1.0))
	return at * scale_to


## Screen radius of a marker's "radius" metadata (world units), measured across the view.
func project_radius(node: Node3D) -> float:
	var meta: Variant = node.get_meta(&"radius", 0.0)
	var r: float = meta if meta is float else 0.0
	var centre: Vector3 = node.global_position
	var side: Vector3 = _camera.global_basis.x * r
	return project(centre).distance_to(project(centre + side))


## Screen points of path [param path].
func project_path(path: Path3D) -> PackedVector2Array:
	var out: PackedVector2Array = []
	if path.curve == null:
		return out
	for i: int in path.curve.point_count:
		out.append(project(path.global_transform * path.curve.get_point_position(i)))
	return out


func _on_setting_changed(section: StringName, key: StringName, value: Variant) -> void:
	if section == &"display" and key == &"quality":
		apply_quality(str(value))
