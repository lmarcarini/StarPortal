## Tests for the Committee's words and Log lines: the top bar readout (whole Confidence and
## today's drift), its tooltip (value with one decimal, why, the last causes), and the Log
## entries of reports filed, the commendation and a warning, in English.
## Bible: docs/content/m27-daily-rhythm.md sections 2 and 5
extends GdUnitTestSuite

var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_real_locale)


func test_readout_shows_whole_confidence_and_drift() -> void:
	assert_str(ConfidenceReadout.readout_text(61, -1)).is_equal("Conf. 61 -0.1")
	assert_str(ConfidenceReadout.readout_text(38, -2)).is_equal("Conf. 38 -0.2")
	assert_str(ConfidenceReadout.readout_text(50, 0)).is_equal("Conf. 50")
	assert_str(CommitteeText.one_decimal(614)).is_equal("61.4")


func test_tooltip_lists_drift_and_newest_causes() -> void:
	var game: GameState = ConstructionFixture.grown()
	game.committee.confidence = 614
	for index: int in 4:
		game.research.done.append(StringName("project_%d" % index))
		ConfidenceEvents.credit_new(game)
	var lines: PackedStringArray = ConfidenceReadout.tooltip_for(game).split("\n")
	assert_int(lines.size()).is_equal(4)
	assert_str(lines[0]).is_equal(
		"Committee Confidence 73.4 (0–100). Today -0.1: settling toward 50."
	)
	assert_str(lines[1]).is_equal("Research finished: project_3  +3")
	assert_bool(ConfidenceReadout.is_warning(game)).is_false()
	game.committee.days_in_red = 7
	assert_bool(ConfidenceReadout.is_warning(game)).is_true()


func test_log_lines_of_committee_entries() -> void:
	var game: GameState = ConstructionFixture.grown()
	game.committee.days_in_red = 14
	var lines: Array[String] = []
	for item: Array in [
		[&"reports_filed", [2]],
		[&"committee_commendation", [1000]],
		[&"committee_warning", [&"red_days"]]
	]:
		var event_name: StringName = item[0]
		var args: Array = item[1]
		for entry: LogEntry in LogRules.entries_for(event_name, args, game, 5):
			assert_str(String(entry.kind)).is_equal("committee")
			lines.append(CommitteeText.log_line(entry.args))
	(
		assert_array(lines)
		. is_equal(
			[
				"Reports filed (2 analysts): Committee Confidence +2.",
				"Committee commendation: $1,000k.",
				"14 days in the red. The Committee is concerned.",
			]
		)
	)
