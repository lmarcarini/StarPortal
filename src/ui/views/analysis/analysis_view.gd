class_name AnalysisView
extends GameView
## The Analysis view: the Address Workbench (about 40% of the width) beside the Analysis
## Board. It passes the simulation down to both and links focus between them; their own
## cards fill them in.
## Bible: game-design.md#core-loop,
## technical-architecture.md#input-accessibility-and-localisation

const _TITLE_KEY: StringName = &"ANALYSIS_TITLE"

@onready var _workbench: Workbench = %Workbench
@onready var _board: AnalysisBoard = %Board


func _ready() -> void:
	_workbench.focus_neighbor_left = _workbench.get_path_to(_workbench)
	_workbench.focus_neighbor_right = _workbench.get_path_to(_board)
	_workbench.focus_neighbor_bottom = _workbench.get_path_to(_workbench)
	_board.focus_neighbor_left = _board.get_path_to(_workbench)
	_board.focus_neighbor_right = _board.get_path_to(_board)
	_board.focus_neighbor_bottom = _board.get_path_to(_board)


## Passes [param simulation] to the Workbench and the Board.
func setup(simulation: Simulation) -> void:
	_workbench.setup(simulation)
	_board.setup(simulation)


## Returns the Workbench, where an address is built.
func get_default_focus() -> Control:
	return _workbench


## Returns [code]ANALYSIS_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY
