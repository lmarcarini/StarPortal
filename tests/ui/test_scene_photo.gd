## Tests for the pictures generated from the world scene (ScenePhotoRules, MothFrameRules,
## SceneNow): the same scene gives the same photo; sky, sun, haze and life follow the scene;
## no sky is the event-horizon blue; each target shows as a silhouette until it is recovered;
## each MOTH scan frames the scene its own way.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (the pole camera's place; MOTH)
extends GdUnitTestSuite

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

const _ANCHOR: StringName = ProbeFixture.ANCHOR_ID


func _scene(game: GameState) -> WorldScene:
	return SceneNow.of(game, ProbeFixture.WORLD_ID)


func test_the_same_scene_gives_the_same_photo() -> void:
	var game: GameState = ProbeFixture.state()
	var first: Array = ScenePhotoRules.params_for(_scene(game)).to_array()
	assert_bool(first == ScenePhotoRules.params_for(_scene(game)).to_array()).is_true()


func test_the_photo_follows_the_scene() -> void:
	var scene: WorldScene = _scene(ProbeFixture.state())
	scene.sun = WorldDef.Sun.HIDDEN
	scene.atmosphere = WorldDef.Atmosphere.TOXIC
	scene.life = WorldDef.Life.NONE
	var params: HorizonPhotoRules.Params = ScenePhotoRules.params_for(scene)
	assert_int(params.suns.size()).is_equal(0)
	assert_float(params.haze).is_equal(0.7)
	assert_int(params.life_marks).is_equal(0)
	scene.sun = WorldDef.Sun.RED
	scene.life = WorldDef.Life.PLANTS
	params = ScenePhotoRules.params_for(scene)
	assert_int(params.suns.size()).is_equal(1)
	assert_int(params.life_marks).is_greater(0)


func test_no_sky_is_the_event_horizon_blue() -> void:
	var scene: WorldScene = _scene(ProbeFixture.state())
	for sky: int in WorldDef.SkyColour.size():
		scene.sky = sky as WorldDef.SkyColour
		var params: HorizonPhotoRules.Params = ScenePhotoRules.params_for(scene)
		assert_bool(HorizonPhotoRules.is_horizon_blue(params.sky_top)).is_false()
		assert_bool(HorizonPhotoRules.is_horizon_blue(params.sky_bottom)).is_false()


func test_a_recovered_target_no_longer_appears() -> void:
	var game: GameState = ProbeFixture.state()
	var params: HorizonPhotoRules.Params = ScenePhotoRules.params_for(_scene(game))
	assert_int(ScenePhotoRules.silhouette_of(params, _ANCHOR)).is_greater_equal(0)
	var kind: int = params.silhouette_kinds[ScenePhotoRules.silhouette_of(params, _ANCHOR)]
	assert_int(kind).is_equal(HorizonPhotoRules.Silhouette.OBJECT)
	game.worlds.targets.raise(ProbeFixture.WORLD_ID, _ANCHOR, TargetStates.State.RECOVERED)
	assert_int(_scene(game).targets.size()).is_equal(1)
	params = ScenePhotoRules.params_for(_scene(game))
	assert_int(ScenePhotoRules.silhouette_of(params, _ANCHOR)).is_equal(-1)
	var frame: HorizonPhotoRules.Params = MothFrameRules.params_for(
		_scene(game), MothRules.Scan.CLOSE_LOOK, _ANCHOR
	)
	assert_int(frame.silhouette_kinds.size()).is_equal(0)


func test_each_scan_frames_the_scene() -> void:
	var scene: WorldScene = _scene(ProbeFixture.state())
	var hover: HorizonPhotoRules.Params = MothFrameRules.params_for(scene, MothFrameRules.HOVER)
	var look: HorizonPhotoRules.Params = MothFrameRules.params_for(
		scene, MothRules.Scan.LOOK_AROUND
	)
	assert_bool(hover.silhouette_x == look.silhouette_x).is_false()
	var close: HorizonPhotoRules.Params = MothFrameRules.params_for(
		scene, MothRules.Scan.CLOSE_LOOK, _ANCHOR
	)
	assert_array(close.silhouette_targets).is_equal([_ANCHOR])
	var tallest: float = hover.silhouette_height.max()
	assert_float(close.silhouette_height[0]).is_greater(tallest)
	var sky: HorizonPhotoRules.Params = MothFrameRules.params_for(scene, MothRules.Scan.SKY)
	assert_int(sky.silhouette_kinds.size()).is_equal(0)
	assert_float(sky.horizon).is_greater(0.9)
	var ring: HorizonPhotoRules.Params = MothFrameRules.params_for(scene, MothRules.Scan.RING)
	assert_array(ring.silhouette_kinds).is_equal([HorizonPhotoRules.Silhouette.RING])
