## Tests for reaching the Research tab: hidden, skipped and deaf to F4 until a Research Lab
## has finished, then reached with F4 and the tab cycle; and the palette's note on a second
## Research Lab. Saves go to a temporary user:// folder, never user://saves.
## Bible: docs/content/m25-lean-start.md section 3
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const BASE_SCENE: String = "res://src/ui/views/base/base_view.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = "user://test_research_tab_%d" % Time.get_ticks_usec()
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12345
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.saves_dir))
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


func test_tab_appears_once_a_lab_has_finished() -> void:
	var switcher: ViewSwitcher = _shell.view_switcher
	var tabs: TabBar = switcher.get_tab_bar()
	var index: int = switcher.get_view_ids().find(ViewSwitcher.RESEARCH)
	assert_int(index).is_equal(2)
	assert_bool(tabs.is_tab_hidden(index)).is_true()
	await _press(&"view_research")
	assert_str(String(switcher.current_view_id())).is_equal("gate_room")
	await _press(&"view_base")
	await _press(&"view_next")
	assert_str(String(switcher.current_station())).is_equal("office")
	PowerFixture.lab(SimClock.simulation.state)
	EventBus.room_built.emit(&"lab")
	assert_bool(switcher.is_station_available(&"lab")).is_true()
	assert_str(tabs.get_tab_title(index)).is_equal("Research")
	await _press(&"view_research")
	assert_str(String(switcher.current_view_id())).is_equal("research")
	await _press(&"view_next")
	assert_str(String(switcher.current_station())).is_equal("office")


func test_header_is_current_when_the_tab_opens() -> void:
	var simulation: Simulation = SimClock.simulation
	StaffChanges.auto_assign(simulation.state, PowerFixture.lab(simulation.state))
	EventBus.room_built.emit(&"lab")
	simulation.state.clock.is_paused = true
	simulation.submit(StartResearchCommand.create(&"excavation_survey"))
	simulation.state.clock.is_paused = false
	await _press(&"view_base")
	for _tick: int in TimeMath.TICKS_PER_DAY + 6 * 60:
		simulation.advance_tick()
	simulation.state.clock.is_paused = true
	await _press(&"view_research")
	var view: ResearchView = _shell.view_switcher.get_view(ViewSwitcher.RESEARCH) as ResearchView
	assert_str(view.get_board().header()[2]).is_equal("18 h left")
	assert_float(view.get_board().get_bar().value).is_equal_approx(0.625, 0.001)


func test_palette_notes_a_second_lab() -> void:
	var root := Control.new()
	root.size = Vector2(1280, 640)
	var view: BaseView = (load(BASE_SCENE) as PackedScene).instantiate() as BaseView
	root.add_child(view)
	add_child(root)
	var state: GameState = ResearchFixture.state(false)
	ConstructionFixture.unlock_all(state)
	var simulation := Simulation.new(state)
	view.setup(simulation)
	var palette: BuildPalette = view.get_palette()
	var button: Button = palette.get_room_button(ResearchRules.LAB_DEF)
	button.mouse_entered.emit()
	assert_bool(palette.get_role().contains("More labs hold")).is_false()
	PowerFixture.lab(state)
	EventBus.room_built.emit(&"lab")
	button = palette.get_room_button(ResearchRules.LAB_DEF)
	button.focus_entered.emit()
	assert_str(palette.get_role()).ends_with("More labs hold more scientists.")
	assert_bool(button.disabled).is_false()
	root.free()


func _press(action: StringName) -> void:
	_runner.simulate_action_pressed(String(action))
	await _runner.await_input_processed()
