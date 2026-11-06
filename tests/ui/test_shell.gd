## Tests for the shell scene, the time bar and the debug overlay, run headless with the
## gdUnit4 scene runner. Saves go to a temporary user:// folder, never user://saves.
## Bible: game-design.md#time-real-time-with-pause,
## technical-architecture.md#architecture-overview
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const TEST_SEED: int = 12345

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = (
		"user://test_shell_saves_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	)
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = TEST_SEED
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	_remove_dir(SaveService.saves_dir)
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


func test_starts_paused_with_new_game_and_minimum_window_size() -> void:
	var simulation: Simulation = SimClock.simulation
	assert_object(simulation).is_not_null()
	var expected: GameState = GameState.new_game(TEST_SEED, Registry.balance())
	GameSetup.build_new(expected, GameDefs.from_registry(Registry))
	assert_dict(simulation.state.to_dict()).is_equal(expected.to_dict())
	assert_object(simulation.state.balance).is_same(Registry.balance())
	assert_str(String(simulation.state.galaxy.home().id)).is_equal("world_cairn")
	assert_bool(simulation.state.clock.is_paused).is_true()
	assert_bool(SimClock.is_running()).is_false()
	assert_str(_label("DateLabel").text).is_equal("2026-01-01 00:00")
	assert_str(_label("SpeedLabel").text).is_equal(tr("UI_SPEED_PAUSED"))
	assert_object(_shell.get_window().min_size).is_equal(ShellScript.MIN_WINDOW_SIZE)
	assert_object(ShellScript.MIN_WINDOW_SIZE).is_equal(Vector2i(1280, 720))


func test_pause_and_speed_actions_change_clock_state() -> void:
	var clock: ClockState = SimClock.simulation.state.clock
	await _press_action(&"time_toggle_pause")
	assert_bool(clock.is_paused).is_false()
	assert_str(_label("SpeedLabel").text).is_equal("1×")
	await _press_action(&"time_faster")
	await _press_action(&"time_faster")
	assert_int(clock.speed_index).is_equal(3)
	assert_str(_label("SpeedLabel").text).is_equal("10×")
	await _press_action(&"time_slower")
	await _press_action(&"time_slower")
	await _press_action(&"time_slower")
	assert_int(clock.speed_index).is_equal(0)
	assert_str(_label("SpeedLabel").text).is_equal("0.5×")
	await _press_action(&"time_toggle_pause")
	assert_bool(clock.is_paused).is_true()
	assert_str(_label("SpeedLabel").text).is_equal(tr("UI_SPEED_PAUSED"))


func test_keyboard_and_gamepad_bindings_drive_the_clock() -> void:
	var clock: ClockState = SimClock.simulation.state.clock
	await _runner.simulate_key_pressed(KEY_SPACE)
	assert_bool(clock.is_paused).is_false()
	await _runner.simulate_key_pressed(KEY_EQUAL)
	assert_int(clock.speed_index).is_equal(2)
	await _pull_trigger(JOY_AXIS_TRIGGER_LEFT, [1.0, 0.0])
	assert_int(clock.speed_index).is_equal(1)
	await _pull_trigger(JOY_AXIS_TRIGGER_RIGHT, [1.0, 0.0])
	assert_int(clock.speed_index).is_equal(2)
	await _press_joypad(JOY_BUTTON_START)
	assert_bool(clock.is_paused).is_true()


func test_space_pauses_instead_of_pressing_the_focused_button() -> void:
	var clock: ClockState = SimClock.simulation.state.clock
	var faster: Button = _shell.time_bar.get_buttons()[2]
	faster.grab_focus()
	await _runner.simulate_key_pressed(KEY_SPACE)
	assert_bool(clock.is_paused).is_false()
	assert_int(clock.speed_index).is_equal(1)


func test_on_screen_buttons_change_clock_state() -> void:
	var clock: ClockState = SimClock.simulation.state.clock
	var buttons: Array[Button] = _shell.time_bar.get_buttons()
	buttons[0].pressed.emit()
	assert_bool(clock.is_paused).is_false()
	assert_str(buttons[0].text).is_equal(tr("UI_TIME_PAUSE"))
	buttons[2].pressed.emit()
	assert_int(clock.speed_index).is_equal(2)
	buttons[1].pressed.emit()
	buttons[1].pressed.emit()
	assert_int(clock.speed_index).is_equal(0)
	buttons[0].pressed.emit()
	assert_bool(clock.is_paused).is_true()
	assert_str(buttons[0].text).is_equal(tr("UI_TIME_RESUME"))


func test_date_label_follows_ticks() -> void:
	SimClock.step_ticks(TimeMath.TICKS_PER_DAY + 90)
	assert_str(_label("DateLabel").text).is_equal("2026-01-02 01:30")


func test_quick_save_then_load_restores_date() -> void:
	PowerFixture.add_bank(SimClock.simulation.state, 25)
	SimClock.step_ticks(90)
	await _runner.simulate_key_pressed(KEY_F8)
	assert_str(_shell.get_toast_text()).is_equal(tr("UI_SAVED"))
	assert_bool(FileAccess.file_exists(SaveService.slot_path(&"quick"))).is_true()
	var before_load: Simulation = SimClock.simulation
	assert_float(before_load.state.power.stored_mwh).is_equal_approx(37.5, 1e-9)
	SimClock.step_ticks(500)
	assert_str(_label("DateLabel").text).is_equal("2026-01-01 09:50")
	await _runner.simulate_key_pressed(KEY_F9)
	assert_object(SimClock.simulation).is_not_same(before_load)
	assert_int(SimClock.simulation.state.clock.tick).is_equal(90)
	assert_str(_label("DateLabel").text).is_equal("2026-01-01 01:30")
	assert_str(_shell.get_toast_text()).is_equal(tr("UI_LOADED"))
	_assert_same_galaxy(before_load.state.galaxy, SimClock.simulation.state.galaxy)
	SimClock.step_ticks(1)
	assert_str(_label("DateLabel").text).is_equal("2026-01-01 01:31")


func test_quick_save_and_load_actions() -> void:
	SimClock.step_ticks(10)
	await _press_action(&"quick_save")
	SimClock.step_ticks(10)
	await _press_action(&"quick_load")
	assert_int(SimClock.simulation.state.clock.tick).is_equal(10)


func test_quick_load_without_a_save_keeps_the_game() -> void:
	var running: Simulation = SimClock.simulation
	SimClock.step_ticks(5)
	await _press_action(&"quick_load")
	assert_object(SimClock.simulation).is_same(running)
	assert_int(running.state.clock.tick).is_equal(5)
	assert_str(_shell.get_toast_text()).is_equal(tr("UI_QUICK_SAVE_MISSING"))


func test_autosaves_on_each_day_start() -> void:
	SimClock.step_ticks(TimeMath.TICKS_PER_DAY - 1)
	assert_array(SaveService.list_slots()).is_empty()
	SimClock.step_ticks(1)
	var slots: Array[Dictionary] = SaveService.list_slots()
	assert_int(slots.size()).is_equal(1)
	var slot: StringName = slots[0]["slot"]
	assert_str(String(slot)).is_equal("autosave_1")
	assert_int(slots[0]["tick"]).is_equal(TimeMath.TICKS_PER_DAY)
	SimClock.step_ticks(TimeMath.TICKS_PER_DAY)
	assert_int(SaveService.list_slots().size()).is_equal(2)


func test_time_bar_text_comes_from_translation_keys() -> void:
	TranslationServer.set_locale("pt_BR")
	await _runner.simulate_frames(2)
	assert_str(_label("SpeedLabel").text).is_equal("Pausado")
	assert_str(_shell.time_bar.get_buttons()[0].text).is_equal("Retomar")
	SimClock.resume()
	assert_str(_label("SpeedLabel").text).is_equal("1×")
	assert_str(_shell.time_bar.get_buttons()[0].text).is_equal("Pausar")
	TranslationServer.set_locale("en")
	await _runner.simulate_frames(2)
	assert_str(_shell.time_bar.get_buttons()[0].text).is_equal("Pause")


## Focus navigation alone walks the top bar ring, goes down to the view tabs and into the
## shown view, moves along the tabs to the other view and through it, and back up.
func test_focus_navigation_reaches_every_button_the_tabs_and_each_view() -> void:
	var buttons: Array[Button] = _shell.get_focus_order()
	assert_int(buttons.size()).is_equal(6)
	assert_object(_focus_owner()).is_same(buttons[0])
	var visited: Array[Control] = []
	for _step: int in buttons.size():
		visited.append(_focus_owner())
		await _press_action(&"ui_right")
	assert_object(_focus_owner()).is_same(buttons[0])
	for button: Button in buttons:
		assert_int(button.focus_mode).is_equal(Control.FOCUS_ALL)
		assert_bool(visited.has(button)).override_failure_message(button.name).is_true()
	await _press_action(&"ui_left")
	assert_object(_focus_owner()).is_same(buttons[buttons.size() - 1])
	var switcher: ViewSwitcher = _shell.view_switcher
	var tabs: TabBar = switcher.get_tab_bar()
	var archive: GameView = switcher.get_view(&"archive")
	await _press_action(&"ui_down")
	assert_object(_focus_owner()).is_same(tabs)
	await _press_action(&"ui_down")
	assert_object(_focus_owner()).is_same(switcher.get_view(&"gate_room").get_default_focus())
	# The console's palette sits under its seal slots: up goes through the slots to the tabs.
	for _step: int in 3:
		if _focus_owner() != tabs:
			await _press_action(&"ui_up")
	assert_object(_focus_owner()).is_same(tabs)
	await _press_action(&"ui_right")
	assert_str(String(switcher.current_view_id())).is_equal("archive")
	await _press_action(&"ui_down")
	assert_object(_focus_owner()).is_same(archive.get_default_focus())
	# A new game's Archive holds the opening documents: up goes back through it to the tabs.
	for _step: int in 4:
		if _focus_owner() != tabs:
			await _press_action(&"ui_up")
	assert_object(_focus_owner()).is_same(tabs)
	await _press_action(&"ui_up")
	assert_object(_focus_owner()).is_same(buttons[0])


func test_gamepad_a_presses_the_focused_button() -> void:
	var quick_save: Button = _shell.get_focus_order()[3]
	var presses: Array[int] = [0]
	quick_save.pressed.connect(func() -> void: presses[0] += 1)
	quick_save.grab_focus()
	await _press_joypad(JOY_BUTTON_A)
	assert_int(presses[0]).is_equal(1)
	assert_str(_shell.get_toast_text()).is_equal(tr("UI_SAVED"))
	assert_bool(FileAccess.file_exists(SaveService.slot_path(&"quick"))).is_true()


func test_ui_actions_gain_gamepad_buttons_and_keep_keys() -> void:
	assert_int(_joypad_events(&"ui_accept", JOY_BUTTON_A)).is_equal(1)
	assert_int(_joypad_events(&"ui_cancel", JOY_BUTTON_B)).is_equal(1)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	assert_bool(InputMap.event_is_action(enter, &"ui_accept")).is_true()
	assert_bool(InputMap.event_is_action(escape, &"ui_cancel")).is_true()


func test_debug_overlay_toggles_and_shows_state() -> void:
	var overlay: DebugOverlay = _shell.debug_overlay
	assert_bool(OS.is_debug_build()).is_true()
	assert_object(overlay).is_not_null()
	assert_bool(overlay.visible).is_false()
	await _press_action(&"debug_toggle_overlay")
	assert_bool(overlay.visible).is_true()
	var tree: Tree = overlay.find_child("StateTree", true, false) as Tree
	var top_level: Array[String] = []
	for item: TreeItem in tree.get_root().get_children():
		top_level.append(item.get_text(0))
	assert_array(top_level).contains(["clock", "flags", "random"])
	await _press_action(&"debug_toggle_overlay")
	assert_bool(overlay.visible).is_false()


func test_debug_overlay_measures_ticks() -> void:
	var overlay: DebugOverlay = _shell.debug_overlay
	overlay.toggle()
	SimClock.set_speed_index(3)
	SimClock.resume()
	await get_tree().create_timer(1.2).timeout
	assert_int(overlay.ticks_per_second).is_greater(0)
	assert_float(overlay.mean_tick_msec).is_greater_equal(0.0)
	var speed_label: Label = overlay.find_child("SpeedIndexLabel", true, false) as Label
	assert_str(speed_label.text).is_equal(tr("UI_DEBUG_SPEED_INDEX").format({"index": "3"}))


## The debug button's SetFlagCommand reaches the state, and the overlay's state tree shows
## it on its next timed refresh, not before.
func test_debug_flag_button_sets_flag_shown_in_state_tree() -> void:
	var overlay: DebugOverlay = _shell.debug_overlay
	overlay.toggle()
	var button: Button = _shell.get_focus_order()[5]
	button.pressed.emit()
	button.pressed.emit()
	SimClock.step_ticks(1)
	var flags: Dictionary = SimClock.simulation.state.flags
	assert_int(flags.get(ShellScript.DEBUG_FLAG_KEY, 0)).is_equal(2)
	assert_str(_tree_value(overlay, ["flags", "debug_counter"])).is_null()
	await get_tree().create_timer(DebugOverlay.REFRESH_SECONDS + 0.2).timeout
	assert_str(_tree_value(overlay, ["flags", "debug_counter"])).is_equal("2")
	assert_str(_tree_value(overlay, ["clock", "tick"])).is_equal("1")


func test_leaving_the_tree_releases_the_clock_and_event_bus() -> void:
	assert_int(_event_bus_connections_into(_shell)).is_greater_equal(6)
	_shell.get_parent().remove_child(_shell)
	assert_object(SimClock.simulation).is_null()
	assert_int(_event_bus_connections_into(_shell)).is_equal(0)


## Checks [param loaded] is a new galaxy that finds every world of [param original] at the
## same home address.
func _assert_same_galaxy(original: GalaxyCatalogue, loaded: GalaxyCatalogue) -> void:
	assert_object(loaded).is_not_same(original)
	var origin: int = original.home().origin_glyph
	for world: WorldRecord in original.all_worlds():
		var address: GateAddress = original.address_of(world.id, origin)
		var found: WorldRecord = loaded.find_by_coordinates(address.coordinates, origin)
		assert_str(String(found.id)).is_equal(String(world.id))


func _press_action(action: StringName) -> void:
	_runner.simulate_action_pressed(String(action))
	await _runner.await_input_processed()


func _press_joypad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


## Moves trigger [param axis] through [param values], one motion event each. The events are
## sent from a process frame, as the engine sends real ones: inside a physics frame Input
## checks "just pressed" against physics frames instead.
func _pull_trigger(axis: JoyAxis, values: Array[float]) -> void:
	await get_tree().process_frame
	for value: float in values:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = value
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


## Returns the value column of the state tree item at [param path], or null if absent.
func _tree_value(overlay: DebugOverlay, path: Array[String]) -> Variant:
	var tree: Tree = overlay.find_child("StateTree", true, false) as Tree
	var item: TreeItem = tree.get_root()
	for part: String in path:
		var found: TreeItem = null
		for child: TreeItem in item.get_children():
			if child.get_text(0) == part:
				found = child
		if found == null:
			return null
		item = found
	return item.get_text(1)


func _joypad_events(action: StringName, button: JoyButton) -> int:
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		var joypad: InputEventJoypadButton = event as InputEventJoypadButton
		if joypad != null and joypad.button_index == button:
			count += 1
	return count


## Counts EventBus connections whose target is [param root] or one of its descendants.
func _event_bus_connections_into(root: Node) -> int:
	var count: int = 0
	for info: Dictionary in EventBus.get_signal_list():
		var signal_name: StringName = info["name"]
		for connection: Dictionary in EventBus.get_signal_connection_list(signal_name):
			var callable: Callable = connection["callable"]
			var target: Node = callable.get_object() as Node
			if target != null and (target == root or root.is_ancestor_of(target)):
				count += 1
	return count


func _label(label_name: String) -> Label:
	return _shell.time_bar.find_child(label_name, true, false) as Label


func _focus_owner() -> Control:
	return _shell.get_viewport().gui_get_focus_owner()


func _remove_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
