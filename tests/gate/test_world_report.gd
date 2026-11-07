## Tests for WorldReport and WorldReportRules: every fact starts unknown at confidence NONE,
## confidence only goes up, and the true threat never shows unnarrowed.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (World Report fields)
extends GdUnitTestSuite

const C := WorldReport.Confidence
const T := WorldDef.Threat


## A new report knows nothing: every fact at NONE, categories UNKNOWN, no targets.
func test_every_fact_starts_unknown() -> void:
	var report := WorldReport.new()
	var facts := WorldFactRules.derive(&"world_0007", false)
	for fact: int in WorldReport.Fact.size():
		assert_int(report.confidence_of(fact)).is_equal(C.NONE)
		assert_bool(WorldReportRules.is_known(report, fact)).is_false()
	for fact: WorldReport.Fact in [
		WorldReport.Fact.BIOHAZARD, WorldReport.Fact.LIFE, WorldReport.Fact.STRUCTURES
	]:
		assert_int(WorldReportRules.shown_category(facts, report, fact)).is_zero()
	assert_array(WorldReportRules.shown_targets(facts, report)).is_empty()
	var reading := WorldReportRules.threat_reading(&"world_0007", facts.threat, C.NONE)
	assert_int(reading.low).is_equal(T.UNKNOWN)
	assert_int(reading.high).is_equal(T.UNKNOWN)


## Raising a fact shows its true value; a lower or equal confidence changes nothing.
func test_raise_only_goes_up() -> void:
	var report := WorldReport.new()
	var facts := WorldFactRules.derive(&"world_0007", false)
	assert_bool(report.raise(WorldReport.Fact.LIFE, C.FAIR, &"moth", 10)).is_true()
	assert_bool(report.raise(WorldReport.Fact.LIFE, C.POOR, &"pole_camera", 20)).is_false()
	assert_bool(report.raise(WorldReport.Fact.LIFE, C.FAIR, &"moth", 30)).is_false()
	assert_int(report.entry_of(WorldReport.Fact.LIFE).tick).is_equal(10)
	var shown := WorldReportRules.shown_category(facts, report, WorldReport.Fact.LIFE)
	assert_int(shown).is_equal(facts.life)


## POOR is always a two-step range holding the true threat; FAIR and GOOD are exact.
func test_threat_never_unnarrowed() -> void:
	for index: int in 300:
		var id := StringName("world_%04d" % index)
		for threat: T in [T.LOW, T.MED, T.HIGH]:
			var poor := WorldReportRules.threat_reading(id, threat, C.POOR)
			assert_bool(poor.is_exact()).is_false()
			assert_int(poor.high - poor.low).is_equal(1)
			assert_bool(threat >= poor.low and threat <= poor.high).is_true()
			for level: C in [C.FAIR, C.GOOD]:
				var exact := WorldReportRules.threat_reading(id, threat, level)
				assert_bool(exact.is_exact()).is_true()
				assert_int(exact.low).is_equal(threat)


## A report survives a save round trip, and bad data is reported.
func test_round_trip_and_validation() -> void:
	var report := WorldReport.new()
	report.raise(WorldReport.Fact.THREAT, C.POOR, &"pole_camera", 5)
	report.raise(WorldReport.Fact.TARGETS, C.FAIR, &"moth", 9)
	var data: Dictionary = JSON.parse_string(JSON.stringify(report.to_dict()))
	assert_array(WorldReport.validate_dict("w", data)).is_empty()
	assert_dict(WorldReport.from_dict(data).to_dict()).is_equal(report.to_dict())
	var bad: Dictionary = {
		"smell": {},
		"life": {"confidence": "none", "source": "", "tick": -1},
		"threat": 3,
	}
	assert_int(WorldReport.validate_dict("w", bad).size()).is_equal(5)
