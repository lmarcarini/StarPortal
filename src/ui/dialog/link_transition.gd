class_name LinkTransition
extends Control
## The link opening and closing over the portrait window (docs/content/dialogue-screen.md
## section 4). Opening: about a second of static and ESTABLISHING LINK (the Ring) or CONNECTING
## SECURE LINE (the phone), then the picture settles; Continue skips it. Closing: the picture
## cuts to LINK CLOSED, or SIGNAL LOST when the link was cut. Skipped (no opening) in headless
## runs and with reduced motion. Static uses its own random stream. Presentation only.
## Bible: docs/content/dialogue-screen.md section 4

## Emitted when the opening has played or was skipped.
signal finished

## What it shows.
enum Mode { NONE, OPENING, CLOSED }

## Seconds the opening lasts when it plays.
const OPENING_SECONDS: float = 1.0
## Static blocks across the window.
const STATIC_CELLS: int = 64

var _mode: Mode = Mode.NONE
var _frame: Color = UiPalette.RULE
var _left: float = 0.0
var _label := Label.new()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_rng.seed = 4848
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	var font: Font = UiThemeBuilder.label_font()
	if font != null:
		_label.add_theme_font_override(&"font", font)
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## Seconds the opening plays now: none in a headless run or with reduced motion.
static func opening_seconds() -> float:
	if DisplayServer.get_name() == "headless":
		return 0.0
	if not Settings.get_bool(&"display", &"ambient_movement"):
		return 0.0
	return OPENING_SECONDS


## Plays the opening for [param channel] over [param seconds]; with none it finishes at once.
func play_opening(channel: StringName, seconds: float) -> void:
	var key: StringName = &"DIALOG_CONNECTING" if channel == &"phone" else &"DIALOG_ESTABLISHING"
	_frame = ChannelStyle.accent(channel)
	_show(Mode.OPENING, key, ChannelStyle.accent(channel))
	_left = seconds
	if seconds <= 0.0:
		skip()
		return
	set_process(true)


## Ends the opening now (Continue during it).
func skip() -> void:
	if _mode != Mode.OPENING:
		return
	clear()
	finished.emit()


## Cuts the picture to LINK CLOSED, or SIGNAL LOST when [param cut_off].
func show_closed(cut_off: bool) -> void:
	var key: StringName = &"DIALOG_SIGNAL_LOST" if cut_off else &"DIALOG_LINK_CLOSED"
	_frame = UiPalette.RULE
	_show(Mode.CLOSED, key, UiPalette.ALARM if cut_off else UiPalette.TEXT_DIM)


## Shows nothing.
func clear() -> void:
	_mode = Mode.NONE
	visible = false
	set_process(false)


## True while the opening plays.
func is_opening() -> bool:
	return _mode == Mode.OPENING


## What it shows now.
func get_mode() -> Mode:
	return _mode


## The label's text ("" when it shows nothing).
func get_text() -> String:
	return _label.text if visible else ""


func _process(delta: float) -> void:
	_left -= delta
	queue_redraw()
	if _left <= 0.0:
		skip()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _mode == Mode.OPENING and size.x > 0.0:
		var cell := Vector2(size.x / STATIC_CELLS, size.y / STATIC_CELLS)
		for row: int in STATIC_CELLS:
			for column: int in STATIC_CELLS:
				var grey: float = _rng.randf_range(0.04, 0.4)
				draw_rect(Rect2(Vector2(column, row) * cell, cell), Color(grey, grey, grey))
	var width: float = PortraitWindow.FRAME_WIDTH
	draw_rect(Rect2(Vector2.ONE * width * 0.5, size - Vector2.ONE * width), _frame, false, width)


func _show(mode: Mode, key: StringName, colour: Color) -> void:
	_mode = mode
	_label.text = String(TranslationServer.translate(key))
	_label.add_theme_color_override(&"font_color", colour)
	visible = true
	queue_redraw()
