## The M4.5 interface pass end to end in the shell: read the top bar, follow an alert, visit
## every tab by key, assign a person by placing and watch the walk finish, open and expand a
## camera, open a wormhole and see the thumbnail, save and load; and pseudo-localisation at
## +30% fits every tab at 1280 × 720.
## Bible: docs/content/interface-pass.md
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const KEYS: Dictionary[StringName, Key] = {
	&"gate_room": KEY_F1,
	&"base": KEY_F2,
	&"personnel": KEY_F4,
	&"archive": KEY_F6,
	&"command": KEY_F7,
}

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _saves: String = ""
var _locale: String = ""


func before_test() -> void:
	_saves = SaveService.saves_dir
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	SaveService.saves_dir = "user://test_m45_flow_%d" % Time.get_ticks_usec()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 45
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	TranslationServer.pseudolocalization_enabled = false
	TranslationServer.set_locale(_locale)
	if is_instance_valid(_shell):
		_shell.free()
	var dir: DirAccess = DirAccess.open(SaveService.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(SaveService.saves_dir.path_join(file_name))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _saves


func _base() -> BaseView:
	return _shell.view_switcher.get_view(ViewSwitcher.BASE) as BaseView


func test_the_interface_pass_end_to_end() -> void:
	var bar: TopBar = _shell.top_bar
	var state: GameState = SimClock.simulation.state
	assert_str(bar.money_label.text).starts_with(MoneyLabel.format_k(state.budget.funds_k))
	assert_str(bar.gate_chip.text).is_equal("GATE: IDLE")
	assert_str(bar.power_readout.text).starts_with("PWR ")
	# Follow an alert.
	bar.toggle_alerts()
	var entries: Array[AlertEntry] = bar.alert_list.entries()
	assert_array(entries).is_not_empty()
	bar.alert_list.alert_chosen.emit(entries[0])
	await _runner.simulate_frames(1)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal(String(entries[0].view_id))
	# Every tab by key.
	for view_id: StringName in KEYS:
		await _runner.simulate_key_pressed(KEYS[view_id])
		assert_str(String(_shell.view_switcher.current_view_id())).is_equal(String(view_id))
	await _place_a_person(state)
	await _camera(state)
	_wormhole(state)
	# Save and load.
	_shell.quick_save()
	var funds: int = state.budget.funds_k
	_shell.quick_load()
	await _runner.simulate_frames(2)
	var loaded: GameState = SimClock.simulation.state
	assert_int(loaded.budget.funds_k).is_equal(funds)
	assert_int(_base().get_plan().staff_layer.tokens().size()).is_equal(
		StaffLayer.on_base(loaded).size()
	)


func _place_a_person(state: GameState) -> void:
	await _runner.simulate_key_pressed(KEY_F2)
	var plan: BasePlan = _base().get_plan()
	var person: PersonState = null
	for candidate: PersonState in StaffLayer.on_base(state):
		if candidate.room_id != &"":
			person = candidate
	assert_object(person).is_not_null()
	var room_id: StringName = person.room_id
	SimClock.simulation.submit(UnassignStaffCommand.create(person.id))
	SimClock.step_ticks(1)
	plan.staff_layer.snap()
	plan.start_placing(person.id)
	assert_bool(plan.staff_layer.assign.allows(room_id)).is_true()
	plan.cursor = state.base.find_room(room_id).origin
	await _runner.simulate_action_pressed(&"ui_accept")
	SimClock.step_ticks(1)
	assert_str(String(state.staff.find_person(person.id).room_id)).is_equal(String(room_id))
	assert_bool(plan.staff_layer.walker.is_moving(person.id)).is_true()
	SimClock.resume()
	for _frame: int in 600:
		if not plan.staff_layer.walker.is_moving(person.id):
			break
		await _runner.simulate_frames(1, 100)
	SimClock.pause()
	assert_bool(plan.staff_layer.walker.is_moving(person.id)).is_false()


func _camera(state: GameState) -> void:
	var room: RoomState = state.base.rooms[0]
	_base().get_plan().show_level(room.level)
	_base().get_plan().select(room.id)
	var camera: RoomCamera = _base().room_camera
	assert_bool(camera.visible).is_true()
	camera.set_expanded(true)
	assert_bool(camera.is_expanded()).is_true()
	await _runner.simulate_action_pressed(&"ui_cancel")
	assert_bool(camera.is_expanded()).is_false()


func _wormhole(state: GameState) -> void:
	state.gate.mode = GateState.RingMode.LOCKED
	state.gate.lock_started_tick = state.clock.tick
	_shell.top_bar.refresh()
	assert_str(String(_shell.top_bar.gate_chip.get_status())).is_equal(String(TopBarText.GATE_OPEN))
	state.gate.mode = GateState.RingMode.IDLE
	_shell.top_bar.refresh()
	assert_str(String(_shell.top_bar.gate_chip.get_status())).is_not_equal(
		String(TopBarText.GATE_OPEN)
	)


func test_pseudo_localisation_fits_every_tab_at_1280() -> void:
	TranslationServer.pseudolocalization_enabled = true
	TranslationServer.reload_pseudolocalization()
	_shell.size = Vector2(1280, 720)
	for view_id: StringName in KEYS:
		_shell.view_switcher.show_view(view_id)
		await _runner.simulate_frames(2)
		var view: Control = _shell.view_switcher.get_view(view_id)
		(
			assert_float(view.get_combined_minimum_size().x)
			. override_failure_message(
				"%s is %d px wide" % [view_id, view.get_combined_minimum_size().x]
			)
			. is_less_equal(1280.0)
		)
	assert_float(_shell.top_bar.size.x).is_less_equal(1280.0)
