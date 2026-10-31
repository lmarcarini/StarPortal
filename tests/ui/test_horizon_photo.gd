## Tests for the horizon photo beside the Ring: Extend the pole camera gives feedback on the same
## frame (progress card, flash, cue on the Ring; softer with reduced flashing); the record shows
## the photo with its caption and the View button; it can be enlarged by mouse and gamepad and
## shrunk with B; closing the wormhole hides it; a later lock on the same world shows the same
## photo; it fits the minimum window left of the Ring in en and pt_BR.
## Bible: game-design.md#base-building-and-power (pole camera, horizon record),
## docs/content/presentation-and-systems.md (Gate Room)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const ArchiveFixture := preload("res://tests/ui/archive_fixture.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""
var _real_flashing: bool = false


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	_real_flashing = Settings.get_bool(&"accessibility", &"reduced_flashing")
	TranslationServer.set_locale("en")
	var state: GameState = Fixture.simulation().state
	var systems: Array[SimSystem] = [
		PowerSystem.new(state.balance), GateSystem.new(), DocumentSystem.new()
	]
	_simulation = Simulation.new(state, systems)
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)
	Settings.set_value(&"accessibility", &"reduced_flashing", _real_flashing)


func _screen() -> WormholeScreen:
	return _view.get_overlays().get_wormhole_screen()


func _photo() -> HorizonPhoto:
	return _view.get_horizon_photo()


func _dial_lock() -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	_view.get_overlays().get_sequence().skip()
	Fixture.open_actions(_view)
	await get_tree().process_frame


func _take_record() -> void:
	_screen().get_actions().get_camera_button().pressed.emit()
	SimClock.step_ticks(ExtendPoleCameraCommand.EXTEND_TICKS)
	await get_tree().process_frame


func test_extend_gives_feedback_on_the_same_frame() -> void:
	await _dial_lock()
	assert_bool(_photo().visible).is_false()
	_screen().get_actions().get_camera_button().pressed.emit()
	# No frame awaited: the feedback is there at once.
	assert_int(_photo().get_phase()).is_equal(HorizonPhoto.Phase.DEVELOPING)
	assert_bool(_photo().is_visible_in_tree()).is_true()
	assert_float(_photo().get_flash()).is_equal(1.0)
	assert_float(_view.get_camera_cue().get_left()).is_equal(1.0)
	assert_str(_screen().get_actions().get_camera_note()).is_equal("Horizon record in 5 min")


func test_reduced_flashing_softens_the_cue() -> void:
	Settings.set_value(&"accessibility", &"reduced_flashing", true)
	await _dial_lock()
	_screen().get_actions().get_camera_button().pressed.emit()
	assert_float(_photo().get_flash()).is_equal(HorizonPhoto.SOFT_FLASH_PEAK)
	assert_float(_view.get_camera_cue().get_peak()).is_equal(CameraCue.SOFT_PEAK)


func test_the_record_shows_the_photo_until_the_wormhole_closes() -> void:
	await _dial_lock()
	await _take_record()
	var world_id: StringName = _simulation.state.gate.connected_world_id
	assert_int(_photo().get_phase()).is_equal(HorizonPhoto.Phase.PHOTO)
	assert_bool(_photo().get_params().to_array() == _params_of(world_id)).is_true()
	assert_str(_photo().get_caption()).starts_with("Horizon record · P3X-111 · ")
	assert_bool(_screen().get_actions().get_photo_button().visible).is_true()
	Fixture.close_wormhole(_view)
	await get_tree().process_frame
	assert_bool(_photo().visible).is_false()
	# A later lock on the same world shows the same photo, from the world alone.
	_screen().dismiss()
	await _dial_lock()
	assert_int(_photo().get_phase()).is_equal(HorizonPhoto.Phase.PHOTO)
	assert_bool(_photo().get_params().to_array() == _params_of(world_id)).is_true()


func test_enlarge_by_mouse() -> void:
	await _dial_lock()
	await _take_record()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_photo()._gui_input(click)
	assert_bool(_photo().is_enlarged()).is_true()
	assert_vector(_photo().size).is_equal(HorizonPhoto.FRAME_SIZE * HorizonPhoto.ENLARGE_SCALE)
	_photo()._gui_input(click)
	assert_bool(_photo().is_enlarged()).is_false()


func test_enlarge_by_gamepad_and_back_with_b() -> void:
	await _dial_lock()
	await _take_record()
	var button: Button = _screen().get_actions().get_photo_button()
	button.grab_focus()
	await ArchiveFixture.pad(JOY_BUTTON_A)
	assert_bool(_photo().is_enlarged()).is_true()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(_photo())
	await ArchiveFixture.pad(JOY_BUTTON_B)
	assert_bool(_photo().is_enlarged()).is_false()
	assert_object(get_viewport().gui_get_focus_owner()).is_same(button)
	assert_bool(_screen().are_actions_shown()).is_true()


@warning_ignore("unused_parameter")
func test_the_photo_fits_beside_the_ring(
	locale: String, test_parameters: Array = [["en"], ["pt_BR"]]  # gdlint: ignore=unused-argument
) -> void:
	TranslationServer.set_locale(locale)
	await _dial_lock()
	await _take_record()
	await get_tree().process_frame
	var rect: Rect2 = _photo().get_global_rect()
	assert_vector(rect.size).is_equal(HorizonPhoto.FRAME_SIZE)
	assert_bool(_holder.get_global_rect().encloses(rect)).is_true()
	assert_bool(rect.intersects(_view.get_ring_view().get_global_rect())).is_false()
	var strip: Control = _screen().get_node("Column") as Control
	assert_bool(rect.intersects(strip.get_global_rect())).is_false()


func _params_of(world_id: StringName) -> Array:
	return HorizonPhotoRules.params_for(world_id).to_array()
