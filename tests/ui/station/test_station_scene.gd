## Tests for StationScene: the Gate plate shows with its anchors, anchors follow a resize,
## layers sort by depth, a def with no picture shows the placeholder, and the content check
## fails on a def missing an anchor that one of its layers needs.
## Bible: docs/content/interface-rethink.md section 7 (plate plus live layers)
extends GdUnitTestSuite

const SCENE: PackedScene = preload("res://src/ui/station/station_scene.tscn")

var _scene: StationScene = null


func before_test() -> void:
	_scene = SCENE.instantiate() as StationScene
	add_child(_scene)
	_scene.size = Vector2(1920, 1080)


func after_test() -> void:
	if is_instance_valid(_scene):
		_scene.free()


func _gate() -> StationSceneDef:
	return Registry.get_def(&"station_gate") as StationSceneDef


func test_gate_def_is_valid() -> void:
	var def: StationSceneDef = _gate()
	assert_object(def).is_not_null()
	assert_object(def.plate).is_not_null()
	assert_array(def.get_content_errors({})).is_empty()


func test_anchor_follows_resize() -> void:
	_scene.setup(_gate())
	var at_1080: Vector2 = _scene.anchor(&"ring_inner")
	_scene.size = Vector2(1280, 720)
	var at_720: Vector2 = _scene.anchor(&"ring_inner")
	assert_float(at_720.x / at_1080.x).is_equal_approx(1280.0 / 1920.0, 0.001)
	assert_float(_scene.radius(&"ring_outer")).is_greater(_scene.radius(&"ring_inner"))


func test_placeholder_without_texture() -> void:
	var def: StationSceneDef = _gate().duplicate() as StationSceneDef
	def.plate = null
	_scene.setup(def)
	assert_bool((_scene.find_child("Placeholder", true, false) as Control).visible).is_true()
	assert_bool((_scene.find_child("Plate", true, false) as Control).visible).is_false()
	assert_vector(_scene.anchor(&"clamp_0")).is_not_equal(Vector2.ZERO)


func test_layers_sort_by_depth() -> void:
	_scene.setup(_gate())
	var high: Control = Control.new()
	var low: Control = Control.new()
	_scene.add_layer(high, 5)
	_scene.add_layer(low, 1)
	assert_int(low.get_index()).is_less(high.get_index())


func test_missing_anchor_fails() -> void:
	var def: StationSceneDef = _gate().duplicate() as StationSceneDef
	var circles: Dictionary[StringName, Vector3] = def.circles.duplicate()
	circles.erase(&"ring_inner")
	def.circles = circles
	var errors: Array[String] = def.get_content_errors({})
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("ring_inner")


func test_overlay_toggles() -> void:
	_scene.setup(_gate())
	_scene.set_anchors_visible(true)
	assert_object(_scene.find_child("AnchorOverlay", true, false)).is_not_null()
