class_name AfterActionReport
extends PanelContainer
## The after-action report (M4c-13): a panel over the game when an incursion ends, with the
## AfterActionText lines and Close. It never pauses the game; the Log keeps a line for it.
## Bible: docs/content/m4c-incursions.md section 7

var title := Label.new()
var body := Label.new()
var close_button := Button.new()


func _init() -> void:
	name = &"AfterActionReport"
	visible = false
	theme_type_variation = &"PanelBezel"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var column := VBoxContainer.new()
	add_child(column)
	title.text = &"AAR_TITLE"
	title.add_theme_color_override(&"font_color", UiPalette.ALARM)
	column.add_child(title)
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.custom_minimum_size.x = 420
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	close_button.text = &"AAR_CLOSE"
	close_button.pressed.connect(hide)
	column.add_child(close_button)


func _enter_tree() -> void:
	EventBus.incursion_ended.connect(show_report)


func _exit_tree() -> void:
	EventBus.incursion_ended.disconnect(show_report)


## Shows [param report].
func show_report(report: Dictionary) -> void:
	var simulation: Simulation = SimClock.simulation
	if simulation == null:
		return
	body.text = "\n".join(AfterActionText.lines(report, simulation.state))
	visible = true
	close_button.grab_focus.call_deferred()
