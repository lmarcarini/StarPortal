## Tests for leaving the Gate Room while the dialing sequence plays: switching view, stopping
## its processing or taking it out of the tree acts as Skip. The cutscene hold is released,
## the dial resolves as it would have, and the result card waits for the player's return.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#state-machines, game-design.md#time-real-time-with-pause
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

var _simulation: Simulation = null
var _root: Control = null
var _switcher: ViewSwitcher = null
var _view: GateRoomView = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_root = Control.new()
	_root.size = Fixture.VIEW_SIZE
	_switcher = (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	_root.add_child(_switcher)
	add_child(_root)
	_switcher.setup(_simulation)
	_view = _switcher.get_view(ViewSwitcher.GATE_ROOM) as GateRoomView


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func _overlays() -> GateOverlays:
	return _view.get_overlays()


func _start_dial(kind: int) -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, kind))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	_overlays().get_sequence().advance(DialSequence.SEAL_SECONDS * 2.0)
	assert_bool(_overlays().get_sequence().is_open()).is_true()
	assert_array(_simulation.state.clock.holds).contains([DialSequence.HOLD_REASON])


func test_switching_view_mid_sequence_releases_the_hold_and_resolves_the_dial() -> void:
	_start_dial(DialOutcome.Kind.NO_GATE)
	_switcher.show_view(ViewSwitcher.ARCHIVE)
	assert_bool(_overlays().get_sequence().is_open()).is_false()
	assert_array(_simulation.state.clock.holds).is_empty()
	assert_int(_simulation.state.clock.mode).is_equal(ClockState.Mode.PAUSED)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_int(_simulation.state.gate.dial_log.size()).is_equal(1)
	_switcher.show_view(ViewSwitcher.GATE_ROOM)
	var card: ResultCard = _overlays().get_result_card()
	assert_bool(card.is_visible_in_tree()).is_true()
	assert_int(card.get_shown_kind()).is_equal(DialOutcome.Kind.NO_GATE)


func test_a_lock_reached_while_away_shows_the_wormhole_screen_on_return() -> void:
	_start_dial(DialOutcome.Kind.LOCK)
	_switcher.show_view(ViewSwitcher.ARCHIVE)
	assert_array(_simulation.state.clock.holds).is_empty()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	_switcher.show_view(ViewSwitcher.GATE_ROOM)
	assert_bool(_overlays().get_wormhole_screen().is_showing_open()).is_true()


func test_leaving_the_tree_mid_sequence_releases_the_hold() -> void:
	_start_dial(DialOutcome.Kind.BLOCKED)
	remove_child(_root)
	assert_array(_simulation.state.clock.holds).is_empty()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)


func test_setup_mid_sequence_releases_the_hold() -> void:
	_start_dial(DialOutcome.Kind.NO_GATE)
	_overlays().get_sequence().setup(_simulation)
	assert_bool(_overlays().get_sequence().is_open()).is_false()
	assert_array(_simulation.state.clock.holds).is_empty()
