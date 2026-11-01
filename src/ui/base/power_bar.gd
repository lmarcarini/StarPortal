class_name PowerBar
extends Control
## The FTL-style power bar (docs/content/m2-base.md section 3, "The meter"): one segment per MW
## of supply, filled in one block per running room that draws power and one block for
## charging the capacitors; spare segments stay empty. A block is labelled with its room's
## name when that fits; when [member expanded] (the energy layer is on) a block too narrow for
## its name shows its MW instead, so every block is labelled.
## Bible: docs/content/m2-base.md sections 3 and 6

## Kind of a block in blocks_of().
enum Kind { ROOM, ALWAYS_ON, CHARGE }

## Instrument-panel palette (concept A).
const BACK := Color("#15171a")
const EDGE := Color("#5b5e51")
const ROOM := Color("#e0a040")
const ALWAYS_ON := Color("#c97c2c")
const CHARGE := Color("#5cb8d6")
const INK := Color("#15171a")
const _FONT_SIZE: int = 11

## True on the energy layer: taller and every block labelled.
var expanded: bool = false:
	set(value):
		expanded = value
		custom_minimum_size.y = 32.0 if value else 22.0
		queue_redraw()

var _supply: float = 0.0
var _blocks: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(200.0, 22.0)
	mouse_filter = MOUSE_FILTER_PASS


## Shows the power of [param state].
func show_state(state: GameState) -> void:
	_supply = PowerRules.supply_mw(state)
	_blocks = blocks_of(state)
	tooltip_text = PowerText.mw(_supply) + " MW"
	queue_redraw()


## Returns the supply shown, in MW.
func get_supply() -> float:
	return _supply


## Returns the blocks shown: see blocks_of().
func get_blocks() -> Array[Dictionary]:
	return _blocks


## The blocks of [param state], in base order then charging: each {"id": room id or &"",
## "kind": Kind, "mw": float, "name": translated name}.
static func blocks_of(state: GameState) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def == null or def.power_draw_mw <= 0.0 or not PowerRules.is_running(room, def):
			continue
		var kind: Kind = Kind.ALWAYS_ON if def.always_on else Kind.ROOM
		var name: String = TranslationServer.translate(def.name_key)
		found.append({"id": room.id, "kind": kind, "mw": def.power_draw_mw, "name": name})
	var charge: float = PowerRules.charge_mw(state)
	if charge > 0.0:
		var label: String = TranslationServer.translate(&"BASE_POWER_BAR_CHARGE")
		found.append({"id": &"", "kind": Kind.CHARGE, "mw": charge, "name": label})
	return found


## The label drawn on [param block] when it is [param width] px wide: its name upper-cased
## when it fits, else (expanded only) its MW, else "".
func label_for(block: Dictionary, width: float) -> String:
	var font: Font = get_theme_default_font()
	var block_mw: float = block["mw"]
	var block_name: String = block["name"]
	var name: String = block_name.to_upper() + " " + PowerText.mw(block_mw)
	if _text_width(font, name) <= width - 4.0:
		return name
	var short: String = PowerText.mw(block_mw)
	if expanded and _text_width(font, short) <= width - 2.0:
		return short
	return ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	if _supply <= 0.0:
		return
	var per_mw: float = size.x / _supply
	var x: float = 0.0
	for block: Dictionary in _blocks:
		var block_mw: float = block["mw"]
		var width: float = per_mw * block_mw
		var area := Rect2(x + 1.0, 2.0, width - 2.0, size.y - 4.0)
		var kind: Kind = block["kind"]
		draw_rect(area, _colour(kind))
		x += width
	for segment: int in range(1, ceili(_supply)):
		var at_x: float = segment * per_mw
		draw_line(Vector2(at_x, 0.0), Vector2(at_x, size.y), Color(EDGE, 0.6))
	_draw_labels(per_mw)
	draw_rect(Rect2(Vector2.ZERO, size), EDGE, false, 1.0)


func _draw_labels(per_mw: float) -> void:
	var font: Font = get_theme_default_font()
	var x: float = 0.0
	for block: Dictionary in _blocks:
		var block_mw: float = block["mw"]
		var width: float = per_mw * block_mw
		var text: String = label_for(block, width)
		if not text.is_empty():
			var at := Vector2(x + 3.0, size.y * 0.5 + _FONT_SIZE * 0.35)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, width - 4.0, _FONT_SIZE, INK)
		x += width


static func _colour(kind: Kind) -> Color:
	match kind:
		Kind.ALWAYS_ON:
			return ALWAYS_ON
		Kind.CHARGE:
			return CHARGE
	return ROOM


static func _text_width(font: Font, text: String) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _FONT_SIZE).x
