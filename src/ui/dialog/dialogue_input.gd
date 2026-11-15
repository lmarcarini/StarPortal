class_name DialogueInput
extends RefCounted
## What the dialogue screen does with input while it is up (docs/content/dialogue-screen.md
## section 5): 1 to 4 pick an answer; Space (the pause key), Enter and dialog_continue go on;
## Up and Down keys, Page Up and Down and the right stick scroll earlier lines; focus moves
## (D-pad, stick, Tab) and pressing the focused key ((A), Enter, Space) act on the screen's
## own keys. Every key and gamepad event is used or swallowed here, before any other node's
## _input, so nothing behind the screen reacts; mouse events go on to the screen's controls
## (the screen stops them from reaching anything behind). The actions the screen lets pass
## are left alone.
## Bible: docs/content/dialogue-screen.md section 5


## True when [param event] is one of [param passed] (it reaches the rest of the game).
static func passes(event: InputEvent, passed: Array[StringName]) -> bool:
	for action: StringName in passed:
		if event.is_action(action):
			return true
	return false


## Acts on [param event] for [param screen]. Returns true when the event goes on (a mouse
## event, to the screen's controls), false when it is used or swallowed here.
static func handle(screen: DialogueScreen, event: InputEvent) -> bool:
	if event is InputEventMouse:
		return true
	if event.is_action_pressed(&"ui_accept") and _focused_key(screen) != null:
		var key: Button = _focused_key(screen)
		if not key.disabled:
			key.pressed.emit()
		return false
	if _is_continue(event):
		screen.continue_pressed()
		return false
	for place: int in DialogueScreen.CHOICE_ACTIONS.size():
		if InputActions.is_new_press(event, DialogueScreen.CHOICE_ACTIONS[place]):
			screen.pick_number(place + 1)
			return false
	if not _scroll(screen, event):
		_move_focus(screen, event)
	return false


## True for a press of Continue: dialog_continue (Enter), the pause key (Space), or (A) with
## no key of the screen focused.
static func _is_continue(event: InputEvent) -> bool:
	return (
		InputActions.is_new_press(event, &"dialog_continue")
		or InputActions.is_new_press(event, &"time_toggle_pause")
		or event.is_action_pressed(&"ui_accept")
	)


## The screen's answer key with focus, or null.
static func _focused_key(screen: DialogueScreen) -> Button:
	if not screen.is_inside_tree():
		return null
	var focused: Control = screen.get_viewport().gui_get_focus_owner()
	if focused is Button and screen.answers.is_ancestor_of(focused):
		return focused as Button
	return null


## D-pad, stick or Tab moves focus among the answer keys (wrapping).
static func _move_focus(screen: DialogueScreen, event: InputEvent) -> void:
	var step: int = 0
	if event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"ui_focus_next", true):
		step = 1
	elif event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"ui_focus_prev", true):
		step = -1
	if step != 0:
		screen.answers.move_focus(step, _focused_key(screen))


static func _scroll(screen: DialogueScreen, event: InputEvent) -> bool:
	var key: bool = event is InputEventKey
	var up: bool = (
		(key and event.is_action_pressed(&"ui_up", true))
		or event.is_action_pressed(&"ui_page_up", true)
		or event.is_action_pressed(&"research_pan_up", true)
	)
	var down: bool = (
		(key and event.is_action_pressed(&"ui_down", true))
		or event.is_action_pressed(&"ui_page_down", true)
		or event.is_action_pressed(&"research_pan_down", true)
	)
	if not up and not down:
		return false
	screen.transcript.scroll_by(-DialogueScreen.SCROLL_STEP if up else DialogueScreen.SCROLL_STEP)
	return true
