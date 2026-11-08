## Tests for the World Report and MOTH texts: every biome template, life, structures and sky key,
## each M1.5 world's Look around and every target's Close look resolve in en and pt_BR and fit
## the report and scan screen; procedural texts are stable; STILLWATER's Look around carries the
## line that marks the circled Chair as its own mark.
## Bible: docs/content/m3-beyond-the-ring.md sections 2 and 3
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
## Longest text the scan screen and report show without crowding, in characters.
const MAX_LOOK_AROUND: int = 300
const MAX_LINE: int = 120
const CHAIR_LINE: String = (
	"On the flat stone before the Ring, one mark cut alone: a tall back leaning away from a flat"
	+ " seat."
)

var _locale: String = ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func _facts(world_id: StringName) -> WorldFacts:
	return WorldFacts.from_def(Registry.get_def(world_id) as WorldDef)


func _assert_resolves(key: StringName, max_length: int) -> void:
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		var text: String = String(TranslationServer.translate(key))
		assert_str(text).override_failure_message("%s %s missing" % [locale, key]).is_not_equal(
			String(key)
		)
		(
			assert_int(text.length())
			. override_failure_message("%s %s too long" % [locale, key])
			. is_less_equal(max_length)
		)


func _procedural_facts() -> Array[WorldFacts]:
	var all: Array[WorldFacts] = []
	for index: int in 400:
		all.append(WorldFactRules.derive(StringName("world_p%d" % index), index % 7 == 0))
	return all


func test_every_biome_life_structures_and_sky_key_resolves() -> void:
	for biome: int in WorldDef.Biome.size():
		for variant: int in MothReportText.BIOME_VARIANTS:
			var key := StringName(
				"REPORT_BIOME_%s_%d" % [WorldDef.Biome.keys()[biome], variant + 1]
			)
			_assert_resolves(key, MAX_LINE)
	for facts: WorldFacts in _procedural_facts():
		for key: StringName in MothReportText.look_around_keys(facts):
			_assert_resolves(key, MAX_LINE)
		_assert_resolves(MothReportText.sky_key(facts), MAX_LINE)
		for target: WorldTarget in facts.targets:
			_assert_resolves(MothReportText.close_look_key(target), MAX_LINE)
	for sky: int in WorldDef.SkyColour.size():
		var sky_facts := WorldFacts.new()
		sky_facts.sky = sky as WorldDef.SkyColour
		_assert_resolves(MothReportText.sky_key(sky_facts), MAX_LINE)


func test_every_m15_world_has_its_look_around_and_close_looks() -> void:
	for world_id: StringName in MothReportText.AUTHORED_LOOK_KEYS:
		var facts: WorldFacts = _facts(world_id)
		assert_array(MothReportText.look_around_keys(facts)).is_equal(
			[MothReportText.AUTHORED_LOOK_KEYS[world_id]]
		)
		_assert_resolves(MothReportText.AUTHORED_LOOK_KEYS[world_id], MAX_LOOK_AROUND)
		assert_array(facts.targets).is_not_empty()
		for target: WorldTarget in facts.targets:
			_assert_resolves(MothReportText.close_look_key(target), MAX_LINE)


func test_stillwater_lists_the_iron_object_and_names_the_chair_mark() -> void:
	var facts: WorldFacts = _facts(&"world_stillwater")
	var iron: WorldTarget = facts.find_target(&"iron_object")
	assert_object(iron).is_not_null()
	assert_bool(iron.is_object).is_true()
	TranslationServer.set_locale("en")
	assert_str(MothReportText.look_around(facts)).contains(CHAIR_LINE)


func test_procedural_texts_are_stable() -> void:
	var first: WorldFacts = WorldFactRules.derive(&"world_p42", false)
	var again: WorldFacts = WorldFactRules.derive(&"world_p42", false)
	assert_array(MothReportText.look_around_keys(first)).is_equal(
		MothReportText.look_around_keys(again)
	)
