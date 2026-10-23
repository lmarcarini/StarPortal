## Tests for DocumentDef: it loads from .tres fixtures with every field, and the Registry rejects a
## pair_id or world_id that names nothing or the wrong kind of definition, and answer_glyphs that
## are not seven distinct glyphs other than CAIRN's origin. Each test loads a fresh Registry.
## Bible: technical-architecture.md#data-model, gate-and-address-spec.md#where-addresses-come-from
extends GdUnitTestSuite

const RegistryScript := preload("res://src/content/registry.gd")
const FIXTURES: String = "res://tests/content/fixtures/"

var _registry: RegistryScript


func before_test() -> void:
	_registry = auto_free(RegistryScript.new())


func _load(fixture: String) -> Array[String]:
	var errors: Array[String] = _registry.load_all(FIXTURES + fixture).value
	return errors


## The errors that mention definition [param id].
func _errors_of(errors: Array[String], id: String) -> Array[String]:
	var found: Array[String] = []
	for error: String in errors:
		if error.contains("/%s.tres:" % id):
			found.append(error)
	return found


## A valid set of a paired note and rubbing and a dossier loads with no errors and every field.
func test_valid_documents_load_with_every_field() -> void:
	assert_array(_load("documents")).is_empty()
	var note: DocumentDef = _registry.get_def(&"doc_survey_note")
	assert_int(note.kind).is_equal(DocumentDef.Kind.NOTE)
	assert_str(String(note.title_key)).is_equal("DOC_SURVEY_NOTE_TITLE")
	assert_str(String(note.body_key)).is_equal("DOC_SURVEY_NOTE_BODY")
	assert_str(String(note.source_key)).is_equal("DOC_SOURCE_SURVEY_1958")
	assert_str(String(note.world_id)).is_equal("world_cairn")
	assert_str(String(note.pair_id)).is_equal("doc_survey_rubbing")
	assert_array(Array(note.answer_glyphs)).is_equal([0, 13, 7, 21, 30, 2, 18])
	assert_object(note.image).is_null()
	var rubbing: DocumentDef = _registry.get_def(&"doc_survey_rubbing")
	assert_int(rubbing.kind).is_equal(DocumentDef.Kind.IMAGE)
	assert_str(String(rubbing.body_key)).is_empty()
	assert_object(rubbing.image).is_instanceof(Texture2D)
	assert_bool(rubbing.answer_glyphs.is_empty()).is_true()
	var dossier: DocumentDef = _registry.get_def(&"doc_dossier")
	assert_int(dossier.kind).is_equal(DocumentDef.Kind.DOSSIER)
	assert_array(dossier.get_references()).is_empty()
	assert_int(_registry.get_all_of(DocumentDef).size()).is_equal(6)


## get_references() names the world and the pair when set.
func test_references_are_world_and_pair() -> void:
	var document := DocumentDef.new()
	assert_array(document.get_references()).is_empty()
	document.world_id = &"world_a"
	document.pair_id = &"doc_b"
	document.arrival_world_id = &"world_c"
	assert_array(document.get_references()).is_equal([&"world_a", &"doc_b", &"world_c"])


## Every bad document is reported, and only the bad ones; the valid world is not.
func test_bad_documents_are_rejected() -> void:
	var errors: Array[String] = _load("documents_bad")
	var expected: Dictionary[String, String] = {
		"bad_pair_missing": 'missing id "ghost_doc"',
		"bad_world_missing": 'missing id "ghost_world"',
		"bad_pair_not_document": "is not a DocumentDef",
		"bad_world_not_world": "is not a WorldDef",
		"bad_pair_self": "names the document itself",
		"bad_answer_six": "has 6 glyphs, not 7",
		"bad_answer_origin": "CAIRN's origin glyph 5",
		"bad_answer_repeat": "repeats glyph 1",
		"bad_answer_range": "is 36, not a glyph",
		"bad_arrival_no_world": "needs an arrival_world_id",
		"bad_arrival_world_missing": 'missing id "ghost_arrival"',
	}
	for id: String in expected:
		var found: Array[String] = _errors_of(errors, id)
		assert_int(found.size()).override_failure_message(id + str(errors)).is_equal(1)
		assert_str(found[0]).contains(expected[id])
	assert_int(errors.size()).override_failure_message(str(errors)).is_equal(expected.size())
	assert_bool(_registry.has_def(&"world_cairn")).is_true()


## An answer cannot be checked without a home world, so it is reported.
func test_answer_without_home_world_is_reported() -> void:
	var errors: Array[String] = _load("documents_no_home")
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("no home world")


## answer_errors() accepts seven distinct glyphs that avoid the origin.
func test_answer_errors_accepts_a_good_answer() -> void:
	var glyphs := PackedInt32Array([35, 0, 1, 2, 3, 4, 6])
	assert_array(DocumentDef.answer_errors(glyphs, 5)).is_empty()
	assert_int(DocumentDef.answer_errors(glyphs, 35).size()).is_equal(1)
	(
		assert_int(DocumentDef.answer_errors(PackedInt32Array([-1, 0, 1, 2, 3, 4, 6]), 5).size())
		. is_equal(1)
	)


## The real content has no broken documents (none yet, but any added must pass).
func test_real_content_has_no_document_errors() -> void:
	var errors: Array[String] = _registry.load_all().value
	assert_array(errors).is_empty()
