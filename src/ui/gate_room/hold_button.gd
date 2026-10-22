class_name HoldButton
extends Button
## A button that must be held for [constant HOLD_SECONDS] before it confirms, so a stray press
## never triggers a costly action. Works with the mouse, the keyboard and the gamepad: all of
## them reach it as button_down / button_up (the accept action presses a focused button), and
## a thin bar along the bottom shows the progress, so the hold reads without colour. Releasing
## early, losing focus or becoming disabled cancels the hold; after confirming, the button must
## be released and pressed again. Real time, not game time: holding works while paused.
## Bible: game-design.md#difficulty-and-accessibility (hold-to-confirm)

## Posted once when the hold reaches [constant HOLD_SECONDS].
signal confirmed

## Seconds the button must be held. A constant for now; a setting later.
const HOLD_SECONDS: float = 0.6
const _BAR_HEIGHT: float = 4.0

var _held_seconds: float = 0.0
var _is_holding: bool = false


func _ready() -> void:
	button_down.connect(begin_hold)
	button_up.connect(cancel_hold)
	focus_exited.connect(cancel_hold)
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		cancel_hold()


func _draw() -> void:
	var width: float = size.x * get_progress()
	if width <= 0.0:
		return
	var color: Color = get_theme_color(&"font_color", &"Button")
	draw_rect(Rect2(0.0, size.y - _BAR_HEIGHT, width, _BAR_HEIGHT), color)


## Starts a hold. Does nothing while disabled.
func begin_hold() -> void:
	if disabled:
		return
	_held_seconds = 0.0
	_is_holding = true
	set_process(true)
	queue_redraw()


## Drops the hold in progress without confirming.
func cancel_hold() -> void:
	_held_seconds = 0.0
	_is_holding = false
	set_process(false)
	queue_redraw()


## Adds [param delta] seconds to the hold in progress and confirms when it is long enough.
## Called every frame by the button itself; tests call it to skip real waiting.
func advance(delta: float) -> void:
	if not _is_holding:
		return
	_held_seconds += delta
	if _held_seconds < HOLD_SECONDS:
		queue_redraw()
		return
	cancel_hold()
	confirmed.emit()


## Returns the hold's progress from 0.0 to 1.0.
func get_progress() -> float:
	return clampf(_held_seconds / HOLD_SECONDS, 0.0, 1.0)


## True while a hold is in progress.
func is_holding() -> bool:
	return _is_holding
