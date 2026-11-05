## Tests for the month-end Log entry: every report line in en and pt_BR, and warnings.
## Bible: docs/content/m26-staff-and-money.md section 5
extends GdUnitTestSuite

var _locale: String = ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func _entry_line(locale: String) -> String:
	TranslationServer.set_locale(locale)
	var game: GameState = ConstructionFixture.grown()
	game.clock.tick = 31 * 1440
	game.budget.funds_k = 2390
	game.research.done.assign(
		[&"excavation_survey", &"lift_shaft", &"second_plant", &"bank_array", &"field_engineering"]
	)
	MonthEnd.close(game, 3000, 270)
	var entries: Array[LogEntry] = LogRules.entries_for(&"month_report_filed", [2026, 2], game, 1)
	assert_int(game.research.done.size()).is_equal(5)
	assert_int(entries.size()).is_equal(1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(entries[0].to_dict()))
	assert_array(LogEntry.validate_dict(data)).is_empty()
	return ArchiveLogRow.line_for(LogEntry.from_dict(data), game)


func test_month_entry_lines_in_english() -> void:
	var lines: PackedStringArray = _entry_line("en").split("\n")
	(
		assert_array(Array(lines))
		. is_equal(
			[
				"Month-end report: Confidence 50 → 65",
				"Allocation: +$3,000k",
				"Room upkeep: -$270k",
				"Salaries (5 people): -$145k",
				"Balance: $2,390k → $4,975k",
				"Committee Confidence: 50 → 65",
				"Research finished (5) +15",
				"Reports filed (1 analyst) +1",
				"Within budget +2",
				"Capped at +15 a month -3",
				"Next allocation: $3,450k",
			]
		)
	)


## Every line of a report holding every cause, the review and months in the red, in both
## locales: non-empty, no raw key or unfilled placeholder, and different from English.
func test_every_line_is_translated_in_both_locales() -> void:
	var report := _full_report()
	TranslationServer.set_locale("en")
	var english: PackedStringArray = MonthReportText.lines(report, null)
	TranslationServer.set_locale("pt_BR")
	var portuguese: PackedStringArray = MonthReportText.lines(report, null)
	assert_int(portuguese.size()).is_equal(english.size())
	assert_int(english.size()).is_equal(1 + 4 + 1 + ConfidenceRules.CAUSES.size() + 1 + 1 + 1)
	for index: int in english.size():
		for line: String in [english[index], portuguese[index]]:
			assert_str(line).is_not_empty()
			(
				assert_bool(line.contains("MONTH_") or line.contains("{"))
				. override_failure_message(line)
				. is_false()
			)
		assert_str(portuguese[index]).is_not_equal(english[index])
	for reason: StringName in MonthReportText.WARNING_KEYS:
		TranslationServer.set_locale("en")
		var line_en: String = MonthReportText.warning_line(reason, 3)
		TranslationServer.set_locale("pt_BR")
		var line_pt: String = MonthReportText.warning_line(reason, 3)
		assert_bool(line_en.contains("COMMITTEE_") or line_pt.contains("COMMITTEE_")).is_false()
		assert_str(line_pt).is_not_equal(line_en)


func _full_report() -> MonthReport:
	var report := MonthReport.blank()
	for index: int in report.amounts.size():
		report.amounts[index] = index + 1
		report.counts[index] = 2
	report.locked_worlds = [&"world_sill"]
	report.surveyed_worlds = [&"world_sill"]
	report.review = ConfidenceRules.PLEASED
	report.grant_k = 1000
	report.months_in_red = 1
	report.people = 2
	return report


func test_warning_line() -> void:
	TranslationServer.set_locale("en")
	var game: GameState = ConstructionFixture.grown()
	game.committee.months_in_red = 3
	var entries: Array[LogEntry] = LogRules.entries_for(
		&"committee_warning", [&"red_months"], game, 1
	)
	assert_str(ArchiveLogRow.line_for(entries[0], game)).starts_with("Warning: 3 month-ends")
