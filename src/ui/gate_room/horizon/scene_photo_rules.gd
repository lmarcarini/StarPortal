class_name ScenePhotoRules
extends RefCounted
## Pure rules of a photo generated from a WorldScene (SceneNow): the scene's sky colour, sun,
## biome (ground), atmosphere (haze), life (marks on the ground), structures (ruins) and its
## targets (one silhouette each, tagged with the target's id, so a recovered object no longer
## appears). Placement and small variations come from the scene's variation seed, so the same
## scene always gives the same photo. Skies stay muted and never read as the event-horizon blue.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (the pole camera's place; MOTH),
## art-and-audio.md (event-horizon blue)

## Most silhouettes a scene photo shows.
const MAX_SILHOUETTES: int = 5

## Sky top hue, saturation and value per WorldDef.SkyColour; the horizon is lighter.
const _SKY_HSV: Array[Vector3] = [
	Vector3(0.7, 0.12, 0.05),
	Vector3(0.78, 0.35, 0.3),
	Vector3(0.12, 0.08, 0.7),
	Vector3(0.58, 0.38, 0.45),
	Vector3(0.6, 0.03, 0.45),
	Vector3(0.09, 0.4, 0.45),
	Vector3(0.3, 0.3, 0.35),
]
## Sun hue and saturation per WorldDef.Sun (HIDDEN shows none).
const _SUN_HS: Array[Vector2] = [
	Vector2.ZERO, Vector2(0.0, 0.0), Vector2(0.14, 0.5), Vector2(0.07, 0.6), Vector2(0.01, 0.7)
]
## Ground colour per WorldDef.Biome.
const _GROUND: Array[Color] = [
	Color(0.3, 0.27, 0.25),
	Color(0.72, 0.75, 0.78),
	Color(0.62, 0.5, 0.32),
	Color(0.4, 0.42, 0.26),
	Color(0.16, 0.26, 0.15),
]
## Haze per WorldDef.Atmosphere.
const _HAZE: Array[float] = [0.0, 0.15, 0.35, 0.7]
## Life marks per WorldDef.Life.
const _LIFE_MARKS: Array[int] = [0, 0, 8, 12, 14]
## Ruin silhouettes per WorldDef.Structures.
const _RUINS: Array[int] = [0, 0, 1, 1, 2]


## Returns the photo of [param scene]; the same scene always gives the same photo.
static func params_for(scene: WorldScene) -> HorizonPhotoRules.Params:
	var rng := RandomNumberGenerator.new()
	rng.seed = scene.variation_seed
	var params := HorizonPhotoRules.Params.new()
	var sky: Vector3 = _SKY_HSV[scene.sky]
	var hue: float = fposmod(sky.x + rng.randf_range(-0.02, 0.02), 1.0)
	params.sky_top = Color.from_hsv(hue, sky.y, sky.z)
	params.sky_bottom = Color.from_hsv(hue, sky.y * 0.7, minf(sky.z + 0.3, 0.9))
	params.horizon = rng.randf_range(0.52, 0.7)
	params.ground = _GROUND[scene.biome].darkened(rng.randf_range(0.0, 0.2))
	params.streaks = rng.randi_range(3, 9)
	params.texture_seed = rng.randi()
	params.haze = _HAZE[scene.atmosphere]
	params.life_marks = _LIFE_MARKS[scene.life]
	if scene.sun != WorldDef.Sun.HIDDEN:
		var sun: Vector2 = _SUN_HS[scene.sun]
		params.sun_color = Color.from_hsv(sun.x, sun.y, 1.0)
		var y: float = rng.randf_range(0.08, params.horizon * 0.6)
		params.suns.append(Vector3(rng.randf_range(0.1, 0.9), y, rng.randf_range(0.04, 0.08)))
	_add_scenery(params, scene, rng)
	return params


## Index of the silhouette of [param target_id] in [param params]; -1 when it does not show.
static func silhouette_of(params: HorizonPhotoRules.Params, target_id: StringName) -> int:
	if target_id.is_empty():
		return -1
	return params.silhouette_targets.find(target_id)


static func _add_scenery(
	params: HorizonPhotoRules.Params, scene: WorldScene, rng: RandomNumberGenerator
) -> void:
	var kinds: Array[HorizonPhotoRules.Silhouette] = []
	var targets: Array[StringName] = []
	for index: int in _RUINS[scene.structures]:
		kinds.append(HorizonPhotoRules.Silhouette.RUIN)
		targets.append(&"")
	if kinds.is_empty():
		kinds.append(HorizonPhotoRules.Silhouette.ROCK)
		targets.append(&"")
	for target: WorldTarget in scene.targets:
		if kinds.size() >= MAX_SILHOUETTES:
			break
		var is_object: bool = target.is_object
		kinds.append(
			HorizonPhotoRules.Silhouette.OBJECT if is_object else HorizonPhotoRules.Silhouette.ROCK
		)
		targets.append(target.id)
	var count: int = kinds.size()
	for index: int in count:
		params.silhouette_kinds.append(kinds[index])
		params.silhouette_targets.append(targets[index])
		params.silhouette_x.append((index + rng.randf_range(0.2, 0.8)) / float(count))
		var is_target: bool = not targets[index].is_empty()
		var height: float = rng.randf_range(0.05, 0.1) if is_target else rng.randf_range(0.1, 0.24)
		params.silhouette_height.append(height)
