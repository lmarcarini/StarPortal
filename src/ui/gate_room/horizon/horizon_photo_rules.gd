class_name HorizonPhotoRules
extends RefCounted
## Pure rules of the horizon photograph (placeholder art drawn in code): a world id gives the
## photo's parameters, always the same for the same world and with no saved state. Sky colour and
## gradient, horizon height, ground tone and texture, 0 to 3 silhouettes (rocks, ruins, the far
## Ring), haze and one or two suns. Skies never use the event-horizon blue, the only saturated
## blue in the game: their hues skip the blue band and stay muted. Authored worlds are derived
## from their id like procedural ones for now.
## Bible: game-design.md#base-building-and-power (pole camera, horizon record),
## art-and-audio.md (event-horizon blue)

## Silhouette kinds.
enum Silhouette { ROCK, RUIN, RING }

## Hues (0 to 1) of the blue band skies never use.
const BLUE_HUE_MIN: float = 0.5
const BLUE_HUE_MAX: float = 0.72
## Most saturation a sky colour can have.
const MAX_SKY_SATURATION: float = 0.4
const MAX_SILHOUETTES: int = 3


## The parameters of one photo. Positions and sizes are fractions of the picture.
class Params:
	extends RefCounted
	## Sky colour at the top and at the horizon.
	var sky_top: Color = Color.BLACK
	var sky_bottom: Color = Color.BLACK
	## Height of the horizon line, from the top.
	var horizon: float = 0.6
	var ground: Color = Color.BLACK
	## Number of ground streaks (texture) and their seed.
	var streaks: int = 0
	var texture_seed: int = 0
	## Each silhouette's kind, centre x and height (fractions).
	var silhouette_kinds: Array[Silhouette] = []
	var silhouette_x: Array[float] = []
	var silhouette_height: Array[float] = []
	## Haze over the horizon, 0 to 1.
	var haze: float = 0.0
	var sun_color: Color = Color.WHITE
	## Each sun: x, y (fractions) and radius (fraction of the picture's height).
	var suns: Array[Vector3] = []

	## Every value as an array, to compare two photos.
	func to_array() -> Array:
		return [
			sky_top,
			sky_bottom,
			horizon,
			ground,
			streaks,
			texture_seed,
			silhouette_kinds,
			silhouette_x,
			silhouette_height,
			haze,
			sun_color,
			suns,
		]


## Returns the photo parameters of [param world_id]; the same id always gives the same ones.
static func params_for(world_id: StringName) -> Params:
	var rng := RandomNumberGenerator.new()
	rng.seed = String(world_id).hash()
	var params := Params.new()
	var hue: float = sky_hue(rng.randf())
	var saturation: float = rng.randf_range(0.12, MAX_SKY_SATURATION)
	params.sky_top = Color.from_hsv(hue, saturation, rng.randf_range(0.12, 0.4))
	params.sky_bottom = Color.from_hsv(
		fposmod(hue + rng.randf_range(-0.06, 0.06), 1.0),
		saturation * 0.7,
		rng.randf_range(0.5, 0.85)
	)
	params.horizon = rng.randf_range(0.48, 0.74)
	params.ground = Color.from_hsv(rng.randf_range(0.02, 0.16), rng.randf_range(0.1, 0.45), 0.3)
	params.streaks = rng.randi_range(3, 9)
	params.texture_seed = rng.randi()
	_add_silhouettes(params, rng)
	params.haze = rng.randf_range(0.0, 0.6)
	params.sun_color = Color.from_hsv(rng.randf_range(0.0, 0.16), rng.randf_range(0.1, 0.5), 1.0)
	_add_suns(params, rng)
	return params


## Maps [param unit] (0 to 1) to a sky hue outside the blue band.
static func sky_hue(unit: float) -> float:
	var span: float = 1.0 - (BLUE_HUE_MAX - BLUE_HUE_MIN)
	return fposmod(BLUE_HUE_MAX + clampf(unit, 0.0, 1.0) * span, 1.0)


## True when [param color] would read as the event-horizon blue.
static func is_horizon_blue(color: Color) -> bool:
	var in_band: bool = color.h >= BLUE_HUE_MIN and color.h <= BLUE_HUE_MAX
	return in_band and color.s > MAX_SKY_SATURATION


static func _add_silhouettes(params: Params, rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(0, MAX_SILHOUETTES)
	for index: int in count:
		var kind: Silhouette = rng.randi_range(0, Silhouette.RING) as Silhouette
		params.silhouette_kinds.append(kind)
		var slot: float = (index + rng.randf_range(0.15, 0.85)) / float(count)
		params.silhouette_x.append(slot)
		params.silhouette_height.append(rng.randf_range(0.08, 0.26))


static func _add_suns(params: Params, rng: RandomNumberGenerator) -> void:
	var count: int = 2 if rng.randf() < 0.3 else 1
	for index: int in count:
		var y: float = rng.randf_range(0.08, params.horizon * 0.7)
		var radius: float = rng.randf_range(0.04, 0.1) / float(index + 1)
		params.suns.append(Vector3(rng.randf_range(0.1, 0.9), y, radius))
