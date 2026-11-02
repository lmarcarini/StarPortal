class_name PowerBar
extends Control
## The FTL-style power bar (docs/content/m2-base.md section 3, "The meter"): one segment per MW
## of supply, filled in one block per running room that draws power and one block for
## charging the capacitors; spare segments stay empty. A block is labelled with its room's
## name when that fits; when [member expanded] (the energy layer is on) a block too narrow for
## its name shows its MW instead, so every block is labelled. With no spare power the bar's
## end carries the "no spare power" mark; after a refusal for lack of power the spare part is
## outlined for a moment, blinking unless reduced flashing is on.
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
const SPARE_OUTLINE := Color("#e5534b")
## Seconds the spare part stays outlined after a refusal, and its blink period.
const FLASH_SECONDS: float = 1.2
const BLINK_SECONDS: float = 0.2
const _FONT_SIZE: int = 11

## True on the energy layer: taller and every block labelled.
var expanded: bool = false:
	set(value):
		expanded = value
		custom_minimum_size.y = 32.0 if value else 22.0
		queue_redraw()

var _supply: float = 0.0
var _spare: float = 0.0
var _blocks: Array[Dictionary] = []
var _flash_left: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(200.0, 22.0)
	mouse_filter = MOUSE_FILTER_PASS
	set_process(false)


## Shows the power of [param state].
func show_state(state: GameState) -> void:
	_supply = PowerRules.supply_mw(state)
	_spare = maxf(PowerRules.spare_mw(state), 0.0)
	_blocks = blocks_of(state)
	tooltip_text = PowerText.mw(_supply) + " MW"
	queue_redraw()


## Returns the supply shown, in MW.
func get_supply() -> float:
	return _supply


## True when the bar shows no spare power.
func has_no_spare() -> bool:
	return _spare < 0.5


## Outlines the spare part for [constant FLASH_SECONDS] (the whole bar when none is spare):
## a refusal for lack of power. It blinks unless reduced flashing is on.
func flash_spare() -> void:
	_flash_left = FLASH_SECONDS
	set_process(true)
	queue_redraw()


## True while the spare outline is drawn this frame.
func is_spare_outlined() -> bool:
	if _flash_left <= 0.0:
		return false
	if Settings.get_bool(&"accessibility", &"reduced_flashing"):
		return true
	return fmod(FLASH_SECONDS - _flash_left, BLINK_SECONDS * 2.0) < BLINK_SECONDS


func _process(delta: float) -> void:
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left <= 0.0:
		set_process(false)
	queue_redraw()


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
		_draw_no_spare()
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
	_draw_no_spare()
	if is_spare_outlined():
		draw_rect(_spare_area(per_mw), SPARE_OUTLINE, false, 2.0)


func _draw_no_spare() -> void:
	if not has_no_spare():
		return
	var mark: float = size.y - 4.0
	PowerMarks.draw_no_power(self, Vector2(size.x - mark * 0.5 - 2.0, size.y * 0.5), mark)


## The spare part of the bar, or the whole bar when nothing is spare.
func _spare_area(per_mw: float) -> Rect2:
	var spare_width: float = per_mw * _spare
	if spare_width < 2.0:
		return Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
	return Rect2(size.x - spare_width + 1.0, 1.0, spare_width - 2.0, size.y - 2.0)


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
