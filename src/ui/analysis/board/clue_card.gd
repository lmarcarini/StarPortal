class_name ClueCard
extends PanelContainer
## One clue on the Analysis Board: its text, source, a grade badge (the letter is always
## shown), the date it arrived, a picture when the clue has one, a suspect mark (a word and a
## thicker border, never colour alone) and the player's tags. The card only shows and reports:
## it emits what the player did and the board decides. Mouse: click to open, drag to move.
## Keyboard and gamepad: focus it, Accept to open; in move mode the arrows nudge it.
## Bible: gate-and-address-spec.md#player-tools,
## game-design.md#difficulty-and-accessibility

## Emitted when the card is clicked or Accept is pressed on it.
signal activated(clue_id: StringName)
## Emitted when Cancel is pressed on the card.
signal cancelled(clue_id: StringName)
## Emitted while the mouse drags the card, each time it moves.
signal moved(clue_id: StringName)
## Emitted when the mouse drops a dragged card.
signal dropped(clue_id: StringName)
## Emitted in move mode when an arrow is pressed; [param direction] is a unit step.
signal nudged(clue_id: StringName, direction: Vector2i)

## Letters of the grades 0..4.
const GRADE_LETTERS: String = "ABCDE"
## Mouse travel in pixels before a press becomes a drag.
const DRAG_THRESHOLD: float = 6.0
## Width of the outline drawn on the focused card.
const FOCUS_WIDTH: float = 3.0
## Most tag chips a card shows.
const MAX_CHIPS: int = 4
## The arrow actions and the step each one nudges by.
const ARROWS: Dictionary[StringName, Vector2i] = {
	&"ui_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT,
	&"ui_up": Vector2i.UP,
	&"ui_down": Vector2i.DOWN,
}

## Border style of a normal card.
@export var normal_style: StyleBox
## Border style of a card marked suspect: thicker, so it shows without colour.
@export var suspect_style: StyleBox

## True while the board is moving this card with the arrows.
var move_mode: bool = false

var _clue_id: StringName = &""
var _pressed: bool = false
var _dragging: bool = false
var _travel: float = 0.0

@onready var _grade_label: Label = %GradeLabel
@onready var _source_label: Label = %SourceLabel
@onready var _suspect_label: Label = %SuspectLabel
@onready var _text_label: Label = %TextLabel
@onready var _sky_chart: SkyChartView = %SkyChart
@onready var _date_label: Label = %DateLabel
@onready var _tags: HBoxContainer = %Tags


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _draw() -> void:
	if has_focus():
		var color: Color = get_theme_color(&"font_color", &"Label")
		draw_rect(Rect2(Vector2.ZERO, size), color, false, FOCUS_WIDTH)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event.is_action_pressed(&"ui_cancel"):
		cancelled.emit(_clue_id)
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		activated.emit(_clue_id)
		accept_event()
	elif move_mode:
		_on_arrow(event)


## Shows [param record] with the player's [param note] and the filled-in [param text].
## Reads only what the player may know: text, source, grade, date and picture.
func setup(record: ClueRecord, note: ClueNote, text: String) -> void:
	_clue_id = record.id
	_grade_label.text = grade_letter(record.grade)
	_grade_label.tooltip_text = tr(&"BOARD_CARD_GRADE").format(
		{"grade": grade_letter(record.grade)}
	)
	_source_label.text = tr(record.source_key)
	_text_label.text = text
	tooltip_text = text
	_date_label.text = date_text(record.received_tick)
	_sky_chart.visible = not record.image_glyphs.is_empty()
	_sky_chart.setup(record.id, record.image_glyphs)
	show_note(note)


## Shows the suspect mark and the tag chips of [param note].
func show_note(note: ClueNote) -> void:
	_suspect_label.visible = note.is_suspect
	add_theme_stylebox_override(&"panel", suspect_style if note.is_suspect else normal_style)
	for chip: Node in _tags.get_children():
		_tags.remove_child(chip)
		chip.queue_free()
	for tag: String in note.tags.slice(0, MAX_CHIPS):
		_tags.add_child(_make_chip(tag))


## Returns the id of the clue shown.
func get_clue_id() -> StringName:
	return _clue_id


## Returns the grade badge's text.
func get_grade_text() -> String:
	return _grade_label.text


## Returns the source line's text.
func get_source_text() -> String:
	return _source_label.text


## Returns the clue text shown.
func get_clue_text() -> String:
	return _text_label.text


## Returns the date line's text.
func get_date_text() -> String:
	return _date_label.text


## Returns true while the mouse is dragging the card.
func is_dragging() -> bool:
	return _dragging


## Returns true when the picture is shown.
func has_image() -> bool:
	return _sky_chart.visible


## Returns true when the suspect word is shown.
func shows_suspect() -> bool:
	return _suspect_label.visible


## Returns the tags of the chips shown.
func get_chip_texts() -> Array[String]:
	var texts: Array[String] = []
	for chip: Node in _tags.get_children():
		texts.append((chip as Label).text)
	return texts


## Returns the letter of [param grade], 0..4 as A..E; other values are clamped.
static func grade_letter(grade: int) -> String:
	return GRADE_LETTERS[clampi(grade, 0, GRADE_LETTERS.length() - 1)]


## Returns the calendar date of [param tick] as "YYYY-MM-DD".
static func date_text(tick: int) -> String:
	var date: Dictionary = TimeMath.date_of(maxi(tick, 0))
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


func _make_chip(tag: String) -> Label:
	var chip: Label = Label.new()
	chip.text = tag
	chip.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(1)
	style.border_color = get_theme_color(&"font_color", &"Label")
	style.set_content_margin_all(2)
	chip.add_theme_stylebox_override(&"normal", style)
	return chip


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if event.pressed:
		grab_focus()
		_pressed = true
		_dragging = false
		_travel = 0.0
	elif _pressed:
		_pressed = false
		if _dragging:
			_dragging = false
			dropped.emit(_clue_id)
		else:
			activated.emit(_clue_id)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _pressed:
		return
	_travel += event.relative.length()
	if _travel < DRAG_THRESHOLD and not _dragging:
		return
	_dragging = true
	position = (position + event.relative).max(Vector2.ZERO)
	moved.emit(_clue_id)


func _on_arrow(event: InputEvent) -> void:
	for action: StringName in ARROWS:
		if event.is_action_pressed(action, true):
			nudged.emit(_clue_id, ARROWS[action])
			accept_event()
			return
