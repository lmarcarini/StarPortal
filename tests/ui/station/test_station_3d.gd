## Tests for the 3D station host (M5-01): a def with a scene shows it from its fixed camera
## instead of the plate, anchors come from the scene's projected markers (the plate's are the
## fallback), the quality setting changes resolution and secondary shadows, and a headless run
## keeps the plate.
## Bible: docs/content/interface-reference.md section 7
extends GdUnitTestSuite

const SCENE: PackedScene = preload("res://src/ui/station/station_scene.tscn")
const FIXTURE: PackedScene = preload("res://tests/ui/station/fixtures/station_3d_fixture.tscn")

var _scene: StationScene = null


func before_test() -> void:
	Station3D.force_enabled = true
	_scene = SCENE.instantiate() as StationScene
	add_child(_scene)
	_scene.size = Vector2(1920, 1080)


func after_test() -> void:
	Station3D.force_enabled = false
	Settings.set_value(&"display", &"quality", "medium")
	if is_instance_valid(_scene):
		_scene.free()


func _def() -> StationSceneDef:
	var def: StationSceneDef = (Registry.get_def(&"station_gate") as StationSceneDef).duplicate()
	def.scene = FIXTURE
	def.camera_position = Vector3(0, 3, 12)
	def.camera_target = Vector3(0, 3, 0)
	return def


func test_a_scene_replaces_the_plate_and_markers_give_the_anchors() -> void:
	_scene.setup(_def())
	await await_idle_frame()
	assert_object(_scene.get_3d()).is_not_null()
	assert_bool((_scene.get_node("%Plate") as CanvasItem).visible).is_false()
	var centre: Vector2 = _scene.anchor(&"ring_inner")
	assert_float(centre.x).is_equal_approx(960.0, 2.0)
	assert_float(centre.y).is_equal_approx(540.0, 2.0)
	assert_float(_scene.radius(&"ring_inner")).is_greater(10.0)
	assert_int(_scene.shape(&"ramp").size()).is_equal(2)


func test_missing_markers_fall_back_to_the_plate() -> void:
	var plate_def: StationSceneDef = _def()
	plate_def.scene = null
	_scene.setup(plate_def)
	var on_plate: Vector2 = _scene.anchor(&"door_left")
	_scene.setup(_def())
	assert_vector(_scene.anchor(&"door_left")).is_equal(on_plate)


func test_quality_low_scales_down_and_drops_secondary_shadows() -> void:
	_scene.setup(_def())
	var view: Station3D = _scene.get_3d()
	var lamp: OmniLight3D = view.get_root().get_node("Lamp") as OmniLight3D
	assert_bool(lamp.shadow_enabled).is_true()
	Settings.set_value(&"display", &"quality", "low")
	assert_float(view.get_viewport_3d().scaling_3d_scale).is_equal(Station3D.LOW_SCALE)
	assert_bool(lamp.shadow_enabled).is_false()
	Settings.set_value(&"display", &"quality", "medium")
	assert_float(view.get_viewport_3d().scaling_3d_scale).is_equal(1.0)
	assert_bool(lamp.shadow_enabled).is_true()


func test_headless_keeps_the_plate() -> void:
	Station3D.force_enabled = false
	_scene.setup(_def())
	assert_object(_scene.get_3d()).is_null()
	assert_bool((_scene.get_node("%Plate") as CanvasItem).visible).is_true()


func test_the_gate_is_the_hall_with_the_plate_as_fallback() -> void:
	var gate: StationSceneDef = Registry.get_def(&"station_gate") as StationSceneDef
	assert_object(gate.scene).is_not_null()
	assert_object(gate.plate).is_not_null()


## The hall keeps the M5-01 budget: triangles under the cap, at most six shadowed lights, and
## no kit logos or letters.
func test_the_hall_keeps_the_budget() -> void:
	var gate: StationSceneDef = Registry.get_def(&"station_gate") as StationSceneDef
	var hall: Node3D = auto_free(gate.scene.instantiate() as Node3D)
	var triangles: int = 0
	for node: Node in hall.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(i)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (index.size() if not index.is_empty() else vertices.size()) / 3
	assert_int(triangles).is_less(Station3D.MAX_TRIANGLES)
	var shadowed: int = 0
	for node: Node in hall.find_children("*", "Light3D", true, false):
		if (node as Light3D).shadow_enabled:
			shadowed += 1
	assert_int(shadowed).is_less_equal(Station3D.MAX_SHADOWED_LIGHTS)
	for node: Node in hall.find_children("*", "", true, false):
		assert_str(node.scene_file_path).not_contains("Decal_Logo")
