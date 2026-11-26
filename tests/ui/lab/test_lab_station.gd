## Tests for the Lab station (card #560): regions on layout.json's lab_*, a tab per open
## discipline with a lamp while it has NEW projects, opening a project clears its NEW, the
## board shows only visible projects with edges to what they opened, the panel's START and
## ADD TO QUEUE, a bench per research building (project, queue chips, IDLE) and picking a
## bench as the target; keyboard and gamepad.
## Bible: docs/content/interface-reference.md section 9
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/research/research_view.tscn"
const SIZE: Vector2 = Vector2(1920, 1080)
const TOLERANCE: float = 4.0

var _root: Control = null
var _view: ResearchView = null
var _runner: GdUnitSceneRunner = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var state: GameState = ResearchFixture.state()
	state.budget.funds_k = 100000
	_simulation = Simulation.new(state)
	_root = Control.new()
	_root.size = SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as ResearchView
	_root.add_child(_view)
	_view.size = SIZE
	_runner = scene_runner(_root)
	_view.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_view.size = SIZE
	_view.setup(_simulation)
	await _runner.await_input_processed()


func after_test() -> void:
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func _state() -> GameState:
	return _simulation.state


func _near(control: Control, region: StringName) -> void:
	var want: Rect2 = LabLayout.REGIONS[region]
	var got: Rect2 = control.get_rect()
	var diffs: Array[float] = [
		got.position.x - want.position.x,
		got.position.y - want.position.y,
		got.size.x - want.size.x,
		got.size.y - want.size.y,
	]
	for diff: float in diffs:
		assert_float(absf(diff)).is_less_equal(TOLERANCE)


func _ids(defs: Array[ResearchDef]) -> Array[StringName]:
	var found: Array[StringName] = []
	for def: ResearchDef in defs:
		found.append(def.id)
	return found


func _tile_ids() -> Array[StringName]:
	var found: Array[StringName] = []
	for tile: LabTile in _view.get_board().tiles():
		found.append(tile.project_id)
	return found


func test_regions_match_layout_json() -> void:
	_near(_view.get_tabs(), &"lab_tabs")
	_near(_view.get_board(), &"lab_board")
	_near(_view.get_panel(), &"lab_panel")
	_near(_view.get_benches(), &"lab_benches")
	var json: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://docs/reference/layout.json")
	)
	for id: StringName in LabLayout.REGIONS:
		var entry: Dictionary = json[String(id)]
		var r: Rect2 = LabLayout.REGIONS[id]
		var x: float = entry["x"]
		var y: float = entry["y"]
		var w: float = entry["w"]
		var h: float = entry["h"]
		assert_that(r).is_equal(Rect2(x, y, w, h))


func test_tabs_only_for_open_disciplines() -> void:
	var tabs: LabTabs = _view.get_tabs()
	assert_array(tabs.disciplines()).is_equal(ResearchRules.open_disciplines(_state()))
	assert_bool(tabs.disciplines().has(&"xenotech")).is_false()
	ResearchFixture.bench_for(_state(), &"xenotech")
	_view.refresh()
	assert_bool(tabs.disciplines().has(&"xenotech")).is_true()
	assert_str(tabs.key_of(&"xenotech").get_name_text()).is_equal("XENOTECH")


func test_board_shows_only_visible_projects() -> void:
	for discipline: StringName in ResearchRules.open_disciplines(_state()):
		_view.show_discipline(discipline)
		assert_array(_tile_ids()).is_equal(
			_ids(ResearchRules.visible_projects(_state(), discipline))
		)
		for def: ResearchDef in _state().research_defs.values():
			if not ResearchRules.visible(_state(), def):
				assert_object(_view.get_board().tile_of(def.id)).is_null()


func test_new_lamp_and_opening_clears_it() -> void:
	var def: ResearchDef = ResearchRules.visible_projects(_state(), &"science")[0]
	_state().research.revealed.append(def.id)
	_view.refresh()
	assert_bool(_view.get_tabs().key_of(&"science").has_new).is_true()
	assert_bool(_view.needs_attention()).is_true()
	_view.show_discipline(&"engineering")
	assert_object(_view.get_board().tile_of(def.id)).is_null()
	_view.select_project(def.id)
	assert_str(String(_view.get_discipline())).is_equal("science")
	assert_bool(_state().research.opened.has(def.id)).is_true()
	assert_bool(_view.get_tabs().key_of(&"science").has_new).is_false()
	assert_bool(_view.needs_attention()).is_false()
	assert_int(_view.get_board().tile_of(def.id).get_status()).is_not_equal(LabText.Status.NEW)


