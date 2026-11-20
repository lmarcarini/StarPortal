class_name PauseMenuParts
extends RefCounted
## Small pieces of the pause menu in the interface reference's type: a section heading
## (dim stencil letters) and the confirm question's style.
## Bible: docs/content/interface-reference.md section 3


## A section heading for translation key [param key].
static func heading(key: StringName) -> Label:
	var title: Label = Label.new()
	title.text = key
	title.add_theme_font_override(
		&"font", RefText.make(RefText.LABEL, 0, RefPaint.TEXT, 2.0).get_font()
	)
	title.add_theme_font_size_override(&"font_size", 22)
	title.add_theme_color_override(&"font_color", RefPaint.DIM)
	return title


## Styles [param question]: wrapped light text, 520 px wide.
static func style_question(question: Label) -> void:
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.custom_minimum_size.x = 520
	question.add_theme_font_override(
		&"font", RefText.make(RefText.LABEL, 0, RefPaint.TEXT, 1.0).get_font()
	)
	question.add_theme_font_size_override(&"font_size", 22)
	question.add_theme_color_override(&"font_color", RefPaint.TEXT)
