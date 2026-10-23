## Tests for the throwaway bridge between the Analysis view's Workbench and the Gate Room's
## Dial button (until the dial console card): on a new game, the address placed in the
## Workbench's seven slots is the one the Gate Room dials.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy, game-design.md#core-loop
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/workbench_fixture.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

var _simulation: Simulation = null
var _switcher: ViewSwitcher = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_simulation = Fixture.build_simulation()
	SimClock.start(_simulation)
	_switcher = (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	_runner = scene_runner(_switcher)
	_switcher.setup(_simulation)
	await _runner.await_input_processed()


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_switcher):
		_switcher.free()


## The address CAIRN's bank can charge soonest: seal 1 is the glyph with the cheapest lock,
## then the other glyphs in order, then CAIRN's origin.
func _cheap_address() -> GateAddress:
	var state: GameState = _simulation.state
	var origin: int = state.galaxy.home().origin_glyph
	var best: GateAddress = null
	for first: int in GateAddress.GLYPH_COUNT:
		if first == origin:
			continue
		var coordinates: Array[int] = [first]
		for glyph: int in GateAddress.GLYPH_COUNT:
			var is_free: bool = glyph != origin and glyph != first
			if is_free and coordinates.size() < GateAddress.COORDINATE_COUNT:
				coordinates.append(glyph)
		var address := GateAddress.create(coordinates, origin)
		var energy: float = GateQueries.lock_energy_mwh(state, address)
		if best == null or energy < GateQueries.lock_energy_mwh(state, best):
			best = address
	return best


func _dial_controls() -> DialControls:
	return _switcher.get_view(&"gate_room").find_child("DialControls", true, false) as DialControls


func test_the_gate_room_dials_the_address_placed_in_the_workbench() -> void:
	var address: GateAddress = _cheap_address()
	_simulation.state.power.stored_mwh = _simulation.state.power.capacity_mwh
	_switcher.show_view(&"gate_room")
	assert_bool(_dial_controls().get_dial_button().disabled).is_true()
	_switcher.show_view(&"analysis")
	var analysis: AnalysisView = _switcher.get_view(&"analysis") as AnalysisView
	var seals: SealRow = analysis.find_child("SealRow", true, false) as SealRow
	for index: int in GateAddress.COORDINATE_COUNT:
		seals.glyph_dropped.emit(index + 1, address.coordinates[index])
	assert_bool(analysis.get_address().equals(address)).is_true()
	_switcher.show_view(&"gate_room")
	var button: HoldButton = _dial_controls().get_dial_button()
	assert_bool(button.disabled).is_false()
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_str(_simulation.state.gate.current_address.key()).is_equal(address.key())
