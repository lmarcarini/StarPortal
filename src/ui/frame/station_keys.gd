class_name StationKeys
extends Control
## The frame's four station keys, bottom left (interface-reference.md section 4,
## station_keys): Gate, Base, Lab and Office, 148 x 168 and 10 px apart, each a 56 px icon
## over a 26 px label. The current station's key is amber; a red lamp in its top right corner
## when something there needs the player (the hosted views' needs_attention()). The Lab key is
## off (dim, unavailable) until a Research Lab exists. Keyboard (F1-F4, Q/E), mouse and
## gamepad.
## Bible: docs/content/interface-reference.md section 4

## The player pressed the key of [param station].
signal station_chosen(station: StringName)

## Key size and gap, in pixels.
const KEY: Vector2 = Vector2(148, 168)
const GAP: float = 10.0
## Seconds between two reads of the attention lamps.
const POLL_SECONDS: float = 0.5

var _switcher: ViewSwitcher = null
var _keys: Dictionary[StringName, RefKey] = {}
var _poll: float = 0.0


func _init() -> void:
	name = &"StationKeys"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x: float = 0.0
	for station: StringName in ViewSwitcher.STATION_ORDER:
		var key: RefKey = RefKey.new()
		key.name = String(station).capitalize() + "Station"
		key.icon_id = station
		key.label = "STATION_" + String(station).to_upper()
		key.label_size = 26
		key.position = Vector2(x, 0)
		key.size = KEY
		key.pressed.connect(station_chosen.emit.bind(station))
		add_child(key)
		_keys[station] = key
		x += KEY.x + GAP
	size = Vector2(x - GAP, KEY.y)


func _ready() -> void:
	for station: StringName in _keys:
		_keys[station].set_help("STATION_KEY_" + String(station).to_upper())


## Follows [param switcher]'s stations.
func bind(switcher: ViewSwitcher) -> void:
	_switcher = switcher
	if not switcher.stations_changed.is_connected(refresh):
		switcher.stations_changed.connect(refresh)
	refresh()


## Lights the current station's key and the attention lamps; an unavailable station's key
## is off.
func refresh() -> void:
	if _switcher == null:
		return
	for station: StringName in _keys:
		var key: RefKey = _keys[station]
		key.disabled = not _switcher.is_station_available(station)
		var current: bool = station == _switcher.current_station()
		key.style = RefPaint.KeyStyle.AMBER if current else RefPaint.KeyStyle.STEEL
		key.lamp = _switcher.station_needs_attention(station)


## The key of [param station].
func get_key(station: StringName) -> RefKey:
	return _keys[station]


## Whether [param station]'s key is the current one (amber).
func is_current(station: StringName) -> bool:
	return _keys[station].style == RefPaint.KeyStyle.AMBER


## Whether [param station]'s attention lamp is lit.
func has_lamp(station: StringName) -> bool:
	return _keys[station].lamp


## The keys that can be pressed, in order.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for station: StringName in ViewSwitcher.STATION_ORDER:
		if not _keys[station].disabled:
			found.append(_keys[station])
	return found


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		refresh()
