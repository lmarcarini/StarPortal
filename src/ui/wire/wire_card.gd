class_name WireCard
extends Control
## One card on the wire (interface-reference.md section 4): 368 x 96 of dark steel, a 6 px
## strip on the left (amber attention, green good news, red danger), a 34 px icon in the
## strip colour, the title (22) and one dim line (17), and up to two 46 x 52 action keys on
## the right, the primary one amber. The full sentence is on the hover card. A key whose
## command would be refused is off with the refusal as its hover reason. A new card slides in
## from the left. Presses go out as [signal action_pressed]; the wire acts on them.
## Bible: docs/content/interface-reference.md section 4

## The player pressed [param action] on this card.
signal action_pressed(card: WireCardData, action: WireAction)

## Card size, in pixels.
const SIZE: Vector2 = Vector2(368, 96)
## Action key size and the most keys a card carries.
const KEY: Vector2 = Vector2(46, 52)
const MAX_KEYS: int = 2
## Seconds of the slide-in.
const SLIDE_SECONDS: float = 0.25
## Kinds that are good news (green strip).
const GOOD: Array[StringName] = [
	&"candidate_waiting", &"research_done", &"site_finished", &"team_returned", &"request_offered"
]

var _data: WireCardData = null
var _line: String = ""
var _keys: Array[RefKey] = []


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS


## Shows [param data] for [param state]; [param fresh] slides it in.
func show_card(data: WireCardData, state: GameState, fresh: bool) -> void:
	_data = data
	name = "Wire_" + data.kind
	_line = WireLine.of(data, state)
	tooltip_text = data.detail
	for key: RefKey in _keys:
		key.queue_free()
	_keys.clear()
	var x: float = SIZE.x - 12.0
	var shown: Array[WireAction] = shown_actions(data)
	for i: int in range(shown.size() - 1, -1, -1):
		x -= KEY.x + 6.0
		var key: RefKey = _key(shown[i], state, i == 0)
		key.position = Vector2(x, 22)
		_keys.push_front(key)
	if fresh:
		_arrive()
	queue_redraw()


## The actions shown as keys: at most two, dismiss last; a card with more actions than
## fit shows its last (go to the screen) action.
static func shown_actions(data: WireCardData) -> Array[WireAction]:
	var slots: int = MAX_KEYS - (1 if data.dismissible else 0)
	var actions: Array[WireAction] = data.actions.slice(0, slots)
	var last: WireAction = null if data.actions.is_empty() else data.actions.back()
	if data.actions.size() > slots and not last.view_id.is_empty():
		actions = [last]
	if data.dismissible:
		actions.append(WireAction.step(&"dismiss", &"dismiss", &"dismiss"))
	return actions


## The card's data.
func get_data() -> WireCardData:
	return _data


## The action keys, in order (dismiss last).
func get_keys() -> Array[RefKey]:
	return _keys.duplicate()


## The strip colour of [param data].
static func strip_of(data: WireCardData) -> Color:
	if data.severity == AlertEntry.ALARM:
		return RefPaint.RED
	return RefPaint.GREEN if GOOD.has(data.kind) else RefPaint.AMBER


func _key(action: WireAction, state: GameState, primary: bool) -> RefKey:
	var key: RefKey = RefKey.new()
	key.name = String(action.id)
	key.icon_id = action.icon_id
	key.size = KEY
	key.style = (
		RefPaint.KeyStyle.AMBER
		if primary and action.special != &"dismiss"
		else RefPaint.KeyStyle.STEEL
	)
	var refusal: StringName = action.refusal(state)
	key.set_help(action.help if refusal.is_empty() else WireText.refusal(refusal))
	key.disabled = not refusal.is_empty()
	key.pressed.connect(func() -> void: action_pressed.emit(_data, action))
	add_child(key)
	return key


func _arrive() -> void:
	var tween: Tween = create_tween()
	modulate.a = 0.0
	var home: float = position.x
	position.x = home - 40.0
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, SLIDE_SECONDS)
	tween.tween_property(self, "position:x", home, SLIDE_SECONDS)


func _draw() -> void:
	if _data == null:
		return
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, SIZE), true, false)
	var strip: Color = strip_of(_data)
	draw_rect(Rect2(2, 2, 6, SIZE.y - 4), strip)
	RefIcons.draw(self, _data.icon_id, Rect2(23, 31, 34, 34), strip)
	RefText.make(RefText.LABEL, 22, RefPaint.TEXT, 2.0).draw(
		self, Vector2(70, 22), tr(_data.title_key)
	)
	RefText.make(RefText.LABEL_MEDIUM, 17, RefPaint.DIM, 1.0).draw(self, Vector2(70, 52), _line)
