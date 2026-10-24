## Tests for the validator's document checks: each is fed good data (no problem) and broken
## data (the right line). Bible: gate-and-address-spec.md#puzzle-design-rules,
## technical-architecture.md#testing-and-tooling
extends GdUnitTestSuite

const Fixture := preload("res://tests/gate/galaxy_fixture.gd")
const NEAR_LY := Vector3i(150, 90, 20)

var _anchors: Array[Vector3i] = []
var _home: WorldDef
var _target: WorldDef
var _relay: WorldDef


func before_test() -> void:
	_anchors = Fixture.anchors()
	_home = Fixture.home(_anchors)
	_target = _world(&"world_target", _anchors[_free_anchor(0)] + NEAR_LY)
	_relay = _world(&"world_relay", _anchors[_free_anchor(10)] + NEAR_LY)


func _free_anchor(from: int) -> int:
	return from + 1 if from == _home.origin_glyph else from


func _world(id: StringName, position: Vector3i) -> WorldDef:
	var world := WorldDef.new()
	world.id = id
	world.position_ly = position
	world.origin_glyph = _home.origin_glyph
	return world


func _worlds() -> Array[WorldDef]:
	return [_home, _target, _relay]


func _answer(world: WorldDef, origin: int) -> PackedInt32Array:
	return PackedInt32Array(AddressRule.address_of(world.position_ly, _anchors, origin).coordinates)


func _document(id: StringName, pair: StringName = &"") -> DocumentDef:
	var document := DocumentDef.new()
	document.id = id
	document.world_id = _target.id
	document.answer_glyphs = _answer(_target, _home.origin_glyph)
	document.title_key = &"DOC_T_TITLE"
	document.pair_id = pair
	return document


func test_real_answers_pass_and_a_broken_answer_is_reported() -> void:
	var document: DocumentDef = _document(&"doc_a")
	var documents: Array[DocumentDef] = [document]
	assert_array(ContentCheckDocuments.check_answers(documents, _worlds(), _anchors)).is_empty()
	var broken: PackedInt32Array = document.answer_glyphs.duplicate()
	var first: int = broken[1]
	broken[1] = broken[2]
	broken[2] = first
	document.answer_glyphs = broken
	var errors: Array[String] = ContentCheckDocuments.check_answers(documents, _worlds(), _anchors)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("document doc_a: answer").contains("world_target's address")


func test_an_answer_for_a_world_that_is_not_authored_is_reported() -> void:
	var document: DocumentDef = _document(&"doc_a")
	document.world_id = &"world_nowhere"
	var documents: Array[DocumentDef] = [document]
	assert_array(ContentCheckDocuments.check_answers(documents, _worlds(), _anchors)).contains(
		["document doc_a: answer for world_nowhere, not an authored world"]
	)


func test_a_world_beyond_the_opening_capacity_is_reported() -> void:
	var balance := BalanceConfig.new()
	balance.max_capacitor_banks = 1
	balance.capacitor_bank_capacity_mwh = 100_000.0
	assert_array(ContentCheckDocuments.check_reach(_worlds(), _anchors, balance)).is_empty()
	balance.capacitor_bank_capacity_mwh = 10.0
	var errors: Array[String] = ContentCheckDocuments.check_reach(_worlds(), _anchors, balance)
	assert_int(errors.size()).is_equal(2)
	assert_str(errors[0]).contains("world world_target needs").contains("above the opening's")


func test_missing_locale_text_and_a_stated_energy_are_reported() -> void:
	var documents: Array[DocumentDef] = [_document(&"doc_a")]
	var table: Dictionary[String, PackedStringArray] = {
		"DOC_T_TITLE": PackedStringArray(["Title", "Título"])
	}
	assert_array(ContentCheckDocuments.check_keys(documents, table)).is_empty()
	table["DOC_T_TITLE"] = PackedStringArray(["Title", " "])
	assert_array(ContentCheckDocuments.check_keys(documents, table)).contains(
		["document doc_a: key 'DOC_T_TITLE' has no pt_BR text in documents.csv"]
	)
	table["DOC_T_TITLE"] = PackedStringArray(["Needs 366.6 MWh", "Título"])
	assert_array(ContentCheckDocuments.check_keys(documents, table)).contains(
		["document doc_a: key 'DOC_T_TITLE' states a lock energy"]
	)
	table.erase("DOC_T_TITLE")
	assert_int(ContentCheckDocuments.check_keys(documents, table).size()).is_equal(2)


