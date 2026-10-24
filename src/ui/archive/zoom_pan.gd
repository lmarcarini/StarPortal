class_name ZoomPan
extends RefCounted
## Zoom and pan of an image inside a frame, as plain numbers: the image's scale and its
## top-left corner in frame coordinates. Zoom 1 fits the whole image in the frame; zooming in
## keeps the point under the cursor (or the frame's centre) still. A smaller image is centred;
## a larger one can be panned only until its edge meets the frame's edge.
## Bible: game-design.md#core-loop (Analysis: read the Archive's images)

## Smallest zoom: the whole image fits.
const MIN_ZOOM: float = 1.0
## Largest zoom, as a multiple of the fitting scale.
const MAX_ZOOM: float = 8.0
## Factor of one zoom step (a wheel notch or a button press).
const STEP: float = 1.25

## Zoom as a multiple of the fitting scale, from [constant MIN_ZOOM] to [constant MAX_ZOOM].
var zoom: float = MIN_ZOOM
## Top-left corner of the drawn image, in frame coordinates.
var offset: Vector2 = Vector2.ZERO

var _image_size: Vector2 = Vector2.ONE
var _frame_size: Vector2 = Vector2.ONE


## Sets the image and frame sizes (each at least one pixel) and fits the image.
func reset(image_size: Vector2, frame_size: Vector2) -> void:
	_image_size = image_size.max(Vector2.ONE)
	_frame_size = frame_size.max(Vector2.ONE)
	zoom = MIN_ZOOM
	_clamp()


## Changes the frame size, keeping the zoom and the image's centre where it can.
func resize(frame_size: Vector2) -> void:
	var anchor: Vector2 = (_frame_size * 0.5 - offset) / scale()
	_frame_size = frame_size.max(Vector2.ONE)
	offset = _frame_size * 0.5 - anchor * scale()
	_clamp()


## Returns the scale the image is drawn at: zoom times the scale that fits it.
func scale() -> float:
	return zoom * minf(_frame_size.x / _image_size.x, _frame_size.y / _image_size.y)


## Returns the drawn image's size in frame pixels.
func drawn_size() -> Vector2:
	return _image_size * scale()


## Multiplies the zoom by [param factor], keeping frame point [param at] still.
func zoom_by(factor: float, at: Vector2) -> void:
	var image_point: Vector2 = (at - offset) / scale()
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	offset = at - image_point * scale()
	_clamp()


## Zooms by [param factor] around the frame's centre.
func zoom_centred(factor: float) -> void:
	zoom_by(factor, _frame_size * 0.5)


## Moves the image by [param delta] frame pixels and returns how far it really moved.
func pan(delta: Vector2) -> Vector2:
	var before: Vector2 = offset
	offset += delta
	_clamp()
	return offset - before


## Keeps the image covering the frame on each axis where it is larger, centred where smaller.
func _clamp() -> void:
	var drawn: Vector2 = drawn_size()
	offset.x = _clamp_axis(offset.x, drawn.x, _frame_size.x)
	offset.y = _clamp_axis(offset.y, drawn.y, _frame_size.y)


static func _clamp_axis(value: float, drawn: float, frame: float) -> float:
	if drawn <= frame:
		return (frame - drawn) * 0.5
	return clampf(value, frame - drawn, 0.0)
