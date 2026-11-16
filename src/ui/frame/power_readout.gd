class_name PowerReadout
extends Button
## The power gauge's number: "PWR 25/30 MW", switched-on draw over supply (the stored energy
## is on the charge gauge). Pressing it opens the Base on Energy (the frame connects it).
## Bible: docs/content/interface-pass.md section 3


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	theme_type_variation = &"ReadoutButton"


## Shows the power of [param state].
func show_state(state: GameState) -> void:
	text = TopBarText.power_text(state)
	var over: bool = PowerRules.allocated_mw(state) > PowerRules.supply_mw(state) + 0.001
	if over:
		add_theme_color_override(&"font_color", UiPalette.WARN)
	else:
		remove_theme_color_override(&"font_color")
