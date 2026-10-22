## Tests the committed home domain: the 36 glyphs, the anchor field and CAIRN load through a
## fresh Registry and meet the card's rules, and the generator reproduces its files exactly.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## lore-and-arcs.md (glyph names), technical-architecture.md#data-model
extends GdUnitTestSuite

const RegistryScript := preload("res://src/content/registry.gd")
const GENERATOR: String = "res://tools/gen_home_domain.gd"
const GLYPH_TABLE: String = "res://localization/glyphs.csv"
const GLYPH_DIR: String = "res://data/gate/glyphs/"
const HALF_SLAB_LY: Vector3i = Vector3i(15_000, 15_000, 1_500)
const MIN_SPACING_LY: int = 2_500
const CAIRN_MAX_DISTANCE_LY: float = 3_000.0
const LOCALES: Array[String] = ["en", "pt_BR"]

var _registry: RegistryScript
var _glyphs: Array[GlyphDef] = []
var _strings: Dictionary[String, PackedStringArray] = {}


func before() -> void:
	_registry = RegistryScript.new()
	var errors: Array[String] = _registry.load_all("res://data").value
	assert_array(errors).is_empty()
	for def: DefBase in _registry.get_all_of(GlyphDef):
		_glyphs.append(def as GlyphDef)
	_glyphs.sort_custom(func(a: GlyphDef, b: GlyphDef) -> bool: return a.index < b.index)
	_strings = _read_table()


func after() -> void:
	_registry.free()


## The real data folder loads with no errors and holds 36 glyphs, one anchor field and CAIRN.
func test_registry_loads_the_home_domain() -> void:
	assert_int(_glyphs.size()).is_equal(36)
	assert_int(_registry.get_all_of(AnchorFieldDef).size()).is_equal(1)
	assert_that(_registry.get_def(&"anchors_home")).is_not_null()
	assert_that(_registry.get_def(&"world_cairn")).is_not_null()


## Indices 0..35 each appear exactly once, and glyph i has the id glyph_ii.
func test_indices_cover_zero_to_thirty_five_once() -> void:
	for position: int in _glyphs.size():
		var glyph: GlyphDef = _glyphs[position]
		assert_int(glyph.index).is_equal(position)
		assert_that(glyph.id).is_equal(StringName("glyph_%02d" % position))
		assert_object(_registry.get_def(glyph.id)).is_same(glyph)


## Every glyph has 3..9 stars inside the unit square and lines that join two different stars.
func test_glyph_geometry_is_valid() -> void:
	for glyph: GlyphDef in _glyphs:
		var count: int = glyph.points.size()
		assert_bool(count >= 3 and count <= 9).override_failure_message(glyph.id).is_true()
		for point: Vector2 in glyph.points:
			var inside: bool = Rect2(0.0, 0.0, 1.0, 1.0).has_point(point)
			assert_bool(inside).override_failure_message("%s star outside" % glyph.id).is_true()
		assert_int(glyph.lines.size() % 2).override_failure_message(glyph.id).is_equal(0)
		var seen: Dictionary[Vector2i, bool] = {}
		for pair: int in range(0, glyph.lines.size() - 1, 2):
			var from: int = glyph.lines[pair]
			var to: int = glyph.lines[pair + 1]
			var valid: bool = from != to and from >= 0 and to >= 0 and maxi(from, to) < count
			assert_bool(valid).override_failure_message("%s bad line" % glyph.id).is_true()
			var key: Vector2i = Vector2i(mini(from, to), maxi(from, to))
			assert_bool(seen.has(key)).override_failure_message("%s repeats" % glyph.id).is_false()
			seen[key] = true


## No two glyphs have the same set of stars, and the star counts use the whole 3..9 range.
func test_glyphs_are_distinct() -> void:
	var shapes: Dictionary[String, int] = {}
	var counts: Dictionary[int, bool] = {}
	for glyph: GlyphDef in _glyphs:
		var stars: Array[String] = []
		for point: Vector2 in glyph.points:
			stars.append("%.3f,%.3f" % [point.x, point.y])
		stars.sort()
		var shape: String = "|".join(stars)
		assert_bool(shapes.has(shape)).override_failure_message(glyph.id).is_false()
		shapes[shape] = glyph.index
		counts[glyph.points.size()] = true
	for count: int in range(3, 10):
		assert_bool(counts.has(count)).override_failure_message("no glyph of %d" % count).is_true()


## Both keys of every glyph exist in glyphs.csv with an English and a Brazilian Portuguese text.
func test_glyph_keys_are_translated() -> void:
	for glyph: GlyphDef in _glyphs:
		for key: StringName in [glyph.name_key, glyph.picture_key]:
			assert_bool(_strings.has(key)).override_failure_message(String(key)).is_true()
			for locale: int in LOCALES.size():
				var text: String = _text(key, locale)
				assert_str(text.strip_edges()).override_failure_message(String(key)).is_not_empty()
	assert_bool(_strings.has("WORLD_CAIRN_NAME")).is_true()


