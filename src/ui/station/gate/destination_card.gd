class_name DestinationCard
extends Button
## One known address in the right panel's grid (interface-reference.md section 5): a
## 164 x 132 well with the picture, the name (20) or, for an address never reached, its
## glyphs, and status dots; an amber frame when selected. The TEAM key (a mission order) shows
## on hover or focus. Click or (A) selects it; right click, F or the right stick's click flips
## it to its World Report; U or the gamepad's Share button pins it (actions station_flip and
## station_pin).
## Bible: docs/content/interface-reference.md section 5

## The card was chosen.
signal selected(card: DestinationCard)
## The card asked to be flipped to its report.
signal flipped(card: DestinationCard)
## The pin was toggled.
signal pin_toggled(card: DestinationCard)
## The card's TEAM key asked for a mission order to its world.
signal order_requested(card: DestinationCard)

## Card size at 100%.
const CARD_SIZE: Vector2 = Vector2(164, 132)

var _destination: GateDestination = null
var _key: String = ""
var _pinned: bool = false
var _thumb: WorldThumb = WorldThumb.new()
var _name: Label = Label.new()
var _glyphs: HBoxContainer = HBoxContainer.new()
var _team_key: IconKey = IconKey.new()


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	toggle_mode = true
	clip_contents = true
	RefKeyLook.clear_boxes(self)


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	_thumb.position = Vector2(6, 6)
	_thumb.size = Vector2(CARD_SIZE.x - 12, CARD_SIZE.y - 42)
	add_child(_thumb)
	_name.visible = false
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_name)
	_glyphs.position = Vector2(8, 40)
	_glyphs.scale = Vector2(0.85, 0.85)
	_glyphs.add_theme_constant_override(&"separation", 0)
	add_child(_glyphs)
	_team_key.name = "TeamKey"
	_team_key.icon_id = &"team"
	_team_key.look = IconKey.Look.STEEL
	add_child(_team_key)
	_team_key.custom_minimum_size = Vector2(44, 44)
	_team_key.size = Vector2(44, 44)
	_team_key.position = Vector2(CARD_SIZE.x - 50.0, 6.0)
	_team_key.set_help("STATION_ORDER_MISSION")
	_team_key.pressed.connect(func() -> void: order_requested.emit(self))
	pressed.connect(func() -> void: selected.emit(self))
	for hint: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		hint.connect(_show_team_key)
	if _destination != null:
		_render()


## Shows [param destination], the Address Book entry [param key].
func show_destination(destination: GateDestination, key: String, pinned: bool) -> void:
	_destination = destination
	_key = key
	_pinned = pinned
	tooltip_text = ""
	if is_node_ready():
		_render()


## The destination shown.
func get_destination() -> GateDestination:
	return _destination


## The Address Book key.
func get_key() -> String:
	return _key


## True when pinned.
func is_pinned() -> bool:
	return _pinned


func _render() -> void:
	_thumb.show_world(_destination.world_id)
	_name.text = _destination.title
	for child: Node in _glyphs.get_children():
		child.queue_free()
	if _destination.title.is_empty():
		for glyph: int in _destination.address.coordinates:
			var icon: GlyphIcon = GlyphIcon.new()
			icon.glyph_index = glyph
			_glyphs.add_child(icon)
	_show_team_key()
	queue_redraw()


func _show_team_key() -> void:
	var near: bool = is_hovered() or has_focus() or _team_key.has_focus()
	_team_key.visible = near and _destination != null and not _destination.world_id.is_empty()


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		flipped.emit(self)
		accept_event()
		return
	if event.is_action_pressed(&"station_flip"):
		flipped.emit(self)
		accept_event()
	elif event.is_action_pressed(&"station_pin"):
		pin_toggled.emit(self)
		accept_event()


func _draw() -> void:
	if _destination == null:
		return
	RefPaint.recess(self, Rect2(Vector2.ZERO, size))
	var name: RefText = RefText.make(RefText.LABEL, 20, RefPaint.TEXT, 2.0)
	name.draw(self, Vector2(10, size.y - 20), _destination.title.to_upper(), "lm")
	var dots: int = mini(_destination.icons.size(), 3)
	for k: int in dots:
		draw_circle(Vector2(size.x - 12 - k * 12, size.y - 20), 4.0, RefPaint.DIM)
	if _pinned:
		draw_circle(Vector2(14, 14), 6.0, RefPaint.RED)
	if button_pressed:
		RefPaint.outline(self, Rect2(Vector2.ZERO, size), RefPaint.AMBER, 3.0)
	if has_focus():
		RefPaint.outline(self, Rect2(Vector2.ZERO, size).grow(2.0), RefPaint.AMBER_HI, 2.0)
