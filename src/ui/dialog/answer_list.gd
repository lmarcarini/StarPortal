class_name AnswerList
extends ScrollContainer
## The dialogue screen's answers: up to four large buttons numbered 1 to 4 (a locked one greyed
## with its reason), or a single Continue or Close key. Focus moves only among its own keys and
## wraps, so a gamepad never leaves the screen. Scrolls when long answers do not fit.
## Presentation only.
## Bible: docs/content/dialogue-screen.md sections 1 and 5

## Emitted when an answer is picked, with its index in the Choice node.
signal chosen(index: int)
## Emitted when Continue (or Close) is pressed.
signal continued

## Font size and smallest height of the keys at UI scale 1.
const FONT_SIZE: int = 20
const BUTTON_HEIGHT: int = 48

## The tallest the list grows before it scrolls, in pixels (the screen sets it).
var max_height: float = 320.0:
	set(value):
		max_height = value
		_fit_height()

var _keys := VBoxContainer.new()
var _scale: float = 1.0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keys.add_theme_constant_override(&"separation", 8)
	add_child(_keys)
	_keys.minimum_size_changed.connect(_fit_height)


## Sets the UI scale used for the keys' font size.
func set_ui_scale(scale: float) -> void:
	_scale = scale
	for button: Button in get_buttons():
		button.add_theme_font_size_override(&"font_size", roundi(FONT_SIZE * _scale))
		button.custom_minimum_size.y = BUTTON_HEIGHT * _scale


## Shows the answers [param shown] ({index, text, enabled, reason} each, in order): "1  text",
## a locked one disabled with its reason on a second line.
func show_choices(shown: Array[Dictionary]) -> void:
	clear()
	for place: int in shown.size():
		var choice: Dictionary = shown[place]
		var text: String = "%d   %s" % [place + 1, choice["text"]]
		if not choice["enabled"]:
			text += "\n     %s" % choice["reason"]
		var button: Button = _add_key(text)
		button.disabled = not choice["enabled"]
		var index: int = choice["index"]
		button.pressed.connect(chosen.emit.bind(index))
	_link_focus()


## Shows a single key reading [param text_key] (Continue or Close).
func show_continue(text_key: StringName) -> void:
	clear()
	var button: Button = _add_key(tr(text_key))
	button.pressed.connect(continued.emit)
	_link_focus()


## Removes every key.
func clear() -> void:
	for child: Node in _keys.get_children():
		child.queue_free()


## Returns the keys, in order.
func get_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _keys.get_children():
		if not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


## Presses answer [param number] (1 to 4) when it is shown and enabled; true when pressed.
func press_number(number: int) -> bool:
	var buttons: Array[Button] = get_buttons()
	if number < 1 or number > buttons.size() or buttons[number - 1].disabled:
		return false
	buttons[number - 1].pressed.emit()
	return true


## Gives focus to the first enabled key.
func focus_first() -> void:
	for button: Button in get_buttons():
		if not button.disabled:
			button.grab_focus()
			return


## Moves focus [param step] keys on from [param from] (wrapping; the first key when none has
## focus), skipping disabled keys.
func move_focus(step: int, from: Button) -> void:
	var buttons: Array[Button] = get_buttons()
	if buttons.is_empty():
		return
	var place: int = buttons.find(from)
	for tries: int in buttons.size():
		place = posmod(place + step, buttons.size()) if place >= 0 else 0
		if not buttons[place].disabled:
			buttons[place].grab_focus()
			return


func _add_key(text: String) -> Button:
	var button := Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override(&"font_size", roundi(FONT_SIZE * _scale))
	button.custom_minimum_size.y = BUTTON_HEIGHT * _scale
	var font: Font = UiThemeBuilder.data_font()
	if font != null:
		button.add_theme_font_override(&"font", font)
	_keys.add_child(button)
	return button


## Every key's neighbours are keys of this list (wrapping), so focus cannot leave it.
func _link_focus() -> void:
	var buttons: Array[Button] = get_buttons()
	for place: int in buttons.size():
		var button: Button = buttons[place]
		var before: NodePath = button.get_path_to(buttons[place - 1])
		var after: NodePath = button.get_path_to(buttons[(place + 1) % buttons.size()])
		button.focus_neighbor_top = before
		button.focus_neighbor_bottom = after
		button.focus_previous = before
		button.focus_next = after
		button.focus_neighbor_left = ^"."
		button.focus_neighbor_right = ^"."


## As tall as the keys, up to max_height (a ScrollContainer has no height of its own).
func _fit_height() -> void:
	custom_minimum_size.y = minf(_keys.get_combined_minimum_size().y, max_height)
