class_name HoverCard
extends PanelContainer
## The one line of help for a hardware control, on a small card beside it, shown while the
## pointer is over the control or while it has keyboard or gamepad focus. No help text is
## ever laid out on screen otherwise.
## Bible: docs/content/interface-rethink.md section 2 (text last)

const _GAP: float = 6.0

var _label: Label = null
var _owner_control: Control = null


## Gives [param control] a hover card reading translation key [param text_key]; returns it.
## An empty key removes nothing and adds nothing.
static func attach(control: Control, text_key: String) -> HoverCard:
	if text_key.is_empty():
		return null
	var card: HoverCard = HoverCard.new()
	card.name = "HoverCard"
	card._owner_control = control
	control.add_child(card)
	card.set_text(text_key)
	control.mouse_entered.connect(card.show_card)
	control.mouse_exited.connect(card.hide)
	control.focus_entered.connect(card.show_card)
	control.focus_exited.connect(card.hide)
	return card


func _init() -> void:
	top_level = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"PaperCard"
	z_index = 50
	_label = Label.new()
	_label.add_theme_color_override(&"font_color", UiThemeHardware.INK)
	add_child(_label)


## Sets the help line to translation key [param text_key].
func set_text(text_key: String) -> void:
	_label.text = text_key


## The help line's key.
func get_text() -> String:
	return _label.text


## Shows the card beside its control: to the right, or to the left near the screen's edge.
func show_card() -> void:
	if _owner_control == null:
		return
	reset_size()
	var r: Rect2 = _owner_control.get_global_rect()
	var screen: Vector2 = get_viewport_rect().size
	var at: Vector2 = Vector2(r.end.x + _GAP, r.position.y)
	if at.x + size.x > screen.x:
		at.x = r.position.x - size.x - _GAP
	at.x = clampf(at.x, 0.0, maxf(0.0, screen.x - size.x))
	at.y = clampf(at.y, 0.0, maxf(0.0, screen.y - size.y))
	global_position = at
	show()
