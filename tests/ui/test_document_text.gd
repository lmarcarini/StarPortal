## Tests for DocumentText, the Archive's pure text helpers: kind keys, titles and sources with
## fallbacks, the arrival line, the body's paragraphs and emphasis, and the list and
## "Read with…" orders.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#the-opening-puzzle
extends GdUnitTestSuite

var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_real_locale)


func test_kind_keys() -> void:
	assert_str(String(DocumentText.kind_key(DocumentDef.Kind.DOSSIER))).is_equal(
		"ARCHIVE_KIND_DOSSIER"
	)
	assert_str(String(DocumentText.kind_key(DocumentDef.Kind.ARTEFACT))).is_equal(
		"ARCHIVE_KIND_ARTEFACT"
	)
	assert_str(String(DocumentText.kind_key(99))).is_equal("ARCHIVE_KIND_NOTE")
	assert_int(DocumentText.KIND_KEYS.size()).is_equal(DocumentDef.Kind.size())


func test_title_and_source_fall_back() -> void:
	var def := DocumentDef.new()
	assert_str(DocumentText.title(def)).is_equal("Untitled document")
	assert_str(DocumentText.title(null)).is_equal("Untitled document")
	assert_str(DocumentText.source_line(def)).is_empty()
	def.source_key = &"ARCHIVE_KIND_LOG"
	assert_str(DocumentText.source_line(def)).is_equal("Source: Log")


func test_received_line() -> void:
	assert_str(DocumentText.received_line(0)).is_equal("Received 2026-01-01 00:00")
	var tick: int = TimeMath.TICKS_PER_DAY * 31 + 90
	assert_str(DocumentText.received_line(tick)).is_equal("Received 2026-02-01 01:30")
	TranslationServer.set_locale("pt_BR")
	assert_str(DocumentText.received_line(0)).is_equal("Recebido em 2026-01-01 00:00")


func test_body_paragraphs_and_emphasis() -> void:
	var text: String = "  First line\r\nsame paragraph  \n\n \n\nSecond *soft* and **loud** [b]x[/b]\n"
	assert_str(DocumentText.body_bbcode(text)).is_equal(
		"First line\nsame paragraph\n\nSecond [i]soft[/i] and [b]loud[/b] [lb]b]x[lb]/b]"
	)
	assert_str(DocumentText.body_bbcode("")).is_empty()
	assert_str(DocumentText.body_bbcode("a * b")).is_equal("a * b")


func test_orders() -> void:
	var received: Array[StringName] = [&"a", &"b", &"c", &"d"]
	assert_array(DocumentText.newest_first(received)).is_equal([&"d", &"c", &"b", &"a"])
	assert_array(received).is_equal([&"a", &"b", &"c", &"d"])
	assert_array(DocumentText.read_with_order(&"c", &"a", received)).is_equal([&"a", &"d", &"b"])
	assert_array(DocumentText.read_with_order(&"c", &"z", received)).is_equal([&"d", &"b", &"a"])
	assert_array(DocumentText.read_with_order(&"c", &"", received)).is_equal([&"d", &"b", &"a"])
	var alone: Array[StringName] = [&"c"]
	assert_array(DocumentText.read_with_order(&"c", &"", alone)).is_empty()
