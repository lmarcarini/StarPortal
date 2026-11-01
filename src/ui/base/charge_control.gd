class_name ChargeControl
extends VBoxContainer
## The selected Capacitor Bank's charge-rate control in the Base tab's panel
## (docs/content/m2-base.md section 6): "Charge rate 26 / 30 MW", a − button, a slider from 0
## to the bank's maximum and a + button, then the capacitors' stored charge. A change is asked
## for through [signal rate_requested]; a refusal is shown under it in plain words.
## Bible: docs/content/m2-base.md sections 3 and 6

## Emitted when the player asks for bank [param room_id] to charge at [param rate_mw].
signal rate_requested(room_id: StringName, rate_mw: int)

var _room_id: StringName = &""
var _rate: Label = _label()
var _row: HBoxContainer = HBoxContainer.new()
var _minus: Button = Button.new()
var _slider: HSlider = HSlider.new()
var _plus: Button = Button.new()
var _stored: Label = _label()
var _note: Label = _label()


func _ready() -> void:
	add_child(_rate)
	add_child(_row)
	for button: Button in [_minus, _plus]:
		button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(36.0, 0.0)
	_minus.text = tr(&"BASE_POWER_RATE_DOWN")
	_plus.text = tr(&"BASE_POWER_RATE_UP")
	_slider.step = 1.0
	_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	_slider.size_flags_vertical = SIZE_SHRINK_CENTER
	_row.add_child(_minus)
	_row.add_child(_slider)
	_row.add_child(_plus)
	add_child(_stored)
	add_child(_note)
	_minus.pressed.connect(func() -> void: _request(roundi(_slider.value) - 1))
	_plus.pressed.connect(func() -> void: _request(roundi(_slider.value) + 1))
	_slider.value_changed.connect(func(value: float) -> void: _request(roundi(value)))
	visible = false


## Shows bank [param room] of [param def] in [param state]; hides the control for any other
## room.
func show_room(state: GameState, room: RoomState, def: RoomDef) -> void:
	visible = PowerRules.is_bank(def) and PowerRules.is_standing(room)
	if not visible:
		return
	_room_id = room.id
	var rate: int = state.power.charge_rates.get(room.id, 0)
	_slider.max_value = def.max_charge_rate_mw
	_slider.set_value_no_signal(rate)
	_rate.text = tr(&"BASE_POWER_CHARGE_RATE").format(
		{"mw": rate, "max": PowerText.mw(def.max_charge_rate_mw)}
	)
	_stored.text = PowerText.capacitors(state)
	_minus.text = tr(&"BASE_POWER_RATE_DOWN")
	_plus.text = tr(&"BASE_POWER_RATE_UP")


## Shows [param text] (a refusal) under the control; "" clears it.
func show_notice(text: String) -> void:
	_note.text = text
	_note.visible = not text.is_empty()


## Returns the rate shown on the slider, in MW.
func get_rate() -> int:
	return roundi(_slider.value)


## Returns the refusal shown, or "".
func get_note() -> String:
	return _note.text


## Returns the − and + buttons, for tests.
func get_steps() -> Array[Button]:
	return [_minus, _plus]


func _request(rate_mw: int) -> void:
	rate_requested.emit(_room_id, clampi(rate_mw, 0, roundi(_slider.max_value)))


static func _label() -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 14)
	return label
