class_name RackLook
extends RefCounted
## How the right panel draws (interface-reference.md section 5, right_panel): the plate, the
## header, and the selected destination large: its well, frame (amber, blue while its
## wormhole is open), name, one dim line and status icons. Pure drawing and text.
## Bible: docs/content/interface-reference.md section 5

## The selected destination's picture and the grid, inside the panel.
const PICTURE: Rect2 = Rect2(20, 62, 328, 180)
const GRID: Rect2 = Rect2(14, 362, 340, 314)


## Draws the panel on [param item] for [param selected] (null for none), framed blue when
## [param open], with [param line_text] under its name.
static func draw(item: Control, selected: GateDestination, open: bool, line_text: String) -> void:
	RefPaint.steel_plate(item, Rect2(Vector2.ZERO, item.size), false, true)
	RefIcons.draw(item, &"gate", Rect2(16, 16, 24, 24), RefPaint.AMBER)
	var title: RefText = RefText.make(RefText.LABEL, 24, RefPaint.TEXT, 3.0)
	title.draw(item, Vector2(50, 28), item.tr(&"STATION_DESTINATIONS"), "lm")
	RefPaint.recess(item, Rect2(14, 56, item.size.x - 28, 290))
	if selected == null:
		return
	var frame: Color = RefPaint.BLUE if open else RefPaint.AMBER
	item.draw_rect(PICTURE.grow(-1.5), frame, false, 3.0)
	var name: RefText = RefText.make(RefText.LABEL, 34, RefPaint.TEXT, 3.0)
	name.draw(item, Vector2(24, 256), selected.title.to_upper())
	var line: RefText = RefText.make(RefText.LABEL_MEDIUM, 16, RefPaint.DIM, 1.0)
	line.draw(item, Vector2(26, 296), line_text)
	var icons: Array[StringName] = selected.icons.slice(0, 3)
	for i: int in icons.size():
		var ink: Color = RefPaint.AMBER if icons[i] == &"threat" else RefPaint.GREEN
		var x: float = item.size.x - 108 + i * 34
		RefIcons.draw(item, icons[i], Rect2(x - 11, 263, 22, 22), ink)


## True while the wormhole is open to [param destination]'s world.
static func is_open(state: GameState, destination: GateDestination) -> bool:
	var gate: GateState = state.gate
	if gate.mode != GateState.RingMode.LOCKED or destination.world_id.is_empty():
		return false
	return gate.connected_world_id == destination.world_id


## "LAST 2D AGO", "LAST TODAY" or "NEVER DIALLED" for Address Book entry [param key].
static func line_of(state: GameState, key: String) -> String:
	if state == null:
		return ""
	var entry: AddressEntry = state.address_book.find(key)
	if entry == null or entry.last_dialed_tick < 0:
		return TranslationServer.translate(&"STATION_DEST_NEVER")
	var days: int = (
		TimeMath.day_index(state.clock.tick) - TimeMath.day_index(entry.last_dialed_tick)
	)
	if days <= 0:
		return TranslationServer.translate(&"STATION_DEST_TODAY")
	return TranslationServer.translate(&"STATION_DEST_LAST").format({"n": days})
