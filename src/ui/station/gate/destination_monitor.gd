class_name DestinationMonitor
extends CrtMonitor
## The console's green CRT: the selected destination's picture, name and up to four status
## icons; NEW ADDRESS while composing; blank when nothing is selected.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Console)

## What the monitor shows.
enum Show { BLANK, DESTINATION, COMPOSING }

## Most status icons shown.
const MAX_ICONS: int = 4

var _show: Show = Show.BLANK
var _picture: TextureRect = TextureRect.new()
var _name: Label = Label.new()
var _icons: HBoxContainer = HBoxContainer.new()


func _ready() -> void:
	super()
	custom_minimum_size = HwMetrics.target(self, Vector2(300, 112))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	add_child(row)
	_picture.custom_minimum_size = Vector2(120, 80) * HwMetrics.scale_of(self)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(_picture)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_name.name = "DestinationName"
	_name.theme_type_variation = &"HwStencil"
	_name.add_theme_color_override(&"font_color", UiThemeHardware.CRT_GREEN)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_name)
	column.add_child(_icons)
	_render(null)


## Shows [param destination], or blank when null.
func show_destination(destination: GateDestination) -> void:
	_show = Show.BLANK if destination == null else Show.DESTINATION
	_render(destination)


## Shows NEW ADDRESS (an address being composed).
func show_composing() -> void:
	_show = Show.COMPOSING
	_render(null)


## What is shown.
func get_show() -> Show:
	return _show


## The name shown.
func get_name_text() -> String:
	return _name.text


func _render(destination: GateDestination) -> void:
	if not is_node_ready():
		return
	for child: Node in _icons.get_children():
		child.queue_free()
	_picture.texture = destination.picture if destination != null else null
	match _show:
		Show.BLANK:
			_name.text = ""
		Show.COMPOSING:
			_name.text = "STATION_NEW_ADDRESS"
		Show.DESTINATION:
			_name.text = destination.title
			for id: StringName in destination.icons.slice(0, MAX_ICONS):
				_icons.add_child(_StatusIcon.new(id))


## A status icon drawn in phosphor green, with its name on a hover card.
class _StatusIcon:
	extends Control
	var _id: StringName

	func _init(id: StringName) -> void:
		_id = id
		custom_minimum_size = Vector2(26, 26)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _ready() -> void:
		HoverCard.attach(self, "HW_ICON_" + String(_id).to_upper())

	func _draw() -> void:
		HardwareIcons.draw(self, _id, Rect2(Vector2.ZERO, size), UiThemeHardware.CRT_GREEN)
