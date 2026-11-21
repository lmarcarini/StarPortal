## Installations in the room panel (M4c-19): the Gate Room offers the Shutter, locked with its
## research name until researched; installing shows progress and Remove; the plan marks it.
## Bible: docs/content/m4c-incursions.md section 6
extends GdUnitTestSuite

var _simulation: Simulation
var _gate: RoomState


func before_test() -> void:
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build_new(GameState.new_game(2, defs.balance), defs).value
	SimClock.start(_simulation)
	SimClock.pause()
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == StartingBase.GATE_ROOM_DEF:
			_gate = room


func after_test() -> void:
	SimClock.stop()


func test_locked_then_install_then_remove() -> void:
	var state: GameState = _simulation.state
	var texts: Array[String] = InstallList.offer_text(
		state, _gate, state.installation_defs[ShutterRules.DEF_ID]
	)
	assert_str(texts[1]).is_equal("Needs research: Iris studies")
	state.research.done.append(&"iris_studies")
	var list := InstallList.new()
	add_child(list)
	list.show_room(_gate)
	assert_bool(list.visible).is_true()
	var offer: Button = null
	for child: Node in list.get_children():
		if child is Button:
			offer = child
	assert_bool(offer.disabled).is_false()
	offer.pressed.emit()
	assert_int(_gate.installations.size()).is_equal(1)
	var labels: Array[String] = []
	for child: Node in list.get_children():
		if child is HBoxContainer:
			labels.append((child.get_child(0) as Label).text)
	assert_str(labels[0]).contains("installing 0%")
	list.free()
