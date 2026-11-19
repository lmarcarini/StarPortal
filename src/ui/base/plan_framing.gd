class_name PlanFraming
extends RefCounted
## Frames the Base plan on the lit table (interface-reference.md section 8): 80 px per cell,
## cell lines snapped to base_plan_grid, centred on the level's rooms or on one room.
## Bible: docs/content/interface-reference.md section 8


## Zooms [param plan] to 80 px cells and centres the shown level's rooms (no corridors).
static func frame(plan: BasePlan, base: BaseState, defs: Dictionary) -> void:
	_zoom(plan, base)
	var box: Rect2i = Rect2i()
	for room: RoomState in BaseRules.rooms_on_level(base, plan.level):
		var def: RoomDef = defs.get(room.def_id)
		if def != null and room.def_id != StartingBase.CORRIDOR_DEF:
			var cells: Rect2i = BaseRules.footprint(room, def)
			box = cells if box.size == Vector2i.ZERO else box.merge(cells)
	_centre(plan, Vector2(box.get_center()) * BasePlanPainter.CELL)


## Centres [param plan] on room [param id].
static func centre_on(plan: BasePlan, base: BaseState, defs: Dictionary, id: StringName) -> void:
	var room: RoomState = base.find_room(id)
	var def: RoomDef = null if room == null else defs.get(room.def_id)
	if def == null:
		return
	_centre(plan, Vector2(BaseRules.footprint(room, def).get_center()) * BasePlanPainter.CELL)


static func _zoom(plan: BasePlan, base: BaseState) -> void:
	var image: Vector2 = Vector2(base.grid_size) * BasePlanPainter.CELL
	var size: Vector2 = plan.size
	var fit: float = minf(size.x / image.x, size.y / image.y) if size.x > 0.0 else 1.0
	var zoom: float = BasePlan.CELL_PX / BasePlanPainter.CELL / fit
	plan.view.zoom = clampf(zoom, ZoomPan.MIN_ZOOM, ZoomPan.MAX_ZOOM)


static func _centre(plan: BasePlan, centre: Vector2) -> void:
	plan.view.offset = plan.size * 0.5 - centre * plan.view.scale()
	plan.view.pan(Vector2.ZERO)
	var origin: Vector2 = BasePlan.GRID_ORIGIN
	plan.view.offset = (
		((plan.view.offset - origin) / BasePlan.CELL_PX).round() * BasePlan.CELL_PX + origin
	)
	plan.queue_redraw()
