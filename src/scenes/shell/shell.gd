extends Control
## Placeholder main scene shown at boot until the real shell is built.

## Smallest window size the game supports, in pixels.
const MIN_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)


func _ready() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.min_size = MIN_WINDOW_SIZE
