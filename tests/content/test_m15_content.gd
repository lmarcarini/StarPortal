## Tests for the M1.5 puzzle content over the real data: the four authored worlds sit at the
## approved positions with the approved addresses, every document and image loads and reads in
## both locales, the validator passes and fails clearly on a broken answer, and a new game played
## through dials each answer (waiting for the charge), locks the right world and, with the pole
## camera's horizon record, receives the next puzzle, while no other ordering of those glyphs within reach locks anything.
## Bible: docs/content/m15-puzzles.md, gate-and-address-spec.md#puzzle-design-rules,
## technical-architecture.md#data-model
extends GdUnitTestSuite

const TEST_SEED: int = 20_261_024
## Each world in puzzle order: position and the seven seals CAIRN dials (m15-puzzles.md,
## "Positions and addresses").
const WORLDS: Array[StringName] = [
	&"world_sill", &"world_lintel", &"world_milestone", &"world_stillwater"
]
const POSITIONS: Array[Vector3i] = [
	Vector3i(-2065, 2433, 1107),
	Vector3i(-68, -3864, -1500),
	Vector3i(-5568, 2636, 200),
	Vector3i(-918, 1286, 370),
]
const ANSWERS: Array[Array] = [
	[35, 24, 29, 10, 19, 22, 8],
	[35, 19, 10, 15, 5, 6, 4],
	[35, 22, 19, 3, 24, 29, 34],
	[35, 10, 24, 19, 29, 8, 15],
]
## Documents at the start, then those each world's first horizon record delivers, in id order.
const AT_START: Array[StringName] = [&"doc_sill_order", &"doc_sill_sketch"]
const ON_LOCK: Array[Array] = [
	[&"doc_lintel_note", &"doc_lintel_rubbing", &"doc_sill_dossier"],
	[
		&"doc_lintel_dossier",
		&"doc_milestone_frame_1",
		&"doc_milestone_frame_2",
		&"doc_milestone_letter",
		&"doc_milestone_record",
	],
	[&"doc_milestone_dossier", &"doc_stillwater_note", &"doc_stillwater_song"],
	[&"doc_stillwater_dossier"],
]
const IMAGE_DOCUMENTS: Array[StringName] = [
	&"doc_sill_sketch", &"doc_lintel_rubbing", &"doc_milestone_frame_1", &"doc_milestone_frame_2"
]

var _locale: String = ""


func before_test() -> void:
	_locale = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale)


func _defs() -> GameDefs:
	return GameDefs.from_registry(Registry)


func _anchors() -> Array[Vector3i]:
	return _defs().anchors.positions_ly


func test_the_four_worlds_sit_at_their_positions_with_their_addresses() -> void:
	var home: WorldDef = Registry.get_def(&"world_cairn") as WorldDef
	for index: int in WORLDS.size():
		var world: WorldDef = Registry.get_def(WORLDS[index]) as WorldDef
		assert_object(world).override_failure_message(String(WORLDS[index])).is_not_null()
		assert_that(world.position_ly).is_equal(POSITIONS[index])
		var address: GateAddress = AddressRule.address_of(
			world.position_ly, _anchors(), home.origin_glyph
		)
		assert_array(address.coordinates).is_equal(ANSWERS[index])
	var lintel: WorldDef = Registry.get_def(&"world_lintel") as WorldDef
	assert_bool(ANSWERS[2].has(lintel.origin_glyph)).is_false()


func test_every_document_loads_with_its_image_and_texts_in_both_locales() -> void:
	var documents: Array[DocumentDef] = _defs().documents
	assert_int(documents.size()).is_equal(14)
	for document: DocumentDef in documents:
		assert_bool(document.image != null).is_equal(IMAGE_DOCUMENTS.has(document.id))
		for locale: String in ["en", "pt_BR"]:
			TranslationServer.set_locale(locale)
			for key: StringName in [document.title_key, document.source_key, document.body_key]:
				if key.is_empty():
					continue
				var text: String = String(TranslationServer.translate(key))
				assert_str(text).override_failure_message("%s %s" % [key, locale]).is_not_equal(
					String(key)
				)
				assert_bool(text.contains("\\n")).is_false()


func test_the_opening_order_tells_the_player_to_install_the_capacitor_bank() -> void:
	TranslationServer.set_locale("en")
	var body: String = DocumentText.body_bbcode(tr(&"DOC_SILL_ORDER_BODY"))
	assert_str(body).contains("until the capacitor bank is installed in the Gate Room")
	assert_str(body).contains("Enter them in this order and in no other:")
	TranslationServer.set_locale("pt_BR")
	assert_str(tr(&"DOC_SILL_ORDER_BODY")).contains("banco de capacitores esteja instalado")


