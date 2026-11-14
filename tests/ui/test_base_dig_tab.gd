## Regression tests for "no N2 after the research" (card #206) and the Base tab's sub-tabs, in
## the running shell with real keys and gamepad buttons: research R1 on the Research tab, come
## back with F3, and the ghost tab and the Dig entry are available at once; hold Dig, the
## level tab shows the dig, and once dug it is selectable and shows the empty level. Saves go
## to a temporary user:// folder.
## Bible: docs/content/m25-lean-start.md sections 2 and 3, docs/content/m2-base.md section 6
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const SURVEY: StringName = &"excavation_survey"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = "user://test_base_dig_tab_%d" % Time.get_ticks_usec()
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12345
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	var state: GameState = SimClock.simulation.state
	StaffChanges.auto_assign(state, PowerFixture.lab(state))
	state.events.drain()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


## Research R1 with the Base tab hidden, press F3: the Dig entry and the "L2 +" ghost tab are
## available at once; holding Dig shows "L2 0%"; when the dig ends, the L2 tab shows level 2.
func test_research_then_dig_shows_a_selectable_level_tab() -> void:
	var base: BaseView = await _open_base()
	var dig: DigButton = base.get_palette().get_dig_button()
	var tabs: LevelTabs = _level_tabs(base)
	assert_bool(dig.disabled).is_true()
	assert_str(dig.get_reason()).is_equal("Unlock: Excavation survey")
	assert_bool(tabs.next_tab.disabled).is_true()
	await _key(KEY_F3)
	await _finish_survey()
	await _key(KEY_F2)
	assert_bool(dig.disabled).is_false()
	assert_bool(tabs.next_tab.visible).is_true()
	assert_bool(tabs.next_tab.disabled).is_false()
	assert_str(tabs.next_tab.text).is_equal("L2 +")
	dig.confirmed.emit()
	await _runner.await_input_processed()
	assert_int(tabs.level_count()).is_equal(2)
	assert_str((tabs.get_child(1) as Button).text).is_equal("L2 0%")
	assert_bool(tabs.next_tab.visible).is_false()
	var state: GameState = SimClock.simulation.state
	while state.base.digging_level() != 0:
		SimClock.step_ticks(120)
	await _runner.await_input_processed()
	var l2: Button = tabs.get_child(1) as Button
	assert_str(l2.text).is_equal("L2")
	l2.pressed.emit()
	assert_int(base.get_plan().level).is_equal(2)


## The research's Log line says where to dig.
func test_survey_log_line_points_to_the_base_tab() -> void:
	var line: String = ArchiveLogRow.line_for(_log_entry(), SimClock.simulation.state)
	assert_str(line).ends_with("Level 2 can now be dug from the Base tab.")


## P jumps to Energy and back; the shoulders step Build -> Energy, then the main tabs.
func test_p_and_shoulders_switch_sub_tabs() -> void:
	var base: BaseView = await _open_base()
	var sub_tabs: BaseSubTabs = base.get_sub_tabs()
	assert_str(String(sub_tabs.shown())).is_equal("build")
	assert_bool(base.get_palette().visible).is_true()
	assert_bool(base.get_power().strip.visible).is_true()
	await _key(KEY_P)
	assert_str(String(sub_tabs.shown())).is_equal("energy")
	assert_bool(base.get_power().is_layer_on()).is_true()
	assert_bool(base.get_palette().visible).is_false()
	assert_bool(base.get_power().strip.visible).is_true()
	await _key(KEY_P)
	assert_str(String(sub_tabs.shown())).is_equal("build")
	await _joypad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_str(String(sub_tabs.shown())).is_equal("energy")
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("base")
	await _joypad(JOY_BUTTON_LEFT_SHOULDER)
	assert_str(String(sub_tabs.shown())).is_equal("build")
	await _joypad(JOY_BUTTON_LEFT_SHOULDER)
	assert_str(String(_shell.view_switcher.current_view_id())).is_not_equal("base")


