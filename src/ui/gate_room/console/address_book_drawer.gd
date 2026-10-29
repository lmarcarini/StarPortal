class_name AddressBookDrawer
extends HBoxContainer
## The Address Book as a side panel on the right edge of the Gate Room, collapsed by default to
## a vertical tab, "Address Book (n)". Pressing the tab (click, Enter or A) opens the panel,
## about 360 px wide, over the right side of the view; the tab, B or Escape closes it, and so
## does Load (the console's slots are filled). The drawer sits above the wormhole status strip,
## which stops left of the tab, so the tab is never hidden and the open panel covers the strip
## and its actions until it closes. The dialing sequence and the result card stay above it: while
## either shows, the drawer is collapsed and hidden ([method set_blocked]), so it can't be opened
## and B / Escape go to the card.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book)

## The panel opened or closed.
signal toggled(is_open: bool)

## Width of the collapsed tab, in pixels.
const TAB_WIDTH: float = 32.0

var _simulation: Simulation = null
var _tab_text: String = ""

@onready var _sheet: Control = %Sheet
@onready var _panel: AddressBookPanel = %AddressBookPanel
@onready var _tab: Button = %Tab


func _ready() -> void:
	_tab.pressed.connect(toggle)
	_tab.draw.connect(_draw_tab_text)
	_panel.load_requested.connect(func(_address: GateAddress) -> void: close())
	_sheet.visible = false
	_render_tab()


func _enter_tree() -> void:
	EventBus.address_book_changed.connect(_render_tab)


func _exit_tree() -> void:
	EventBus.address_book_changed.disconnect(_render_tab)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render_tab()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()
	_tab.grab_focus()


## Connects the panel to [param simulation] and collapses it.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_panel.setup(simulation)
	_sheet.visible = false
	_render_tab()


## Collapses and hides the drawer while [param blocked] (the dialing sequence or the result
## card shows); shows the tab again otherwise.
func set_blocked(blocked: bool) -> void:
	if blocked:
		close()
	visible = not blocked


## Opens the panel and focuses its first row (or its search field).
func open() -> void:
	if not visible:
		return
	if is_open():
		_panel.get_first_focus().grab_focus()
		return
	_sheet.visible = true
	_panel.get_first_focus().grab_focus()
	toggled.emit(true)


## Collapses the panel to its tab.
func close() -> void:
	if not is_open():
		return
	_sheet.visible = false
	toggled.emit(false)


## Opens the panel if collapsed, collapses it if open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## True while the panel is open.
func is_open() -> bool:
	return _sheet.visible


## Returns the Address Book panel.
func get_panel() -> AddressBookPanel:
	return _panel


## Returns the tab that opens and closes the panel.
func get_tab() -> Button:
	return _tab


## Returns the tab's text, "Address Book (n)".
func get_tab_text() -> String:
	return _tab_text


func _render_tab() -> void:
	if not is_node_ready():
		return
	var count: int = 0
	if _simulation != null:
		count = _simulation.state.address_book.entries.size()
	_tab_text = tr(&"BOOK_TAB").format({"count": count})
	_tab.tooltip_text = tr(&"BOOK_TAB_TOOLTIP")
	_tab.custom_minimum_size = Vector2(TAB_WIDTH, _text_size().x + 24.0)
	_tab.queue_redraw()


func _text_size() -> Vector2:
	var font: Font = _tab.get_theme_font(&"font")
	var font_size: int = _tab.get_theme_font_size(&"font_size")
	return font.get_string_size(_tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)


## The tab's text is drawn turned a quarter left, reading bottom to top, centred on the tab.
func _draw_tab_text() -> void:
	var font: Font = _tab.get_theme_font(&"font")
	var font_size: int = _tab.get_theme_font_size(&"font_size")
	var text: Vector2 = _text_size()
	var baseline: float = (
		(_tab.size.x - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size)
	)
	_tab.draw_set_transform(Vector2(baseline, (_tab.size.y + text.x) / 2.0), -PI / 2.0)
	var color: Color = _tab.get_theme_color(&"font_color")
	_tab.draw_string(font, Vector2.ZERO, _tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	_tab.draw_set_transform(Vector2.ZERO)
