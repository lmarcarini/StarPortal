## Tests for HorizonPhotoRules: the same world always gives the same photo, across calls and
## with no saved state; twenty worlds give twenty different photos; every value stays in range;
## no sky reads as the event-horizon blue.
## Bible: game-design.md#base-building-and-power (pole camera, horizon record),
## art-and-audio.md (event-horizon blue)
extends GdUnitTestSuite

const WORLDS: int = 20


func _world_ids() -> Array[StringName]:
	var ids: Array[StringName] = [&"world_cairn", &"world_abydos_like"]
	for index: int in WORLDS - ids.size():
		ids.append(StringName("world_%03d" % index))
	return ids


func test_the_same_world_gives_the_same_photo() -> void:
	for id: StringName in _world_ids():
		var first: Array = HorizonPhotoRules.params_for(id).to_array()
		var again: Array = HorizonPhotoRules.params_for(id).to_array()
		assert_bool(first == again).override_failure_message(String(id)).is_true()


func test_a_known_world_gives_recorded_values() -> void:
	# Recorded from a run: String.hash() and the seeded generator are stable across runs, so
	# a change here means every world's photo changed.
	var params: HorizonPhotoRules.Params = HorizonPhotoRules.params_for(&"world_cairn")
	assert_int(params.texture_seed).is_equal(3049494532)
	assert_float(params.horizon).is_equal_approx(0.646447, 0.00001)
	assert_int(params.suns.size()).is_equal(1)


func test_twenty_worlds_give_twenty_different_photos() -> void:
	var seen: Array[Array] = []
	for id: StringName in _world_ids():
		var values: Array = HorizonPhotoRules.params_for(id).to_array()
		assert_bool(seen.has(values)).override_failure_message(String(id)).is_false()
		seen.append(values)
	assert_int(seen.size()).is_equal(WORLDS)


func test_values_stay_in_range() -> void:
	for id: StringName in _world_ids():
		var params: HorizonPhotoRules.Params = HorizonPhotoRules.params_for(id)
		assert_float(params.horizon).is_between(0.4, 0.8)
		assert_int(params.silhouette_kinds.size()).is_between(0, HorizonPhotoRules.MAX_SILHOUETTES)
		assert_int(params.silhouette_x.size()).is_equal(params.silhouette_kinds.size())
		assert_int(params.suns.size()).is_between(1, 2)
		assert_float(params.haze).is_between(0.0, 1.0)


func test_no_sky_is_the_event_horizon_blue() -> void:
	assert_bool(HorizonPhotoRules.is_horizon_blue(EventHorizon.HORIZON_BLUE)).is_true()
	for id: StringName in _world_ids():
		var params: HorizonPhotoRules.Params = HorizonPhotoRules.params_for(id)
		assert_bool(HorizonPhotoRules.is_horizon_blue(params.sky_top)).is_false()
		assert_bool(HorizonPhotoRules.is_horizon_blue(params.sky_bottom)).is_false()
	for step: int in 101:
		var hue: float = HorizonPhotoRules.sky_hue(step / 100.0)
		var in_band: bool = (
			hue > HorizonPhotoRules.BLUE_HUE_MIN and hue < HorizonPhotoRules.BLUE_HUE_MAX
		)
		assert_bool(in_band).is_false()
