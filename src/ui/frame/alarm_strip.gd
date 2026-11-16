class_name AlarmStrip
extends PanelContainer
## The red strip in the top bar during an incursion (M4c-11), and the alarm look: a faint red
## wash with red rules round the screen, over every tab, that never moves anything or takes a
## click. Hidden when there is no incursion.
## Bible: docs/content/m4c-incursions.md section 7

## The strip's text.
var label := Label.new()
## The full-screen alarm wash.
var wash := AlarmWash.new()


func _init() -> void:
	name = &"AlarmStrip"
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.ALARM.darkened(0.3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	add_theme_stylebox_override(&"panel", style)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(label)
	add_child(wash)


## Shows the alarm of [param state].
func show_state(state: GameState) -> void:
	var text: String = AlarmText.strip(state)
	visible = not text.is_empty()
	wash.visible = visible
	label.text = text
