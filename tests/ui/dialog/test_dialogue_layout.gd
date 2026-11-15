## Layout tests for the dialogue screen (M4.8-04): it covers the window; the left column is
## about a quarter of the width with a square portrait no taller than 40% of the screen; the
## transcript takes the rest; long answers in pseudo-localised text (+30%) wrap and the list
## scrolls instead of pushing the transcript away, from UI scale 0.8 to 1.5.
## Bible: docs/content/dialogue-screen.md sections 1 and 6
extends GdUnitTestSuite

var _fixture: DialogueFixture
var _screen: DialogueScreen


func before_test() -> void:
	_fixture = DialogueFixture.new(self)
	_screen = _fixture.screen


func after_test() -> void:
	Settings.set_value(&"display", &"ui_scale", 1.0)
	_fixture.dispose()


func _long_answers() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	var long: String = "Ẁé ŵàñţ ţö ķñöŵ ŵĥý ţĥé ŕîñĝ öƥéñéð àñð ŵĥö ŝéñţ ţĥé ŝöļðîéŕŝ ţĥŕöûĝĥ îţ "
	for index: int in 4:
		shown.append(
			{"index": index, "text": long.repeat(2), "enabled": index != 3, "reason": long}
		)
	return shown


func test_covers_the_window_with_a_quarter_column_and_a_square_portrait() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(_screen.get_global_rect()).is_equal(Rect2(Vector2.ZERO, Vector2(1280, 720)))
	var slot: Rect2 = _screen.portrait_slot.get_global_rect()
	assert_float(slot.size.x).is_equal_approx(slot.size.y, 1.0)
	assert_float(slot.size.y).is_less_equal(720.0 * 0.4 + 0.5)
	var left: Rect2 = _screen.get_left_column().get_global_rect()
	assert_float(left.size.x).is_between(1280.0 * 0.22, 1280.0 * 0.3)
	var transcript: Rect2 = _screen.transcript.get_global_rect()
	assert_float(transcript.position.x).is_greater(left.end.x)
	assert_float(transcript.end.x).is_less_equal(1280.0)


func test_long_answers_wrap_and_scroll_at_every_scale() -> void:
	_fixture.start(&"conv_kindred_first_hail")
	for scale: float in [0.8, 1.0, 1.5]:
		Settings.set_value(&"display", &"ui_scale", scale)
		_screen.bind(_fixture.simulation)
		_screen.answers.show_choices(_long_answers())
		await get_tree().process_frame
		await get_tree().process_frame
		var answers: Rect2 = _screen.answers.get_global_rect()
		var transcript: Rect2 = _screen.transcript.get_global_rect()
		var message: String = "scale %s" % scale
		assert_float(answers.end.y).override_failure_message(message).is_less_equal(720.0)
		assert_float(answers.size.y).override_failure_message(message).is_greater(40.0)
		assert_float(transcript.size.y).override_failure_message(message).is_greater(150.0)
		for button: Button in _screen.answers.get_buttons():
			assert_float(button.get_global_rect().size.x).is_less_equal(answers.size.x + 1.0)
