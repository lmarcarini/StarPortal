class_name PowerTray
extends Control
## The Base console's POWER tray (interface-reference.md section 8): the supply line
## ("SUPPLY 30 MW · USED 25 · CHARGING 5") and one breaker per switchable room on the base:
## a slot with a lever (up and amber when on, down and steel when off) and the room's name.
## A press asks to toggle the room ([signal toggle_requested]; the view submits the existing
## power switch command). Scrolls with a tray arrow when the breakers do not fit.
## Bible: docs/content/interface-reference.md section 8

signal toggle_requested(room_id: StringName)

## Breaker size and pitch, in pixels.
const BREAKER: Vector2 = Vector2(96, 84)
const PITCH: float = 112.0

var _scroll: ScrollContainer = ScrollContainer.new()
var _row: HBoxContainer = HBoxContainer.new()
var _line: String = ""
var _poll: float = 0.0
var _news: String = ""


## Shows [param text] (the latest power news) after the supply line.
func show_news(text: String) -> void:
	_news = text
	queue_redraw()


## The news shown, or "".
func get_news() -> String:
	return _news


func _init() -> void:
	name = &"PowerTray"
	custom_minimum_size = Vector2(0, 136)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.position = Vector2(8, 36)
	_row.add_theme_constant_override(&"separation", int(PITCH - BREAKER.x))
	_scroll.add_child(_row)
	add_child(_scroll)
	TrayArrow.new().attach(_scroll)
	resized.connect(func() -> void: _scroll.size = Vector2(size.x - 8, BREAKER.y + 8))


## Shows [param state]'s supply line and breakers.
func show_state(state: GameState) -> void:
	_line = PowerTrayText.line(state)
	var rooms: Array[RoomState] = PowerTrayText.switchable(state)
	while _row.get_child_count() > rooms.size():
		var extra: Node = _row.get_child(_row.get_child_count() - 1)
		_row.remove_child(extra)
		extra.queue_free()
	while _row.get_child_count() < rooms.size():
		var breaker: Breaker = Breaker.new()
		breaker.pressed.connect(func() -> void: toggle_requested.emit(breaker.room_id))
		_row.add_child(breaker)
	for i: int in rooms.size():
		var breaker: Breaker = _row.get_child(i) as Breaker
		breaker.show_room(state, rooms[i])
	queue_redraw()


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0 or not is_visible_in_tree() or SimClock.simulation == null:
		return
	_poll = 0.25
	show_state(SimClock.simulation.state)


## The breakers, in order.
func get_breakers() -> Array[Breaker]:
	var out: Array[Breaker] = []
	for child: Node in _row.get_children():
		out.append(child as Breaker)
	return out


func _draw() -> void:
	var supply: RefText = RefText.make(RefText.LABEL, 18, RefPaint.TEXT, 2.0)
	supply.draw(self, Vector2(16, 18), _line, "lm")
	var news: RefText = RefText.make(RefText.LABEL_MEDIUM, 16, RefPaint.AMBER, 1.0)
	news.draw(self, Vector2(32 + supply.width(_line), 18), _news, "lm")
