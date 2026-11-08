## Tests for the MOTH scan screen over the Gate Room: Send the MOTH opens it; every scan runs
## from it by mouse and by gamepad (D-pad, A), taking its battery minutes; finished scans say
## "done"; RECALL (or B) flies the drone back and hides the screen; a run that leaves no battery
## for a recall ends in SIGNAL LOST, closed with Close or B; the frame is generated from the
## world scene as it stands now; it refreshes while paused.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH) and section 7 (MOTH scan screen)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var game: GameState = ProbeFixture.state()
	game.galaxy.get_world(ProbeFixture.WORLD_ID).designation = "P3X-111"
	var systems: Array[SimSystem] = [
		PowerSystem.new(game.balance), GateSystem.new(), DocumentSystem.new(), ProbeSystem.new()
	]
	_simulation = Simulation.new(game, systems)
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)
	ProbeFixture.open(_simulation)
	SimClock.pause()
	Fixture.open_actions(_view)
	await get_tree().process_frame


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _moth() -> MothScreen:
	return _view.get_moth_screen()


func _launch() -> void:
	_view.get_overlays().get_wormhole_screen().get_actions().get_moth_button().pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame


func _run(scan: MothRules.Scan, target: StringName = &"") -> void:
	_moth().get_scan_list().get_button(scan, target).pressed.emit()
	SimClock.step_ticks(MothRules.minutes_of(scan))
	await get_tree().process_frame


## Input events are not transported in headless mode, so the gamepad is played as the engine
## does: D-pad down moves focus to the next valid control, A presses the focused button, B
## reaches the screen's unhandled input.
func _push(action: StringName) -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	match action:
		&"ui_down":
			focused.find_next_valid_focus().grab_focus()
		&"ui_accept":
			(focused as BaseButton).pressed.emit()
		_:
			var event := InputEventAction.new()
			event.action = action
			event.pressed = true
			_moth()._unhandled_input(event)
	await get_tree().process_frame


func test_send_the_moth_opens_the_screen_with_focus() -> void:
	assert_bool(_moth().is_open()).is_false()
	await _launch()
	assert_int(_moth().get_phase()).is_equal(MothScreen.Phase.LIVE)
	assert_bool(_moth().is_visible_in_tree()).is_true()
	assert_str(_moth().get_battery_text()).is_equal("20 min left")
	var focused: Control = get_viewport().gui_get_focus_owner()
	assert_object(focused).is_same(_moth().get_scan_list().get_button(MothRules.Scan.LOOK_AROUND))
	assert_bool(_view.get_overlays().get_wormhole_screen().get_actions().get_moth_button().disabled)
	assert_object(_moth().get_frame().get_params()).is_not_null()


func test_every_scan_runs_from_the_screen_and_recall_hides_it() -> void:
	await _launch()
	# While paused the order shows at once: the scan runs, the caption says so.
	_moth().get_scan_list().get_button(MothRules.Scan.LOOK_AROUND).pressed.emit()
	assert_str(_moth().get_frame().get_caption()).is_equal("[ SCANNING: Look around ]")
	SimClock.step_ticks(5)
	await get_tree().process_frame
	assert_str(_moth().get_battery_text()).is_equal("15 min left")
	var close: Button = _moth().get_scan_list().get_button(
		MothRules.Scan.CLOSE_LOOK, ProbeFixture.FOOTPRINTS_ID
	)
	assert_object(close).is_not_null()
	assert_bool(close.disabled).is_false()
	assert_bool(_moth().get_scan_list().get_button(MothRules.Scan.LOOK_AROUND).disabled).is_true()
	await _run(MothRules.Scan.CLOSE_LOOK, ProbeFixture.FOOTPRINTS_ID)
	await _run(MothRules.Scan.RING)
	await _run(MothRules.Scan.SKY)
	assert_str(_moth().get_battery_text()).is_equal("5 min left")
	assert_int(_simulation.state.probes.photos.size()).is_equal(2)
	_moth().get_recall_button().pressed.emit()
	SimClock.step_ticks(2)
	await get_tree().process_frame
	assert_bool(_moth().is_open()).is_false()
	assert_int(_simulation.state.probes.rack).is_equal(MothRules.RACK_SIZE)


