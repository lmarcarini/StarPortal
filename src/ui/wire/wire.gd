class_name Wire
extends Control
## The wire (interface-reference.md section 4; interface-rethink.md section 6): a column of
## event cards top left, 368 px wide, cards 96 high and 10 px apart. Each card carries its own
## action keys; at most [constant VISIBLE] show, then a +N key (the older cards) that opens
## the full log.
## Event cards can be dismissed; condition cards go when their cause does. It never pauses
## the game. A key's command is submitted here (the UI builds commands, never mutates);
## screens and the shell's own steps (rescue, report) go out as signals.
## Bible: docs/content/interface-rethink.md sections 3 and 6

## Asks to show [param view_id] on [param sub_tab].
signal open_view(view_id: StringName, sub_tab: StringName)
## Asks the shell to run [param step] (&"rescue", &"report") for [param card].
signal step_requested(step: StringName, card: WireCardData)
## The stack was pressed: open the full log.
signal log_requested
## A GO TO key of an alert's card: the shell opens its screen and selects its target.
signal entry_chosen(entry: AlertEntry)

## Screens that cover the station whole (the alien panel, the MOTH screen, the team report)
## join this group; the wire hides while one is shown.
const COVER_GROUP: StringName = &"covers_frame"
## Width of the wire's column, in pixels.
const WIDTH: float = 368.0
## Gap between two cards, in pixels.
const GAP: float = 10.0
## Size of the +N key.
const STACK_SIZE: Vector2 = Vector2(120, 44)
## Cards shown at most; the rest are in the stack.
const VISIBLE: int = 5

## The alerts the wire reads (the old alert list, now a model only).
var alerts: AlertList = null

var _simulation: Simulation = null
var _cards: Array[WireCardData] = []
var _shown: Dictionary[String, bool] = {}
var _signature: String = ""
var _dismissed: Dictionary[String, bool] = {}
var _stack: RefKey = RefKey.new()
var _column: Control = Control.new()


func _init() -> void:
	name = &"Wire"
	size = Vector2(WIDTH, (WireCard.SIZE.y + GAP) * VISIBLE + STACK_SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_stack.name = "WireStack"
	_stack.size = STACK_SIZE
	_stack.label_size = 20
	_stack.visible = false
	_stack.pressed.connect(log_requested.emit)
	add_child(_stack)


func _ready() -> void:
	_stack.set_help("WIRE_STACK")


func _enter_tree() -> void:
	for signal_name: StringName in _signals():
		EventBus.connect(signal_name, _on_event)


func _exit_tree() -> void:
	for signal_name: StringName in _signals():
		EventBus.disconnect(signal_name, _on_event)


func _process(_delta: float) -> void:
	var covered: bool = false
	for node: Node in get_tree().get_nodes_in_group(COVER_GROUP):
		var screen: CanvasItem = node as CanvasItem
		covered = covered or (screen != null and screen.is_visible_in_tree())
	visible = not covered


## Reads [param simulation] and [param model] (after a start or a load).
func bind(simulation: Simulation, model: AlertList) -> void:
	_simulation = simulation
	if alerts != model:
		alerts = model
		alerts.changed.connect(refresh)
	_shown.clear()
	refresh()


## Rebuilds the cards from the state; new ones slide in.
func refresh() -> void:
	if _simulation == null or alerts == null:
		return
	var state: GameState = _simulation.state
	var all: Array[WireCardData] = WireRules.cards(state, alerts.entries())
	_cards = all.filter(func(c: WireCardData) -> bool: return not _dismissed.has(c.key()))
	var signature: String = _signature_of(state)
	if signature == _signature:
		return
	_signature = signature
	_rebuild(state)


## The cards on the wire now, newest first (shown and stacked).
func get_cards() -> Array[WireCardData]:
	return _cards.duplicate()


## The card nodes shown, top first.
func get_card_nodes() -> Array[WireCard]:
	var found: Array[WireCard] = []
	for child: Node in _column.get_children():
		if child is WireCard and not child.is_queued_for_deletion():
			found.append(child as WireCard)
	return found


## The +N key (its label counts the stacked cards).
func get_stack() -> RefKey:
	return _stack


## The first shown card of [param kind], or null.
func card_of(kind: StringName) -> WireCard:
	for card: WireCard in get_card_nodes():
		if card.get_data().kind == kind:
			return card
	return null


## Every action key shown, top card first (the focus ring).
func get_keys() -> Array[Button]:
	var found: Array[Button] = []
	for card: WireCard in get_card_nodes():
		found.append_array(card.get_keys())
	if _stack.visible:
		found.append(_stack)
	return found


## Runs [param action] of [param card]: submits its command, opens its screen, dismisses the
## card or asks the shell for its step.
func press(card: WireCardData, action: WireAction) -> void:
	if action.special == &"dismiss":
		_dismissed[card.key()] = true
		if card.entry != null:
			alerts.dismiss(card.entry)
		_signature = ""
		refresh()
		return
	if action.command != null:
		_simulation.submit(action.command)
		_signature = ""
		refresh()
		return
	if not action.special.is_empty():
		step_requested.emit(action.special, card)
		return
	if card.entry != null and action.id == &"go_to":
		entry_chosen.emit(card.entry)
		return
	open_view.emit(action.view_id, action.sub_tab)


func _rebuild(state: GameState) -> void:
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	var y: float = 0.0
	for data: WireCardData in _cards.slice(0, VISIBLE):
		var card: WireCard = WireCard.new()
		card.position = Vector2(0, y)
		_column.add_child(card)
		var fresh: bool = not _shown.has(data.key())
		_shown[data.key()] = true
		card.show_card(data, state, fresh)
		card.action_pressed.connect(press)
		y += WireCard.SIZE.y + GAP
	var stacked: int = maxi(0, _cards.size() - VISIBLE)
	_stack.visible = true
	_stack.position = Vector2(0, y)
	_stack.label = "+%d" % stacked if stacked > 0 else ""
	_stack.icon_id = &"" if stacked > 0 else &"log"


## What the cards look like now: kinds, keys and which keys are refused.
func _signature_of(state: GameState) -> String:
	var parts: PackedStringArray = []
	for data: WireCardData in _cards.slice(0, VISIBLE):
		parts.append(data.key())
		for action: WireAction in data.actions:
			parts.append("%s:%s" % [action.id, action.refusal(state)])
	parts.append(str(_cards.size()))
	return "|".join(parts)


static func _signals() -> Array[StringName]:
	return [
		&"request_offered",
		&"request_changed",
		&"incoming_wormhole",
		&"incoming_answered",
		&"incoming_ignored",
		&"contact_pending",
		&"call_missed",
		&"conversation_started",
		&"conversation_ended",
		&"team_returned",
		&"research_started",
		&"candidates_changed",
		&"staff_changed",
		&"power_allocation_changed",
		&"budget_changed",
		&"game_loaded",
	]


func _on_event(
	_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null
) -> void:
	refresh()
