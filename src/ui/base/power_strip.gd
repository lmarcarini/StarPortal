class_name PowerStrip
extends HBoxContainer
## The Base tab's power strip (docs/content/m2-base.md section 6): the power bar, the supply
## and spare, the capacitors line and the button that toggles the energy layer.
## Bible: docs/content/m2-base.md sections 3 and 6

## Emitted when the energy-layer button is pressed.
signal energy_pressed

var bar: PowerBar = PowerBar.new()
var _supply: Label = _label()
var _capacitors: Label = _label()
var _button: Button = Button.new()


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.size_flags_vertical = SIZE_SHRINK_CENTER
	add_child(bar)
	add_child(_supply)
	add_child(_capacitors)
	_button.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_button.toggle_mode = true
	_button.focus_mode = FOCUS_ALL
	_button.toggled.connect(func(_on: bool) -> void: energy_pressed.emit())
	add_child(_button)


## Shows [param state]; [param energy_on] when the energy layer is shown.
func show_state(state: GameState, energy_on: bool) -> void:
	bar.expanded = energy_on
	bar.show_state(state)
	var supply: String = PowerText.mw(PowerRules.supply_mw(state))
	var spare: String = PowerText.mw(PowerRules.spare_mw(state))
	var key: StringName = (
		&"BASE_POWER_SUPPLY_NO_SPARE" if bar.has_no_spare() else &"BASE_POWER_SUPPLY"
	)
	_supply.text = tr(key).format({"supply": supply, "spare": spare})
	_capacitors.text = PowerText.capacitors(state)
	_button.text = tr(&"BASE_POWER_LAYER_BUTTON")
	_button.set_pressed_no_signal(energy_on)


## Returns the supply and capacitor lines, for tests.
func texts() -> Array[String]:
	return [_supply.text, _capacitors.text]


## Returns the energy-layer button.
func get_button() -> Button:
	return _button


static func _label() -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override(&"font_size", 14)
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	return label
