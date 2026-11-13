## Tests for the Command tab's Factions sub-tab (M4-17): only met factions, name in the accent
## colour, bar range, value and attitude, open requests and the last causes; it follows
## standing_changed and faction_met.
## Bible: docs/content/m4-core-systems.md section 2
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/command/command_view.tscn"
const KINDRED: StringName = &"faction_kindred"

var _state: GameState
var _simulation: Simulation
var _root: Control
var _view: CommandView


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = StoryFixture.state()
	var kindred := FactionDef.new()
	kindred.id = KINDRED
	kindred.name_key = &"Kindred"
	kindred.accent = Color(0.2, 0.7, 0.4)
	var committee := FactionDef.new()
	committee.id = FactionRules.COMMITTEE
	committee.name_key = &"Committee"
	committee.uses_confidence = true
	committee.kind = &"earth"
	_state.faction_defs[KINDRED] = kindred
	_state.faction_defs[FactionRules.COMMITTEE] = committee
	_state.factions.met.clear()
	_state.factions.met.append(FactionRules.COMMITTEE)
	_simulation = Simulation.new(_state, [])
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = Vector2(1280, 624)
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as CommandView
	_root.add_child(_view)
	add_child(_root)
	_view.setup(_simulation)
	_view.show_subtab(CommandView.FACTIONS)


func after_test() -> void:
	EventBus.bind_simulation(null)
	_root.free()


func _panel() -> FactionsPanel:
	return _view.get_factions()


func test_only_met_factions() -> void:
	assert_array(_panel().get_names()).is_equal(["Committee"])
	assert_float(_panel().get_bar(0).min_value).is_equal(0.0)
	_state.clock.mode = ClockState.Mode.PAUSED
	FactionRules.meet(_state, KINDRED)
	_simulation.submit(SetFlagCommand.create(&"x", true))
	assert_array(_panel().get_names()).is_equal(["Committee", "Kindred"])


func test_kindred_block() -> void:
	FactionRules.meet(_state, KINDRED)
	FactionRules.change(_state, KINDRED, 30, &"CAUSE_GIFT")
	var request := RequestDef.new()
	request.id = &"request_x"
	request.faction = KINDRED
	request.offer_days = 1
	_state.request_defs[request.id] = request
	StoryRulesItems.offer_request(_state, request.id)
	_panel().refresh()
	var text: String = _panel().get_block_text(1)
	assert_str(text).contains("Standing 30  Friendly  Open requests: 1")
	assert_str(text).contains("Gift  +30")
	assert_float(_panel().get_bar(1).min_value).is_equal(-100.0)
	assert_float(_panel().get_bar(1).value).is_equal(30.0)
