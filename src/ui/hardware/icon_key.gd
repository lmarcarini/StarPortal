class_name IconKey
extends Button
## A square key with a code-drawn icon, a small badge and a hover card. States differ by shape
## as well as colour: READY raised; ACTIVE pressed in with a lit bar; USED with a corner tick;
## UNAVAILABLE dimmed, slashed and disabled.
## Bible: docs/content/interface-rethink.md sections 2, 4 (send rail) and 7

## Key states.
enum KeyState { READY, ACTIVE, USED, UNAVAILABLE }
## Looks: the old kit, the reference's steel key, or a key printed on paper (the mission
## sheet).
enum Look { CLASSIC, STEEL, PAPER }

const _ICON: Color = Color("#ece6d2")
const _LIT: Color = Color("#e8a33d")

## The icon (one of HardwareIcons.IDS).
@export var icon_id: StringName = &"gate":
	set(value):
		icon_id = value
		queue_redraw()
## Short badge text (a count, a time); empty for none.
@export var badge_text: String = "":
	set(value):
		badge_text = value
		queue_redraw()

## The look (CLASSIC by default).
var look: Look = Look.CLASSIC:
	set(value):
		look = value
		if value != Look.CLASSIC:
			RefKeyLook.clear_boxes(self)
		queue_redraw()
## Label under the icon (reference looks); a translation key or text.
var label: String = ""
## Label size, in pixels.
var label_size: int = 18

var _state: KeyState = KeyState.READY
var _card: HoverCard = null


func _init() -> void:
	theme_type_variation = &"IconKey"
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	custom_minimum_size = HwMetrics.target(self, Vector2(64, 64))


## Sets the hover card's help to translation key [param text_key].
func set_help(text_key: String) -> void:
	if _card == null:
		_card = HoverCard.attach(self, text_key)
		return
	_card.set_text(text_key)


## Sets the state; UNAVAILABLE also disables the key.
func set_state(state: KeyState) -> void:
	_state = state
	disabled = state == KeyState.UNAVAILABLE
	button_pressed = false
	queue_redraw()


## The state shown.
func get_state() -> KeyState:
	return _state


func _draw() -> void:
	if look != Look.CLASSIC:
		RefKeyLook.draw(self, look == Look.PAPER, _state)
		return
	var s: float = HwMetrics.scale_of(self)
	var side: float = minf(size.x, size.y) * 0.6
	var shift: float = 4.0 * s if _state == KeyState.ACTIVE else 0.0
	var area: Rect2 = Rect2((size.x - side) * 0.5, (size.y - side) * 0.4 + shift, side, side)
	var ink: Color = _LIT if _state == KeyState.ACTIVE else _ICON
	if _state == KeyState.UNAVAILABLE:
		ink = Color(_ICON, 0.35)
	HardwareIcons.draw(self, icon_id, area, ink)
	_draw_marks(s)
	if not badge_text.is_empty():
		var font: Font = UiThemeBuilder.data_font()
		var fs: int = roundi(13 * s)
		draw_string(
			font,
			Vector2(4 * s, size.y - 6 * s),
			badge_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			_ICON
		)


func _draw_marks(s: float) -> void:
	match _state:
		KeyState.ACTIVE:
			draw_rect(Rect2(6 * s, 4 * s, size.x - 12 * s, 4 * s), _LIT)
		KeyState.USED:
			var c: Vector2 = Vector2(size.x - 14 * s, 14 * s)
			draw_polyline(
				PackedVector2Array(
					[c + Vector2(-6, 0) * s, c + Vector2(-2, 4) * s, c + Vector2(6, -5) * s]
				),
				_ICON,
				2.5 * s
			)
		KeyState.UNAVAILABLE:
			draw_line(Vector2(8, size.y - 8), Vector2(size.x - 8, 8), Color(_ICON, 0.5), 2.0 * s)
