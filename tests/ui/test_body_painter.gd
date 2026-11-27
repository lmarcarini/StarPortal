## Tests of the full-body sprite renderer (card M8-03): the same record gives the same
## pixels, the pose table's frame counts, every animation of the table in the built
## SpriteFrames, a transparent background, feet on the baseline in every frame, and the cache.
## Bible: docs/content/portraits.md
extends GdUnitTestSuite


func before_test() -> void:
	PortraitCache.clear()


func after_test() -> void:
	PortraitCache.clear()


func _record(seed_text: String, field: String) -> Dictionary:
	return AppearanceRules.roll_seeded(seed_text, field)


func _lowest_opaque_row(image: Image) -> int:
	for y: int in range(image.get_height() - 1, -1, -1):
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return y
	return -1


func test_same_record_same_pixels() -> void:
	var record: Dictionary = _record("body-a", "military")
	for view: String in BodyFrames.DIRECTIONS:
		var a: Image = BodyPainter.paint(record, "walk", view, 1)
		var b: Image = BodyPainter.paint(record.duplicate(), "walk", view, 1)
		assert_bool(a.get_data() == b.get_data()).is_true()


func test_different_records_differ() -> void:
	var a: Image = BodyPainter.paint(_record("body-a", "military"), "idle", "front", 0)
	var b: Image = BodyPainter.paint(_record("body-b", "science"), "idle", "front", 0)
	assert_bool(a.get_data() == b.get_data()).is_false()


func test_size_and_transparent_background() -> void:
	var image: Image = BodyPainter.paint(_record("body-c", "office"), "idle", "front", 0)
	assert_int(image.get_width()).is_equal(64)
	assert_int(image.get_height()).is_equal(128)
	assert_bool(image.detect_alpha() != Image.ALPHA_NONE).is_true()
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(63, 0), Vector2i(0, 127), Vector2i(63, 127)]:
		assert_float(image.get_pixelv(corner).a).is_equal(0.0)


func test_frame_counts_per_pose() -> void:
	assert_int(BodyFrames.frame_count("idle")).is_equal(2)
	assert_int(BodyFrames.frame_count("walk")).is_equal(4)
	assert_int(BodyFrames.frame_count("work")).is_equal(2)
	assert_int(BodyFrames.frame_count("sit")).is_equal(0)


func test_animation_names() -> void:
	var names: Array[String] = BodyFrames.animations()
	assert_int(names.size()).is_equal(BodyFrames.POSES.size() * 3)
	for expected: String in ["idle_front", "walk_back", "work_side"]:
		assert_bool(expected in names).is_true()
	assert_str(BodyFrames.animation("walk", "back")).is_equal("walk_back")


func test_sprite_frames_hold_every_animation_of_the_table() -> void:
	var frames: SpriteFrames = BodyPainter.sprite_frames(_record("body-d", "engineering"))
	assert_int(frames.get_animation_names().size()).is_equal(BodyFrames.animations().size())
	for pose: String in BodyFrames.poses():
		for view: String in BodyFrames.DIRECTIONS:
			var anim := StringName(BodyFrames.animation(pose, view))
			assert_bool(frames.has_animation(anim)).is_true()
			assert_int(frames.get_frame_count(anim)).is_equal(BodyFrames.frame_count(pose))
			assert_bool(frames.get_animation_loop(anim)).is_true()
			assert_float(frames.get_animation_speed(anim)).is_equal(BodyFrames.fps(pose))


func test_feet_on_the_baseline_in_every_frame() -> void:
	for field: String in AppearanceRules.VARIANTS:
		var record: Dictionary = _record("feet-" + field, field)
		for pose: String in BodyFrames.poses():
			for view: String in BodyFrames.DIRECTIONS:
				for i: int in BodyFrames.frame_count(pose):
					var image: Image = BodyPainter.paint(record, pose, view, i)
					assert_int(_lowest_opaque_row(image)).is_equal(BodyPainter.BASELINE)


func test_frame_defaults_fill_missing_keys() -> void:
	var frame: Dictionary = BodyFrames.frame("idle", 0)
	for key: String in BodyFrames.DEFAULTS:
		assert_bool(frame.has(key)).is_true()
	assert_int(frame["bob"]).is_equal(0)
	assert_str(BodyFrames.frame("work", 0)["arms"]).is_equal("forward")


func test_every_variant_and_hair_draws() -> void:
	var base: Dictionary = _record("variants", "office")
	for field: String in AppearanceRules.VARIANTS:
		for variant: String in AppearanceRules.VARIANTS[field]:
			for hair: String in AppearanceRules.HAIR:
				var record: Dictionary = base.duplicate()
				record["field"] = field
				record["variant"] = variant
				record["hair"] = hair
				var image: Image = BodyPainter.paint(record, "idle", "back", 0)
				assert_bool(image.is_invisible()).is_false()


func test_cache_keeps_sprite_frames_until_the_record_changes() -> void:
	var record: Dictionary = _record("cache", "medicine")
	var first: SpriteFrames = PortraitCache.sprite_frames_for(&"s1", record)
	assert_object(PortraitCache.sprite_frames_for(&"s1", record)).is_same(first)
	var changed: Dictionary = record.duplicate()
	var skin: int = record["skin"]
	changed["skin"] = (skin + 1) % AppearanceRules.SKIN_TONES
	assert_object(PortraitCache.sprite_frames_for(&"s1", changed)).is_not_same(first)


func _top_opaque_row(image: Image) -> int:
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return y
	return -1


func _opaque_width(image: Image, y: int) -> int:
	var count: int = 0
	for x: int in image.get_width():
		if image.get_pixel(x, y).a > 0.0:
			count += 1
	return count


## M8-05: changing only "build" widens the shoulders; slim < average < broad.
func test_build_comes_from_the_record() -> void:
	var record: Dictionary = _record("build", "engineering")
	var widths: Array[int] = []
	for build: String in AppearanceRules.BUILDS:
		var look: Dictionary = record.duplicate()
		look["build"] = build
		look["height"] = 0
		var image: Image = BodyPainter.paint(look, "idle", "front", 0)
		widths.append(
			_opaque_width(image, BodyParts.shoulder_y(BodyPainter.new(look, "front", {})) + 4)
		)
	assert_bool(widths[0] < widths[1] and widths[1] < widths[2]).is_true()


## M8-05: "height" moves the top of the head by whole pixels; the feet stay on the baseline.
func test_height_comes_from_the_record() -> void:
	var record: Dictionary = _record("height", "office")
	record["hair"] = "buzz"
	var tops: Array[int] = []
	for h: int in [AppearanceRules.HEIGHT_MIN, 0, AppearanceRules.HEIGHT_MAX]:
		var look: Dictionary = record.duplicate()
		look["height"] = h
		var image: Image = BodyPainter.paint(look, "idle", "front", 0)
		tops.append(_top_opaque_row(image))
		assert_int(_lowest_opaque_row(image)).is_equal(BodyPainter.BASELINE)
	assert_int(tops[0] - tops[1]).is_equal(-AppearanceRules.HEIGHT_MIN)
	assert_int(tops[1] - tops[2]).is_equal(AppearanceRules.HEIGHT_MAX)
