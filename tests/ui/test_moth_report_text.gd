## Tests for the World Report and MOTH texts: every biome template, life, structures and sky key,
## each M1.5 world's Look around and every target's Close look resolve in en and pt_BR (the fit is
## tested in test_moth_screen_layout and test_archive_worlds); procedural texts are stable;
## STILLWATER's Look around carries the line that marks the circled Chair as its own mark; the
## finished-scan text follows the last scan and the report lines show only known facts.
## Bible: docs/content/m3-beyond-the-ring.md sections 2 and 3
extends GdUnitTestSuite

const LOCALES: Array[String] = ["en", "pt_BR"]
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


func _assert_resolves(key: StringName) -> void:
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		var text: String = String(TranslationServer.translate(key))
		assert_str(text).override_failure_message("%s %s missing" % [locale, key]).is_not_equal(
			String(key)
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
			_assert_resolves(key)
	for facts: WorldFacts in _procedural_facts():
		for key: StringName in MothReportText.look_around_keys(facts):
			_assert_resolves(key)
		_assert_resolves(MothReportText.sky_key(facts))
		for target: WorldTarget in facts.targets:
			_assert_resolves(MothReportText.close_look_key(target))
	for sky: int in WorldDef.SkyColour.size():
		var sky_facts := WorldFacts.new()
		sky_facts.sky = sky as WorldDef.SkyColour
		_assert_resolves(MothReportText.sky_key(sky_facts))


func test_every_m15_world_has_its_look_around_and_close_looks() -> void:
	for world_id: StringName in MothReportText.AUTHORED_LOOK_KEYS:
		var facts: WorldFacts = _facts(world_id)
		assert_array(MothReportText.look_around_keys(facts)).is_equal(
			[MothReportText.AUTHORED_LOOK_KEYS[world_id]]
		)
		_assert_resolves(MothReportText.AUTHORED_LOOK_KEYS[world_id])
		assert_array(facts.targets).is_not_empty()
		for target: WorldTarget in facts.targets:
			_assert_resolves(MothReportText.close_look_key(target))


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


func test_finished_text_follows_the_last_scan_and_report_lines_only_known_facts() -> void:
	TranslationServer.set_locale("en")
	var facts: WorldFacts = _facts(&"world_stillwater")
	var run := MothRun.create(&"world_stillwater")
	assert_str(MothReportText.finished_text(run, facts)).is_empty()
	run.done.append(MothRun.scan_key(MothRules.Scan.LOOK_AROUND))
	assert_str(MothReportText.finished_text(run, facts)).contains(CHAIR_LINE)
	run.done.append(MothRun.scan_key(MothRules.Scan.CLOSE_LOOK, &"iron_object"))
	assert_str(MothReportText.finished_text(run, facts)).is_equal(
		tr(&"MOTH_CLOSE_STILLWATER_IRON_OBJECT")
	)
	var report := WorldReport.new()
	assert_str(MothReportText.report_lines(facts, report)).is_empty()
