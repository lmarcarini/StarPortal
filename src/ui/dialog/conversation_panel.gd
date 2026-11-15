class_name ConversationPanel
extends PanelContainer
## The non-modal conversation panel on the right third of the screen: the faction, the lines
## as they arrive, then the answers (locked ones greyed with their reason); "(signal lost)"
## when cut off. Answers by mouse, keyboard (1 to 4) or gamepad focus; Continue moves a line
## on and, once the link has ended, becomes Close. It only reads the state and submits
## ChooseOptionCommand and AdvanceConversationCommand. Stand-in until the dialogue screen
## (M4.8-04) replaces it.
## Bible: docs/content/m4-core-systems.md section 3, docs/content/dialogue-screen.md section 2

## Actions that pick the first four answers (keys 1 to 4 by default).
const _ACTIONS: Array[StringName] = [
	&"dialog_choice_1", &"dialog_choice_2", &"dialog_choice_3", &"dialog_choice_4"
]

var _simulation: Simulation = null
var _header := Label.new()
var _scroll := ScrollContainer.new()
var _lines := VBoxContainer.new()
var _choices := VBoxContainer.new()
var _continue := Button.new()


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	anchor_left = 2.0 / 3.0
	offset_top = 96.0
	offset_bottom = -16.0
	offset_right = -16.0
	var layout := VBoxContainer.new()
	add_child(layout)
	_header.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_header.add_theme_font_size_override(&"font_size", 18)
	layout.add_child(_header)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_lines)
	layout.add_child(_scroll)
	layout.add_child(_choices)
	_continue.text = &"CONV_CONTINUE"
	_continue.pressed.connect(_advance)
	layout.add_child(_continue)


func _enter_tree() -> void:
	EventBus.conversation_started.connect(_on_started)
	EventBus.conversation_line.connect(_on_line)
	EventBus.conversation_choices.connect(_on_choices)
	EventBus.conversation_over.connect(_on_over)
	EventBus.conversation_ended.connect(_on_ended)


func _exit_tree() -> void:
	EventBus.conversation_started.disconnect(_on_started)
	EventBus.conversation_line.disconnect(_on_line)
	EventBus.conversation_choices.disconnect(_on_choices)
	EventBus.conversation_over.disconnect(_on_over)
	EventBus.conversation_ended.disconnect(_on_ended)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var number: int = -1
	for place: int in _ACTIONS.size():
		if InputActions.is_new_press(event, _ACTIONS[place]):
			number = place
	if number >= 0 and number < _choices.get_child_count():
		var button: Button = _choices.get_child(number) as Button
		if not button.disabled:
			button.pressed.emit()
			get_viewport().set_input_as_handled()


## Connects the panel to [param simulation]; shows a conversation already running (a load).
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	hide()
	var active: ActiveConversation = simulation.state.conversations.active
	if active == null:
		return
	_on_started(active.conversation, active.channel)
	var def: ConversationDef = ConversationRules.active_def(simulation.state)
	for step: Array in active.path:
		var node_id: StringName = step[0]
		var node: ConversationNodeDef = def.node(node_id)
		if node != null and node.kind == ConversationNodeDef.Kind.LINE:
			_add_line(ConversationText.line(simulation.state, node))
	if active.phase == ActiveConversation.Phase.ENDED:
		_on_over(active.cut_off)
		return
	_show_choices()
	_update_continue()


## Returns the shown lines' texts, oldest first.
func get_line_texts() -> Array[String]:
	var found: Array[String] = []
	for child: Node in _lines.get_children():
		found.append((child as Label).text)
	return found


## Returns the answer buttons, in order.
func get_choice_buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child: Node in _choices.get_children():
		found.append(child as Button)
	return found


## Returns the Continue (Close once ended) button.
func get_continue_button() -> Button:
	return _continue


## Returns the header text.
func get_header_text() -> String:
	return _header.text


func _on_started(conversation_id: StringName, _channel: StringName) -> void:
	if _simulation == null:
		return
	for child: Node in _lines.get_children():
		child.queue_free()
		_lines.remove_child(child)
	_clear_choices()
	var def: ConversationDef = _simulation.state.conversation_defs.get(conversation_id)
	_header.text = ConversationText.header(_simulation.state, def)
	_update_continue()
	show()


func _on_line(node_id: StringName) -> void:
	var def: ConversationDef = (
		null if _simulation == null else ConversationRules.active_def(_simulation.state)
	)
	if def == null or def.node(node_id) == null:
		return
	_clear_choices()
	_add_line(ConversationText.line(_simulation.state, def.node(node_id)))
	_update_continue()


func _on_choices() -> void:
	_show_choices()
	_update_continue()


func _on_over(cut_off: bool) -> void:
	_clear_choices()
	if cut_off:
		_add_line(tr(&"CONV_SIGNAL_LOST"))
	_update_continue()


func _on_ended(_uid: int, _cut_off: bool) -> void:
	hide()


## Continue shows except at a choice; it reads Close once the link has ended.
func _update_continue() -> void:
	var active: ActiveConversation = (
		null if _simulation == null else _simulation.state.conversations.active
	)
	_continue.visible = active != null and active.phase != ActiveConversation.Phase.CHOICE
	var ended: bool = active != null and active.phase == ActiveConversation.Phase.ENDED
	_continue.text = &"CONV_CLOSE" if ended else &"CONV_CONTINUE"
	if _continue.visible and is_inside_tree():
		_continue.grab_focus.call_deferred()


func _advance() -> void:
	if _simulation != null:
		_simulation.submit(AdvanceConversationCommand.new())


func _show_choices() -> void:
	_clear_choices()
	if _simulation == null:
		return
	var shown: Array[Dictionary] = ConversationRules.choices(_simulation.state)
	for place: int in shown.size():
		var choice: Dictionary = shown[place]
		var button := Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = ConversationText.choice(choice, place + 1)
		button.disabled = not choice["enabled"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var index: int = choice["index"]
		button.pressed.connect(_choose.bind(index))
		_choices.add_child(button)
	for button: Button in get_choice_buttons():
		if not button.disabled and is_inside_tree():
			button.grab_focus.call_deferred()
			break


func _choose(index: int) -> void:
	if _simulation != null:
		_simulation.submit(ChooseOptionCommand.new(index))


func _add_line(text: String) -> void:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	_lines.add_child(label)


func _clear_choices() -> void:
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
