## Tests for artefact holding and housing (M4-26): arrivals in holding and, when full, waiting
## at the gate; retrieve, house and unhouse with every refusal code; class fitting; modifiers
## only while housed in a working room; no demolition while a slot is used; recovered targets
## giving their artefact; save and reload.
## Bible: docs/content/m4-core-systems.md section 5
extends GdUnitTestSuite

var _state: GameState
var _vault_uid: int
var _vault: RoomState


func before_test() -> void:
	_state = ConstructionFixture.unlock_all(ConstructionFixture.grown())
	_state.artefact_defs.clear()
	for id: StringName in [&"artefact_plain", &"artefact_hot"]:
		var def := ArtefactDef.new()
		def.id = id
		def.storage = &"containment" if id == &"artefact_hot" else &"vault"
		var modifier := ModifierEffect.new()
		modifier.key = &"wormhole_minutes"
		modifier.amount = 5
		def.modifiers = [modifier]
		_state.artefact_defs[id] = def
	_vault = _state.base.add_room(&"room_artefact_vault", 2, Vector2i(4, 10))
	_vault_uid = ArtefactRules.room_uid_of(_vault.id)


func _give(id: StringName = &"artefact_plain") -> int:
	return StoryRulesItems.give_artefact(_state, id)


func _code(command: Command) -> String:
	return String(command.validate(_state).error_code)


func _run(command: Command) -> void:
	assert_bool(command.validate(_state).is_ok).override_failure_message(_code(command)).is_true()
	command.apply(_state)


func test_holding_then_gate_then_retrieve() -> void:
	var first: int = _give()
	var second: int = _give()
	var third: int = _give()
	assert_array(ArtefactRules.holding(_state)).is_equal([first, second])
	assert_array(ArtefactRules.at_gate(_state)).is_equal([third])
	assert_str(_code(RetrieveArtefactCommand.new(third))).is_equal("holding_full")
	assert_str(_code(RetrieveArtefactCommand.new(first))).is_equal("not_at_gate")
	assert_str(_code(HouseArtefactCommand.new(third, _vault_uid))).is_equal("not_in_holding")
	_run(HouseArtefactCommand.new(first, _vault_uid))
	_run(RetrieveArtefactCommand.new(third))
	assert_array(ArtefactRules.holding(_state)).is_equal([second, third])
	assert_int(_state.artefacts.items.size()).is_equal(3)


func test_house_refusals() -> void:
	var plain: int = _give()
	var hot: int = _give(&"artefact_hot")
	assert_str(_code(HouseArtefactCommand.new(99, _vault_uid))).is_equal("unknown_artefact")
	assert_str(_code(HouseArtefactCommand.new(plain, 999))).is_equal("not_storage")
	assert_str(_code(HouseArtefactCommand.new(hot, _vault_uid))).is_equal("wrong_class")
	_vault.build_ticks_left = 10
	assert_str(_code(HouseArtefactCommand.new(plain, _vault_uid))).is_equal("not_built")
	_vault.build_ticks_left = 0
	_run(HouseArtefactCommand.new(plain, _vault_uid))
	assert_int(ArtefactRules.find(_state, plain).state).is_equal(
		ArtefactRecord.ArtefactState.HOUSED
	)
	var third: int = _give()
	_run(HouseArtefactCommand.new(third, _vault_uid))
	var fourth: int = _give()
	assert_str(_code(HouseArtefactCommand.new(fourth, _vault_uid))).is_equal("room_full")


func test_containment_takes_both() -> void:
	var containment: RoomState = _state.base.add_room(&"room_containment", 2, Vector2i(10, 10))
	var room_uid: int = ArtefactRules.room_uid_of(containment.id)
	var plain: int = _give()
	assert_bool(HouseArtefactCommand.new(plain, room_uid).validate(_state).is_ok).is_true()
	assert_bool(ArtefactRules.fits(&"containment", &"containment")).is_true()
	assert_bool(ArtefactRules.fits(&"vault", &"containment")).is_false()


func test_unhouse_and_modifiers() -> void:
	var plain: int = _give()
	assert_str(_code(UnhouseArtefactCommand.new(plain))).is_equal("not_housed")
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(0)
	_run(HouseArtefactCommand.new(plain, _vault_uid))
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(5)
	_vault.powered_on = false
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(0)
	_vault.powered_on = true
	_give()
	_give()
	assert_str(_code(UnhouseArtefactCommand.new(plain))).is_equal("holding_full")
	_state.artefacts.items.remove_at(2)
	_run(UnhouseArtefactCommand.new(plain))
	assert_int(ModifierRules.total(_state, &"wormhole_minutes")).is_equal(0)


func test_studied_stays_studied_and_gate_not_studied() -> void:
	var plain: int = _give()
	var record: ArtefactRecord = ArtefactRules.find(_state, plain)
	record.state = ArtefactRecord.ArtefactState.STUDIED
	_run(HouseArtefactCommand.new(plain, _vault_uid))
	assert_int(record.state).is_equal(ArtefactRecord.ArtefactState.STUDIED)
	_give(&"artefact_hot")
	_give(&"artefact_hot")
	_give(&"artefact_hot")
	var waiting: ArtefactRecord = _state.artefacts.items[-1]
	assert_int(waiting.room_uid).is_equal(ArtefactRecord.AT_GATE)
	var study := StudyArtefactEffect.new()
	study.artefact = &"artefact_hot"
	StoryRules.apply(_state, study, &"x")
	assert_int(waiting.state).is_equal(ArtefactRecord.ArtefactState.RECOVERED)


func test_no_demolition_while_used() -> void:
	var plain: int = _give()
	_run(HouseArtefactCommand.new(plain, _vault_uid))
	var demolish := DemolishRoomCommand.create(_vault.id)
	assert_str(_code(demolish)).is_equal("holds_artefacts")


func test_recovered_target_gives_its_artefact() -> void:
	var game: GameState = StoryFixture.state()
	var facts: WorldFacts = WorldFactRules.facts_for_id(game.galaxy, &"world_lintel")
	var target: WorldTarget = facts.targets[0]
	target.artefact_id = &"artefact_plain"
	ExpeditionReturns._recover(game, &"world_lintel", target.id)
	assert_int(game.artefacts.items.size()).is_equal(1)
	assert_str(String(game.artefacts.items[0].artefact)).is_equal("artefact_plain")


func test_save_and_reload() -> void:
	var plain: int = _give()
	_run(HouseArtefactCommand.new(plain, _vault_uid))
	_give()
	_give()
	_give()
	var text: String = JSON.stringify(_state.to_dict())
	var data: Dictionary = JSON.parse_string(text)
	assert_array(GameState.validate_dict(data)).is_empty()
	assert_str(JSON.stringify(GameState.from_dict(data).to_dict())).is_equal(text)
