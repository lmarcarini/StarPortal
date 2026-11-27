## Tests of the portrait renderer (card M8-02): every record option draws, the same record
## gives the same pixels, the style rules (navy background, outlines, accent colours), the
## cache, the speed budget, the widget's whole-number scales with nearest filtering, and the
## portrait on the Personnel row and panel.
## Bible: docs/content/portraits.md
extends GdUnitTestSuite

## Portraits timed against the budget.
const TIMED: int = 50
## Budget for TIMED portraits, in milliseconds (card: under 0.5 s on the CI machine).
const BUDGET_MS: int = 500


func before_test() -> void:
	PortraitCache.clear()


func after_test() -> void:
	PortraitCache.clear()


func _record(seed_text: String, field: String) -> Dictionary:
	return AppearanceRules.roll_seeded(seed_text, field)


func test_every_option_of_every_key_draws() -> void:
	var base: Dictionary = _record("base", "office")
	var options: Dictionary = {
		"sex": AppearanceRules.SEXES,
		"age": AppearanceRules.AGES,
		"head": AppearanceRules.HEADS,
		"jaw": AppearanceRules.JAWS,
		"eyes": AppearanceRules.EYES,
		"brows": AppearanceRules.BROWS,
		"nose": AppearanceRules.NOSES,
		"mouth": AppearanceRules.MOUTHS,
		"facial_hair": AppearanceRules.FACIAL_HAIR,
		"hair": AppearanceRules.HAIR,
		"accessory": AppearanceRules.ACCESSORIES,
		"face_width": [-1, 0, 1],
		"skin": range(AppearanceRules.SKIN_TONES),
		"hair_colour": range(AppearanceRules.HAIR_COLOURS),
		"eye_colour": range(AppearanceRules.EYE_COLOURS),
	}
	for key: String in options:
		for value: Variant in options[key]:
			var record: Dictionary = base.duplicate()
			record[key] = value
			_assert_portrait(PortraitPainter.paint(record))


func test_every_uniform_variant_with_every_hair_style_draws() -> void:
	for field: String in AppearanceRules.VARIANTS:
		for variant: String in AppearanceRules.VARIANTS[field]:
			for hair: String in AppearanceRules.HAIR:
				for sex: String in AppearanceRules.SEXES:
					var record: Dictionary = _record("%s-%s" % [field, hair], field)
					record["variant"] = variant
					record["hair"] = hair
					record["sex"] = sex
					_assert_portrait(PortraitPainter.paint(record))


func test_same_record_same_pixels() -> void:
	for i: int in 10:
		var record: Dictionary = _record("same-%d" % i, _field(i))
		var first: Image = PortraitPainter.paint(record)
		var second: Image = PortraitPainter.paint(record.duplicate())
		assert_bool(first.get_data() == second.get_data()).is_true()


func test_different_records_differ() -> void:
	var a: Image = PortraitPainter.paint(_record("one", "science"))
	var b: Image = PortraitPainter.paint(_record("two", "science"))
	assert_bool(a.get_data() == b.get_data()).is_false()


func test_background_is_smooth_navy_and_lighter_at_the_top() -> void:
	var image: Image = PortraitPainter.paint(_record("bg", "military"))
	var corner: Color = image.get_pixel(1, 1)
	assert_bool(corner.b > corner.r).is_true()
	assert_bool(corner.get_luminance() > image.get_pixel(1, 60).get_luminance()).is_true()


func test_outlines_are_dark_even_on_pale_skin() -> void:
	for hex: String in PortraitRamp.SKINS:
		var outline: Color = PortraitRamp.ramp(hex)[PortraitRamp.OUTLINE]
		var hls: Vector3 = PortraitRamp.rgb_to_hls(outline)
		assert_float(hls.y).is_less_equal(0.27)