func test_start_and_add_to_queue_from_the_panel() -> void:
	_view.show_discipline(&"science")
	var defs: Array[ResearchDef] = ResearchRules.visible_projects(_state(), &"science")
	var first: StringName = defs[0].id
	_view.select_project(first)
	_view.get_panel().start_key.pressed.emit()
	assert_str(String(_state().research.room_running(first))).is_not_empty()
	assert_str(_view.get_panel().start_key.label).is_equal("LAB_CANCEL")
	assert_bool(_view.get_panel().queue_key.disabled).is_true()
	var bench: LabBench = _view.get_benches().benches()[0]
	assert_bool(bench.is_idle()).is_false()
	assert_str(bench.texts()[2]).is_not_empty()
	var other: ResearchDef = _second_available(&"engineering")
	assert_object(other).is_not_null()
	_view.select_project(other.id)
	_view.get_panel().queue_pressed.emit(other.id)
	assert_str(String(_state().research.room_queuing(other.id))).is_not_empty()
	assert_str(_view.get_board().tile_of(other.id).texts()[1]).is_equal("QUEUED 1")


func _second_available(discipline: StringName) -> ResearchDef:
	ResearchFixture.workshop(_state())
	_view.refresh()
	var defs: Array[ResearchDef] = ResearchRules.visible_projects(_state(), discipline)
	if defs.size() < 2:
		return null
	var room: StringName = ResearchRules.pick_room(_state(), defs[0])
	ConstructionFixture.run(_state(), StartResearchCommand.create(defs[0].id, room))
	_view.refresh()
	return defs[1]


func test_cancel_while_running() -> void:
	var id: StringName = ResearchRules.visible_projects(_state(), &"science")[0].id
	_view.start(id)
	assert_bool(_state().research.is_running()).is_true()
	_view.start(id)
	assert_bool(_state().research.room_running(id).is_empty()).is_true()


func test_benches_one_per_building_and_idle() -> void:
	var rooms: Array[RoomState] = LabBenches.buildings(_state())
	assert_int(_view.get_benches().benches().size()).is_equal(rooms.size())
	var bench: LabBench = _view.get_benches().benches()[0]
	assert_bool(bench.is_idle()).is_true()
	assert_str(bench.texts()[0]).is_equal("RESEARCH LAB")
	assert_str(bench.texts()[1]).ends_with("SCI.")


func test_picked_bench_is_the_target() -> void:
	PowerFixture.load_room_defs(_state())
	var second: RoomState = _state().base.add_room(&"room_research_lab", 1, Vector2i(30, 2))
	_view.refresh()
	var benches: Array[LabBench] = _view.get_benches().benches()
	assert_int(benches.size()).is_equal(2)
	assert_str(benches[1].texts()[0]).is_equal("RESEARCH LAB 2")
	benches[1].pressed.emit()
	assert_str(String(_view.get_benches().get_target())).is_equal(String(second.id))
	assert_bool(_view.get_benches().benches()[1].target).is_true()
	var id: StringName = ResearchRules.visible_projects(_state(), &"science")[0].id
	_view.start(id)
	assert_str(String(_state().research.room_running(id))).is_equal(String(second.id))


func test_keyboard_enter_on_a_tile_starts_it() -> void:
	_view.show_discipline(&"science")
	var tile: LabTile = _view.get_board().first_tile()
	tile.grab_focus()
	await _runner.await_input_processed()
	assert_str(String(_view.get_panel().get_project())).is_equal(String(tile.project_id))
	_runner.simulate_action_pressed("ui_accept")
	await _runner.await_input_processed()
	assert_str(String(_state().research.room_running(tile.project_id))).is_not_empty()


func test_gamepad_shoulders_step_disciplines() -> void:
	var open: Array[StringName] = ResearchRules.open_disciplines(_state())
	_view.show_discipline(open[0])
	assert_bool(_view.step_discipline(-1)).is_false()
	assert_bool(_view.step_discipline(1)).is_true()
	assert_str(String(_view.get_discipline())).is_equal(String(open[1]))
	assert_bool(_view.step_discipline(open.size())).is_false()


func test_tab_key_press_shows_its_discipline() -> void:
	_view.get_tabs().key_of(&"science").pressed.emit()
	assert_str(String(_view.get_discipline())).is_equal("science")
	assert_int(_view.get_tabs().key_of(&"science").style).is_equal(RefPaint.KeyStyle.AMBER)


func test_wire_new_research_card() -> void:
	assert_object(WireRules.new_research(_state())).is_null()
	var def: ResearchDef = ResearchRules.visible_projects(_state(), &"science")[0]
	_state().research.revealed.append(def.id)
	var card: WireCardData = WireRules.new_research(_state())
	assert_object(card).is_not_null()
	assert_str(card.detail).is_equal("Science · 1")
	assert_str(String(card.actions[0].sub_tab)).is_equal("science")
	_state().research.opened.append(def.id)
	assert_object(WireRules.new_research(_state())).is_null()
