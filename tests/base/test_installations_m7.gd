## M7-06: Contract work in the Workshop (earns daily while it speeds no build, shown in the
## Office ledger) and the specimen cold store in the Bio Lab.
## Bible: docs/content/research-and-progression.md section 9
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ResearchFixture.state()
	for def: DefBase in Registry.get_all_of(InstallationDef):
		_state.installation_defs[def.id] = def as InstallationDef


func _fit(room: RoomState, def_id: StringName) -> void:
	var item: InstallationState = InstallationRules.create(_state.installation_defs[def_id])
	item.build_ticks_left = 0
	room.installations.append(item)


func test_both_need_their_research() -> void:
	var shop: RoomState = ResearchFixture.workshop(_state)
	var contract: InstallationDef = _state.installation_defs[ContractWork.DEF_ID]
	assert_str(String(contract.requires_research)).is_equal("contract_work")
	var cold: InstallationDef = _state.installation_defs[SpecimenRules.COLD_STORE]
	assert_str(String(cold.requires_research)).is_equal("cold_store")
	assert_bool(contract.fits_room(shop.def_id)).is_true()
	assert_bool(cold.fits_room(&"room_bio_lab")).is_true()


func test_contract_work_earns_while_idle_and_shows_in_the_ledger() -> void:
	var shop: RoomState = ResearchFixture.workshop(_state)
	assert_int(ContractWork.daily_k(_state)).is_equal(0)
	_fit(shop, ContractWork.DEF_ID)
	assert_int(ContractWork.daily_k(_state)).is_equal(ContractWork.DAILY_K)
	var found: bool = false
	for line: CommandLine in CommandLedger.lines(_state):
		if line.kind == CommandLine.Kind.CONTRACTS:
			found = true
			assert_int(line.per_period_k).is_equal(ContractWork.DAILY_K * 30)
			assert_str(CommandText.line_name(_state, line)).is_equal("Contract work")
	assert_bool(found).is_true()
	var site: RoomState = _state.base.add_room(&"room_quarters", 1, Vector2i(2, 2))
	site.build_ticks_left = 30
	assert_int(ContractWork.daily_k(_state)).is_equal(0)


func test_cold_store_keeps_specimens() -> void:
	var lab: RoomState = ResearchFixture.bench_for(_state, &"xenobiology")
	assert_bool(SpecimenRules.has_cold_store(_state)).is_false()
	_fit(lab, SpecimenRules.COLD_STORE)
	assert_bool(SpecimenRules.has_cold_store(_state)).is_true()
