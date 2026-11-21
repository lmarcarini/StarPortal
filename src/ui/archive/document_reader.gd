class_name DocumentReader
extends PanelContainer
## One open document: its title, source and the date it arrived, then its image (pressing it
## opens the image viewer) and its text, in a pane that scrolls by mouse, keyboard and gamepad.
## "Read with…" asks to open a second document beside it; the second reader has Close instead.
## The reader shows only what the document holds for the player to read: never its answer or
## the world it is about.
## Bible: game-design.md#core-loop, gate-and-address-spec.md#the-opening-puzzle

## The player pressed the image: show [param texture] large.
signal image_requested(texture: Texture2D)
## The player pressed "Read with…".
signal read_with_pressed
## The player pressed Close (a second reader only).
signal close_pressed

var _document_id: StringName = &""
var _def: DocumentDef = null
var _received_tick: int = 0

@onready var _title: Label = %Title
@onready var _source: Label = %Source
@onready var _received: Label = %Received
@onready var _read_with: Button = %ReadWithButton
@onready var _close: Button = %CloseButton
@onready var _scroll: ScrollPane = %ScrollPane
@onready var _image: Button = %ImageButton
@onready var _body: RichTextLabel = %Body
@onready var _empty: Label = %EmptyLabel


func _ready() -> void:
	_image.pressed.connect(func() -> void: image_requested.emit(_image.icon))
	_read_with.pressed.connect(func() -> void: read_with_pressed.emit())
	_close.pressed.connect(func() -> void: close_pressed.emit())
	_close.visible = false
	_show()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_show()


## Shows document [param document_id], described by [param def] (null when no definition is
## loaded), that arrived at [param received_tick]; scrolls back to the top.
func show_document(document_id: StringName, def: DocumentDef, received_tick: int) -> void:
	_document_id = document_id
	_def = def
	_received_tick = received_tick
	_show()
	_scroll.scroll_vertical = 0


## Shows the transcript [param document_id] titled [param title_text], its [param lines] as
## the body, received at [param received_tick].
func show_transcript(
	document_id: StringName, title_text: String, lines: Array[String], received_tick: int
) -> void:
	show_document(document_id, null, received_tick)
	_title.text = title_text
	_body.text = "\n\n".join(lines)
	_body.visible = not lines.is_empty()


## Shows no document.
func clear() -> void:
	show_document(&"", null, 0)


## Returns the id of the document shown, or &"" for none.
func get_document_id() -> StringName:
	return _document_id


## Makes this the second reader, with Close instead of "Read with…", or the first.
func set_secondary(secondary: bool) -> void:
	_close.visible = secondary
	_read_with.visible = not secondary


## Enables "Read with…" when there is another document to read beside this one.
func set_read_with_enabled(enabled: bool) -> void:
	_read_with.disabled = not enabled or _document_id.is_empty()


## Returns the control that takes focus: the text pane while a document shows.
func get_default_focus() -> Control:
	return _scroll if not _document_id.is_empty() else _read_with


## Returns the scrolling text pane.
func get_scroll() -> ScrollPane:
	return _scroll


## Returns the image button, hidden when the document has no image.
func get_image_button() -> Button:
	return _image


## Returns the "Read with…" button.
func get_read_with_button() -> Button:
	return _read_with


## Returns the Close button.
func get_close_button() -> Button:
	return _close


## Returns the title, source and date lines and the body text as shown, in that order.
func get_shown_texts() -> Array[String]:
	return [_title.text, _source.text, _received.text, _body.get_parsed_text()]


func _state_now() -> GameState:
	return SimClock.simulation.state if SimClock.simulation != null else null


func _show() -> void:
	var has_document: bool = not _document_id.is_empty()
	_empty.visible = not has_document
	_scroll.visible = has_document
	_title.visible = has_document
	_received.visible = has_document
	_title.text = DocumentText.title(_def) if has_document else ""
	_source.text = DocumentText.source_line(_def) if has_document else ""
	_source.visible = not _source.text.is_empty()
	_received.text = DocumentText.received_line(_received_tick) if has_document else ""
	var image: Texture2D = _def.image if _def != null else null
	_image.icon = image
	_image.visible = image != null
	var body_key: StringName = _def.body_key if _def != null else &""
	_body.text = DocumentText.body_bbcode(tr(body_key)) if not body_key.is_empty() else ""
	var gloss: String = DocumentText.gloss(_def, _state_now())
	if not gloss.is_empty():
		_body.text += ("\n\n" if not _body.text.is_empty() else "") + gloss
	_body.visible = not _body.text.is_empty()
	if not has_document:
		_read_with.disabled = true
