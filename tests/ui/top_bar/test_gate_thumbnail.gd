## The gate chip's live thumbnail: only while open, from the Gate Room's own viewport, and no
## rendering when closed with the Gate Room hidden.
## Bible: docs/content/interface-pass.md section 3 (Gate chip)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 6
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func test_thumbnail_only_while_open_and_reuses_the_gate_room_feed() -> void:
	var chip: GateChip = _shell.top_bar.gate_chip
	var gate_room: GateRoomView = _shell.view_switcher.get_view(ViewSwitcher.GATE_ROOM)
	var ring: RingView = gate_room.get_ring_view()
	assert_object(chip.ring).is_same(ring)
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	assert_bool(chip.has_thumbnail()).is_false()
	assert_bool(ring.is_feed_live()).is_false()
	var state: GameState = SimClock.simulation.state
	state.gate.mode = GateState.RingMode.LOCKED
	state.gate.lock_started_tick = state.clock.tick
	chip.show_state(state)
	assert_bool(chip.has_thumbnail()).is_true()
	assert_object(chip.icon).is_same(ring.feed_texture())
	assert_bool(ring.is_feed_live()).is_true()
	state.gate.mode = GateState.RingMode.IDLE
	chip.show_state(state)
	assert_bool(chip.has_thumbnail()).is_false()
	assert_bool(ring.is_feed_live()).is_false()
