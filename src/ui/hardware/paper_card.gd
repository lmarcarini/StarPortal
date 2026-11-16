class_name PaperCard
extends PanelContainer
## An off-white card with a coloured left edge (a destination's report, a debrief, a hover
## card). Labels inside take the ink colour.
## Bible: docs/content/interface-rethink.md section 7

## The edge's colour.
@export var edge_colour: Color = UiThemeHardware.AMBER:
	set(value):
		edge_colour = value
		_restyle()


func _init() -> void:
	theme_type_variation = &"PaperCard"
	var ink: Theme = Theme.new()
	ink.set_color(&"font_color", &"Label", UiThemeHardware.INK)
	theme = ink


func _ready() -> void:
	_restyle()


func _restyle() -> void:
	if not is_inside_tree():
		return
	var base: StyleBox = get_theme_stylebox(&"panel", &"PaperCard")
	var flat: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	if flat == null:
		return
	flat.border_color = edge_colour
	add_theme_stylebox_override(&"panel", flat)
