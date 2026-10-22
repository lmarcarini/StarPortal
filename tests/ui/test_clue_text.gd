## Tests for ClueText: every argument prefix, missing arguments and both languages.
## Bible: gate-and-address-spec.md#clue-types-and-reliability
extends GdUnitTestSuite

const EN_NAMES: Array[String] = ["Heron", "Anvil", "Kettle"]
const PT_NAMES: Array[String] = ["Garça", "Bigorna", "Chaleira"]
const EN_PICTURES: Array[String] = ["a tall bird", "a heavy block", "a round pot"]
const PT_PICTURES: Array[String] = ["uma ave alta", "um bloco pesado", "um pote redondo"]


func test_glyph_argument_shows_the_glyph_name() -> void:
	var text: String = ClueText.format("Glyph {glyph_a}.", {"glyph_a": 1}, EN_NAMES, EN_PICTURES)
	assert_str(text).is_equal("Glyph Anvil.")


func test_picture_argument_shows_the_picture_description() -> void:
	var text: String = ClueText.format(
		"It looks like {picture}", {"picture": 2}, EN_NAMES, EN_PICTURES
	)
	assert_str(text).is_equal("It looks like a round pot")


func test_address_argument_joins_glyph_names() -> void:
	var text: String = ClueText.format("{address}", {"address": "0-2-1"}, EN_NAMES, EN_PICTURES)
	assert_str(text).is_equal("Heron · Kettle · Anvil")


func test_other_arguments_are_shown_as_given() -> void:
	var args: Dictionary = {"seal_a": 4, "world": "P3X-118", "count": 7}
	var text: String = ClueText.format("{world}: {count} at {seal_a}", args, EN_NAMES, EN_PICTURES)
	assert_str(text).is_equal("P3X-118: 7 at 4")


func test_text_without_placeholders_is_unchanged() -> void:
	assert_str(ClueText.format("Plain.", {"a": 1}, EN_NAMES, EN_PICTURES)).is_equal("Plain.")
	assert_str(ClueText.format("", {}, EN_NAMES, EN_PICTURES)).is_empty()


func test_a_repeated_placeholder_is_filled_each_time() -> void:
	var text: String = ClueText.format(
		"{glyph_a}, {glyph_a}", {"glyph_a": 0}, EN_NAMES, EN_PICTURES
	)
	assert_str(text).is_equal("Heron, Heron")


## A missing argument stays visible as "{name}" and the rest is still filled.
func test_missing_argument_stays_visible() -> void:
	var text: String = ClueText.format(
		"{glyph_a} then {glyph_b}", {"glyph_a": 0}, EN_NAMES, EN_PICTURES
	)
	assert_str(text).is_equal("Heron then {glyph_b}")


## An unusable value (out of range, wrong type, bad address) stays visible too.
func test_unusable_values_stay_visible() -> void:
	var cases: Array[Dictionary] = [
		{"glyph_a": 9},
		{"glyph_a": -1},
		{"glyph_a": "x"},
		{"address_a": "0-x"},
		{"address_a": "0-7"},
		{"address_a": 3},
		{"picture_a": 3},
	]
	for args: Dictionary in cases:
		var name: String = str(args.keys()[0])
		var text: String = ClueText.format("{%s}" % name, args, EN_NAMES, EN_PICTURES)
		assert_str(text).override_failure_message(str(args)).is_equal("{%s}" % name)


## The same template reads in both languages, from fixture translations.
func test_templates_in_both_languages() -> void:
	var english: String = "{glyph_a} at seal {seal_a}: {picture_a}"
	var portuguese: String = "{glyph_a} no selo {seal_a}: {picture_a}"
	var args: Dictionary = {"glyph_a": 0, "seal_a": 5, "picture_a": 0}
	assert_str(ClueText.format(english, args, EN_NAMES, EN_PICTURES)).is_equal(
		"Heron at seal 5: a tall bird"
	)
	assert_str(ClueText.format(portuguese, args, PT_NAMES, PT_PICTURES)).is_equal(
		"Garça no selo 5: uma ave alta"
	)
