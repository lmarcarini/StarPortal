## M5 flow: with 3D stations on, the shell's Gate is the 3D hall with the 3D Ring and the 3D
## floor; an answered wormhole opens the horizon and a team walks out.
## Bible: docs/content/interface-reference.md section 7
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	Station3D.force_enabled = true
	Station3D.skip_lightmaps = true
	_shell = (load("res://src/scenes/shell/shell.tscn") as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 4
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	Station3D.force_enabled = false
	Station3D.skip_lightmaps = false
	if is_instance_valid(_shell):
		_shell.free()


func test_the_gate_is_3d_and_a_wormhole_opens_the_horizon() -> void:
	var gate: GateStationView = _shell.view_switcher.get_view(ViewSwitcher.GATE_ROOM)
	assert_object(gate.get_station().get_3d()).is_not_null()
	assert_object(gate.get_ring_layer().ring_3d).is_not_null()
	assert_object(gate.get_floor().get_floor_3d()).is_not_null()
	var state: GameState = SimClock.simulation.state
	state.gate.incoming_faction = &"team"
	state.gate.incoming_until_tick = state.clock.tick + 10
	RingControl.answer_incoming(state.gate, state.galaxy.home().id, state.clock.tick)
	gate.get_ring_layer().advance(2.0)
	gate.get_ring_layer().ring_3d.advance(2.0)
	assert_int(state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_bool(gate.get_ring_layer().ring_3d.get_light().visible).is_true()
