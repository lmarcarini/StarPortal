class_name PowerReadout
extends Button
## The top bar's power readout: "PWR 25/30 MW  CAP 310 MWh", switched-on draw over supply
## and the energy stored. Pressing it opens the Base on Energy (the top bar connects it).
## Bible: docs/content/interface-pass.md section 3


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ReadoutButton"


## Shows the power of [param state].
func show_state(state: GameState) -> void:
	var stored: String = TopBarText.stored_text(state)
	var power: String = TopBarText.power_text(state)
	text = power if stored.is_empty() else "%s  %s" % [power, stored]
	var over: bool = PowerRules.allocated_mw(state) > PowerRules.supply_mw(state) + 0.001
	if over:
		add_theme_color_override(&"font_color", UiPalette.WARN)
	else:
		remove_theme_color_override(&"font_color")
