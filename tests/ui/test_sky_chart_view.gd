## Tests for SkyChartView: the turn of each glyph comes from a hash, not a random generator.
## Bible: gate-and-address-spec.md#clue-types-and-reliability
extends GdUnitTestSuite

const SCENE: String = "res://src/ui/analysis/board/sky_chart_view.tscn"


func test_angle_is_stable_and_within_a_turn() -> void:
	for glyph: int in GateAddress.GLYPH_COUNT:
		var angle: float = SkyChartView.angle_for(&"clue_0002", glyph)
		assert_float(angle).is_between(0.0, TAU)
		assert_float(SkyChartView.angle_for(&"clue_0002", glyph)).is_equal(angle)


func test_angles_differ_between_clues_and_glyphs() -> void:
	var angles: Dictionary[float, bool] = {}
	for number: int in range(1, 6):
		for glyph: int in 6:
			angles[SkyChartView.angle_for(StringName("clue_%04d" % number), glyph)] = true
	assert_int(angles.size()).is_greater(20)


func test_offset_is_stable_and_small() -> void:
	var offset: Vector2 = SkyChartView.offset_for(&"clue_0002", 14)
	assert_object(SkyChartView.offset_for(&"clue_0002", 14)).is_equal(offset)
	assert_float(absf(offset.x)).is_less_equal(SkyChartView.JITTER)
	assert_float(absf(offset.y)).is_less_equal(SkyChartView.JITTER)


func test_draws_headless_with_seven_glyphs() -> void:
	var view: SkyChartView = (load(SCENE) as PackedScene).instantiate() as SkyChartView
	view.size = Vector2(224, 80)
	add_child(view)
	auto_free(view)
	var glyphs: Array[int] = [14, 3, 22, 7, 30, 1, 9]
	view.setup(&"clue_0002", glyphs)
	await await_idle_frame()
	assert_array(view.get_glyphs()).is_equal(glyphs)
