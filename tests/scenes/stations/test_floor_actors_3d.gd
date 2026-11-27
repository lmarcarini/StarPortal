## Tests for the 3D floor (M5-04): on a 3D station the floor's people and props are 3D figures
## on fixed paths (the 2D layer draws nothing); a team walks from the blast door up the ramp
## into the horizon; idle staff stand at the consoles; props show while their cue plays.
## Bible: docs/content/interface-reference.md section 7
extends GdUnitTestSuite

const SCENE: PackedScene = preload("res://src/ui/station/station_scene.tscn")

var _station: StationScene = null
var _floor: FloorActors = null


func before_test() -> void:
	Station3D.force_enabled = true
	Station3D.skip_lightmaps = true
	_station = SCENE.instantiate() as StationScene
	add_child(_station)
	_station.size = Vector2(1920, 1080)
	_station.setup(Registry.get_def(&"station_gate") as StationSceneDef)
	_floor = FloorActors.new()
	_station.add_layer(_floor, 35)
	_floor.bind(_station)


func after_test() -> void:
	Station3D.force_enabled = false
	Station3D.skip_lightmaps = false
	_station.free()


func test_the_floor_is_3d() -> void:
	assert_object(_floor.get_floor_3d()).is_not_null()


func test_a_team_walks_from_the_door_up_the_ramp_into_the_horizon() -> void:
	var view: Station3D = _station.get_3d()
	var path: PackedVector3Array = FloorPaths3D.path_of(view, Actor.Route.OUT, &"")
	var door: Vector3 = view.marker(&"door_left").global_position
	assert_float(path[0].distance_to(door)).is_less(0.01)
	assert_float(path[path.size() - 1].z).is_less(path[1].z)
	_floor.play(ActorCues.Cue.TEAM_OUT, 4)
	_floor.advance(3.0)
	_floor.get_floor_3d().refresh()
	# The hall's TeamOnRamp draws teams as staff sprites (M8-04): no mannequins for them.
	assert_int(_floor.get_floor_3d().shown_figures()).is_equal(0)


func test_props_show_while_their_cue_plays() -> void:
	_floor.play(ActorCues.Cue.MOTH_OUT)
	_floor.advance(0.5)
	_floor.get_floor_3d().refresh()
	assert_array(_floor.get_floor_3d().shown_props()).contains([Props.Kind.MOTH])


func test_idle_staff_stand_at_their_spots() -> void:
	var view: Station3D = _station.get_3d()
	var at: Vector3 = FloorPaths3D.path_of(view, Actor.Route.STAND, &"console_left")[0]
	assert_float(at.x).is_less(0.0)
	assert_float(at.y).is_equal(0.0)
