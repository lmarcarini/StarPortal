class_name AnalysisView
extends GameView
## The Analysis view: the Address Workbench (about 40% of the width) beside a placeholder
## where the Archive will go. It passes the simulation down to the Workbench, and lends the
## Workbench's address to the Gate Room's Dial button until the dial console replaces both.
## Bible: game-design.md#core-loop,
## technical-architecture.md#input-accessibility-and-localisation

const _TITLE_KEY: StringName = &"ANALYSIS_TITLE"

@onready var _workbench: Workbench = %Workbench


func _ready() -> void:
	var own: NodePath = _workbench.get_path_to(_workbench)
	_workbench.focus_neighbor_left = own
	_workbench.focus_neighbor_right = own
	_workbench.focus_neighbor_bottom = own


## Passes [param simulation] to the Workbench.
func setup(simulation: Simulation) -> void:
	_workbench.setup(simulation)


## Returns the address placed in the Workbench's slots, or null until all seven are filled.
func get_address() -> GateAddress:
	return _workbench.get_address()


## Returns the Workbench, where an address is built.
func get_default_focus() -> Control:
	return _workbench


## Returns [code]ANALYSIS_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY
