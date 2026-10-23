## Tests for the content validator's checks: each is fed good data (no problem) and broken data
## (the right line). Bible: technical-architecture.md#testing-and-tooling
extends GdUnitTestSuite

const Fixture := preload("res://tests/gate/galaxy_fixture.gd")
const RegistryScript := preload("res://src/content/registry.gd")


func _glyph(index: int, name_key: StringName = &"K") -> GlyphDef:
	var glyph := GlyphDef.new()
	glyph.id = StringName("glyph_%02d" % index)
	glyph.index = index
	glyph.name_key = name_key
	glyph.picture_key = name_key
	glyph.points = PackedVector2Array(
		[Vector2(0.1, 0.1), Vector2(0.2 + index * 0.02, 0.5), Vector2(0.9, 0.7)]
	)
	glyph.lines = PackedInt32Array([0, 1, 1, 2])
	return glyph


func _glyphs() -> Array[GlyphDef]:
	var glyphs: Array[GlyphDef] = []
	for index: int in 36:
		glyphs.append(_glyph(index))
	return glyphs


func _keys() -> Dictionary[String, bool]:
	return {"K": true}


func _field(positions: Array[Vector3i]) -> AnchorFieldDef:
	var field := AnchorFieldDef.new()
	field.id = &"anchors_test"
	field.domain_id = &"home"
	field.positions_ly = positions
	return field


func _spread() -> Array[Vector3i]:
	var positions: Array[Vector3i] = []
	for index: int in 36:
		positions.append(Vector3i(index * 3000, 0, 0))
	return positions


func _world(id: StringName, position: Vector3i, origin: int, is_home: bool) -> WorldDef:
	var world := WorldDef.new()
	world.id = id
	world.position_ly = position
	world.origin_glyph = origin
	world.is_home = is_home
	return world


func test_valid_glyphs_have_no_problem() -> void:
	assert_array(ContentCheckGlyphs.check(_glyphs(), _keys())).is_empty()


func test_duplicate_glyph_index_is_reported() -> void:
	var glyphs: Array[GlyphDef] = _glyphs()
	glyphs[5].index = 4
	var errors: Array[String] = ContentCheckGlyphs.check(glyphs, _keys())
	assert_array(errors).contains(["glyph glyph_05 repeats index 4 of glyph_04"])
	assert_array(errors).contains(["glyphs: no glyph has index 5"])


func test_wrong_glyph_count_and_index_range_are_reported() -> void:
	var glyphs: Array[GlyphDef] = _glyphs()
	glyphs.pop_back()
	assert_array(ContentCheckGlyphs.check(glyphs, _keys())).contains(
		["glyphs: found 35, expected 36"]
	)
	glyphs[0].index = 36
	assert_array(ContentCheckGlyphs.check(glyphs, _keys())).contains(
		["glyph glyph_00 has index 36, expected 0..35"]
	)


func test_missing_translation_key_is_reported() -> void:
	var glyphs: Array[GlyphDef] = _glyphs()
	glyphs[3].picture_key = &"GLYPH_NOWHERE_PICTURE"
	assert_array(ContentCheckGlyphs.check(glyphs, _keys())).contains(
		["glyph glyph_03: key 'GLYPH_NOWHERE_PICTURE' is not in glyphs.csv"]
	)


func test_bad_and_repeated_constellations_are_reported() -> void:
	var glyphs: Array[GlyphDef] = _glyphs()
	glyphs[1].points = PackedVector2Array([Vector2(0.1, 0.1), Vector2(2.0, 0.5)])
	glyphs[1].lines = PackedInt32Array([0, 5])
	glyphs[7].points = glyphs[8].points
	var errors: Array[String] = ContentCheckGlyphs.check(glyphs, _keys())
	assert_array(errors).contains(["glyph glyph_01 has 2 stars, expected 3..9"])
	assert_array(errors).contains(["glyph glyph_01 has a star outside the unit square: (2.0, 0.5)"])
	assert_array(errors).contains(["glyph glyph_01 has a bad line 0-5"])
	assert_array(errors).contains(["glyph glyph_08 has the same constellation as glyph_07"])


func test_anchors_too_close_are_reported() -> void:
	var positions: Array[Vector3i] = _spread()
	assert_array(ContentCheckWorlds.check_field(_field(positions), true)).is_empty()
	positions[10] = positions[11] + Vector3i(100, 0, 0)
	assert_array(ContentCheckWorlds.check_field(_field(positions), true)).contains(
		["anchor field anchors_test: anchors 10 and 11 are 100 ly apart, least 2500"]
	)
	assert_array(ContentCheckWorlds.check_field(_field(positions), false)).is_empty()


