## The log strip: the newest entry folded, the last five unfolded, new entries appear, and
## Open shows the Archive's Log.
## Bible: docs/content/interface-pass.md section 3 (owner request 2026-11-14)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 17
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()


func test_folded_shows_the_newest_and_unfolded_the_last_five() -> void:
	var strip: LogStrip = _shell.log_strip
	var state: GameState = SimClock.simulation.state
	for index: int in 7:
		state.operations_log.entries.append(
			LogEntry.create(state.clock.tick, &"research", &"", {"project_id": "p%d" % index})
		)
	strip.refresh()
	assert_int(strip.shown_lines().size()).is_equal(1)
	state.operations_log.entries.append(
		LogEntry.create(state.clock.tick + 90, &"research", &"", {"project_id": "last"})
	)
	strip.refresh()
	var newest: String = GateRoomFormat.date_time(state.clock.tick + 90)
	assert_str(strip.shown_lines()[0]).starts_with(newest)
	strip.toggle()
	assert_int(strip.shown_lines().size()).is_equal(LogStrip.LINES_OPEN)
	strip.toggle()
	assert_int(strip.shown_lines().size()).is_equal(1)


func test_views_end_above_the_strip_and_open_shows_the_log() -> void:
	await _runner.simulate_frames(2)
	assert_float(_shell.view_switcher.offset_bottom).is_less(0.0)
	_shell.log_strip.open_button.pressed.emit()
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("archive")
