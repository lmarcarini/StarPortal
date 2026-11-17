## The four station keys (M4.10-03): Gate, Base, Lab and Office reach every screen; the
## current key is lit; lamps follow the hosted views' needs_attention(); Lab is off until a
## Research Lab exists; F1-F4 and the mouse.
## Bible: docs/content/interface-rethink.md section 3
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

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


func _keys() -> StationKeys:
	return _shell.frame.station_keys


func test_every_old_screen_is_reachable_from_a_station() -> void:
	var switcher: ViewSwitcher = _shell.view_switcher
	PowerFixture.lab(SimClock.simulation.state)
	EventBus.room_built.emit(&"lab")
	for view_id: StringName in switcher.get_view_ids():
		var station: StringName = switcher.station_of(view_id)
		_keys().get_key(station).pressed.emit()
		var folders: Array = ViewSwitcher.STATIONS[station]
		assert_bool(folders.has(view_id)).override_failure_message(view_id).is_true()
		switcher.show_view(view_id)
		assert_str(String(switcher.current_view_id())).is_equal(String(view_id))


func test_keys_light_the_current_station_and_the_lab_is_off() -> void:
	_keys().refresh()
	assert_bool(_keys().is_current(&"gate")).is_true()
	assert_bool(_keys().get_key(&"lab").disabled).is_true()
	assert_bool(_keys().get_buttons().has(_keys().get_key(&"lab"))).is_false()
	_keys().get_key(&"office").pressed.emit()
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("command")
	_keys().refresh()
	assert_bool(_keys().is_current(&"office")).is_true()
	assert_bool(_keys().is_current(&"gate")).is_false()


func test_lamps_follow_needs_attention() -> void:
	var switcher: ViewSwitcher = _shell.view_switcher
	_keys().refresh()
	for station: StringName in ViewSwitcher.STATION_ORDER:
		assert_bool(_keys().has_lamp(station)).is_equal(switcher.station_needs_attention(station))


func test_f_keys_reach_the_stations() -> void:
	await _runner.simulate_key_pressed(KEY_F4)
	assert_str(String(_shell.view_switcher.current_station())).is_equal("office")
	await _runner.simulate_key_pressed(KEY_F2)
	assert_str(String(_shell.view_switcher.current_station())).is_equal("base")
	await _runner.simulate_key_pressed(KEY_F1)
	assert_str(String(_shell.view_switcher.current_station())).is_equal("gate")
