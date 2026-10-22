extends GameView
## Test double: a view with one focusable button that records every simulation passed to
## setup(). Name it before adding it to a switcher's %Views; its id comes from the name.

## Every simulation passed to setup(), in order.
var received: Array[Simulation] = []

var _focus: Button = Button.new()


func _init() -> void:
	_focus.focus_mode = FOCUS_ALL
	add_child(_focus)


## Records [param simulation].
func setup(simulation: Simulation) -> void:
	received.append(simulation)


## Returns the spy's only button.
func get_default_focus() -> Control:
	return _focus


## Returns a key that exists in core.csv.
func get_title_key() -> StringName:
	return &"UI_SAVE"
