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
