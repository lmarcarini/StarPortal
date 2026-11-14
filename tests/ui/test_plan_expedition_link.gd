## Tests for the World Report's **Plan expedition** (docs/content/m3-beyond-the-ring.md
## section 7): greyed before the unlock, and once Expeditions unlock a click or (A) opens the
## Expeditions tab (F7) with that world chosen; F7 reaches the tab.
## Bible: docs/content/m3-beyond-the-ring.md section 7 (World Report; gamepad: Worlds)
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"

var _root: Control = null
var _switcher: ViewSwitcher = null
var _simulation: Simulation = null


func before_test() -> void:
	_simulation = Fixture.simulation(Fixture.state())
	EventBus.bind_simulation(_simulation)
	_root = Control.new()
	_root.size = Vector2(1280, 680)
	_switcher = (load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	_root.add_child(_switcher)
	scene_runner(_root)
	_switcher.setup(_simulation)
	await UiInput.settle(_root)


func after_test() -> void:
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()


func _report() -> WorldReportPanel:
	var archive: ArchiveView = _switcher.get_view(ViewSwitcher.ARCHIVE) as ArchiveView
	_switcher.show_view(ViewSwitcher.ARCHIVE)
	archive.show_worlds()
	archive.get_worlds().open_world(Fixture.WORLD_ID)
	return archive.get_worlds().get_report()


func _expeditions() -> ExpeditionsView:
	return _switcher.get_view(ViewSwitcher.EXPEDITIONS) as ExpeditionsView


func test_click_opens_expeditions_with_the_world_chosen() -> void:
	assert_bool(_expeditions().is_available()).is_true()
	var plan: Button = _report().get_plan_button()
	await UiInput.settle(_root)
	assert_bool(plan.disabled).is_false()
	await UiInput.click(plan)
	assert_str(String(_switcher.current_view_id())).is_equal("expeditions")
	var draft: ExpeditionPlanDraft = _expeditions().get_sheet().get_draft()
	assert_str(String(draft.world_id)).is_equal(String(Fixture.WORLD_ID))


func test_gamepad_a_opens_expeditions() -> void:
	var plan: Button = _report().get_plan_button()
	await UiInput.settle(_root)
	await UiInput.pad(plan, JOY_BUTTON_A)
	assert_str(String(_switcher.current_view_id())).is_equal("expeditions")


func test_f7_reaches_the_tab() -> void:
	await UiInput.key(_switcher.get_tab_bar(), KEY_F5)
	assert_str(String(_switcher.current_view_id())).is_equal("expeditions")


func test_greyed_before_the_unlock() -> void:
	_simulation.state.flags.erase(ExpeditionUnlock.FLAG)
	_switcher.setup(_simulation)
	assert_bool(_report().get_plan_button().disabled).is_true()
