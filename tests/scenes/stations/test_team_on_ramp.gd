## Tests for the staff billboards in the 3D Gate hall (M8-04): the team stands on the ramp,
## walks into the horizon and vanishes; a returning team walks down, the injured slower; the
## facing picks side (mirrored when going left), front or back; sheets are built lazily.
## Bible: docs/content/interface-reference.md section 7; docs/content/portraits.md
extends GdUnitTestSuite

const SCENARIO: String = "res://data/scenarios/scenario_gate_station.json"

var _view: Station3D = null
var _ramp: TeamOnRamp = null
var _ids: Array[StringName] = []


func before_test() -> void:
	Station3D.force_enabled = true
	Station3D.skip_lightmaps = true
	var loaded: Result = SaveService.load_file(SCENARIO, GameDefs.from_registry(Registry))
	var state: GameState = loaded.value
	SimClock.start(Simulation.new(state))
	_view = Station3D.new()
	add_child(_view)
	_view.setup(Registry.get_def(&"station_gate") as StationSceneDef)
	_ramp = _view.get_root().get_node(^"TeamOnRamp") as TeamOnRamp
	_ramp.set_process(false)
	_ids.clear()
	for person: PersonState in state.staff.people:
		if not person.appearance.is_empty() and _ids.size() < 2:
			_ids.append(person.id)


func after_test() -> void:
	Station3D.force_enabled = false
	Station3D.skip_lightmaps = false
	SimClock.stop()
	_view.free()


func _build_all() -> void:
	while StaffSprite3D.pending() > 0:
		StaffSprite3D.build_next()


func test_the_sprite_is_a_lit_y_billboard_about_1_8_m_tall() -> void:
	var sprite := StaffSprite3D.new()
	assert_int(sprite.billboard).is_equal(BaseMaterial3D.BILLBOARD_FIXED_Y)
	assert_bool(sprite.shaded).is_true()
	assert_int(sprite.alpha_cut).is_equal(SpriteBase3D.ALPHA_CUT_DISCARD)
	assert_int(sprite.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_float(sprite.pixel_size * 112.0).is_equal_approx(1.8, 0.01)
	sprite.free()


func test_facing_follows_screen_motion() -> void:
	var basis := Basis.IDENTITY
	assert_dict(StaffSprite3D.direction_of(Vector3(-1, 0, 0), basis)).is_equal(
		{"direction": "side", "left": true}
	)
	assert_str(StaffSprite3D.direction_of(Vector3(1, 0, 0), basis)["direction"]).is_equal("side")
	assert_str(StaffSprite3D.direction_of(Vector3(0, 0, 1), basis)["direction"]).is_equal("front")
	assert_str(StaffSprite3D.direction_of(Vector3(0, 0, -1), basis)["direction"]).is_equal("back")


func test_sheets_are_built_lazily_one_per_call() -> void:
	PortraitCache.clear()
	_ramp.show_ramp_team(_ids)
	assert_int(StaffSprite3D.pending()).is_equal(2)
	assert_bool(_ramp.sprite_of(_ids[0]).visible).is_false()
	StaffSprite3D.build_next()
	assert_int(StaffSprite3D.pending()).is_equal(1)
	_build_all()


func test_the_team_stands_on_the_ramp_and_walks_into_the_horizon() -> void:
	_ramp.show_ramp_team(_ids)
	_build_all()
	var sprite: StaffSprite3D = _ramp.sprite_of(_ids[0])
	assert_bool(sprite.visible).is_true()
	assert_str(String(sprite.animation)).is_equal("idle_back")
	_ramp.send(_ids)
	_ramp.advance(0.5)
	assert_str(String(sprite.animation)).is_equal("walk_back")
	for i: int in 100:
		_ramp.advance(0.1)
	assert_array(_ramp.walkers()).is_empty()
	# Gone through the horizon; in this test the state still has them on base, so the
	# post refresh may stand them at a post instead.
	assert_bool(sprite.visible and not _ids[0] in _ramp.posts().values()).is_false()


func test_a_returning_team_walks_down_the_injured_slower() -> void:
	_ramp.bring_back(_ids, [_ids[1]])
	_build_all()
	for i: int in 30:
		_ramp.advance(0.1)
	var well: StaffSprite3D = _ramp.sprite_of(_ids[0])
	var hurt: StaffSprite3D = _ramp.sprite_of(_ids[1])
	assert_bool(well.visible).is_true()
	assert_float(hurt.speed_scale).is_less(1.0)
	assert_float(well.position.z).is_greater(hurt.position.z)


func test_swapping_the_ramp_team_hides_who_left_it() -> void:
	_ramp.show_ramp_team(_ids)
	_build_all()
	_ramp.show_ramp_team([_ids[0]])
	assert_bool(_ramp.sprite_of(_ids[0]).visible).is_true()
	assert_bool(_ramp.sprite_of(_ids[1]).visible).is_false()
	_ramp.show_ramp_team([])
	assert_bool(_ramp.sprite_of(_ids[0]).visible).is_false()


func test_the_ramp_clears_after_the_grace_without_team_sent() -> void:
	_ramp.show_ramp_team(_ids)
	_build_all()
	_ramp.advance(TeamOnRamp.GRACE * 0.5)
	assert_array(_ramp.ramp_team()).has_size(2)
	_ramp.advance(TeamOnRamp.GRACE)
	assert_array(_ramp.ramp_team()).is_empty()
	var sprite: StaffSprite3D = _ramp.sprite_of(_ids[0])
	assert_bool(sprite.visible and not _ids[0] in _ramp.posts().values()).is_false()


func test_a_person_without_appearance_keeps_a_mannequin() -> void:
	var state: GameState = SimClock.simulation.state
	state.staff.people[0].appearance = {}
	var shown: int = _ramp.send([state.staff.people[0].id, _ids[1]])
	assert_int(shown).is_equal(1)
	assert_object(_ramp.sprite_of(state.staff.people[0].id)).is_null()


func test_a_person_who_leaves_the_roster_loses_the_sprite() -> void:
	_ramp.show_ramp_team(_ids)
	_build_all()
	var state: GameState = SimClock.simulation.state
	for person: PersonState in state.staff.people.duplicate():
		if person.id == _ids[1]:
			state.staff.people.erase(person)
	_ramp.advance(TeamOnRamp.POST_SECONDS + 0.1)
	assert_object(_ramp.sprite_of(_ids[1])).is_null()


func test_a_paused_head_does_not_stall_the_queue() -> void:
	PortraitCache.clear()
	_ramp.show_ramp_team(_ids)
	var head: StaffSprite3D = _ramp.sprite_of(_ids[0])
	head.process_mode = Node.PROCESS_MODE_DISABLED
	await await_idle_frame()
	await await_idle_frame()
	assert_int(StaffSprite3D.pending()).is_equal(0)
	assert_bool(head.is_ready()).is_true()
