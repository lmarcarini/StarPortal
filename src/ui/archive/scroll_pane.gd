class_name ScrollPane
extends ScrollContainer
## A scroll area that takes focus, so long text scrolls by keyboard and gamepad as well as by
## the mouse wheel: up and down scroll a line's worth, page up and page down a page. At the top
## or bottom edge, up or down moves focus on instead, so the player is never stuck in it.
## Bible: technical-architecture.md#input-accessibility-and-localisation

## Pixels one up or down press scrolls.
const STEP: int = 48


func _init() -> void:
	focus_mode = FOCUS_ALL
	horizontal_scroll_mode = SCROLL_MODE_DISABLED


func _gui_input(event: InputEvent) -> void:
	var delta: int = _delta_for(event)
	if delta == 0:
		return
	var before: int = scroll_vertical
	scroll_vertical = clampi(before + delta, 0, max_scroll())
	if scroll_vertical != before:
		accept_event()


## Returns the largest [member ScrollContainer.scroll_vertical]; 0 when everything fits.
func max_scroll() -> int:
	var bar: VScrollBar = get_v_scroll_bar()
	return maxi(int(bar.max_value - bar.page), 0)


## Pixels [param event] asks to scroll by: negative is up, 0 for anything else.
func _delta_for(event: InputEvent) -> int:
	if event.is_action_pressed(&"ui_up", true):
		return -STEP
	if event.is_action_pressed(&"ui_down", true):
		return STEP
	if event.is_action_pressed(&"ui_page_up", true):
		return -maxi(int(size.y) - STEP, STEP)
	if event.is_action_pressed(&"ui_page_down", true):
		return maxi(int(size.y) - STEP, STEP)
	return 0
