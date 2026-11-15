class_name DialogueScreen
extends Control
## The dialogue screen (M4.8-04): a modal over the whole game while a conversation is open.
## Top strip (the stopped date and time, BASE ON HOLD, the channel); on the left, about a
## quarter of the width, the portrait window (a square no taller than 40% of the screen) and
## the name plate; on the right the transcript and the answers. Lines type out; Continue
## (Space, Enter, click, (A)) shows the whole line, then moves on. Nothing behind it can be
## reached; only the pause menu (and quick save and load) still work. It reads the state and
## submits AdvanceConversationCommand and ChooseOptionCommand only.
## Bible: docs/content/dialogue-screen.md sections 1, 2, 5 and 6

## Emitted when the screen opens and when it closes.
signal opened
signal closed

## The screen's ground: darker and calmer than the management tabs.
const GROUND: Color = Color("#0b0e0f")
## Share of the width the left column takes.
const LEFT_SHARE: float = 0.25
## The portrait window's largest side, as a share of the screen's height.
const PORTRAIT_MAX_SHARE: float = 0.4
## The answers' largest height, as a share of the screen's height (they scroll beyond it).
const ANSWERS_MAX_SHARE: float = 0.42
## Pixels the transcript scrolls per key press or stick pull.
const SCROLL_STEP: float = 60.0
## Actions that pick the first four answers.
const CHOICE_ACTIONS: Array[StringName] = [
	&"dialog_choice_1", &"dialog_choice_2", &"dialog_choice_3", &"dialog_choice_4"
]
## Actions that still reach the rest of the game while the screen is up.
const PASSED_ACTIONS: Array[StringName] = [
	&"pause_menu", &"quick_save", &"quick_load", &"debug_toggle_overlay"
]

## The pause menu, when the shell has one: while it is open the screen takes no input.
var pause_menu: PauseMenu = null
## The square window the portrait goes in (a plain frame until M4.8-05).
var portrait_slot := PanelContainer.new()
var name_plate := NamePlate.new()
var transcript := TranscriptView.new()
var answers := AnswerList.new()

var _simulation: Simulation = null
var _date: Label = null
var _hold: Label = null
var _channel: Label = null
var _left: VBoxContainer = null
var _focus_before: Control = null


func _init() -> void:
	name = &"DialogueScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		set_focus_neighbor(side, ^".")
	focus_next = ^"."
	focus_previous = ^"."
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DialogueLayout.build(self)
	transcript.clicked.connect(continue_pressed)
	transcript.typing_finished.connect(_on_typing_finished)
	answers.chosen.connect(_choose)
	answers.continued.connect(continue_pressed)
	resized.connect(_fit_portrait)


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


func _input(event: InputEvent) -> void:
	if not visible or (pause_menu != null and pause_menu.is_open()):
		return
	if DialogueInput.passes(event, PASSED_ACTIONS):
		return
	if not DialogueInput.handle(self, event):
		get_viewport().set_input_as_handled()


## Binds [param simulation]; shows a conversation already open (after a load) at its phase.
func bind(simulation: Simulation) -> void:
	_simulation = simulation
	_close_screen()
	var active: ActiveConversation = simulation.state.conversations.active
	if active == null:
		return
	_open_screen()
	DialogueReplay.replay(self, simulation.state)
	_show_phase()


## Continue: shows the whole line while it types, else moves the conversation on (to the first
## line, the next line, or closing at the end). Nothing at a choice.
func continue_pressed() -> void:
	if transcript.is_typing():
		transcript.finish_typing()
		return
	var active: ActiveConversation = _active()
	if active == null or active.phase == ActiveConversation.Phase.CHOICE:
		return
	_simulation.submit(AdvanceConversationCommand.new())


## Picks the answer shown at place [param number] (1 to 4); true when one was picked.
func pick_number(number: int) -> bool:
	if transcript.is_typing():
		return false
	return answers.press_number(number)


## True while shown.
func is_open() -> bool:
	return visible


## The simulation bound, or null.
func get_simulation() -> Simulation:
	return _simulation


## Returns the top strip's texts: date, hold and channel.
func get_strip_texts() -> Array[String]:
	return [_date.text, _hold.text, _channel.text]


## Returns the left column (portrait window and name plate).
func get_left_column() -> Control:
	return _left


## Called by DialogueLayout: the strip's labels and the left column.
func adopt(date: Label, hold: Label, channel: Label, left: VBoxContainer) -> void:
	_date = date
	_hold = hold
	_channel = channel
	_left = left


## Shows the line [param node] (typed unless [param typed] is false) and its speaker.
func show_line(node: ConversationNodeDef, typed: bool = true) -> void:
	var state: GameState = _simulation.state
	var speaker: SpeakerDef = state.speaker_defs.get(node.speaker)
	var faction: StringName = &"" if speaker == null else speaker.faction
	var accent: Color = ConversationText.readable_accent(state, faction, GROUND)
	var speaker_name: String = (
		"" if node.speaker.is_empty() else ConversationText.speaker_name(state, node.speaker)
	)
	transcript.add_line(speaker_name, accent, tr(node.text_key), typed)
	if speaker != null:
		var title: String = ConversationText.speaker_title(state, node.speaker)
		var standing: String = ConversationText.standing(state, faction)
		name_plate.show_speaker(speaker_name, accent, title, standing)
	speaker_shown(speaker, node.mood)


