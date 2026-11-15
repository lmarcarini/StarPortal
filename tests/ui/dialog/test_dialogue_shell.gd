## Tests for the dialogue screen inside the shell (M4.8-04): while it is up the tabs, the time
## keys and the views cannot be reached by keys or gamepad; Space and Enter continue; Esc opens
## the pause menu over it; a save made mid-conversation loads back with the screen at its line.
## Saves go to a temporary user:// folder, never user://saves.
## Bible: docs/content/dialogue-screen.md sections 1, 2 and 5
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	SaveService.saves_dir = "user://test_dialogue_shell_%d" % Time.get_ticks_usec()
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 4242
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	for file: String in DirAccess.get_files_at(SaveService.saves_dir):
		DirAccess.remove_absolute(SaveService.saves_dir.path_join(file))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _real_saves_dir


func _state() -> GameState:
	return SimClock.simulation.state


func _open() -> DialogueScreen:
	var state: GameState = _state()
	state.gate.mode = GateState.RingMode.LOCKED
	ConversationRules.start(state, &"conv_kindred_first_hail", &"wormhole", &"world_lintel")
	SimClock.simulation.submit(SetFlagCommand.create(&"t", 1))
	await _runner.await_input_processed()
	return _shell.get_dialogue_screen()


func _key(keycode: Key) -> void:
	await _runner.simulate_key_pressed(keycode)
	await _runner.await_input_processed()


func test_the_game_behind_cannot_be_reached() -> void:
	var screen: DialogueScreen = await _open()
	assert_bool(screen.visible).is_true()
	var switcher: ViewSwitcher = _shell.view_switcher
	var view: StringName = switcher.current_view_id()
	_runner.simulate_action_pressed("view_next")
	await _runner.await_input_processed()
	_runner.simulate_action_pressed("time_faster")
	await _runner.await_input_processed()
	assert_str(String(switcher.current_view_id())).is_equal(String(view))
	assert_int(_state().clock.speed_index).is_equal(ClockState.NORMAL_SPEED_INDEX)
	var focused: Control = _shell.get_viewport().gui_get_focus_owner()
	assert_bool(focused == screen or screen.is_ancestor_of(focused)).is_true()
	assert_int(screen.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_object(screen.get_global_rect()).is_equal(_shell.get_global_rect())


func test_space_and_enter_continue() -> void:
	var screen: DialogueScreen = await _open()
	assert_bool(screen.transcript.is_typing()).is_true()
	await _key(KEY_SPACE)
	assert_bool(screen.transcript.is_typing()).is_false()
	assert_int(_state().clock.mode).is_equal(ClockState.Mode.HELD)
	await _key(KEY_ENTER)
	assert_int(_state().conversations.active.phase).is_equal(ActiveConversation.Phase.CHOICE)
	await _key(KEY_2)
	assert_str(String(_state().conversations.active.node)).is_equal("end_cold")


func test_escape_opens_the_pause_menu_over_it() -> void:
	var screen: DialogueScreen = await _open()
	await _key(KEY_ESCAPE)
	assert_bool(_shell.pause_menu.is_open()).is_true()
	assert_bool(screen.visible).is_true()
	assert_bool(screen.transcript.is_typing()).is_true()
	_shell.pause_menu.close()
	assert_array(_state().clock.holds).is_equal([ConversationRules.HOLD])


func test_a_save_mid_conversation_loads_back_at_its_line() -> void:
	var screen: DialogueScreen = await _open()
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	await _key(KEY_1)
	_shell.save_slot(&"mid")
	_shell.load_slot(&"mid")
	await _runner.await_input_processed()
	assert_bool(screen.visible).is_true()
	assert_str(String(_state().conversations.active.node)).is_equal("end_warm")
	assert_str(screen.transcript.get_texts()[-1]).is_equal(
		"Kindred Elder: Then you are welcome here."
	)
	assert_int(_state().clock.mode).is_equal(ClockState.Mode.HELD)
