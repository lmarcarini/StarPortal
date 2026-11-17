## The gate monitor (M4.10-04): not on the Gate, IDLE and not rendering while the Ring is
## idle, live (rendering) while dialling, open or incoming, the same look as the Gate
## station, the alarm tint in an incursion, a click goes to the Gate.
## Bible: docs/content/interface-rethink.md section 3
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 4
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func _monitor() -> GateMonitor:
	return _shell.frame.gate_monitor


func test_hidden_on_the_gate_shown_elsewhere() -> void:
	await _runner.simulate_frames(2)
	assert_bool(_monitor().visible).is_false()
	_shell.view_switcher.show_station(&"base")
	await _runner.simulate_frames(2)
	assert_bool(_monitor().visible).is_true()


func test_idle_costs_nothing_and_a_dial_lights_it() -> void:
	_shell.view_switcher.show_station(&"base")
	await _runner.simulate_frames(2)
	assert_bool(_monitor().is_live()).is_false()
	var state: GameState = SimClock.simulation.state
	state.power.stored_mwh = 1.0e6
	var address: GateAddress = DialFixture.address_of(state.galaxy, state.galaxy.home().id)
	SimClock.simulation.submit(DialCommand.create(address))
	await _runner.simulate_frames(2)
	assert_bool(_monitor().is_live()).is_true()
	assert_int(_monitor().current_look().phase).is_equal(RingLook.Phase.DIALING)


func test_incoming_and_the_click() -> void:
	_shell.view_switcher.show_station(&"office")
	var state: GameState = SimClock.simulation.state
	state.gate.incoming_faction = &"faction_kindred"
	state.gate.incoming_until_tick = state.clock.tick + 100
	await _runner.simulate_frames(2)
	assert_int(_monitor().current_look().phase).is_equal(RingLook.Phase.INCOMING)
	assert_bool(_monitor().is_live()).is_true()
	_monitor().pressed.emit()
	await _runner.simulate_frames(2)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("gate_room")
	assert_bool(_monitor().visible).is_false()
