class_name Breaker
extends Button
## One breaker of the POWER tray: a dark slot with a lever (up and amber when the room runs,
## down and steel when off; off and dim when it cannot be switched now) and the room's name;
## the refusal or the room's draw on its hover card.
## Bible: docs/content/interface-reference.md section 8

var room_id: StringName = &""
var _title: String = ""
var _on: bool = false
var _card: HoverCard = null


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = PowerTray.BREAKER
	RefKeyLook.clear_boxes(self)


## Shows [param room] of [param state].
func show_room(state: GameState, room: RoomState) -> void:
	room_id = room.id
	var def: RoomDef = state.room_defs.get(room.def_id)
	_title = BuildCardText.title(def)
	_on = room.powered_on
	var locked: String = PowerText.lock_reason(state, room, def)
	disabled = not locked.is_empty()
	var help: String = (
		locked
		if not locked.is_empty()
		else "%s · %s" % [tr(def.name_key), PowerText.mw(def.power_draw_mw)]
	)
	if _card == null:
		_card = HoverCard.attach(self, help)
	else:
		_card.set_text(help)
	queue_redraw()


## True when the lever is up.
func is_on() -> bool:
	return _on


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_polygon(RefPaint.rounded(rect, 6.0), [Color8(22, 23, 20)])
	RefPaint.outline(self, rect, RefPaint.EDGE, 2.0)
	var slot: Rect2 = Rect2(size.x * 0.5 - 12, 8, 24, 52)
	draw_polygon(RefPaint.rounded(slot, 6.0), [Color8(10, 10, 9)])
	var lever: Rect2 = Rect2(size.x * 0.5 - 18, 10 if _on else 34, 36, 24)
	var style: RefPaint.KeyStyle = RefPaint.KeyStyle.AMBER if _on else RefPaint.KeyStyle.STEEL
	RefPaint.key(self, lever, RefPaint.KeyStyle.OFF if disabled and not _on else style)
	var ink: Color = RefPaint.TEXT if _on else RefPaint.DIM
	RefText.make(RefText.LABEL, 14, ink, 1.0).draw(
		self, Vector2(size.x * 0.5, size.y - 10), _title, "mm"
	)
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)
