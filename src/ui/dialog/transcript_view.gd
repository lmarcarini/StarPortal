class_name TranscriptView
extends ScrollContainer
## The dialogue screen's transcript: the current line large and typing out (about 40
## characters a second), earlier lines and the player's answers dimmed above it, scrollable.
## Presentation only.
## Bible: docs/content/dialogue-screen.md sections 1, 2 and 6

## Emitted when the current line has finished typing (or was shown whole).
signal typing_finished
## Emitted on a click on the transcript (the screen treats it as Continue).
signal clicked

## Characters typed per second (a setting later).
const CHARS_PER_SECOND: float = 40.0
## Font sizes at UI scale 1: the current line and earlier lines.
const CURRENT_SIZE: int = 20
const HISTORY_SIZE: int = 16
## Name labels' size at UI scale 1.
const NAME_SIZE: int = 24

var _entries := VBoxContainer.new()
var _current: Label = null
var _current_name: Label = null
var _typed: float = 0.0
var _scale: float = 1.0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override(&"separation", 14)
	add_child(_entries)
	set_process(false)


func _process(delta: float) -> void:
	if _current == null:
		set_process(false)
		return
	_typed += delta * CHARS_PER_SECOND
	_current.visible_characters = floori(_typed)
	if _typed >= _current.get_total_character_count():
		finish_typing()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


## Sets the UI scale (0.8 to 1.5) used for new and existing entries' font sizes.
func set_ui_scale(scale: float) -> void:
	_scale = scale
	for entry: Node in _entries.get_children():
		_size_entry(entry as VBoxContainer, entry == _entries.get_child(-1))


## Removes every entry.
func clear() -> void:
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.free()
	_current = null
	_current_name = null
	set_process(false)


## Adds a line by [param speaker] (shown in [param accent]) saying [param text]; the line
## before it is dimmed. With [param typed] it types out, otherwise it shows whole at once.
func add_line(speaker: String, accent: Color, text: String, typed: bool = true) -> void:
	finish_typing()
	var entry := VBoxContainer.new()
	_current_name = _label(speaker, RefText.make(RefText.LABEL, 0, accent, 2.0).get_font())
	_current_name.add_theme_color_override(&"font_color", accent)
	_current_name.visible = not speaker.is_empty()
	entry.add_child(_current_name)
	_current = _label(text, UiThemeBuilder.data_font())
	entry.add_child(_current)
	_entries.add_child(entry)
	for each: Node in _entries.get_children():
		_size_entry(each as VBoxContainer, each == entry)
	_typed = 0.0
	_current.visible_characters = 0 if typed else -1
	set_process(typed)
	_scroll_to_end.call_deferred()
	if not typed:
		typing_finished.emit()


## True while the current line is still typing.
func is_typing() -> bool:
	return is_processing() and _current != null


## Shows the whole current line at once (Continue while typing).
func finish_typing() -> void:
	if not is_typing():
		return
	_current.visible_characters = -1
	set_process(false)
	typing_finished.emit()


## Scrolls the earlier lines by [param pixels] (negative is up).
func scroll_by(pixels: float) -> void:
	scroll_vertical = maxi(0, scroll_vertical + roundi(pixels))


## Returns every entry as "NAME: text" ("text" when it has no name), oldest first.
func get_texts() -> Array[String]:
	var found: Array[String] = []
	for entry: Node in _entries.get_children():
		var name_label: Label = entry.get_child(0) as Label
		var text: String = (entry.get_child(1) as Label).text
		found.append(text if not name_label.visible else "%s: %s" % [name_label.text, text])
	return found


## Returns the current line's label, or null.
func get_current_label() -> Label:
	return _current


## Returns the current speaker's name label, or null.
func get_current_name_label() -> Label:
	return _current_name


func _size_entry(entry: VBoxContainer, is_current: bool) -> void:
	var name_label: Label = entry.get_child(0) as Label
	var text_label: Label = entry.get_child(1) as Label
	var text_size: int = CURRENT_SIZE if is_current else HISTORY_SIZE
	name_label.add_theme_font_size_override(&"font_size", roundi(NAME_SIZE * _scale))
	text_label.add_theme_font_size_override(&"font_size", roundi(text_size * _scale))
	var colour: Color = UiPalette.TEXT if is_current else UiPalette.TEXT_DIM
	text_label.add_theme_color_override(&"font_color", colour)
	entry.modulate.a = 1.0 if is_current else 0.75


func _label(text: String, font: Font) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text
	if font != null:
		label.add_theme_font_override(&"font", font)
	return label


func _scroll_to_end() -> void:
	if is_inside_tree():
		scroll_vertical = roundi(get_v_scroll_bar().max_value)
