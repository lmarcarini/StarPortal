class_name DocumentRow
extends Button
## One document in the Archive's list: its kind as an icon (and as the tooltip), its title and
## source, and a "New" mark while it is unread. Pressing the row opens the document; the row
## shows pressed while the reader shows it.
## Bible: game-design.md#core-loop, game-design.md#difficulty-and-accessibility (status by
## shape as well as colour)

## The player pressed this row.
signal chosen(document_id: StringName)

## Colour of the "New" mark (the analysis area's CRT green accent).
const UNREAD_COLOR: Color = Color(0.45, 0.85, 0.5)

var _document_id: StringName = &""
var _def: DocumentDef = null
var _unread: bool = false

@onready var _icon: KindIcon = %KindIcon
@onready var _title: Label = %Title
@onready var _source: Label = %Source
@onready var _unread_mark: Label = %UnreadMark


func _ready() -> void:
	_unread_mark.add_theme_color_override(&"font_color", UNREAD_COLOR)
	pressed.connect(func() -> void: chosen.emit(_document_id))
	_show()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show()


## Shows document [param document_id], described by [param def] (null when no definition is
## loaded), with the unread mark when [param unread].
func setup(document_id: StringName, def: DocumentDef, unread: bool) -> void:
	_document_id = document_id
	_def = def
	_unread = unread
	if is_node_ready():
		_show()


## Shows or hides the unread mark.
func set_unread(unread: bool) -> void:
	_unread = unread
	if is_node_ready():
		_unread_mark.visible = unread


## Returns the id of the document shown.
func get_document_id() -> StringName:
	return _document_id


## True while the unread mark shows.
func is_unread() -> bool:
	return _unread


## Returns the title shown.
func get_title_text() -> String:
	return _title.text


func _show() -> void:
	var kind: int = _def.kind if _def != null else DocumentDef.Kind.NOTE
	_icon.kind = kind
	tooltip_text = tr(DocumentText.kind_key(kind))
	_title.text = DocumentText.title(_def)
	_source.text = DocumentText.source_line(_def)
	_source.visible = not _source.text.is_empty()
	_unread_mark.text = tr(&"ARCHIVE_UNREAD")
	_unread_mark.visible = _unread
