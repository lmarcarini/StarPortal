class_name HorizonPainter
extends RefCounted
## Draws a horizon photograph from HorizonPhotoRules.Params onto a CanvasItem, inside a rect:
## a banded sky gradient, suns, silhouettes, a haze band and a streaked ground. Cheap for the
## Compatibility renderer: a few dozen rects and polygons, no shader, no texture.
## Bible: game-design.md#base-building-and-power (pole camera, horizon record)

const _SKY_BANDS: int = 12
const _SILHOUETTE_COLOR: Color = Color(0.07, 0.07, 0.08)
const _RING_POINTS: int = 24


## Draws the photo of [param params] on [param canvas] inside [param rect].
static func paint(canvas: CanvasItem, rect: Rect2, params: HorizonPhotoRules.Params) -> void:
	var horizon_y: float = rect.position.y + rect.size.y * params.horizon
	_paint_sky(canvas, rect, horizon_y, params)
	for sun: Vector3 in params.suns:
		var center := rect.position + Vector2(sun.x, sun.y) * rect.size
		canvas.draw_circle(center, sun.z * rect.size.y * 1.8, Color(params.sun_color, 0.18))
		canvas.draw_circle(center, sun.z * rect.size.y, params.sun_color)
	for index: int in params.silhouette_kinds.size():
		_paint_silhouette(canvas, rect, horizon_y, [params, index])
	var haze := Rect2(
		rect.position.x, horizon_y - rect.size.y * 0.08, rect.size.x, rect.size.y * 0.1
	)
	canvas.draw_rect(haze, Color(params.sky_bottom.lightened(0.3), params.haze * 0.6))
	_paint_ground(canvas, rect, horizon_y, params)


static func _paint_sky(
	canvas: CanvasItem, rect: Rect2, horizon_y: float, params: HorizonPhotoRules.Params
) -> void:
	var band: float = (horizon_y - rect.position.y) / _SKY_BANDS
	for index: int in _SKY_BANDS:
		var color: Color = params.sky_top.lerp(params.sky_bottom, index / float(_SKY_BANDS - 1))
		var top: float = rect.position.y + band * index
		canvas.draw_rect(Rect2(rect.position.x, top, rect.size.x, band + 1.0), color)


static func _paint_ground(
	canvas: CanvasItem, rect: Rect2, horizon_y: float, params: HorizonPhotoRules.Params
) -> void:
	var bottom: float = rect.end.y
	canvas.draw_rect(
		Rect2(rect.position.x, horizon_y, rect.size.x, bottom - horizon_y), params.ground
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = params.texture_seed
	for index: int in params.streaks:
		var y: float = lerpf(horizon_y + 2.0, bottom - 2.0, rng.randf())
		var depth: float = (y - horizon_y) / maxf(bottom - horizon_y, 1.0)
		var width: float = rect.size.x * rng.randf_range(0.1, 0.4) * (0.4 + depth)
		var x: float = rect.position.x + rng.randf() * (rect.size.x - width)
		var tone: Color = (
			params.ground.darkened(0.25) if index % 2 == 0 else params.ground.lightened(0.15)
		)
		canvas.draw_rect(Rect2(x, y, width, 1.0 + depth * 3.0), tone)


## [param item] is [Params, silhouette index], to stay within four arguments.
static func _paint_silhouette(
	canvas: CanvasItem, rect: Rect2, horizon_y: float, item: Array
) -> void:
	var params: HorizonPhotoRules.Params = item[0]
	var index: int = item[1]
	var x: float = rect.position.x + params.silhouette_x[index] * rect.size.x
	var height: float = params.silhouette_height[index] * rect.size.y
	match params.silhouette_kinds[index]:
		HorizonPhotoRules.Silhouette.ROCK:
			var points := PackedVector2Array(
				[
					Vector2(x - height, horizon_y + 1.0),
					Vector2(x - height * 0.3, horizon_y - height),
					Vector2(x + height * 0.4, horizon_y - height * 0.7),
					Vector2(x + height * 1.1, horizon_y + 1.0),
				]
			)
			canvas.draw_colored_polygon(points, _SILHOUETTE_COLOR)
		HorizonPhotoRules.Silhouette.RUIN:
			var column: float = height * 0.25
			for step: int in 3:
				var tall: float = height * (1.0 - 0.3 * (step % 2))
				var left: float = x + (step - 1) * column * 1.6
				canvas.draw_rect(
					Rect2(left, horizon_y - tall, column, tall + 1.0), _SILHOUETTE_COLOR
				)
		HorizonPhotoRules.Silhouette.RING:
			var radius: float = height * 0.5
			var center := Vector2(x, horizon_y - radius)
			canvas.draw_arc(
				center, radius, 0.0, TAU, _RING_POINTS, _SILHOUETTE_COLOR, maxf(radius * 0.3, 2.0)
			)