func test_gamepad_dpad_and_a_run_a_scan_and_b_recalls() -> void:
	await _launch()
	await _push(&"ui_accept")
	assert_int(_simulation.state.probes.moth.scan).is_equal(MothRules.Scan.LOOK_AROUND)
	SimClock.step_ticks(5)
	await get_tree().process_frame
	_moth().get_scan_list().get_default_focus().grab_focus()
	await _push(&"ui_down")
	await _push(&"ui_accept")
	assert_int(_simulation.state.probes.moth.scan).is_equal(MothRules.Scan.CLOSE_LOOK)
	SimClock.step_ticks(4)
	await _push(&"ui_cancel")
	assert_int(_simulation.state.probes.moth.scan).is_equal(MothRules.Scan.RECALL)


func test_no_battery_for_a_recall_ends_in_signal_lost() -> void:
	await _launch()
	await _run(MothRules.Scan.LOOK_AROUND)
	await _run(MothRules.Scan.CLOSE_LOOK, ProbeFixture.ANCHOR_ID)
	await _run(MothRules.Scan.CLOSE_LOOK, ProbeFixture.FOOTPRINTS_ID)
	await _run(MothRules.Scan.RING)
	assert_bool(_moth().get_recall_button().disabled).is_false()
	await _run(MothRules.Scan.SKY)
	assert_int(_moth().get_phase()).is_equal(MothScreen.Phase.LOST)
	assert_str(_moth().get_frame().get_caption()).is_equal("SIGNAL LOST")
	assert_bool(_moth().get_close_button().is_visible_in_tree()).is_true()
	await get_tree().process_frame
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_moth().get_close_button())
	await _push(&"ui_cancel")
	assert_bool(_moth().is_open()).is_false()


func test_close_button_closes_signal_lost() -> void:
	await _launch()
	_simulation.submit(CloseWormholeCommand.new())
	SimClock.step_ticks(1)
	await get_tree().process_frame
	assert_int(_moth().get_phase()).is_equal(MothScreen.Phase.LOST)
	_moth().get_close_button().pressed.emit()
	assert_bool(_moth().is_open()).is_false()


func test_the_frame_shows_the_world_as_it_is_now() -> void:
	await _launch()
	await _run(MothRules.Scan.LOOK_AROUND)
	var params: HorizonPhotoRules.Params = _moth().get_frame().get_params()
	assert_int(ScenePhotoRules.silhouette_of(params, ProbeFixture.ANCHOR_ID)).is_greater_equal(0)
	_simulation.state.worlds.targets.raise(
		ProbeFixture.WORLD_ID, ProbeFixture.ANCHOR_ID, TargetStates.State.RECOVERED
	)
	_moth().refresh()
	params = _moth().get_frame().get_params()
	assert_int(ScenePhotoRules.silhouette_of(params, ProbeFixture.ANCHOR_ID)).is_equal(-1)


func test_the_horizon_photo_drops_a_recovered_object() -> void:
	_simulation.submit(ExtendPoleCameraCommand.new())
	SimClock.step_ticks(ExtendPoleCameraCommand.EXTEND_TICKS)
	await get_tree().process_frame
	var photo: HorizonPhoto = _view.get_horizon_photo()
	assert_int(photo.get_phase()).is_equal(HorizonPhoto.Phase.PHOTO)
	var anchor: StringName = ProbeFixture.ANCHOR_ID
	assert_int(ScenePhotoRules.silhouette_of(photo.get_params(), anchor)).is_greater_equal(0)
	_simulation.submit(_RecoverCommand.new())
	assert_int(ScenePhotoRules.silhouette_of(photo.get_params(), anchor)).is_equal(-1)


## Stands in for a team's Recover (a later card): raises the anchor to RECOVERED.
class _RecoverCommand:
	extends Command

	func get_type() -> StringName:
		return &"test_recover"

	func validate(_state: GameState) -> CommandResult:
		return CommandResult.ok()

	func apply(state: GameState) -> void:
		WorldProgress.raise_target(
			state, ProbeFixture.WORLD_ID, ProbeFixture.ANCHOR_ID, TargetStates.State.RECOVERED
		)

	func to_dict() -> Dictionary:
		return {"type": "test_recover"}
