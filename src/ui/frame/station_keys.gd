class_name StationKeys
extends SteelPanel
## The frame's four station keys, bottom left (interface-rethink.md section 3): Gate, Base,
## Lab and Office as large icon keys with a one-word stencil label. The current station's key
## is lit (pressed in); a lamp on a key glows when something there needs the player (the
## hosted views' needs_attention()). Lab is hidden until a Research Lab exists. Keyboard (F1-F4,
## Q/E), mouse and gamepad.
## Bible: docs/content/interface-rethink.md section 3

## The player pressed the key of [param station].
signal station_chosen(station: StringName)

## Seconds between two reads of the attention lamps.
const POLL_SECONDS: float = 0.5

var _switcher: ViewSwitcher = null
var _keys: Dictionary[StringName, IconKey] = {}
var _lamps: Dictionary[StringName, IndicatorLamp] = {}
var _row: HBoxContainer = HBoxContainer.new()
var _poll: float = 0.0


func _init() -> void:
	super()
	name = &"StationKeys"
	_row.add_theme_constant_override(&"separation", 6)
	add_child(_row)
	for station: StringName in ViewSwitcher.STATION_ORDER:
		_row.add_child(_unit(station))


func _ready() -> void:
	for station: StringName in _keys:
		_keys[station].set_help("STATION_KEY_" + String(station).to_upper())


## Follows [param switcher]'s stations.
func bind(switcher: ViewSwitcher) -> void:
	_switcher = switcher
	if not switcher.stations_changed.is_connected(refresh):
		switcher.stations_changed.connect(refresh)
	refresh()


## Lights the current station's key, the attention lamps, and hides unavailable stations.
func refresh() -> void:
	if _switcher == null:
		return
	for station: StringName in _keys:
		var key: IconKey = _keys[station]
		(key.get_parent() as Control).visible = _switcher.is_station_available(station)
		var current: bool = station == _switcher.current_station()
		key.set_state(IconKey.KeyState.ACTIVE if current else IconKey.KeyState.READY)
		_lamps[station].set_lit(_switcher.station_needs_attention(station), UiThemeHardware.AMBER)


## The key of [param station].
func get_key(station: StringName) -> IconKey:
	return _keys[station]


## The lamp of [param station].
func get_lamp(station: StringName) -> IndicatorLamp:
	return _lamps[station]


## The visible keys in order.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for station: StringName in ViewSwitcher.STATION_ORDER:
		if (_keys[station].get_parent() as Control).visible:
			found.append(_keys[station])
	return found


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		refresh()


func _unit(station: StringName) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 2)
	var key: IconKey = IconKey.new()
	key.name = String(station).capitalize() + "Station"
	key.icon_id = station
	key.custom_minimum_size = Vector2(64, 64)
	key.pressed.connect(station_chosen.emit.bind(station))
	var lamp: IndicatorLamp = IndicatorLamp.new()
	lamp.custom_minimum_size = Vector2(12, 12)
	lamp.position = Vector2(48, 4)
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_child(lamp)
	column.add_child(key)
	var label: Label = Label.new()
	label.theme_type_variation = &"HwStencil"
	label.text = "STATION_" + String(station).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	_keys[station] = key
	_lamps[station] = lamp
	return column
