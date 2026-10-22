class_name GateRoomView
extends GameView
## The Gate Room view. A placeholder for now: a title only, which takes focus so a gamepad
## can reach the view. The dialing card replaces its contents.
## Bible: game-design.md#core-loop

const _TITLE_KEY: StringName = &"GATE_ROOM_TITLE"

@onready var _title: Label = %Title


func _ready() -> void:
	var own: NodePath = _title.get_path_to(_title)
	_title.focus_neighbor_left = own
	_title.focus_neighbor_right = own
	_title.focus_neighbor_bottom = own


## Does nothing yet; the Gate Room has no state to show.
@warning_ignore("unused_parameter")
func setup(simulation: Simulation) -> void:  # gdlint: ignore=unused-argument
	pass


## Returns the title, the only control of the placeholder.
func get_default_focus() -> Control:
	return _title


## Returns [code]GATE_ROOM_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY
