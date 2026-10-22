## Tests for the Address Workbench's counter and candidate list: the count matches
## CandidateCounter, uses the locale's digit grouping, explains zero, lists 50 or fewer with
## their lock energy, and sends one to the dial queue. Also: a sky chart plus orderings driven
## by gamepad to "1 possible", recount only on workbench changes, and reload.
## Bible: gate-and-address-spec.md#player-tools,
## gate-and-address-spec.md#clue-types-and-reliability,
## technical-architecture.md#save-system
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/workbench_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")

var _simulation: Simulation = null
var _workbench: Workbench = null
var _runner: GdUnitSceneRunner = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Fixture.build_simulation()
	EventBus.bind_simulation(_simulation)
	_workbench = Fixture.instantiate()
	_runner = scene_runner(_workbench)
	_workbench.setup(_simulation)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_workbench):
		_workbench.free()
	EventBus.bind_simulation(SimClock.simulation)
	TranslationServer.set_locale(_real_locale)


## An empty draft shows every 8-seal address with the locale's digit grouping.
func test_empty_draft_count_uses_locale_grouping() -> void:
	assert_str(_count().text).is_equal("33,891,580,800 possible")
	TranslationServer.set_locale("pt_BR")
	await UiInput.settle(_workbench)
	assert_str(_count().text).is_equal("33.891.580.800 possíveis")


## The counter equals CandidateCounter.count for the draft and its origin.
func test_count_matches_the_candidate_counter() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	var c: Array[int] = target.coordinates
	var drafts: Array = [
		[AddressConstraint.glyph_at(1, c[0])],
		[AddressConstraint.exact_set(c), AddressConstraint.nearer_than(c[0], c[1])],
		[AddressConstraint.excluded(c[0]), AddressConstraint.included(c[1])],
	]
	for draft: Array in drafts:
		var constraints: Array[AddressConstraint] = []
		constraints.assign(draft)
		_set_draft(constraints)
		var expected: int = CandidateCounter.count(constraints, target.origin)
		assert_int(_workbench.get_summary().count).is_equal(expected)
		assert_int(_count().get_count()).is_equal(expected)


## Zero candidates shows the contradiction message and lists nothing.
func test_zero_shows_the_contradiction_message() -> void:
	_set_draft([AddressConstraint.included(3), AddressConstraint.excluded(3)])
	assert_str(_count().text).is_equal("No address fits: a constraint is wrong")
	assert_array(_candidates().get_rows()).is_empty()
	assert_bool(_candidates().is_hint_shown()).is_false()


## Above 50 the list is replaced by a hint; at 50 or fewer every candidate is listed with its
## lock energy.
func test_lists_only_at_fifty_or_fewer() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	var c: Array[int] = target.coordinates
	_set_draft([AddressConstraint.exact_set(c)])
	assert_int(_workbench.get_summary().count).is_equal(5040)
	assert_bool(_candidates().is_hint_shown()).is_true()
	assert_array(_candidates().get_rows()).is_empty()
	var constraints: Array[AddressConstraint] = [AddressConstraint.exact_set(c)]
	for index: int in 5:
		constraints.append(AddressConstraint.nearer_than(c[index], c[index + 1]))
	_set_draft(constraints)
	await UiInput.settle(_workbench)
	var rows: Array[CandidateRow] = _candidates().get_rows()
	assert_int(rows.size()).is_equal(7)
	assert_bool(_candidates().is_hint_shown()).is_false()
	var energy: float = GateQueries.lock_energy_mwh(_simulation.state, rows[0].get_address())
	var label: Label = rows[0].get_node("%Energy") as Label
	assert_str(label.text).is_equal(
		"Lock energy: %s MWh" % DigitGrouping.group(roundi(energy), ",")
	)


## The reviewer's walk: from an empty workbench, a sky chart's set plus orderings by gamepad
## reach "1 possible", and the one address goes to the dial queue; sending it again and a
## full queue show their messages.
func test_sky_chart_and_orderings_to_one_then_queue() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	var c: Array[int] = target.coordinates
	for glyph: int in c:
		await UiInput.pad(_palette().get_button(glyph), JOY_BUTTON_A)
		await UiInput.pad(_action(ActionBar.Action.INCLUDE), JOY_BUTTON_A)
	await UiInput.pad(_action(ActionBar.Action.GROUP), JOY_BUTTON_A)
	assert_str(_count().text).is_equal("5,040 possible")
	for index: int in GateAddress.COORDINATE_COUNT - 1:
		await UiInput.pad(_palette().get_button(c[index]), JOY_BUTTON_A)
		await UiInput.pad(_action(ActionBar.Action.NEARER), JOY_BUTTON_A)
		await UiInput.pad(_palette().get_button(c[index + 1]), JOY_BUTTON_A)
	assert_str(_count().text).is_equal("1 possible")
	var rows: Array[CandidateRow] = _candidates().get_rows()
	assert_int(rows.size()).is_equal(1)
	assert_bool(rows[0].get_address().equals(target)).is_true()
	await UiInput.pad(rows[0].get_send_button(), JOY_BUTTON_A)
	assert_int(_simulation.state.gate.dial_queue.size()).is_equal(1)
	assert_bool(_simulation.state.gate.dial_queue[0].equals(target)).is_true()
	assert_str(_candidates().get_message()).is_equal("Sent to the dial queue.")
	assert_bool(rows[0].is_marked_queued()).is_true()
	await UiInput.key(rows[0].get_send_button(), KEY_ENTER)
	assert_int(_simulation.state.gate.dial_queue.size()).is_equal(1)
	assert_str(_candidates().get_message()).is_equal("That address is already in the dial queue.")


