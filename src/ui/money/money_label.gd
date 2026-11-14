class_name MoneyLabel
extends Button
## Top bar money display: shows the budget as "$12,000k", in red below zero, then today's
## net change ("+38/d") once [method show_net] has been called, and updates on
## EventBus.budget_changed. The shell calls show_budget() after each start or load. It is a
## flat focusable button: a click, (A) or Enter opens the Command tab (the shell connects
## [signal BaseButton.pressed]).
## Bible: docs/content/m2-base.md section 5, docs/content/m27-daily-rhythm.md section 4,
## docs/content/interface-pass.md section 3

## Font colour of a negative balance.
const NEGATIVE_COLOR: Color = UiPalette.ALARM

var _budget_k: int = 0
var _net_text: String = ""


func _enter_tree() -> void:
	EventBus.budget_changed.connect(show_budget)


func _exit_tree() -> void:
	EventBus.budget_changed.disconnect(show_budget)


## Shows [param budget_k] thousands of dollars, red when negative.
func show_budget(budget_k: int) -> void:
	_budget_k = budget_k
	_show_text()
	for color: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		if budget_k < 0:
			add_theme_color_override(color, NEGATIVE_COLOR)
		else:
			remove_theme_color_override(color)


## Shows today's net change of [param net_k] $k a day after the balance.
func show_net(net_k: int) -> void:
	_net_text = TopBarText.net_text(net_k)
	_show_text()


func _show_text() -> void:
	text = (
		format_k(_budget_k) if _net_text.is_empty() else "%s %s" % [format_k(_budget_k), _net_text]
	)


## Returns [param amount_k] as "$12,000k", or "-$240k" when negative.
static func format_k(amount_k: int) -> String:
	var digits: String = str(absi(amount_k))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	var prefix: String = "-" if amount_k < 0 else ""
	return "%s$%s%sk" % [prefix, digits, grouped]
