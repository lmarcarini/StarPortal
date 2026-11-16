class_name WireCard
extends SteelPanel
## One card on the wire: a severity lamp, the kind's icon, a two-word title and the action
## keys; event cards add a dismiss key. The full sentence is on the hover card. A key whose
## command would be refused is greyed with the refusal as its hover reason. A new card slides
## in and blinks its lamp. Presses go out as [signal action_pressed]; the wire acts on them.
## Bible: docs/content/interface-rethink.md sections 3 and 6

## The player pressed [param action] on this card.
signal action_pressed(card: WireCardData, action: WireAction)

## Seconds of the slide-in and of the lamp blink.
const SLIDE_SECONDS: float = 0.25
const BLINK_SECONDS: float = 1.2

var _data: WireCardData = null
var _lamp: IndicatorLamp = IndicatorLamp.new()
var _icon: Control = Control.new()
var _title: Label = Label.new()
var _keys: HBoxContainer = HBoxContainer.new()


func _init() -> void:
	super()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	add_child(row)
	_lamp.custom_minimum_size = Vector2(14, 14)
	_lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_lamp)
	_icon.custom_minimum_size = Vector2(28, 28)
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)
	_title.theme_type_variation = &"HwStencil"
	_title.custom_minimum_size.x = 120
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	row.add_child(_keys)
	_keys.add_theme_constant_override(&"separation", 4)


## Shows [param data] for [param state]; [param fresh] slides it in and blinks the lamp.
func show_card(data: WireCardData, state: GameState, fresh: bool) -> void:
	_data = data
	name = "Wire_" + data.kind
	_title.text = data.title_key
	_lamp.set_lit(true, _lamp_colour(data.severity))
	if not data.detail.is_empty():
		HoverCard.attach(_icon, data.detail)
	for key: Node in _keys.get_children():
		key.queue_free()
	for action: WireAction in data.actions:
		_keys.add_child(_key(action, state))
	if data.dismissible:
		_keys.add_child(_key(WireAction.step(&"dismiss", &"dismiss", &"dismiss"), state))
	if fresh:
		_arrive()


## The card's data.
func get_data() -> WireCardData:
	return _data


## The action keys, in order (dismiss last).
func get_keys() -> Array[IconKey]:
	var found: Array[IconKey] = []
	for key: Node in _keys.get_children():
		if key is IconKey and not key.is_queued_for_deletion():
			found.append(key as IconKey)
	return found


func _key(action: WireAction, state: GameState) -> IconKey:
	var key: IconKey = IconKey.new()
	key.name = String(action.id)
	key.icon_id = action.icon_id
	key.custom_minimum_size = Vector2(40, 40)
	var refusal: StringName = action.refusal(state)
	if refusal.is_empty():
		key.set_help(action.help)
	else:
		key.set_help(WireText.refusal(refusal))
		key.set_state(IconKey.KeyState.UNAVAILABLE)
	key.pressed.connect(func() -> void: action_pressed.emit(_data, action))
	return key


func _arrive() -> void:
	var tween: Tween = create_tween()
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, SLIDE_SECONDS)
	var blink: Tween = create_tween().set_loops(3)
	blink.tween_callback(_lamp.set_lit.bind(false)).set_delay(BLINK_SECONDS / 6.0)
	blink.tween_callback(_lamp.set_lit.bind(true, _lamp_colour(_data.severity)))
	blink.tween_interval(BLINK_SECONDS / 6.0)


func _draw_icon() -> void:
	if _data != null:
		HardwareIcons.draw(_icon, _data.icon_id, Rect2(Vector2.ZERO, _icon.size), Color("#ece6d2"))


static func _lamp_colour(severity: StringName) -> Color:
	match severity:
		AlertEntry.ALARM:
			return UiPalette.ALARM
		AlertEntry.WARN:
			return UiThemeHardware.AMBER
	return UiThemeHardware.CRT_GREEN