## A full queue rejects the send with a translated message.
func test_full_queue_shows_its_message() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	var constraints: Array[AddressConstraint] = _chain(target.coordinates, 6)
	constraints.append(AddressConstraint.exact_set(target.coordinates))
	_set_draft(constraints)
	for filler: int in QueueAddressCommand.MAX_QUEUE:
		var coordinates: Array[int] = [30, 31, 32, 33, 34, 35, filler]
		_simulation.submit(QueueAddressCommand.create(GateAddress.create(coordinates, 29)))
	assert_int(_simulation.state.gate.dial_queue.size()).is_equal(QueueAddressCommand.MAX_QUEUE)
	TranslationServer.set_locale("pt_BR")
	await UiInput.pad(_candidates().get_rows()[0].get_send_button(), JOY_BUTTON_A)
	assert_str(_candidates().get_message()).is_equal(
		"A fila de discagem está cheia (%d endereços)." % QueueAddressCommand.MAX_QUEUE
	)


## The count is computed once per workbench change: frames and queue changes reuse it.
func test_recount_only_on_workbench_change() -> void:
	var first: CandidateSummary = _workbench.get_summary()
	await UiInput.settle(_workbench)
	_simulation.submit(QueueAddressCommand.create(Fixture.target_address(_simulation.state)))
	await UiInput.settle(_workbench)
	assert_object(_workbench.get_summary()).is_same(first)
	_set_draft([AddressConstraint.excluded(1)])
	assert_object(_workbench.get_summary()).is_not_same(first)


## The draft lives in the state: a save round trip and setup() with the loaded simulation
## show the same slots, origin, rows and count.
func test_reload_restores_the_workbench() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	var c: Array[int] = target.coordinates
	var other_origin: int = (target.origin + 1) % GateAddress.GLYPH_COUNT
	var constraints: Array[AddressConstraint] = [
		AddressConstraint.glyph_at(3, c[2]), AddressConstraint.nearer_than(c[0], c[1])
	]
	_simulation.submit(SetWorkbenchCommand.create(other_origin, constraints))
	var texts: Array[String] = _row_texts()
	var count: int = _count().get_count()
	var data: Dictionary = JSON.parse_string(JSON.stringify(_simulation.state.to_dict()))
	var built: Result = GameSetup.build(GameState.from_dict(data), GameDefs.from_registry(Registry))
	_simulation = built.value
	EventBus.bind_simulation(_simulation)
	_workbench.setup(_simulation)
	assert_int(_simulation.state.workbench.origin_glyph).is_equal(other_origin)
	assert_int(_seals().get_slot(3).get_glyph()).is_equal(c[2])
	assert_int(_seals().get_slot(GateAddress.SEAL_COUNT).get_glyph()).is_equal(other_origin)
	assert_array(_row_texts()).is_equal(texts)
	assert_int(_count().get_count()).is_equal(count)


func _set_draft(constraints: Array[AddressConstraint]) -> void:
	var result: CommandResult = _simulation.submit(
		SetWorkbenchCommand.create(WorkbenchState.HOME_ORIGIN, constraints)
	)
	assert_bool(result.is_ok).is_true()


func _chain(glyphs: Array[int], links: int) -> Array[AddressConstraint]:
	var chain: Array[AddressConstraint] = []
	for index: int in links:
		chain.append(AddressConstraint.nearer_than(glyphs[index], glyphs[index + 1]))
	return chain


func _row_texts() -> Array[String]:
	var texts: Array[String] = []
	for row: ConstraintRow in _constraint_list().get_rows():
		texts.append(row.get_text())
	return texts


func _count() -> CountDisplay:
	return _workbench.get_node("%Count") as CountDisplay


func _candidates() -> CandidateList:
	return _workbench.get_node("%Candidates") as CandidateList


func _constraint_list() -> ConstraintList:
	return _workbench.get_node("%Constraints") as ConstraintList


func _palette() -> GlyphPalette:
	return _workbench.get_node("%Palette") as GlyphPalette


func _seals() -> SealRow:
	return _workbench.get_node("%SealRow") as SealRow


func _action(action: ActionBar.Action) -> Button:
	return (_workbench.get_node("%ActionBar") as ActionBar).get_button(action)
