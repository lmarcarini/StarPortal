## Tests for transcripts in the Archive (M4-14): a finished or cut-off conversation is listed
## unread among the documents, rendered from its path with the current texts ("You: ..." for
## answers, "(signal lost)" when cut off), and opens in the reader.
## Bible: docs/content/m4-core-systems.md section 3 (Transcripts)
extends GdUnitTestSuite

const ConversationTests := preload("res://tests/dialog/test_conversation_runner.gd")

var _state: GameState


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = StoryFixture.state()
	_state.conversation_defs[ConversationTests.CONV] = ConversationTests.make_def()


func _finish(choice: int, cut_off: bool) -> TranscriptRecord:
	ConversationRules.start(_state, ConversationTests.CONV, &"wormhole", &"")
	if cut_off:
		ConversationRules.finish(_state, true)
	else:
		for node: StringName in [&"l2", &"l3", &"ask"]:
			ConversationRules.arrive(_state, node)
		ConversationRules.choose(_state, choice)
	return _state.conversations.transcripts[-1]


func test_listed_unread_in_the_archive() -> void:
	var record: TranscriptRecord = _finish(1, false)
	var id: StringName = TranscriptText.archive_id(record.uid)
	assert_bool(_state.archive.has_document(id)).is_true()
	assert_bool(_state.archive.is_read(id)).is_false()
	assert_object(TranscriptText.record_of(_state, id)).is_same(record)
	assert_object(TranscriptText.record_of(_state, &"doc_x")).is_null()
	assert_bool(MarkDocumentReadCommand.create(id).validate(_state).is_ok).is_true()


func test_rendered_from_the_path() -> void:
	var record: TranscriptRecord = _finish(1, false)
	var lines: Array[String] = TranscriptText.lines(_state, record)
	assert_int(lines.size()).is_equal(4)
	assert_str(lines[3]).starts_with("You: ")
	var def: ConversationDef = _state.conversation_defs[ConversationTests.CONV]
	def.node(&"l1").text_key = &"CONV_CLOSE"
	assert_str(TranscriptText.lines(_state, record)[0]).is_equal("Close")
	assert_str(TranscriptText.title(_state, record)).is_equal("faction_kindred, by our wormhole")


func test_cut_off_says_signal_lost() -> void:
	var record: TranscriptRecord = _finish(0, true)
	var lines: Array[String] = TranscriptText.lines(_state, record)
	assert_str(lines[-1]).is_equal("(signal lost)")
	assert_int(lines.size()).is_equal(2)


func test_reader_shows_a_transcript() -> void:
	var record: TranscriptRecord = _finish(1, false)
	var reader: DocumentReader = auto_free(
		(load("res://src/ui/archive/document_reader.tscn") as PackedScene).instantiate()
	)
	add_child(reader)
	var id: StringName = TranscriptText.archive_id(record.uid)
	reader.show_transcript(id, "Title", TranscriptText.lines(_state, record), 0)
	var shown: Array[String] = reader.get_shown_texts()
	assert_str(shown[0]).is_equal("Title")
	assert_str(shown[3]).contains("You: ")