## A click on the Energy sub-tab turns the energy layer on.
func test_clicking_energy_turns_the_layer_on() -> void:
	var base: BaseView = await _open_base()
	base.get_sub_tabs().current_tab = 1
	assert_bool(base.get_power().is_layer_on()).is_true()


## Leaving Build with a palette button focused (P, or RB) never leaves focus on nothing.
func test_switching_to_energy_keeps_focus() -> void:
	var base: BaseView = await _open_base()
	for leave: Callable in [_key.bind(KEY_P), _joypad.bind(JOY_BUTTON_RIGHT_SHOULDER)]:
		base.get_sub_tabs().show_tab(BaseSubTabs.BUILD)
		base.get_palette().first_button().grab_focus()
		await leave.call()
		assert_str(String(base.get_sub_tabs().shown())).is_equal("energy")
		var owner: Control = _focus_owner()
		assert_bool(owner != null and owner.is_visible_in_tree()).is_true()


## Esc or (B) on the plan in Energy keeps focus on the plan, never the hidden palette.
func test_cancel_on_the_plan_in_energy_keeps_focus() -> void:
	var base: BaseView = await _open_base()
	await _key(KEY_P)
	base.get_plan().grab_focus()
	await _key(KEY_ESCAPE)
	assert_object(_focus_owner()).is_same(base.get_plan())
	await _joypad(JOY_BUTTON_B)
	assert_object(_focus_owner()).is_same(base.get_plan())


## The message line (power news) shows on the Energy sub-tab too.
func test_message_line_shows_on_energy() -> void:
	var base: BaseView = await _open_base()
	await _key(KEY_P)
	var state: GameState = SimClock.simulation.state
	var lab: RoomState = PowerFixture.lab(state)
	EventBus.charging_lowered.emit(lab.id, 20)
	var line: Control = base.get_palette().message_line
	assert_bool(line.is_visible_in_tree()).is_true()
	assert_str(base.get_palette().get_hint()).contains("20 MW")


## Cancelling a dig with the tab shown rebuilds the level column without reading past it.
func test_cancelling_a_dig_rebuilds_the_level_column() -> void:
	var base: BaseView = await _open_base()
	await _finish_survey()
	await _key(KEY_F2)
	var tabs: LevelTabs = _level_tabs(base)
	var dig: DigButton = base.get_palette().get_dig_button()
	dig.confirmed.emit()
	await _runner.await_input_processed()
	assert_int(tabs.level_count()).is_equal(2)
	dig.confirmed.emit()
	await _runner.await_input_processed()
	assert_int(SimClock.simulation.state.base.digging_level()).is_equal(0)
	assert_int(tabs.level_count()).is_equal(1)
	assert_str(tabs.next_tab.text).is_equal("L2 +")


## LevelTabs.refresh() with fewer levels than tabs (before the rebuild) labels what it can.
func test_level_tabs_refresh_with_a_shorter_level_list() -> void:
	var tabs := LevelTabs.new()
	var levels: Array[LevelState] = [LevelState.new(), LevelState.new()]
	tabs.show_levels(levels, 1)
	levels.pop_back()
	tabs.mark(1)
	assert_bool((tabs.get_child(0) as Button).button_pressed).is_true()
	tabs.free()


func _focus_owner() -> Control:
	return _shell.get_viewport().gui_get_focus_owner()


func _open_base() -> BaseView:
	await _key(KEY_F2)
	return _shell.view_switcher.get_view(&"base") as BaseView


func _level_tabs(base: BaseView) -> LevelTabs:
	return base.find_child("LevelTabs", true, false) as LevelTabs


func _finish_survey() -> void:
	var state: GameState = SimClock.simulation.state
	var result: CommandResult = SimClock.simulation.submit(StartResearchCommand.create(SURVEY))
	assert_bool(result.is_ok).is_true()
	while state.research.is_running():
		SimClock.step_ticks(60)
	await _runner.await_input_processed()


func _log_entry() -> LogEntry:
	return LogEntry.create(0, &"research", &"", {"project_id": String(SURVEY)})


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()


func _joypad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _runner.await_input_processed()
