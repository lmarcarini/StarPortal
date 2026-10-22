## Tests that GlyphDef, AnchorFieldDef and WorldDef load from `.tres` fixtures and the Registry
## accepts them. Loads a fresh Registry instance, never the autoload or the real data/ folder.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## technical-architecture.md#data-model
extends GdUnitTestSuite

const RegistryScript := preload("res://src/content/registry.gd")
const FIXTURES: String = "res://tests/content/fixtures/gate"

var _registry: RegistryScript


func before_test() -> void:
	_registry = auto_free(RegistryScript.new())
	var errors: Array[String] = _registry.load_all(FIXTURES).value
	assert_array(errors).is_empty()


## The Registry loads every gate fixture under its id, each as its own class.
func test_registry_accepts_gate_defs() -> void:
	assert_int(_registry.get_all_of(GlyphDef).size()).is_equal(1)
	assert_int(_registry.get_all_of(AnchorFieldDef).size()).is_equal(1)
	assert_int(_registry.get_all_of(WorldDef).size()).is_equal(2)
	assert_int(_registry.get_all_of(DefBase).size()).is_equal(4)


## A GlyphDef keeps its index, keys, star points and line pairs.
func test_glyph_def_fields() -> void:
	var glyph := _registry.get_def(&"glyph_heron") as GlyphDef
	assert_that(glyph).is_not_null()
	assert_int(glyph.index).is_equal(7)
	assert_that(glyph.name_key).is_equal(&"GLYPH_HERON_NAME")
	assert_that(glyph.picture_key).is_equal(&"GLYPH_HERON_PICTURE")
	var points := PackedVector2Array([Vector2(0.1, 0.2), Vector2(0.5, 0.5), Vector2(0.9, 0.4)])
	assert_that(glyph.points).is_equal(points)
	assert_that(glyph.lines).is_equal(PackedInt32Array([0, 1, 1, 2]))


## An AnchorFieldDef keeps its domain and exactly 36 integer positions, index = glyph index.
func test_anchor_field_def_fields() -> void:
	var field := _registry.get_def(&"anchors_home") as AnchorFieldDef
	assert_that(field).is_not_null()
	assert_that(field.domain_id).is_equal(&"home")
	assert_int(field.positions_ly.size()).is_equal(GateAddress.GLYPH_COUNT)
	assert_that(field.positions_ly[0]).is_equal(Vector3i(-1800, -25, 0))
	assert_that(field.positions_ly[35]).is_equal(Vector3i(1700, 20, 25))


## The fixture anchors give a well-formed address through the address rule.
func test_anchor_field_feeds_address_rule() -> void:
	var field := _registry.get_def(&"anchors_home") as AnchorFieldDef
	var cairn := _registry.get_def(&"world_cairn") as WorldDef
	var address := AddressRule.address_of(cairn.position_ly, field.positions_ly, 5)
	assert_bool(address.is_well_formed()).is_true()


## A WorldDef keeps its fields; unset ones take their defaults (OPEN, not guarded, not home).
func test_world_def_fields() -> void:
	var cairn := _registry.get_def(&"world_cairn") as WorldDef
	assert_that(cairn.name_key).is_equal(&"WORLD_CAIRN_NAME")
	assert_that(cairn.position_ly).is_equal(Vector3i(120, -45, 9))
	assert_int(cairn.origin_glyph).is_equal(5)
	assert_int(cairn.ring_status).is_equal(WorldDef.RingStatus.OPEN)
	assert_bool(cairn.is_guarded).is_false()
	assert_bool(cairn.is_home).is_true()
	var buried := _registry.get_def(&"world_buried") as WorldDef
	assert_int(buried.ring_status).is_equal(WorldDef.RingStatus.BURIED)
	assert_bool(buried.is_guarded).is_true()
	assert_bool(buried.is_home).is_false()


## RingStatus has the three states later cards rely on, in this order.
func test_ring_status_values() -> void:
	assert_int(WorldDef.RingStatus.OPEN).is_equal(0)
	assert_int(WorldDef.RingStatus.BURIED).is_equal(1)
	assert_int(WorldDef.RingStatus.SHIELDED).is_equal(2)
	assert_int(WorldDef.new().ring_status).is_equal(WorldDef.RingStatus.OPEN)
