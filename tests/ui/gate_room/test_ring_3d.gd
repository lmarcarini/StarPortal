## The Gate Room's 3D Ring view: chevrons and horizon follow the 2D Ring, the camera frames
## the Ring to the overlay, and the feed renders only while visible or kept live.
## Bible: docs/content/interface-pass.md section 6
extends GdUnitTestSuite

const RING_SCENE: String = "res://src/ui/gate_room/ring/ring_view.tscn"

var _ring: RingView = null


func before_test() -> void:
	_ring = (load(RING_SCENE) as PackedScene).instantiate() as RingView
	_ring.size = Vector2(600, 480)
	add_child(_ring)
	await get_tree().process_frame


func after_test() -> void:
	_ring.free()


func test_chevrons_light_with_the_seals() -> void:
	_ring.begin_dialing()
	_ring.set_lit(3)
	assert_int(_ring.ring_set.lit_count()).is_equal(3)
	_ring.end_dialing(false)
	assert_int(_ring.ring_set.lit_count()).is_equal(0)


func test_horizon_and_its_light_show_only_while_open() -> void:
	assert_bool(_ring.ring_set.horizon.visible).is_false()
	_ring.begin_dialing()
	_ring.end_dialing(true)
	assert_bool(_ring.ring_set.horizon.visible).is_true()
	assert_bool(_ring.ring_set.horizon_light.visible).is_true()
	assert_int(_ring.ring_set.lit_count()).is_equal(GateAddress.SEAL_COUNT)
	EventBus.wormhole_closed.emit(&"test")
	_ring.advance(RingView.CLOSE_SECONDS)
	assert_bool(_ring.ring_set.horizon.visible).is_false()


func test_camera_frames_the_ring_to_the_overlay() -> void:
	var camera: Camera3D = _ring.ring_set.camera
	assert_int(camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	var feed_height: float = _ring.feed_texture().get_size().y
	var outer_feed: float = RingView.outer_radius(_ring.size) / RingView.FEED_DOWNSCALE
	var ring_pixels: float = RingSet.RING_RADIUS / camera.size * feed_height
	assert_float(ring_pixels).is_equal_approx(outer_feed, 1.0)
	assert_float(RingView.outer_radius(_ring.size) * 2.0).is_greater_equal(_ring.size.y / 2.0)


func test_feed_stops_when_hidden_unless_kept_live() -> void:
	assert_bool(_ring.is_feed_live()).is_true()
	_ring.visible = false
	assert_bool(_ring.is_feed_live()).is_false()
	_ring.keep_live = true
	assert_bool(_ring.is_feed_live()).is_true()
	_ring.keep_live = false
	assert_bool(_ring.is_feed_live()).is_false()
	_ring.visible = true
	assert_bool(_ring.is_feed_live()).is_true()


func test_open_horizon_is_the_only_ring_blue() -> void:
	var material := (_ring.ring_set.horizon.mesh as CylinderMesh).material as StandardMaterial3D
	assert_bool(Color(material.albedo_color, 1.0).is_equal_approx(UiPalette.RING)).is_true()
	assert_bool(_ring.ring_set.horizon_light.light_color.is_equal_approx(UiPalette.RING)).is_true()
