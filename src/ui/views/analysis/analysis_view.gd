class_name AnalysisView
extends GameView
## The Analysis view: a placeholder where the Archive will go. The address is built and dialed
## in the Gate Room's dial console.
## Bible: game-design.md#core-loop,
## technical-architecture.md#input-accessibility-and-localisation

const _TITLE_KEY: StringName = &"ANALYSIS_TITLE"

@onready var _placeholder: Label = %ArchivePlaceholder


func _ready() -> void:
	var own: NodePath = _placeholder.get_path_to(_placeholder)
	_placeholder.focus_neighbor_left = own
	_placeholder.focus_neighbor_right = own
	_placeholder.focus_neighbor_bottom = own


## Nothing to pass on yet: the Archive is not built.
func setup(_simulation: Simulation) -> void:
	pass


## Returns the Archive placeholder, focusable so the view has a focus target.
func get_default_focus() -> Control:
	return _placeholder


## Returns [code]ANALYSIS_TITLE[/code].
func get_title_key() -> StringName:
	return _TITLE_KEY
