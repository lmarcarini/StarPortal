class_name NamePlate
extends VBoxContainer
## Under the portrait window: the speaker's name in the faction's accent, their title, and the
## faction with its standing (Confidence for the Committee). Presentation only.
## Bible: docs/content/dialogue-screen.md section 1

## Font sizes at UI scale 1: name, then title and standing.
const NAME_SIZE: int = 24
const LINE_SIZE: int = 15

var _name := Label.new()
var _title := Label.new()
var _standing := Label.new()
var _scale: float = 1.0


func _init() -> void:
	for label: Label in [_name, _title, _standing]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var font: Font = UiThemeBuilder.label_font()
		if font != null:
			label.add_theme_font_override(&"font", font)
		add_child(label)
	_title.add_theme_color_override(&"font_color", UiPalette.TEXT_DIM)
	_standing.add_theme_color_override(&"font_color", UiPalette.TEXT_DIM)
	set_ui_scale(1.0)


## Sets the UI scale used for the font sizes.
func set_ui_scale(scale: float) -> void:
	_scale = scale
	_name.add_theme_font_size_override(&"font_size", roundi(NAME_SIZE * _scale))
	_title.add_theme_font_size_override(&"font_size", roundi(LINE_SIZE * _scale))
	_standing.add_theme_font_size_override(&"font_size", roundi(LINE_SIZE * _scale))


## Shows [param speaker_name] in [param accent], [param title] and [param standing] (either
## may be "" to hide its line).
func show_speaker(speaker_name: String, accent: Color, title: String, standing: String) -> void:
	_name.text = speaker_name.to_upper()
	_name.add_theme_color_override(&"font_color", accent)
	_title.text = title
	_title.visible = not title.is_empty()
	_standing.text = standing
	_standing.visible = not standing.is_empty()


## Returns the name, title and standing texts.
func get_texts() -> Array[String]:
	return [_name.text, _title.text, _standing.text]


## Returns the name label's colour.
func get_name_colour() -> Color:
	return _name.get_theme_color(&"font_color")
