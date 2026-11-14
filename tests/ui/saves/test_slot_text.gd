## Save list rows: name, in-game date, real date and version; an unusable slot says why.
## Bible: docs/bible/technical-architecture.md#save-and-load (M4.6-02)
extends GdUnitTestSuite


func test_usable_row() -> void:
	var entry: Dictionary = {
		"slot": &"quicksave",
		"tick": 0,
		"saved_at_unix": 1700000000,
		"format_version": 18,
		"error": &""
	}
	var text: String = SlotText.row(entry)
	assert_str(text).starts_with("quicksave · ")
	assert_str(text).contains(GateRoomFormat.date_time(0))
	assert_str(text).ends_with("v18")


func test_unusable_row_says_why() -> void:
	var entry: Dictionary = {
		"slot": &"old",
		"tick": -1,
		"saved_at_unix": 1700000000,
		"format_version": -1,
		"error": &"newer_format_version"
	}
	assert_str(SlotText.row(entry)).contains(SlotText.reason(&"newer_format_version"))
	assert_str(SlotText.reason(&"anything")).is_equal(TranslationServer.translate(&"SAVES_BROKEN"))
