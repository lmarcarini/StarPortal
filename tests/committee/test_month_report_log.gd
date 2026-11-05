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
	for index: int in 4:
		game.research.done.append(StringName("p%d" % index))
	MonthEnd.close(game, 3000, 270)
	var entries: Array[LogEntry] = LogRules.entries_for(&"month_report_filed", [2026, 2], game, 1)
	assert_int(entries.size()).is_equal(1)
	var data: Dictionary = JSON.parse_string(JSON.stringify(entries[0].to_dict()))
	assert_array(LogEntry.validate_dict(data)).is_empty()
	return ArchiveLogRow.line_for(LogEntry.from_dict(data), game)


func test_month_entry_shows_every_line_in_english() -> void:
	var lines: PackedStringArray = _entry_line("en").split("\n")
	assert_str(lines[0]).is_equal("Month-end report: Confidence 50 → 65")
	(
		assert_array(Array(lines))
		. contains(
			[
				"Allocation: +$3,000k",
				"Room upkeep: -$270k",
				"Research finished (4) +12",
				"Reports filed (1 analyst) +1",
				"Within budget +2",
				"Next allocation: $3,450k",
			]
		)
	)


func test_month_entry_in_portuguese() -> void:
	var text: String = _entry_line("pt_BR")
	assert_str(text).contains("Relatório do mês: Confiança 50 → 65")
	assert_str(text).contains("Pesquisas concluídas (4) +12")
	assert_str(text).contains("Próxima verba: $3.450k".replace(".", ","))


func test_warning_line() -> void:
	TranslationServer.set_locale("en")
	var game: GameState = ConstructionFixture.grown()
	game.committee.months_in_red = 3
	var entries: Array[LogEntry] = LogRules.entries_for(
		&"committee_warning", [&"red_months"], game, 1
	)
	assert_str(ArchiveLogRow.line_for(entries[0], game)).starts_with("Warning: 3 month-ends")