func test_pairs_must_point_at_each_other() -> void:
	var first: DocumentDef = _document(&"doc_a", &"doc_b")
	var second: DocumentDef = _document(&"doc_b", &"doc_a")
	var documents: Array[DocumentDef] = [first, second]
	assert_array(ContentCheckDocuments.check_pairs(documents)).is_empty()
	second.pair_id = &""
	assert_array(ContentCheckDocuments.check_pairs(documents)).contains(
		["document doc_a is read with doc_b, which is read with ''"]
	)


func test_a_far_side_reading_must_give_the_same_address_from_that_ring() -> void:
	var document: DocumentDef = _document(&"doc_a")
	var documents: Array[DocumentDef] = [document]
	var readings: Dictionary[StringName, StringName] = {&"doc_a": _relay.id}
	_relay.origin_glyph = _unused_origin()
	(
		assert_array(ContentCheckDocuments.check_far_side(documents, _worlds(), _anchors, readings))
		. is_empty()
	)
	_relay.origin_glyph = document.answer_glyphs[3]
	var errors: Array[String] = ContentCheckDocuments.check_far_side(
		documents, _worlds(), _anchors, readings
	)
	assert_str("\n".join(errors)).contains(
		"read on world_relay, whose origin glyph %d is in the answer" % _relay.origin_glyph
	)
	assert_str("\n".join(errors)).contains("the inscription on world_relay reads")


func test_a_far_side_reading_of_a_missing_document_or_world_is_reported() -> void:
	var documents: Array[DocumentDef] = [_document(&"doc_a")]
	var readings: Dictionary[StringName, StringName] = {
		&"doc_a": &"world_nowhere", &"doc_gone": _relay.id
	}
	var errors: Array[String] = ContentCheckDocuments.check_far_side(
		documents, _worlds(), _anchors, readings
	)
	(
		assert_array(errors)
		. contains(
			[
				"document doc_a: read on world_nowhere, not an authored world",
				"far-side reading doc_gone names no document",
			]
		)
	)


func test_a_decoy_that_is_a_real_address_or_an_answer_is_reported() -> void:
	var documents: Array[DocumentDef] = [_document(&"doc_a")]
	var wrong: PackedInt32Array = _answer(_target, _home.origin_glyph)
	wrong.reverse()
	var decoys: Array[PackedInt32Array] = [wrong]
	(
		assert_array(ContentCheckDocuments.check_decoys(decoys, _worlds(), _anchors, documents))
		. is_empty()
	)
	decoys.append(_answer(_relay, _home.origin_glyph))
	var errors: Array[String] = ContentCheckDocuments.check_decoys(
		decoys, _worlds(), _anchors, documents
	)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).ends_with("is world world_relay")


func test_a_decoy_that_a_generated_world_has_is_reported() -> void:
	var records: Array[WorldRecord] = [WorldRecord.from_def(_home), WorldRecord.from_def(_target)]
	var galaxy: GalaxyCatalogue = GalaxyCatalogue.build(records, _anchors)
	var decoys: Array[PackedInt32Array] = [_answer(_relay, _home.origin_glyph)]
	assert_array(ContentCheckDocuments.check_galaxy_decoys(decoys, galaxy)).is_empty()
	decoys.append(_answer(_target, _home.origin_glyph))
	var errors: Array[String] = ContentCheckDocuments.check_galaxy_decoys(decoys, galaxy)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).ends_with("is the address of world_target")


func test_the_documents_table_reads_both_locales() -> void:
	var table: Dictionary[String, PackedStringArray] = ContentCheckDocuments.read_table(
		ContentCheckDocuments.TABLE
	)
	assert_array(Array(table["DOC_SILL_ORDER_TITLE"])).is_equal(
		["Gallow Commission, Order No. 1", "Comissão de Gallow, Ordem nº 1"]
	)


## An origin glyph outside the target's seven nearest anchors and not the home origin.
func _unused_origin() -> int:
	var nearest: Array[int] = AddressRule.nearest_anchors(_target.position_ly, _anchors, -1, 8)
	for glyph: int in GateAddress.GLYPH_COUNT:
		if not nearest.has(glyph) and glyph != _home.origin_glyph:
			return glyph
	return -1
