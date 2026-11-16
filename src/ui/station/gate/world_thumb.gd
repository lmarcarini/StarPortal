class_name WorldThumb
extends Control
## A small picture of a world for a destination card: its sky and ground from the horizon
## photo's rules once the base has seen it through the gate, else a generic dark frame with
## the Ring's mark (an address never reached).
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations)

var _params: HorizonPhotoRules.Params = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 68)


## Shows [param world_id] (&"" for a never-reached address).
func show_world(world_id: StringName) -> void:
	_params = null if world_id.is_empty() else HorizonPhotoRules.params_for(world_id)
	queue_redraw()


## True when a world's picture is drawn (not the generic frame).
func has_picture() -> bool:
	return _params != null


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	if _params == null:
		draw_rect(r, Color("#1b1c1a"))
		HardwareIcons.draw(self, &"gate", Rect2(size * 0.3, size * 0.4), Color("#4a4740"))
		return
	var horizon_y: float = size.y * _params.horizon
	var sky: PackedColorArray = PackedColorArray(
		[_params.sky_top, _params.sky_top, _params.sky_bottom, _params.sky_bottom]
	)
	var sky_pts: PackedVector2Array = PackedVector2Array(
		[Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, horizon_y), Vector2(0, horizon_y)]
	)
	draw_polygon(sky_pts, sky)
	draw_rect(Rect2(0, horizon_y, size.x, size.y - horizon_y), _params.ground)
	for sun: Vector3 in _params.suns:
		draw_circle(Vector2(sun.x, sun.y) * size, maxf(2.0, sun.z * size.y), _params.sun_color)
