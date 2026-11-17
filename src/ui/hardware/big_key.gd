class_name BigKey
extends Button
## The main console key (DIAL, CLOSE, GO), drawn as the interface reference's key: AMBER an
## amber key, HAZARD yellow-black stripes round a dark face, RED a steel key with red ink; off
## while disabled. The word is its text at [member label_size]. With hold-to-confirm a
## ring round the key fills while held and [signal activated] fires when it closes; without
## it, a press fires at once. Mouse, keyboard and gamepad all reach it as button_down/up.
## Bible: docs/content/interface-rethink.md sections 4 (Gate console) and 7

## Fired when the key is pressed (or held through, with hold-to-confirm).
signal activated

## Key looks; each also differs in shape: AMBER plain, HAZARD striped collar, RED notched.
enum KeyStyle { AMBER, HAZARD, RED }

## Seconds to hold when [member hold_to_confirm] is on.
const HOLD_SECONDS: float = 0.6
const _CAPS: Dictionary[KeyStyle, Color] = {
	KeyStyle.AMBER: Color("#e8a33d"),
	KeyStyle.HAZARD: Color("#d9a521"),
	KeyStyle.RED: Color("#c8432f")
}

## The look.
@export var key_style: KeyStyle = KeyStyle.AMBER:
	set(value):
		key_style = value
		queue_redraw()
## Whether the key must be held to fire.
@export var hold_to_confirm: bool = false
## Size of the word, in pixels (DIAL 50, CLOSE 46, GO 36).
@export var label_size: int = 36

var _held: float = 0.0
var _holding: bool = false


func _init() -> void:
	theme_type_variation = &"BigKey"
	focus_mode = Control.FOCUS_ALL
	RefKeyLook.clear_boxes(self)
	for colour: StringName in [
		&"font_color",
		&"font_hover_color",
		&"font_pressed_color",
		&"font_focus_color",
		&"font_disabled_color",
		&"font_hover_pressed_color"
	]:
		add_theme_color_override(colour, Color(0, 0, 0, 0))


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, Vector2(160, 72))
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	focus_exited.connect(_on_up)
	pressed.connect(_on_pressed)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Moves a hold on by [param delta] seconds; fires once it is complete.
func advance(delta: float) -> void:
	if not _holding:
		return
	_held += delta
	queue_redraw()
	if _held >= HOLD_SECONDS:
		_holding = false
		_held = 0.0
		set_process(false)
		activated.emit()


## How far the hold has run, 0 to 1.
func get_hold_progress() -> float:
	return clampf(_held / HOLD_SECONDS, 0.0, 1.0)


func _on_down() -> void:
	if not hold_to_confirm or disabled:
		return
	_holding = true
	_held = 0.0
	set_process(true)


func _on_up() -> void:
	_holding = false
	_held = 0.0
	set_process(false)
	queue_redraw()


func _on_pressed() -> void:
	if not hold_to_confirm:
		activated.emit()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var styles: Dictionary[KeyStyle, RefPaint.KeyStyle] = {
		KeyStyle.AMBER: RefPaint.KeyStyle.AMBER,
		KeyStyle.HAZARD: RefPaint.KeyStyle.HAZARD,
		KeyStyle.RED: RefPaint.KeyStyle.STEEL,
	}
	var style: RefPaint.KeyStyle = RefPaint.KeyStyle.OFF if disabled else styles[key_style]
	var ink: Color = RefPaint.key(self, rect, style)
	if key_style == KeyStyle.RED and not disabled:
		ink = RefPaint.RED
	if is_hovered() and not disabled:
		draw_polygon(RefPaint.rounded(rect, 6.0), [Color(1, 1, 1, 0.06)])
	var word: RefText = RefText.make(RefText.LABEL, label_size, ink, 3.0)
	word.draw(self, Vector2(size.x * 0.5, size.y * 0.5 + 2.0), tr(text), "mm")
	if has_focus():
		RefPaint.outline(self, rect.grow(3.0), RefPaint.AMBER_HI, 2.0)
	if _holding:
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(
			size * 0.5,
			r,
			-PI / 2,
			-PI / 2 + TAU * get_hold_progress(),
			48,
			RefPaint.AMBER_HI,
			4.0,
			true
		)
