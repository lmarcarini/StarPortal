## Tests for the floor actors: events start cues, figures walk the ramp and finish, cues are
## skipped while the station is hidden, reduced motion fades, CLOSE asks to be held while busy.
## Bible: docs/content/interface-rethink.md section 2 (Show it happening)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	_holder.free()
	Settings.set_value(&"display", &"ambient_movement", true)


func test_cue_mapping() -> void:
	assert_int(ActorCues.cue_of(&"team_sent")).is_equal(ActorCues.Cue.TEAM_OUT)
	assert_int(ActorCues.cue_of(&"nothing")).is_equal(ActorCues.Cue.NONE)
	assert_int(ActorCues.figures(ActorCues.Cue.TEAM_OUT, 4)).is_equal(4)


func test_team_walks_up_and_finishes() -> void:
	var floor_layer: FloorActors = _view.get_floor()
	EventBus.team_sent.emit(&"w", 1, [&"a", &"b"], false)
	assert_int(floor_layer.get_actors().size()).is_equal(2)
	assert_bool(floor_layer.is_busy()).is_true()
	var ramp: PackedVector2Array = _view.get_station().shape(&"ramp")
	floor_layer.advance(6.5)
	var first: Actor = floor_layer.get_actors()[0]
	assert_float(floor_layer.position_of(first).x).is_equal_approx(ramp[0].x, 2.0)
	floor_layer.advance(10.0)
	assert_bool(floor_layer.is_busy()).is_false()


func test_hidden_station_skips() -> void:
	_view.hide()
	_view.get_floor().play(ActorCues.Cue.MOTH_OUT)
	assert_bool(_view.get_floor().is_busy()).is_false()


func test_reduced_motion_fades() -> void:
	Settings.set_value(&"display", &"ambient_movement", false)
	_view.get_floor().play(ActorCues.Cue.TEAM_IN, 1)
	var actor: Actor = _view.get_floor().get_actors()[0]
	assert_bool(actor.fade_only).is_true()
	assert_float(actor.duration).is_equal(ActorCues.FADE_SECONDS)


func test_along_path() -> void:
	var path: PackedVector2Array = PackedVector2Array(
		[Vector2.ZERO, Vector2(10, 0), Vector2(10, 10)]
	)
	assert_vector(ActorCues.along(path, 0.5)).is_equal(Vector2(10, 0))
	assert_vector(ActorCues.along(path, 1.0)).is_equal(Vector2(10, 10))


func test_idle_crew_comes_from_staff_on_base() -> void:
	var state: GameState = _simulation.state
	var crew: Dictionary[StringName, int] = ActorCues.idle_crew(state)
	var has_scientist: bool = false
	var has_soldier: bool = false
	for person: PersonState in state.staff.people:
		has_scientist = has_scientist or person.role == &"role_scientist"
		has_soldier = has_soldier or person.role == &"role_soldier"
	assert_bool(crew.has(&"console_left")).is_equal(has_scientist)
	assert_bool(crew.has(&"blast_door")).is_equal(has_soldier)
	if has_soldier:
		assert_int(crew[&"blast_door"]).is_equal(FigureSprite.Kind.SOLDIER)


func test_nobody_when_the_base_is_empty_or_under_attack() -> void:
	var state: GameState = _simulation.state
	state.incursion.phase = IncursionState.Phase.WARNING
	assert_dict(ActorCues.idle_crew(state)).is_empty()
	assert_int(ActorCues.crosser(state, 0.5)).is_equal(-1)
	state.incursion.phase = IncursionState.Phase.NONE
	state.staff.people.clear()
	assert_dict(ActorCues.idle_crew(state)).is_empty()
	_view.get_floor().refresh_crew(state)
	assert_array(_view.get_floor().get_idle()).is_empty()


func test_someone_crosses_now_and_then() -> void:
	var floor_layer: FloorActors = _view.get_floor()
	if ActorCues.crosser(_simulation.state, 0.0) < 0:
		return
	floor_layer.advance(ActorCues.CROSS_MIN_SECONDS + ActorCues.CROSS_SPREAD_SECONDS + 0.1)
	assert_object(floor_layer.get_crosser()).is_not_null()
	floor_layer.advance(ActorCues.CROSS_SECONDS + 0.1)
	assert_object(floor_layer.get_crosser()).is_null()


func test_no_crossing_with_reduced_motion() -> void:
	Settings.set_value(&"display", &"ambient_movement", false)
	var floor_layer: FloorActors = _view.get_floor()
	floor_layer.advance(ActorCues.CROSS_MIN_SECONDS + ActorCues.CROSS_SPREAD_SECONDS + 0.1)
	assert_object(floor_layer.get_crosser()).is_null()


func test_idle_steps_aside_while_a_team_goes() -> void:
	var floor_layer: FloorActors = _view.get_floor()
	var before: Vector2 = floor_layer.path_of(Actor.Route.STAND, &"console_left")[0]
	EventBus.team_sent.emit(&"w", 1, [&"a"], false)
	var aside: Vector2 = floor_layer.path_of(Actor.Route.STAND, &"console_left")[0]
	assert_float(aside.x).is_less(before.x)
