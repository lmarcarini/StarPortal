class_name ClockPlate
extends SteelPanel
## The frame's top-left plate: the clock with its date flap and speed, three keys (pause,
## play, fast), the slow lamp and the call lamp. The keys stand in for the time bar's text
## buttons; the time bar still reads the speed actions (Space, the shoulders) and draws the
## date, speed, slow lamp and call lamp. Play resumes a paused clock and otherwise steps the
## speed down; fast steps it up (or overrides a slow).
## Bible: docs/content/interface-rethink.md section 3

const _TIME_BAR_SCENE: PackedScene = preload("res://src/ui/time_bar/time_bar.tscn")

## The clock, speed, slow lamp and call lamp (its text buttons hidden).
var time_bar: TimeBar = _TIME_BAR_SCENE.instantiate() as TimeBar
## The three speed keys.
var pause_key: IconKey = IconKey.new()
var play_key: IconKey = IconKey.new()
var fast_key: IconKey = IconKey.new()

var _row: HBoxContainer = HBoxContainer.new()


func _init() -> void:
	super()
	name = &"ClockPlate"
	_row.add_theme_constant_override(&"separation", 6)
	add_child(_row)
	var keys: Dictionary[IconKey, StringName] = {
		pause_key: &"pause", play_key: &"play", fast_key: &"fast"
	}
	for key: IconKey in keys:
		key.icon_id = keys[key]
		key.name = String(keys[key]).capitalize() + "Key"
		_row.add_child(key)
	_row.add_child(time_bar)
	pause_key.pressed.connect(SimClock.pause)
	play_key.pressed.connect(play)
	fast_key.pressed.connect(func() -> void: time_bar.faster())


func _ready() -> void:
	pause_key.set_help("FRAME_PAUSE")
	play_key.set_help("FRAME_PLAY")
	fast_key.set_help("FRAME_FAST")
	for key: IconKey in [pause_key, play_key, fast_key]:
		key.custom_minimum_size = HwMetrics.target(key, Vector2(44, 44))
	for button: Button in time_bar.get_buttons():
		if button != time_bar.get_call_button():
			button.visible = false
			button.focus_mode = Control.FOCUS_NONE


## Play: resumes a paused clock; while running, one speed step slower.
func play() -> void:
	if SimClock.simulation == null:
		return
	if SimClock.simulation.state.clock.is_paused:
		SimClock.resume()
	else:
		SimClock.slower()


## The keys in focus order, then the call lamp while lit.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = [pause_key, play_key, fast_key]
	if time_bar.get_call_button().visible:
		found.append(time_bar.get_call_button())
	return found
