## Tests for GlyphIcon: it draws headless at 24 px, 96 px and with the name, reads glyphs from
## the Registry by index, and uses theme colours only.
## Bible: art-and-audio.md (Glyphs are clean vector icons),
## gate-and-address-spec.md#glyphs-and-the-hidden-address-math
extends GdUnitTestSuite

const SCENE: String = "res://src/ui/widgets/glyph_icon.tscn"
const SCRIPT_PATH: String = "res://src/ui/widgets/glyph_icon.gd"
const HERON_INDEX: int = 0
const HARD_CODED_COLOR: String = "Color\\s*\\(\\s*[0-9.]|Color8|Color\\.[A-Z]|#[0-9a-fA-F]{3,8}\\b"


func _make_icon(icon_size: Vector2) -> GlyphIcon:
	var icon: GlyphIcon = (load(SCENE) as PackedScene).instantiate() as GlyphIcon
	icon.size = icon_size
	add_child(icon)
	return auto_free(icon)


func _glyph(index: int) -> GlyphDef:
	return Registry.get_def(StringName("glyph_%02d" % index)) as GlyphDef


## Setting the index reads the glyph from the Registry; -1 and out-of-range indices draw nothing.
func test_index_resolves_through_the_registry() -> void:
	var icon: GlyphIcon = _make_icon(Vector2(96, 96))
	assert_that(icon.get_glyph()).is_null()
	icon.glyph_index = HERON_INDEX
	assert_object(icon.get_glyph()).is_same(_glyph(HERON_INDEX))
	icon.glyph_index = 35
	assert_object(icon.get_glyph()).is_same(_glyph(35))
	icon.glyph_index = -1
	assert_that(icon.get_glyph()).is_null()
	icon.glyph_index = 36
	assert_that(icon.get_glyph()).is_null()


## setup() draws a definition the caller holds; setup(null) clears it.
func test_setup_takes_a_definition() -> void:
	var icon: GlyphIcon = _make_icon(Vector2(96, 96))
	var glyph: GlyphDef = _glyph(10)
	icon.setup(glyph)
	assert_object(icon.get_glyph()).is_same(glyph)
	assert_int(icon.glyph_index).is_equal(10)
	icon.setup(null)
	assert_that(icon.get_glyph()).is_null()
	assert_int(icon.glyph_index).is_equal(-1)


## Every glyph draws without errors at 24 px, at 96 px, and with its name.
func test_every_glyph_draws_at_both_sizes_and_with_name() -> void:
	var small: GlyphIcon = _make_icon(Vector2(24, 24))
	var large: GlyphIcon = _make_icon(Vector2(96, 96))
	var named: GlyphIcon = _make_icon(Vector2(120, 140))
	named.show_name = true
	for index: int in 36:
		for icon: GlyphIcon in [small, large, named]:
			icon.glyph_index = index
		await await_idle_frame()
		assert_that(small.get_glyph()).is_not_null()
	large.size = Vector2(60, 200)
	small.size = Vector2(2, 2)
	await await_idle_frame()
	assert_that(large.get_glyph()).is_not_null()


## The name line adds to the minimum height, and the control asks for at least 24 x 24.
func test_show_name_grows_the_minimum_size() -> void:
	var icon: GlyphIcon = _make_icon(Vector2(96, 96))
	var plain: Vector2 = icon.get_combined_minimum_size()
	assert_float(plain.x).is_greater_equal(24.0)
	assert_float(plain.y).is_greater_equal(24.0)
	icon.show_name = true
	assert_float(icon.get_combined_minimum_size().y).is_greater(plain.y)
	assert_float(icon.get_combined_minimum_size().x).is_equal(plain.x)


## At 24 px and at 96 px every star of every glyph lies inside the control, a star stays at
## least 2 px in radius, and the name line leaves the stars above it.
func test_stars_fit_and_stay_visible() -> void:
	for control_side: float in [24.0, 96.0]:
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(control_side, control_side))
		var area: Rect2 = GlyphIcon.art_rect(bounds.size, 0.0)
		var radius: float = GlyphIcon.star_radius(area.size.x)
		assert_float(radius).is_greater_equal(2.0)
		assert_float(GlyphIcon.line_width(area.size.x)).is_greater_equal(1.0)
		for index: int in 36:
			for star: Vector2 in GlyphIcon.star_positions(_glyph(index).points, area):
				var disc: Rect2 = Rect2(star - Vector2(radius, radius), Vector2(radius, radius) * 2)
				(
					assert_bool(bounds.encloses(disc))
					. override_failure_message(
						"glyph %d star %s at %d px" % [index, star, int(control_side)]
					)
					. is_true()
				)
	var named: Rect2 = GlyphIcon.art_rect(Vector2(96, 96), 20.0)
	assert_float(named.end.y + GlyphIcon.star_radius(named.size.x)).is_less_equal(76.0)


## There is no room to draw in a degenerate size, and the helper says so with an empty rect.
func test_art_rect_is_empty_without_room() -> void:
	assert_that(GlyphIcon.art_rect(Vector2(0, 0), 0.0)).is_equal(Rect2())
	assert_that(GlyphIcon.art_rect(Vector2(40, 10), 12.0)).is_equal(Rect2())
	assert_that(GlyphIcon.art_rect(Vector2(4, 4), 0.0)).is_equal(Rect2())


## Colours come from the theme: the script holds no colour literal or named colour constant.
func test_script_has_no_hard_coded_colours() -> void:
	var source: String = FileAccess.get_file_as_string(SCRIPT_PATH)
	var pattern: RegEx = RegEx.create_from_string(HARD_CODED_COLOR)
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		assert_object(pattern.search(line)).override_failure_message(line).is_null()
