class_name MoneyLabel
extends Button
## Top bar money display: shows the budget as "$12,000k", in red below zero, and updates on
## EventBus.budget_changed. The shell calls show_budget() after each start or load. It is a
## flat focusable button: a click, (A) or Enter opens the Command tab (the shell connects
## [signal BaseButton.pressed]).
## Bible: docs/content/m2-base.md section 5, docs/content/m27-daily-rhythm.md section 4

## Font colour of a negative balance.
const NEGATIVE_COLOR: Color = Color(0.9, 0.25, 0.2)


func _enter_tree() -> void:
	EventBus.budget_changed.connect(show_budget)


func _exit_tree() -> void:
	EventBus.budget_changed.disconnect(show_budget)


## Shows [param budget_k] thousands of dollars, red when negative.
func show_budget(budget_k: int) -> void:
	text = format_k(budget_k)
	for color: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		if budget_k < 0:
			add_theme_color_override(color, NEGATIVE_COLOR)
		else:
			remove_theme_color_override(color)


## Returns [param amount_k] as "$12,000k", or "-$240k" when negative.
static func format_k(amount_k: int) -> String:
	var digits: String = str(absi(amount_k))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	var prefix: String = "-" if amount_k < 0 else ""
	return "%s$%s%sk" % [prefix, digits, grouped]
