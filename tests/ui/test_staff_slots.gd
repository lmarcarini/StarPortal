## Tests for the staff slots on the Base tab's SELECTED panel: a staffable room lists its
## slots, an empty slot's + offers the matching Unassigned people and assigns through the
## command, a filled slot unassigns, rooms without slots hide them; the beds_needed refusal
## has its words; F5 opens Personnel from the start; and the research time follows staffing.
## Bible: docs/content/m26-staff-and-money.md sections 3 and 6
extends GdUnitTestSuite

const BASE_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const ShellScript := preload("res://src/scenes/shell/shell.gd")

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_root = Control.new()
	_root.size = Vector2(1280, 680)
	_view = (load(BASE_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	add_child(_root)
	var state: GameState = ResearchFixture.state()
	state.clock.is_paused = true
	_simulation = Simulation.new(state)
	EventBus.bind_simulation(_simulation)
	_view.setup(_simulation)


func after_test() -> void:
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func _lab() -> RoomState:
	return PowerFixture.first_room(_simulation.state, ResearchRules.LAB_DEF)


func _texts() -> Array[String]:
	var found: Array[String] = []
	for button: Button in _view.get_staff_slots().buttons():
		found.append(button.text)
	return found


func test_lab_slots_assign_and_unassign() -> void:
	var state: GameState = _simulation.state
	_view.get_plan().select(_lab().id)
	var slots: StaffSlots = _view.get_staff_slots()
	assert_bool(slots.visible).is_true()
	assert_str(slots.lines()[0]).is_equal("Staff 2/4")
	var texts: Array[String] = _texts()
	assert_int(texts.size()).is_equal(3)
	assert_str(texts[2]).is_equal("+ Empty slot")
	slots.buttons()[2].pressed.emit()
	assert_str(slots.lines()[1]).is_equal("No unassigned scientist on base.")
	var person := PersonState.new()
	person.name = "Dr New Hire"
	person.role = StartingStaff.SCIENTIST
	person.skill = 2
	state.staff.add_person(person)
	slots.open_picks()
	assert_array(_texts()).contains(["Dr New Hire  **", "Back"])
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	slots._unhandled_input(cancel)
	assert_bool(slots.is_picking()).is_false()
	assert_str(_texts()[-1]).is_equal("+ Empty slot")
	slots.open_picks()
	slots.buttons()[-1].pressed.emit()
	assert_bool(slots.is_picking()).is_false()
	slots.open_picks()
	slots.buttons()[2].pressed.emit()
	assert_str(person.room_id).is_equal(_lab().id)
	assert_str(slots.lines()[0]).is_equal("Staff 3/4")
	assert_str(_texts()[2]).is_equal("Dr New Hire  ×")
	slots.buttons()[2].pressed.emit()
	assert_bool(person.is_assigned()).is_false()
	assert_str(slots.lines()[0]).is_equal("Staff 2/4")


func test_rooms_without_slots_hide_them() -> void:
	var gate: RoomState = PowerFixture.first_room(_simulation.state, StartingBase.GATE_ROOM_DEF)
	_view.get_plan().select(gate.id)
	assert_bool(_view.get_staff_slots().visible).is_false()


func test_beds_needed_refusal_has_words() -> void:
	var result := CommandResult.fail(&"beds_needed")
	assert_str(BuildText.reason(result, _simulation.state, 0)).is_equal(
		"Beds in use. Dismiss someone first."
	)
	TranslationServer.set_locale("pt_BR")
	assert_str(BuildText.reason(result, _simulation.state, 0)).is_equal(
		"Camas em uso. Dispense alguém antes."
	)


func test_research_time_follows_staffing() -> void:
	var state: GameState = _simulation.state
	var def: ResearchDef = state.research_defs[&"excavation_survey"]
	assert_str(ResearchText.duration(ResearchText.planned_ticks(state, def))).is_equal("2 d")
	StaffFixture.scientists(state, _lab(), [3, 3])
	assert_str(ResearchText.duration(ResearchText.planned_ticks(state, def))).is_equal("1 d")
	for person: PersonState in state.staff.people.duplicate():
		if person.room_id == _lab().id:
			state.staff.remove_person(person.id)
	assert_str(ResearchText.duration(ResearchText.planned_ticks(state, def))).is_equal("8 d")


func test_f5_opens_personnel_from_the_start() -> void:
	var real_saves: String = SaveService.saves_dir
	SaveService.saves_dir = "user://test_staff_slots_%d" % Time.get_ticks_usec()
	var shell: ShellScript = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	shell.new_game_seed = 12345
	var runner: GdUnitSceneRunner = scene_runner(shell)
	await runner.await_input_processed()
	runner.simulate_action_pressed("view_personnel")
	await runner.await_input_processed()
	assert_str(String(shell.view_switcher.current_view_id())).is_equal("personnel")
	var view: PersonnelView = shell.view_switcher.get_view(ViewSwitcher.PERSONNEL) as PersonnelView
	assert_int(view.get_board().rows().size()).is_equal(5)
	shell.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveService.saves_dir))
	SaveService.saves_dir = real_saves