func test_anchor_field_size_and_bounds_are_reported() -> void:
	var positions: Array[Vector3i] = _spread()
	positions.pop_back()
	assert_array(ContentCheckWorlds.check_field(_field(positions), true)).contains(
		["anchor field anchors_test has 35 positions, expected 36"]
	)
	positions = _spread()
	positions[2] = Vector3i(0, AddressRule.MAX_COORDINATE_LY + 1, 0)
	var errors: Array[String] = ContentCheckWorlds.check_field(_field(positions), true)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("anchor 2").contains("is beyond 1000000 ly")


func test_world_origin_and_home_rules_are_reported() -> void:
	var anchors: Array[Vector3i] = _spread()
	var home: WorldDef = _world(&"world_cairn", Vector3i(0, 500, 0), 30, true)
	assert_array(ContentCheckWorlds.check_worlds([home], anchors)).is_empty()
	home.origin_glyph = 36
	assert_array(ContentCheckWorlds.check_worlds([home], anchors)).contains(
		["world world_cairn has origin glyph 36, expected 0..35"]
	)
	home.origin_glyph = 1
	assert_array(ContentCheckWorlds.check_worlds([home], anchors)).contains(
		["home world world_cairn: origin 1 is among its seven nearest anchors"]
	)
	var other: WorldDef = _world(&"world_other", Vector3i(5, 5, 5), 30, true)
	assert_array(ContentCheckWorlds.check_worlds([home, other], anchors)).contains(
		["expected exactly one home world, found 2"]
	)
	var elsewhere: WorldDef = _world(&"world_far", Vector3i(0, 0, 0), 30, true)
	assert_array(ContentCheckWorlds.check_worlds([elsewhere], anchors)).contains(
		["the home world is world_far, expected world_cairn"]
	)


func test_duplicate_authored_address_is_reported() -> void:
	var anchors: Array[Vector3i] = _spread()
	var first: WorldDef = _world(&"world_a", Vector3i(100, 0, 0), 30, false)
	var second: WorldDef = _world(&"world_b", Vector3i(200, 50, 0), 30, false)
	var errors: Array[String] = ContentCheckWorlds.check_unique_addresses([first, second], anchors)
	assert_int(errors.size()).is_equal(36)
	assert_str(errors[0]).starts_with("worlds world_a and world_b share address")
	second.position_ly = Vector3i(60_000, 0, 0)
	assert_array(ContentCheckWorlds.check_unique_addresses([first, second], anchors)).is_empty()


func test_balance_tunables_are_checked() -> void:
	assert_array(ContentCheckBalance.check(BalanceConfig.new())).is_empty()
	var balance := BalanceConfig.new()
	balance.lock_reference_distance_ly = 0.0
	balance.seal_multiplier_9 = -1.0
	balance.cost_fraction_blocked = 1.5
	var errors: Array[String] = ContentCheckBalance.check(balance)
	assert_int(errors.size()).is_equal(3)
	assert_str(errors[0]).contains("lock_reference_distance_ly")
	assert_str(errors[1]).contains("seal_multiplier_9")
	assert_str(errors[2]).contains("cost_fraction_blocked")
	assert_array(ContentCheckBalance.check(null)).is_not_empty()


func test_generated_galaxy_is_checked() -> void:
	var anchors: Array[Vector3i] = Fixture.anchors()
	var params := GeneratorParams.new()
	var balance := BalanceConfig.new()
	var worlds: Array[WorldRecord] = WorldGenerator.generate(
		1, anchors, Fixture.authored(anchors), params, balance
	)
	assert_array(ContentCheckGalaxy.check(worlds, anchors, params, balance)).is_empty()
	assert_int(ContentCheckGalaxy.reachable(worlds, anchors, params, balance).size()).is_greater(
		params.min_reach_worlds - 1
	)
	var twin: WorldRecord = WorldRecord.new()
	twin.id = &"world_twin"
	twin.position_ly = worlds[5].position_ly
	var broken: Array[WorldRecord] = worlds.duplicate()
	broken.append(twin)
	var errors: Array[String] = ContentCheckGalaxy.check(broken, anchors, params, balance)
	assert_array(errors).contains(["generated 301 procedural worlds, expected 300"])
	(
		assert_bool(errors.any(func(line: String) -> bool: return line.contains("share address")))
		. is_true()
	)
	params.min_reach_worlds = 500
	assert_array(ContentCheckGalaxy.check(worlds, anchors, params, balance)).is_not_empty()


func test_real_content_is_valid() -> void:
	var registry: RegistryScript = auto_free(ContentSource.new_registry())
	var load_errors: Array[String] = registry.load_all().value
	assert_array(ContentValidator.run(registry, load_errors, 2, false)).is_empty()
	var broken: Array[String] = ["res://data/x.tres: could not be loaded"]
	assert_array(ContentValidator.run(registry, broken, 2, false)).contains(broken)
