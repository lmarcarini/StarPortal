## The gate chip: a shape per state and the Ring blue only while open.
## Bible: docs/content/interface-pass.md section 3
extends GdUnitTestSuite

const STATES: Array[StringName] = [&"idle", &"dialling", &"open", &"incoming"]


func test_each_state_has_its_own_shape() -> void:
	var shapes: Array[StringName] = []
	for status: StringName in STATES:
		assert_bool(shapes.has(GateChip.shape_of(status))).is_false()
		shapes.append(GateChip.shape_of(status))


func test_ring_blue_only_while_open() -> void:
	for status: StringName in STATES:
		var is_blue: bool = GateChip.color_of(status).is_equal_approx(UiPalette.RING)
		assert_bool(is_blue).is_equal(status == &"open")


func test_icon_is_drawn_in_the_state_colour() -> void:
	var icon: ImageTexture = GateChip.shape_icon(&"open")
	var image: Image = icon.get_image()
	var centre: int = GateChip.ICON_SIZE / 2
	assert_bool(image.get_pixel(centre, centre).is_equal_approx(UiPalette.RING)).is_true()
