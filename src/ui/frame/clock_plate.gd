class_name ClockPlate
extends Control
## The top bar's clock plate (interface-reference.md section 4, top_clock): the clock icon,
## the date, the time below in amber, and the slow lamp at the right end (unlit green when
## the clock runs normally, lit amber with its reason on hover while slowed). It holds the
## time bar, hidden: the time bar still reads the speed actions (Space, the shoulders) and
## keeps the call lamp's logic; nothing of it shows.
## Bible: docs/content/interface-reference.md section 4

const _TIME_BAR_SCENE: PackedScene = preload("res://src/ui/time_bar/time_bar.tscn")

## The clock, speed, slow lamp and call logic (hidden).
var time_bar: TimeBar = _TIME_BAR_SCENE.instantiate() as TimeBar


func _init() -> void:
	name = &"ClockPlate"
	mouse_filter = Control.MOUSE_FILTER_PASS
	time_bar.visible = false
	add_child(time_bar)


func _ready() -> void:
	for button: Button in time_bar.get_buttons():
		button.focus_mode = Control.FOCUS_NONE


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


## "02 JAN 1997" for [param tick].
static func date_text(tick: int) -> String:
	var date: Dictionary = TimeMath.date_of(tick)
	var month: String = TranslationServer.translate("COMMAND_MONTH_%d" % date["month"])
	return "%02d %s %04d" % [date["day"], month.to_upper(), date["year"]]


## "07:01" for [param tick].
static func time_text(tick: int) -> String:
	var date: Dictionary = TimeMath.date_of(tick)
	return "%02d:%02d" % [date["hour"], date["minute"]]


## The reason the clock is slowed now, as a translation key, or &"".
func slow_key() -> StringName:
	if SimClock.simulation == null:
		return &""
	return SlowLamp.shown_key(SimClock.simulation.state.clock)


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	RefIcons.draw(self, &"clock", Rect2(17, 15, 30, 30), RefPaint.TEXT)
	var lamp: Vector2 = Vector2(size.x - 28, 30)
	var reason: StringName = slow_key()
	tooltip_text = "" if reason.is_empty() else tr(SlowLamp.label_key(reason))
	if reason.is_empty():
		RefPaint.lamp_off(self, lamp, 7.0, true)
	else:
		RefPaint.lamp_on(self, lamp, 7.0, RefPaint.AMBER)
	if SimClock.simulation == null:
		return
	var tick: int = SimClock.simulation.state.clock.tick
	RefText.make(RefText.LABEL, 26, RefPaint.TEXT, 2.0).draw(self, Vector2(60, 8), date_text(tick))
	RefText.make(RefText.MONO_BOLD, 18, RefPaint.AMBER).draw(self, Vector2(60, 36), time_text(tick))
