class_name GateMonitorText
extends RefCounted
## What the gate monitor's screen shows for a state (pure): the state line (IDLE, DIALLING,
## INCOMING, SHUTTER, RETURNING, or OPEN · the world), its colour, the time left while open,
## and the Ring drawing.
## Bible: docs/content/interface-reference.md section 4 (gate_monitor)


## The gate status the monitor shows: open while a wormhole is locked, else the top bar's.
static func status_of(state: GameState) -> StringName:
	if state.gate.mode == GateState.RingMode.LOCKED:
		return TopBarText.GATE_OPEN
	return TopBarText.gate_status(state)


## The state line of [param state], upper case.
static func line(state: GameState) -> String:
	var status: StringName = status_of(state)
	if status != TopBarText.GATE_OPEN:
		return _tr("FRAME_MONITOR_" + String(status).to_upper())
	var world: String = AddressBookText.name_of_world(state.gate.connected_world_id, state)
	return _tr("FRAME_MONITOR_OPEN").format({"world": world.to_upper()})


## The colour of the state line.
static func color_of(state: GameState) -> Color:
	match status_of(state):
		TopBarText.GATE_OPEN:
			return RefPaint.BLUE
		TopBarText.GATE_IDLE:
			return RefPaint.DIM
	return RefPaint.AMBER


## "0:42" (hours:minutes) left on the open wormhole of [param state], or "".
static func time_left(state: GameState) -> String:
	if status_of(state) != TopBarText.GATE_OPEN:
		return ""
	var minutes: int = maxi(GateQueries.open_ticks_left(state), 0)
	return "%d:%02d" % [minutes / 60, minutes % 60]


## Draws the screen of [param state] into [param screen] on [param item].
static func draw_screen(item: CanvasItem, screen: Rect2, state: GameState) -> void:
	var o: Vector2 = screen.position
	var centre: Vector2 = o + Vector2(screen.size.x * 0.62, screen.size.y * 0.5)
	var r: float = screen.size.y * 0.36
	item.draw_arc(centre, r + 5.0, 0.0, TAU, 64, Color8(90, 96, 92), 10.0, true)
	if status_of(state) == TopBarText.GATE_OPEN:
		item.draw_circle(centre, r, Color8(60, 150, 230))
		item.draw_circle(centre - Vector2(r, r) * 0.1, r * 0.4, Color8(170, 220, 255))
	RefText.make(RefText.LABEL, 22, RefPaint.GREEN, 3.0).draw(
		item, o + Vector2(14, 16), _tr("FRAME_MONITOR_GATE")
	)
	RefText.make(RefText.LABEL_MEDIUM, 18, color_of(state), 2.0).draw(
		item, o + Vector2(14, 46), line(state)
	)
	RefText.make(RefText.MONO_BOLD, 20, RefPaint.TEXT).draw(
		item, o + Vector2(14, screen.size.y - 18), time_left(state), "lm"
	)


static func _tr(key: String) -> String:
	return TranslationServer.translate(key)
