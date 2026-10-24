class_name ImageViewer
extends Control
## A document's image seen large, over the Archive: the image fits the frame at first and can
## be zoomed (mouse wheel at the cursor, or the Zoom buttons) and panned (drag with the mouse,
## or the arrow keys and the d-pad while the frame has focus). At an edge the arrows move focus
## on instead, so the toolbar is always reachable. Cancel (Esc, gamepad B) or Close shuts it.
## Bible: game-design.md#core-loop, art-and-audio.md#ui-and-typography

## The viewer was closed.
signal closed

## Frame pixels one arrow press pans.
const PAN_STEP: float = 64.0
## Pan direction of each arrow action.
const _DIRECTIONS: Dictionary[StringName, Vector2] = {
	&"ui_left": Vector2.LEFT,
	&"ui_right": Vector2.RIGHT,
	&"ui_up": Vector2.UP,
	&"ui_down": Vector2.DOWN,
}

var _zoom_pan: ZoomPan = ZoomPan.new()
var _dragging: bool = false

@onready var _frame: Control = %Frame
@onready var _picture: TextureRect = %Picture
@onready var _zoom_label: Label = %ZoomLabel
@onready var _zoom_in: Button = %ZoomInButton
@onready var _zoom_out: Button = %ZoomOutButton
@onready var _fit: Button = %FitButton
@onready var _close: Button = %CloseButton


func _ready() -> void:
	hide()
	_frame.gui_input.connect(_on_frame_input)
	_frame.resized.connect(_on_frame_resized)
	_frame.draw.connect(_draw_frame_focus)
	_frame.focus_entered.connect(_frame.queue_redraw)
	_frame.focus_exited.connect(_frame.queue_redraw)
	_zoom_in.pressed.connect(zoom_step.bind(1))
	_zoom_out.pressed.connect(zoom_step.bind(-1))
	_fit.pressed.connect(fit)
	_close.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Shows [param texture] fitted to the frame and gives the frame focus. Null does nothing.
func open(texture: Texture2D) -> void:
	if texture == null:
		return
	_picture.texture = texture
	show()
	_zoom_pan.reset(texture.get_size(), _frame.size)
	_apply()
	_frame.grab_focus()


## Hides the viewer and emits [signal closed]. Does nothing while it is closed.
func close() -> void:
	if not visible:
		return
	hide()
	_dragging = false
	closed.emit()


## True while the viewer shows an image.
func is_open() -> bool:
	return visible


## Zooms one step in ([param direction] 1) or out (-1) around the frame's centre.
func zoom_step(direction: int) -> void:
	_zoom_pan.zoom_centred(ZoomPan.STEP if direction > 0 else 1.0 / ZoomPan.STEP)
	_apply()


## Fits the whole image in the frame again.
func fit() -> void:
	_zoom_pan.reset(_picture.texture.get_size() if _picture.texture else Vector2.ONE, _frame.size)
	_apply()


## Returns the zoom and pan state, for tests.
func get_zoom_pan() -> ZoomPan:
	return _zoom_pan


## Returns the image frame, the viewer's focus target.
func get_frame() -> Control:
	return _frame


## Returns the image as drawn, for tests.
func get_picture() -> TextureRect:
	return _picture


func _apply() -> void:
	_picture.position = _zoom_pan.offset
	_picture.size = _zoom_pan.drawn_size()
	_zoom_label.text = tr(&"ARCHIVE_IMAGE_ZOOM").format({"percent": roundi(_zoom_pan.zoom * 100)})
	_zoom_in.disabled = _zoom_pan.zoom >= ZoomPan.MAX_ZOOM
	_zoom_out.disabled = _zoom_pan.zoom <= ZoomPan.MIN_ZOOM


## Outlines the frame while it has focus, so keyboard and gamepad players see where they are.
func _draw_frame_focus() -> void:
	if _frame.has_focus():
		_frame.draw_style_box(
			get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, _frame.size)
		)


func _on_frame_resized() -> void:
	if visible:
		_zoom_pan.resize(_frame.size)
		_apply()


func _on_frame_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _dragging:
		_zoom_pan.pan((event as InputEventMouseMotion).relative)
		_apply()
		_frame.accept_event()
	else:
		_on_pan_action(event)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if not event.pressed:
				return
			var up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
			_zoom_pan.zoom_by(ZoomPan.STEP if up else 1.0 / ZoomPan.STEP, event.position)
			_apply()
		MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			_frame.grab_focus()
		_:
			return
	_frame.accept_event()


## Arrow keys and the d-pad pan the image the way they point; nothing moved means focus moves.
func _on_pan_action(event: InputEvent) -> void:
	var direction: Vector2 = Vector2.ZERO
	for action: StringName in [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		if event.is_action_pressed(action, true):
			direction = _DIRECTIONS[action]
	if direction == Vector2.ZERO:
		return
	if _zoom_pan.pan(-direction * PAN_STEP) != Vector2.ZERO:
		_apply()
		_frame.accept_event()
