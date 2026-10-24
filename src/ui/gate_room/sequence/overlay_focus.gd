class_name OverlayFocus
extends RefCounted
## Focus helpers for the Gate Room's overlays: an overlay's buttons point their focus
## neighbours and tab order at each other only, so the keyboard and the gamepad cannot reach
## the console behind it while it is open.
## Bible: game-design.md#difficulty-and-accessibility (full gamepad and keyboard support)

const _SIDES: Array[Side] = [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]


## Makes every direction and tab from [param button] stay on it.
static func trap(button: Control) -> void:
	trap_all([button])


## Links [param controls] in a loop: up and left go to the previous one, down, right and tab
## go to the next one, wrapping; nothing leads outside the list.
static func trap_all(controls: Array[Control]) -> void:
	var count: int = controls.size()
	for index: int in count:
		var control: Control = controls[index]
		var previous: NodePath = control.get_path_to(controls[(index + count - 1) % count])
		var next: NodePath = control.get_path_to(controls[(index + 1) % count])
		for side: Side in _SIDES:
			var is_back: bool = side == SIDE_LEFT or side == SIDE_TOP
			control.set_focus_neighbor(side, previous if is_back else next)
		control.focus_previous = previous
		control.focus_next = next
