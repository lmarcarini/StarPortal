class_name DialogueLayout
extends RefCounted
## Builds the dialogue screen's tree: the dark ground, the top strip, the left column (portrait
## window over the name plate) and the right column (transcript over answers).
## Bible: docs/content/dialogue-screen.md sections 1 and 6

## Margin around the screen at UI scale 1.
const MARGIN: int = 24
## Font size of the top strip at UI scale 1.
const STRIP_SIZE: int = 18


## Adds the screen's children to [param screen].
static func build(screen: DialogueScreen) -> void:
	var ground := ColorRect.new()
	ground.color = DialogueScreen.GROUND
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(ground)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	screen.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 16)
	margin.add_child(rows)
	var strip: Array[Label] = _strip(rows)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 28)
	rows.add_child(body)
	var left: VBoxContainer = _left_column(screen, body)
	_right_column(screen, body)
	screen.adopt(strip[0], strip[1], strip[2], left)


static func _strip(rows: VBoxContainer) -> Array[Label]:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override(&"separation", 24)
	rows.add_child(strip)
	var labels: Array[Label] = []
	for colour: Color in [UiPalette.TEXT_DIM, UiPalette.WARN, UiPalette.TEXT_DIM]:
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.add_theme_color_override(&"font_color", colour)
		label.add_theme_font_size_override(&"font_size", STRIP_SIZE)
		var font: Font = UiThemeBuilder.label_font()
		if font != null:
			label.add_theme_font_override(&"font", font)
		labels.append(label)
		strip.add_child(label)
	labels[2].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels[2].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	labels[2].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	labels[2].clip_text = true
	var rule := HSeparator.new()
	rows.add_child(rule)
	return labels


static func _left_column(screen: DialogueScreen, body: HBoxContainer) -> VBoxContainer:
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 12)
	body.add_child(left)
	screen.portrait_slot.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	screen.portrait_slot.add_child(screen.portrait)
	screen.portrait_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	screen.portrait_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(screen.portrait_slot)
	left.add_child(screen.name_plate)
	return left


static func _right_column(screen: DialogueScreen, body: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 16)
	body.add_child(right)
	right.add_child(screen.transcript)
	right.add_child(HSeparator.new())
	screen.answers.size_flags_vertical = Control.SIZE_SHRINK_END
	right.add_child(screen.answers)