func test_ramps_run_dark_to_light() -> void:
	for hex: String in PortraitRamp.HAIRS + PortraitRamp.SKINS:
		var shades: Array[Color] = PortraitRamp.ramp(hex)
		assert_int(shades.size()).is_equal(5)
		for i: int in 4:
			assert_bool(shades[i].get_luminance() <= shades[i + 1].get_luminance() + 0.01).is_true()


func test_military_standard_shows_the_red_patch() -> void:
	var record: Dictionary = _record("patch", "military")
	record["variant"] = "standard"
	var image: Image = PortraitPainter.paint(record)
	var accent: Array[Color] = PortraitRamp.ramp(PortraitRamp.ACCENTS["military"])
	assert_bool(_has_colour(image, Rect2i(8, 82, 8, 8), accent[PortraitRamp.MID])).is_true()


func test_drawn_once_per_staff_member_and_cached() -> void:
	var record: Dictionary = _record("cache", "engineering")
	var first: ImageTexture = PortraitCache.texture_for(&"p1", record)
	assert_object(PortraitCache.texture_for(&"p1", record)).is_same(first)
	assert_int(PortraitCache.size()).is_equal(1)
	var changed: Dictionary = record.duplicate()
	changed["hair"] = "bald" if record["hair"] != "bald" else "buzz"
	assert_object(PortraitCache.texture_for(&"p1", changed)).is_not_same(first)


func test_fifty_portraits_within_budget() -> void:
	PortraitPainter.paint(_record("warm-up", "office"))
	var records: Array[Dictionary] = []
	for i: int in TIMED:
		records.append(_record("speed-%d" % i, _field(i)))
	var start: int = Time.get_ticks_msec()
	for i: int in TIMED:
		PortraitCache.texture_for(StringName("speed-%d" % i), records[i])
	var spent: int = Time.get_ticks_msec() - start
	assert_int(spent).override_failure_message("50 portraits took %d ms" % spent).is_less(BUDGET_MS)


func test_widget_whole_number_scales_and_nearest_filter() -> void:
	var portrait: StaffPortrait = auto_free(StaffPortrait.new())
	portrait.show_record(&"w", _record("widget", "medicine"))
	assert_int(portrait.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	for scale: int in [1, 2, 3]:
		portrait.portrait_scale = scale
		assert_vector(portrait.custom_minimum_size).is_equal(Vector2(96, 96) * scale)
	portrait.portrait_scale = 0
	assert_int(portrait.portrait_scale).is_equal(1)
	portrait.crop = StaffPortrait.FACE
	portrait.show_record(&"w", _record("widget", "medicine"))
	assert_vector(portrait.custom_minimum_size).is_equal(Vector2(48, 48))
	assert_object(portrait.texture).is_instanceof(AtlasTexture)


func test_personnel_row_and_panel_show_the_portrait() -> void:
	var state: GameState = ResearchFixture.state()
	var person: PersonState = state.staff.people[0]
	var row: PersonnelRow = auto_free(PersonnelRow.new())
	row.show_person(state, person)
	assert_object(row.get_portrait().texture).is_not_null()
	assert_int(row.get_portrait().side()).is_equal(PersonnelRow.HEIGHT)
	var panel: PersonnelPanel = auto_free(PersonnelPanel.new())
	panel.show_id(state, person.id)
	assert_bool(panel.get_portrait().visible).is_true()
	assert_str(str(panel.get_portrait().get_id())).is_equal(str(person.id))
	panel.show_id(state, &"nobody")
	assert_bool(panel.get_portrait().visible).is_false()


func _assert_portrait(image: Image) -> void:
	assert_object(image).is_not_null()
	assert_int(image.get_width()).is_equal(96)
	assert_int(image.get_height()).is_equal(96)


func _has_colour(image: Image, area: Rect2i, colour: Color) -> bool:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).to_rgba32() == colour.to_rgba32():
				return true
	return false


func _field(index: int) -> String:
	var fields: Array[String] = AppearanceRules.VARIANTS.keys()
	return fields[index % fields.size()]
