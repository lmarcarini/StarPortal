## Status lamps: each status has its own shape and colour.
## Bible: docs/content/interface-pass.md section 2
extends GdUnitTestSuite


func test_each_status_has_its_own_shape_and_colour() -> void:
	var shapes: Array[StringName] = []
	var colors: Array[Color] = []
	for status: StringName in StatusLamp.STATUSES:
		assert_bool(shapes.has(StatusLamp.shape_of(status))).is_false()
		assert_bool(colors.has(StatusLamp.color_of(status))).is_false()
		shapes.append(StatusLamp.shape_of(status))
		colors.append(StatusLamp.color_of(status))


func test_set_status_keeps_known_statuses_and_ignores_others() -> void:
	var lamp: StatusLamp = auto_free(StatusLamp.new())
	lamp.set_status(&"alarm")
	assert_str(lamp.get_status()).is_equal("alarm")
	lamp.set_status(&"purple")
	assert_str(lamp.get_status()).is_equal("alarm")
