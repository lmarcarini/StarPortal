## Tests for the artefact UI (M4-28): the list's rows and moves through commands with refusal
## reasons, the Base room filter, the Archive section and the Gate Room button.
## Bible: docs/content/m4-core-systems.md section 5
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation
var _panel: ArtefactPanel
var _vault: RoomState


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ConstructionFixture.unlock_all(ConstructionFixture.grown())
	_state.clock.mode = ClockState.Mode.PAUSED
	var def := ArtefactDef.new()
	def.id = &"artefact_plain"
	def.hazard_chance_pct = 5
	var modifier := ModifierEffect.new()
	modifier.key = &"wormhole_minutes"
	modifier.amount = 5
	def.modifiers = [modifier]
	_state.artefact_defs[def.id] = def
	_vault = _state.base.add_room(&"room_artefact_vault", 2, Vector2i(4, 10))
	_simulation = Simulation.new(_state, [])
	_panel = ArtefactPanel.new()
	add_child(_panel)
	_panel.setup(_simulation)


func after_test() -> void:
	_panel.free()


func test_rows_and_moves() -> void:
	for index: int in 3:
		StoryRulesItems.give_artefact(_state, &"artefact_plain")
	_panel.refresh()
	assert_str(_panel.get_header_text()).is_equal("Holding 2/2  At the gate: 1")
	assert_str(_panel.get_row_text(0)).contains("in Gate Room holding")
	assert_str(_panel.get_row_text(0)).contains("While on: wormhole_minutes +5")
	assert_str(_panel.get_row_text(0)).contains("Hazard: 5%")
	assert_str(_panel.get_row_text(2)).contains("waiting at the gate")
	var buttons: Array[Button] = _panel.get_buttons()
	assert_str(buttons[0].text).starts_with("House in Artefact Vault")
	assert_str(buttons[-1].text).is_equal("Retrieve")
	buttons[-1].pressed.emit()
	assert_str(_panel.get_message()).is_equal("Holding is full.")
	_panel.get_buttons()[0].pressed.emit()
	assert_str(_panel.get_message()).is_empty()
	assert_int(_state.artefacts.items[0].room_uid).is_equal(ArtefactRules.room_uid_of(_vault.id))
	_panel.get_buttons()[-1].pressed.emit()
	assert_array(ArtefactRules.at_gate(_state)).is_empty()


func test_room_filter() -> void:
	StoryRulesItems.give_artefact(_state, &"artefact_plain")
	var other: RoomState = _state.base.add_room(&"room_artefact_vault", 2, Vector2i(14, 10))
	_panel.room_filter = ArtefactRules.room_uid_of(other.id)
	_panel.refresh()
	assert_int(_panel.get_buttons().size()).is_equal(1)
	_panel.get_buttons()[0].pressed.emit()
	_panel.room_filter = ArtefactRules.room_uid_of(_vault.id)
	_panel.refresh()
	assert_array(_panel.get_buttons()).is_empty()


func test_refusal_words() -> void:
	assert_str(ArtefactText.refusal(&"wrong_class")).is_equal("It needs Containment.")
	assert_str(ArtefactText.refusal(&"something_else")).is_equal("something_else")


func test_archive_section_and_gate_locker() -> void:
	StoryRulesItems.give_artefact(_state, &"artefact_plain")
	var locker: GateLocker = auto_free(GateLocker.new())
	add_child(locker)
	var card: PaperCard = auto_free(locker.get_card())
	add_child(card)
	locker.setup(_simulation)
	assert_bool(locker.get_holding_key().visible).is_true()
	assert_str(locker.get_holding_key().badge_text).is_equal("1")
	locker.toggle_holding()
	assert_bool(locker.get_card().visible).is_true()
