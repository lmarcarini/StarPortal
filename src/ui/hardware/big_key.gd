class_name BigKey
extends Button
## The main console key (DIAL, CLOSE, GO): a large steel key with a stencilled word. AMBER is
## a lit amber cap, HAZARD has a hazard-striped collar, RED a red cap. With hold-to-confirm a
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

var _held: float = 0.0
var _holding: bool = false
var _hazard: Texture2D = preload("res://art/ui/hardware/hazard.png")


func _init() -> void:
	theme_type_variation = &"BigKey"
	focus_mode = Control.FOCUS_ALL


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
	var s: float = HwMetrics.scale_of(self)
	var cap: Color = _CAPS[key_style]
	if disabled:
		cap = cap.darkened(0.6)
	var lip: float = 4.0 * s
	var top: Rect2 = Rect2(lip, lip, size.x - 2 * lip, 6 * s)
	if key_style == KeyStyle.HAZARD:
		draw_texture_rect(_hazard, Rect2(0, 0, size.x, lip * 2), true)
		draw_texture_rect(_hazard, Rect2(0, size.y - lip * 2, size.x, lip * 2), true)
	draw_rect(top, cap)
	if key_style == KeyStyle.RED:
		draw_rect(Rect2(size.x * 0.5 - 6 * s, top.end.y, 12 * s, 4 * s), cap)
	if _holding:
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		var c: Vector2 = size * 0.5
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * get_hold_progress(), 48, cap, 4 * s, true)
