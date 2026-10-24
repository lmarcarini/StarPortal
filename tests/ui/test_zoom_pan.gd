## Tests for ZoomPan, the image viewer's zoom and pan numbers: fitting, zooming around a point,
## the zoom limits, and panning that stops at the image's edges.
## Bible: game-design.md#core-loop
extends GdUnitTestSuite


func _fitted() -> ZoomPan:
	var zoom_pan := ZoomPan.new()
	zoom_pan.reset(Vector2(2000, 1000), Vector2(500, 500))
	return zoom_pan


func test_reset_fits_and_centres() -> void:
	var zoom_pan := _fitted()
	assert_float(zoom_pan.scale()).is_equal_approx(0.25, 0.0001)
	assert_vector(zoom_pan.drawn_size()).is_equal_approx(Vector2(500, 250), Vector2.ONE * 0.01)
	assert_vector(zoom_pan.offset).is_equal_approx(Vector2(0, 125), Vector2.ONE * 0.01)
	assert_vector(zoom_pan.pan(Vector2(40, 40))).is_equal(Vector2.ZERO)


func test_zoom_keeps_the_point_still_and_is_limited() -> void:
	var zoom_pan := _fitted()
	var at := Vector2(100, 250)
	var image_point: Vector2 = (at - zoom_pan.offset) / zoom_pan.scale()
	zoom_pan.zoom_by(2.0, at)
	assert_float(zoom_pan.zoom).is_equal_approx(2.0, 0.0001)
	var after: Vector2 = zoom_pan.offset + image_point * zoom_pan.scale()
	assert_vector(after).is_equal_approx(at, Vector2.ONE * 0.01)
	zoom_pan.zoom_by(100.0, at)
	assert_float(zoom_pan.zoom).is_equal(ZoomPan.MAX_ZOOM)
	zoom_pan.zoom_by(0.0001, at)
	assert_float(zoom_pan.zoom).is_equal(ZoomPan.MIN_ZOOM)
	assert_vector(zoom_pan.offset).is_equal_approx(Vector2(0, 125), Vector2.ONE * 0.01)


func test_pan_stops_at_the_edges() -> void:
	var zoom_pan := _fitted()
	zoom_pan.zoom_centred(4.0)
	assert_vector(zoom_pan.drawn_size()).is_equal_approx(Vector2(2000, 1000), Vector2.ONE * 0.01)
	var moved: Vector2 = zoom_pan.pan(Vector2(10000, 10000))
	assert_vector(zoom_pan.offset).is_equal(Vector2.ZERO)
	assert_bool(moved.x > 0.0 and moved.y > 0.0).is_true()
	zoom_pan.pan(Vector2(-10000, -10000))
	assert_vector(zoom_pan.offset).is_equal_approx(Vector2(-1500, -500), Vector2.ONE * 0.01)
	assert_vector(zoom_pan.pan(Vector2(-5, -5))).is_equal(Vector2.ZERO)


func test_resize_keeps_the_zoom() -> void:
	var zoom_pan := _fitted()
	zoom_pan.zoom_centred(2.0)
	zoom_pan.resize(Vector2(1000, 1000))
	assert_float(zoom_pan.zoom).is_equal_approx(2.0, 0.0001)
	assert_float(zoom_pan.scale()).is_equal_approx(1.0, 0.0001)