## Names are unique in each locale; in English no two start with the same three letters,
## and Heron and Anvil are among them.
func test_names_are_unique_and_include_heron_and_anvil() -> void:
	for locale: int in LOCALES.size():
		var names: Dictionary[String, bool] = {}
		for glyph: GlyphDef in _glyphs:
			var text: String = _text(glyph.name_key, locale).to_lower()
			assert_bool(names.has(text)).override_failure_message(text).is_false()
			names[text] = true
	var prefixes: Dictionary[String, bool] = {}
	var english: Array[String] = []
	for glyph: GlyphDef in _glyphs:
		var text: String = _text(glyph.name_key, 0)
		english.append(text)
		var prefix: String = text.substr(0, 3).to_lower()
		assert_bool(prefixes.has(prefix)).override_failure_message(text).is_false()
		prefixes[prefix] = true
	assert_array(english).contains(["Heron", "Anvil"])
	assert_str(_text(&"GLYPH_HERON_NAME", 1)).is_equal("Garça")
	assert_str(_text(&"GLYPH_ANVIL_NAME", 1)).is_equal("Bigorna")


## A picture description describes the drawing without naming it, in both locales.
func test_pictures_do_not_name_their_glyph() -> void:
	for glyph: GlyphDef in _glyphs:
		for locale: int in LOCALES.size():
			var name_text: String = _text(glyph.name_key, locale).to_lower()
			var picture: String = _text(glyph.picture_key, locale).to_lower()
			var message: String = "%s (%s) names itself" % [glyph.id, LOCALES[locale]]
			assert_bool(picture.contains(name_text)).override_failure_message(message).is_false()


## The anchor field is the home domain's: 36 positions inside the slab, at least 2,500 ly apart.
func test_anchor_field_fits_the_slab_and_spacing() -> void:
	var field: AnchorFieldDef = _registry.get_def(&"anchors_home") as AnchorFieldDef
	assert_that(field.domain_id).is_equal(&"home")
	assert_int(field.positions_ly.size()).is_equal(36)
	for anchor: Vector3i in field.positions_ly:
		var inside: bool = (
			absi(anchor.x) <= HALF_SLAB_LY.x
			and absi(anchor.y) <= HALF_SLAB_LY.y
			and absi(anchor.z) <= HALF_SLAB_LY.z
		)
		assert_bool(inside).override_failure_message("anchor %s outside" % anchor).is_true()
	for first: int in field.positions_ly.size():
		for second: int in range(first + 1, field.positions_ly.size()):
			var squared: int = AddressRule.squared_distance(
				field.positions_ly[first], field.positions_ly[second]
			)
			var message: String = "anchors %d and %d too close" % [first, second]
			(
				assert_bool(squared >= MIN_SPACING_LY * MIN_SPACING_LY)
				. override_failure_message(message)
				. is_true()
			)


## CAIRN is the home Ring within 3,000 ly of the centre, and its origin glyph is not among
## its seven nearest anchors, so its own address is well formed.
func test_cairn_placement_and_origin() -> void:
	var field: AnchorFieldDef = _registry.get_def(&"anchors_home") as AnchorFieldDef
	var cairn: WorldDef = _registry.get_def(&"world_cairn") as WorldDef
	assert_bool(cairn.is_home).is_true()
	assert_that(cairn.name_key).is_equal(&"WORLD_CAIRN_NAME")
	assert_int(cairn.ring_status).is_equal(WorldDef.RingStatus.OPEN)
	assert_float(AddressRule.distance_ly(cairn.position_ly, Vector3i.ZERO)).is_less(
		CAIRN_MAX_DISTANCE_LY
	)
	assert_bool(cairn.origin_glyph >= 0 and cairn.origin_glyph < 36).is_true()
	var nearest: Array[int] = AddressRule.nearest_anchors(
		cairn.position_ly, field.positions_ly, -1, 7
	)
	assert_array(nearest).not_contains([cairn.origin_glyph])
	var address: GateAddress = AddressRule.address_of(
		cairn.position_ly, field.positions_ly, cairn.origin_glyph
	)
	assert_bool(address.is_well_formed()).is_true()


## The generator rebuilds the committed anchor field and CAIRN byte for byte, the same every
## time, and never produces a glyph file.
func test_generator_reproduces_the_committed_files() -> void:
	var generator: GDScript = load(GENERATOR) as GDScript
	var first: Dictionary = generator.call("generated_files")
	var second: Dictionary = generator.call("generated_files")
	assert_dict(first).is_equal(second)
	assert_int(first.size()).is_equal(2)
	for path: String in first:
		assert_bool(path.begins_with(GLYPH_DIR)).is_false()
		var committed: String = FileAccess.get_file_as_string(path)
		assert_str(committed).override_failure_message(path).is_equal(first[path])


## Returns the text of [param key] in locale [param locale] (0 = en, 1 = pt_BR).
func _text(key: StringName, locale: int) -> String:
	if not _strings.has(key):
		return ""
	return _strings[key][locale + 1]


func _read_table() -> Dictionary[String, PackedStringArray]:
	var rows: Dictionary[String, PackedStringArray] = {}
	var file: FileAccess = FileAccess.open(GLYPH_TABLE, FileAccess.READ)
	while file != null and not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() > 1:
			rows[row[0]] = row
	return rows