## Hook for the portrait window (M4.8-05): [param speaker] now talks in [param mood].
func speaker_shown(_speaker: SpeakerDef, _mood: StringName) -> void:
	pass


## Shows the player's answer [param text] as YOU.
func show_answer(text: String) -> void:
	transcript.add_line(tr(&"DIALOG_YOU"), UiPalette.SELECT, text, false)


func _active() -> ActiveConversation:
	return null if _simulation == null else _simulation.state.conversations.active


func _on_started(_conversation_id: StringName, _channel_id: StringName) -> void:
	if _simulation == null:
		return
	_open_screen()
	_simulation.submit(AdvanceConversationCommand.new())


func _on_line(node_id: StringName) -> void:
	var def: ConversationDef = (
		null if _simulation == null else ConversationRules.active_def(_simulation.state)
	)
	if def == null or def.node(node_id) == null:
		return
	show_line(def.node(node_id))
	answers.show_continue(&"CONV_CONTINUE")
	answers.focus_first()


func _on_choices() -> void:
	_show_choices()


func _on_over(cut_off: bool) -> void:
	transcript.finish_typing()
	if cut_off:
		transcript.add_line("", UiPalette.ALARM, tr(&"CONV_SIGNAL_LOST"), false)
	answers.show_continue(&"CONV_CLOSE")
	answers.focus_first()


func _on_ended(_uid: int, _cut_off: bool) -> void:
	_close_screen()


func _on_typing_finished() -> void:
	pass


func _show_phase() -> void:
	var active: ActiveConversation = _active()
	match active.phase:
		ActiveConversation.Phase.OPENING:
			_simulation.submit(AdvanceConversationCommand.new())
		ActiveConversation.Phase.LINE:
			answers.show_continue(&"CONV_CONTINUE")
		ActiveConversation.Phase.CHOICE:
			_show_choices()
		ActiveConversation.Phase.ENDED:
			_on_over(active.cut_off)
	answers.focus_first()


func _show_choices() -> void:
	var state: GameState = _simulation.state
	var shown: Array[Dictionary] = []
	for choice: Dictionary in ConversationRules.choices(state):
		var key: StringName = choice["text_key"]
		var value: Variant = choice["reason"]
		var reason: ConditionDef = value if value is ConditionDef else null
		(
			shown
			. append(
				{
					"index": choice["index"],
					"text": tr(key),
					"enabled": choice["enabled"],
					"reason": "" if reason == null else StoryText.reason(reason),
				}
			)
		)
	answers.show_choices(shown)
	answers.focus_first()


func _choose(index: int) -> void:
	var node: ConversationNodeDef = ConversationRules.current_node(_simulation.state)
	if node == null or node.kind != ConversationNodeDef.Kind.CHOICE:
		return
	var command := ChooseOptionCommand.new(index)
	if not command.validate(_simulation.state).is_ok:
		return
	show_answer(tr(node.choices[index].text_key))
	answers.clear()
	_simulation.submit(command)


func _open_screen() -> void:
	if visible:
		return
	_focus_before = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	transcript.clear()
	answers.clear()
	_refresh_strip()
	visible = true
	if is_inside_tree():
		grab_focus()
	opened.emit()


func _close_screen() -> void:
	transcript.clear()
	answers.clear()
	if not visible:
		return
	visible = false
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null
	closed.emit()


func _refresh_strip() -> void:
	var state: GameState = _simulation.state
	var date: Dictionary = TimeMath.date_of(state.clock.tick)
	_date.text = (
		"%04d-%02d-%02d %02d:%02d"
		% [date["year"], date["month"], date["day"], date["hour"], date["minute"]]
	)
	_hold.text = tr(&"DIALOG_BASE_ON_HOLD")
	var active: ActiveConversation = state.conversations.active
	_channel.text = "" if active == null else ConversationText.channel(state, active)
	var scale: float = Settings.get_float(&"display", &"ui_scale")
	transcript.set_ui_scale(scale)
	answers.set_ui_scale(scale)
	name_plate.set_ui_scale(scale)
	for label: Label in [_date, _hold, _channel]:
		label.add_theme_font_size_override(&"font_size", roundi(DialogueLayout.STRIP_SIZE * scale))


func _fit_portrait() -> void:
	var side: float = minf(size.x * LEFT_SHARE, size.y * PORTRAIT_MAX_SHARE)
	portrait_slot.custom_minimum_size = Vector2(side, side)
	_left.custom_minimum_size.x = size.x * LEFT_SHARE
	answers.max_height = size.y * ANSWERS_MAX_SHARE
