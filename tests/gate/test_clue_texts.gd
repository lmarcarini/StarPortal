## Tests for the text a generated clue points at: argument names by kind, and keys in
## localization/clues.csv in both locales with matching placeholders.
## Bible: gate-and-address-spec.md#clue-types-and-reliability
extends GdUnitTestSuite

const Fixtures := preload("res://tests/gate/clue_fixture.gd")
const CSV_PATH: String = "res://localization/clues.csv"
const TARGET_COUNT: int = 60
const ARG_NAMES: Dictionary = {
	"CLUE_FRAGMENT_ONE": ["glyph", "seal"],
	"CLUE_FRAGMENT_TWO": ["glyph_a", "glyph_b", "seal_a", "seal_b"],
	"CLUE_PICTORIAL": ["picture", "seal"],
	"CLUE_SKY_CHART": [],
	"CLUE_ORDINAL": ["glyph_a", "glyph_b"],
	"CLUE_NEIGHBOUR": ["address", "count", "world"],
}

var _rows: Dictionary = {}
var _clues: Array[ClueRecord] = []


func before() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 3:
			_rows[row[0]] = row
	var galaxy: GalaxyCatalogue = Fixtures.galaxy()
	var targets: Array[StringName] = Fixtures.targets(galaxy, TARGET_COUNT)
	for index: int in targets.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + index
		_clues.append_array(
			ClueGenerator.generate_dossier(targets[index], galaxy, rng, ClueSetParams.new())
		)


## Every kind and variant that can be generated appears, and every key and source exists in
## both locales, non-empty, with the same placeholders in both.
func test_keys_exist_in_both_locales_with_matching_placeholders() -> void:
	var kinds: Dictionary = {}
	for clue: ClueRecord in _clues:
		kinds[clue.kind] = true
		for key: StringName in [clue.text_key, clue.source_key]:
			assert_bool(_rows.has(String(key))).override_failure_message(String(key)).is_true()
	assert_int(kinds.size()).is_equal(ClueRecord.KIND_NAMES.size())
	for key: String in _rows:
		var row: PackedStringArray = _rows[key]
		assert_str(row[1]).override_failure_message(key).is_not_empty()
		assert_str(row[2]).override_failure_message(key).is_not_empty()
		var english: Array[String] = Fixtures.placeholders(row[1])
		var portuguese: Array[String] = Fixtures.placeholders(row[2])
		assert_array(portuguese).override_failure_message(key).is_equal(english)


## Every variant key exists (two per kind, fragments have two per count), and its placeholders
## are exactly the argument names of its kind.
func test_variants_and_placeholders_follow_the_argument_names() -> void:
	for base: String in ARG_NAMES:
		for variant: String in ClueCommon.VARIANTS:
			var key: String = "%s_%s" % [base, variant]
			assert_bool(_rows.has(key)).override_failure_message(key).is_true()
			var names: Array[String] = Fixtures.placeholders(str(_rows[key][1]))
			assert_array(names).override_failure_message(key).is_equal(ARG_NAMES[base])


## Generated text arguments carry exactly the names their text key uses, with typed values.
func test_generated_args_follow_the_naming_rule() -> void:
	for clue: ClueRecord in _clues:
		var base: String = String(clue.text_key).left(-2)
		assert_bool(ARG_NAMES.has(base)).override_failure_message(base).is_true()
		var names: Array = clue.text_args.keys()
		names.sort()
		assert_array(names).is_equal(ARG_NAMES[base])
		(
			assert_array(ClueRecord.validate_dict(_saved(clue)))
			. override_failure_message(str(clue.text_args))
			. is_empty()
		)


func _saved(clue: ClueRecord) -> Dictionary:
	clue.id = &"clue_0001"
	clue.dossier_id = &"dossier_0001"
	return clue.to_dict()
