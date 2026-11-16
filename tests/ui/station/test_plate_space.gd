## Tests for PlateSpace: the plate covers the station rect evenly (cropped, never letterboxed
## or stretched) and maps both ways at several screen sizes.
## Bible: docs/content/interface-rethink.md section 7 (plate plus live layers)
extends GdUnitTestSuite


func _def() -> StationSceneDef:
	var def: StationSceneDef = StationSceneDef.new()
	def.plate_size = Vector2i(1672, 941)
	return def


func test_cover_fills_both_axes() -> void:
	for size: Vector2 in [
		Vector2(1920, 1080), Vector2(1280, 720), Vector2(2560, 1440), Vector2(3440, 1440)
	]:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		var s: float = PlateSpace.cover_scale(Vector2(1672, 941), rect)
		assert_bool(1672.0 * s >= size.x - 0.01 and 941.0 * s >= size.y - 0.01).is_true()
		(
			assert_bool(is_equal_approx(1672.0 * s, size.x) or is_equal_approx(941.0 * s, size.y))
			. is_true()
		)


func test_round_trip() -> void:
	var def: StationSceneDef = _def()
	var rect: Rect2 = Rect2(Vector2(10, 20), Vector2(3440, 1440))
	var p: Vector2 = Vector2(836, 390)
	var back: Vector2 = PlateSpace.to_plate(def, rect, PlateSpace.to_screen(def, rect, p))
	assert_float(back.distance_to(p)).is_less(0.001)


func test_crop_is_even() -> void:
	var def: StationSceneDef = _def()
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(3440, 1440))
	var top_left: Vector2 = PlateSpace.to_screen(def, rect, Vector2.ZERO)
	var bottom_right: Vector2 = PlateSpace.to_screen(def, rect, Vector2(1672, 941))
	assert_float(top_left.y + (bottom_right.y - 1440.0)).is_equal_approx(0.0, 0.01)
	assert_float(top_left.x).is_equal_approx(0.0, 0.01)