func test_the_validator_passes_and_reports_a_broken_answer() -> void:
	var registry: ContentSource.RegistryScript = ContentSource.new_registry()
	var load_errors: Array[String] = registry.load_all().value
	var errors: Array[String] = ContentValidator.run(registry, load_errors, 1, false)
	registry.free()
	assert_array(errors).override_failure_message("\n".join(errors)).is_empty()
	var broken: DocumentDef = (Registry.get_def(&"doc_lintel_note") as DocumentDef).duplicate()
	broken.answer_glyphs = PackedInt32Array([35, 19, 10, 6, 5, 15, 4])
	var documents: Array[DocumentDef] = [broken]
	var found: Array[String] = ContentCheckDocuments.check_answers(
		documents, _defs().authored_worlds, _anchors()
	)
	assert_array(found).is_equal(
		[
			(
				"document doc_lintel_note: answer [35, 19, 10, 6, 5, 15, 4] is not world_lintel's"
				+ " address [35, 19, 10, 15, 5, 6, 4] from CAIRN"
			)
		]
	)


func test_each_document_arrives_as_the_chain_says() -> void:
	for document: DocumentDef in _defs().documents:
		if AT_START.has(document.id):
			assert_int(document.arrival).is_equal(DocumentDef.Arrival.AT_START)
			continue
		assert_int(document.arrival).is_equal(DocumentDef.Arrival.ON_FIRST_LOCK)
		var world: int = WORLDS.find(document.arrival_world_id)
		(
			assert_bool(world >= 0 and ON_LOCK[world].has(document.id))
			. override_failure_message(String(document.id))
			. is_true()
		)


## A new game: install the bank, then for each puzzle wait for the charge, dial the answer, lock
## the right world, extend the pole camera and receive exactly the next documents; close and go
## on.
func test_dialing_each_answer_from_a_new_game_locks_its_world_and_delivers_the_next() -> void:
	var defs: GameDefs = _defs()
	var built: Result = GameSetup.build_new(GameState.new_game(TEST_SEED, defs.balance), defs)
	assert_bool(built.is_ok).is_true()
	var simulation: Simulation = built.value
	var state: GameState = simulation.state
	assert_array(state.archive.received).is_equal(AT_START)
	state.clock.is_paused = true
	assert_bool(simulation.submit(InstallCapacitorsCommand.new()).is_ok).is_true()
	for index: int in WORLDS.size():
		var coordinates: Array[int] = []
		coordinates.assign(ANSWERS[index])
		var address := GateAddress.create(coordinates, state.galaxy.home().origin_glyph)
		var held: int = state.archive.received.size()
		_wait_for_charge(simulation, address)
		state.clock.is_paused = true
		assert_bool(simulation.submit(DialCommand.create(address)).is_ok).is_true()
		simulation.advance_tick()
		simulation.advance_tick()
		var entry: DialLogEntry = state.gate.dial_log.back()
		assert_int(entry.outcome).is_equal(DialOutcome.Kind.LOCK)
		assert_str(String(entry.world_id)).is_equal(String(WORLDS[index]))
		assert_int(state.archive.received.size()).is_equal(held)
		assert_bool(simulation.submit(ExtendPoleCameraCommand.new()).is_ok).is_true()
		for _tick: int in ExtendPoleCameraCommand.EXTEND_TICKS:
			simulation.advance_tick()
		assert_array(state.archive.received.slice(held)).is_equal(ON_LOCK[index])
		assert_bool(simulation.submit(CloseWormholeCommand.new()).is_ok).is_true()


## Runs ticks until the bank is installed and holds the lock energy of [param address].
func _wait_for_charge(simulation: Simulation, address: GateAddress) -> void:
	for _tick: int in 20_000:
		var power: PowerState = simulation.state.power
		var ready: bool = power.banks_installed > 0
		if ready and GateQueries.ticks_until_ready(simulation.state, address) == 0:
			return
		simulation.advance_tick()
	fail("the bank never charged for %s" % address.key())


## Each answer is its authored world's address alone in the opening galaxy, and none of the
## likely wrong readings (the design's decoys) is any world's address, procedural worlds
## included. Other orderings of the same glyphs are not ruled out: the generator places
## procedural worlds in the same neighbourhood (see the PR).
func test_the_answers_find_their_worlds_and_no_decoy_locks_anything() -> void:
	var defs: GameDefs = _defs()
	var state := GameState.new_game(TEST_SEED, defs.balance)
	assert_bool(GameSetup.build(state, defs).is_ok).is_true()
	var origin: int = state.galaxy.home().origin_glyph
	for index: int in ANSWERS.size():
		var coordinates: Array[int] = []
		coordinates.assign(ANSWERS[index])
		var found: WorldRecord = state.galaxy.find_by_coordinates(coordinates, origin)
		assert_str(String(found.id)).is_equal(String(WORLDS[index]))
	var decoys: Array[String] = ContentCheckDocuments.check_galaxy_decoys(
		ContentCheckDocuments.decoys(), state.galaxy
	)
	assert_array(decoys).override_failure_message("\n".join(decoys)).is_empty()
	for decoy: PackedInt32Array in ContentCheckDocuments.decoys():
		var coordinates: Array[int] = []
		coordinates.assign(Array(decoy))
		var outcome: Dictionary = DialResolver.resolve(
			GateAddress.create(coordinates, origin), state.galaxy
		)
		assert_int(outcome["outcome"]).is_equal(DialOutcome.Kind.NO_GATE)
