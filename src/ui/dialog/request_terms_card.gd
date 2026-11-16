class_name RequestTermsCard
extends PaperCard
## The terms of a request offered in a conversation (M4.10-05), on a paper card beside the
## transcript: what is asked (with the request's title), the time to do it, and the reward
## and penalty, each behind an icon. Shown only at an offer step.
## Bible: docs/content/interface-rethink.md section 6 (In conversations)

const _ICON_SIDE: float = 22.0

var _title: Label = Label.new()
var _rows: VBoxContainer = VBoxContainer.new()


func _init() -> void:
	super()
	name = &"RequestTerms"
	visible = false
	custom_minimum_size.x = 300.0
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 6)
	add_child(column)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	column.add_child(_rows)


## Shows the terms of [param def] in [param state], or hides the card for null.
func show_terms(state: GameState, def: RequestDef) -> void:
	visible = def != null
	for child: Node in _rows.get_children():
		child.queue_free()
	if def == null:
		return
	_title.text = tr(def.title_key)
	for line: String in RequestText.objective_lines(state, def):
		_add_row(&"report", line.trim_prefix(RequestText.UNMET).trim_prefix(RequestText.MET))
	if def.deadline_days > 0:
		_add_row(&"clock", tr(&"REQUEST_TERMS_DAYS").format({"days": def.deadline_days}))
	for line: String in RequestText.preview_lines(def):
		_add_row(&"funds", line)


## The texts shown, title first (for tests).
func get_texts() -> Array[String]:
	var texts: Array[String] = [_title.text]
	for row: Node in _rows.get_children():
		if row.is_queued_for_deletion():
			continue
		texts.append((row.get_child(1) as Label).text)
	return texts


func _add_row(icon_id: StringName, text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var icon: Control = Control.new()
	icon.custom_minimum_size = Vector2(_ICON_SIDE, _ICON_SIDE)
	icon.draw.connect(
		func() -> void:
			HardwareIcons.draw(icon, icon_id, Rect2(Vector2.ZERO, icon.size), UiThemeHardware.INK)
	)
	row.add_child(icon)
	var label: Label = Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text.strip_edges()
	row.add_child(label)
	_rows.add_child(row)
