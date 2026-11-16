class_name DestinationCard
extends Button
## One known address on the Gate station's rack: a picture, a name (or, for an address never
## reached, its glyphs), up to four status icons and a pin. Click or (A) selects it; right
## click, F or (Y) flips it to its World Report; P or (X) pins it.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations)

## The card was chosen.
signal selected(card: DestinationCard)
## The card asked to be flipped to its report.
signal flipped(card: DestinationCard)
## The pin was toggled.
signal pin_toggled(card: DestinationCard)

## Card size at 100%.
const CARD_SIZE: Vector2 = Vector2(156, 132)

var _destination: GateDestination = null
var _key: String = ""
var _pinned: bool = false
var _thumb: WorldThumb = WorldThumb.new()
var _name: Label = Label.new()
var _glyphs: HBoxContainer = HBoxContainer.new()


func _init() -> void:
	theme_type_variation = &"IconKey"
	focus_mode = Control.FOCUS_ALL
	toggle_mode = true
	clip_contents = true


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, CARD_SIZE)
	var s: float = HwMetrics.scale_of(self)
	_thumb.position = Vector2(8, 8) * s
	_thumb.size = Vector2(CARD_SIZE.x - 16, 68) * s
	add_child(_thumb)
	_name.theme_type_variation = &"HwStencil"
	_name.position = Vector2(8, 80) * s
	_name.size = Vector2(CARD_SIZE.x - 16, 24) * s
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_name)
	_glyphs.position = _name.position
	_glyphs.add_theme_constant_override(&"separation", 1)
	add_child(_glyphs)
	pressed.connect(func() -> void: selected.emit(self))
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
	_name.visible = not _destination.title.is_empty()
	for child: Node in _glyphs.get_children():
		child.queue_free()
	if _destination.title.is_empty():
		for glyph: int in _destination.address.coordinates:
			var icon: GlyphIcon = GlyphIcon.new()
			icon.glyph_index = glyph
			icon.custom_minimum_size = Vector2(18, 22) * HwMetrics.scale_of(self)
			_glyphs.add_child(icon)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		flipped.emit(self)
		accept_event()
		return
	if _is_key(event, KEY_F, JOY_BUTTON_Y):
		flipped.emit(self)
		accept_event()
	elif _is_key(event, KEY_P, JOY_BUTTON_X):
		pin_toggled.emit(self)
		accept_event()


static func _is_key(event: InputEvent, key: Key, button: JoyButton) -> bool:
	var k: InputEventKey = event as InputEventKey
	if k != null:
		return k.pressed and not k.echo and k.keycode == key
	var j: InputEventJoypadButton = event as InputEventJoypadButton
	return j != null and j.pressed and j.button_index == button


func _draw() -> void:
	if _destination == null:
		return
	var s: float = HwMetrics.scale_of(self)
	var side: float = 20.0 * s
	var x: float = 8.0 * s
	for id: StringName in _destination.icons.slice(0, DestinationMonitor.MAX_ICONS):
		HardwareIcons.draw(self, id, Rect2(x, size.y - side - 6 * s, side, side), Color("#ece6d2"))
		x += side + 4 * s
	if _pinned:
		var pin: Vector2 = Vector2(size.x - 14 * s, 14 * s)
		draw_circle(pin, 6 * s, Color("#c8432f"))
		draw_line(pin, pin + Vector2(0, 10) * s, Color("#c8432f"), 2 * s)
	if button_pressed:
		draw_rect(Rect2(Vector2.ZERO, size), UiThemeHardware.AMBER, false, 3 * s)
