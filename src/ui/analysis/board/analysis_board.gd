class_name AnalysisBoard
extends Control
## The Analysis Board of the Analysis view: a corkboard with one card for every clue the base
## has received, in the order they arrived. The player drags cards (or moves them with the
## arrows), links two cards with a string, tags them, marks them suspect and filters by tag;
## clicking or accepting a card opens its detail panel. The view never changes state: every
## change is an [AnnotateClueCommand] submitted to the simulation, and the board redraws on
## [signal EventBus.clue_received], [signal EventBus.clue_note_changed] and [method setup].
## It reads only what the player may know of a clue: text, source, grade, date and picture.
## Bible: gate-and-address-spec.md#player-tools,
## game-design.md#difficulty-and-accessibility

## What a press on a card means.
enum Mode { BROWSE, MOVE, LINK }

## Board zoom levels, widest first.
const ZOOM_LEVELS: Array[float] = [1.0, 0.6]

const _CARD_SCENE: PackedScene = preload("res://src/ui/analysis/board/clue_card.tscn")
# Longest linked-clue text shown in the detail panel, in characters.
const _LINK_TEXT_LENGTH: int = 60

var _simulation: Simulation = null
var _mode: Mode = Mode.BROWSE
var _active_id: StringName = &""
var _zoom_index: int = 0
var _filter_tag: String = ""
var _cards: Dictionary[StringName, ClueCard] = {}
var _positions: Dictionary[StringName, Vector2i] = {}
var _glyphs: GlyphTables = GlyphTables.new()

@onready var _filter_button: OptionButton = %FilterButton
@onready var _zoom_button: Button = %ZoomButton
@onready var _mode_label: Label = %ModeLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _holder: Control = %Holder
@onready var _surface: Control = %Surface
@onready var _link_layer: LinkLayer = %LinkLayer
@onready var _cards_root: Control = %Cards
@onready var _detail: ClueDetail = %Detail


func _enter_tree() -> void:
	if not EventBus.clue_received.is_connected(_on_clue_changed):
		EventBus.clue_received.connect(_on_clue_changed)
		EventBus.clue_note_changed.connect(_on_clue_changed)
	if is_node_ready():
		_refresh()


func _exit_tree() -> void:
	if EventBus.clue_received.is_connected(_on_clue_changed):
		EventBus.clue_received.disconnect(_on_clue_changed)
		EventBus.clue_note_changed.disconnect(_on_clue_changed)


func _ready() -> void:
	_zoom_button.pressed.connect(_on_zoom_pressed)
	_filter_button.item_selected.connect(_on_filter_selected)
	_detail.note_edited.connect(_submit_note)
	_detail.unlink_requested.connect(_on_unlink_requested)
	_detail.move_requested.connect(_start_move)
	_detail.link_requested.connect(_start_link)
	_detail.closed.connect(_close_detail)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _draw() -> void:
	if has_focus():
		var color: Color = get_theme_color(&"font_color", &"Label")
		draw_rect(Rect2(Vector2.ZERO, size), color, false, ClueCard.FOCUS_WIDTH)


# The board itself is the view's focus target: Accept steps into the cards, Cancel steps back.
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		_focus_first()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not has_focus() and _has_focus_inside():
		grab_focus()
		get_viewport().set_input_as_handled()


## Shows the clues of [param simulation]. Called when the view opens and after a load.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_mode = Mode.BROWSE
	_active_id = &""
	_mode_label.text = ""
	_detail.hide()
	_refresh()


## Returns the card of clue [param clue_id], or null when there is none.
func get_card(clue_id: StringName) -> ClueCard:
	return _cards.get(clue_id)


## Returns the ids of the clues shown, in arrival order.
func get_card_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _simulation == null:
		return ids
	for clue: ClueRecord in _simulation.state.intel.clues:
		ids.append(clue.id)
	return ids


## Returns what a press on a card means now.
func get_mode() -> Mode:
	return _mode


## Returns the detail panel.
func get_detail() -> ClueDetail:
	return _detail


## Returns the tag filter.
func get_filter_button() -> OptionButton:
	return _filter_button


## Returns the zoom button.
func get_zoom_button() -> Button:
	return _zoom_button


## Returns the layer that draws the links.
func get_link_layer() -> LinkLayer:
	return _link_layer


## Returns the zoom level now in use.
func get_zoom() -> float:
	return ZOOM_LEVELS[_zoom_index]


func _refresh() -> void:
	if _simulation == null:
		return
	var intel: IntelState = _simulation.state.intel
	_glyphs = GlyphTables.build()
	_positions = BoardLayout.positions(intel)
	_sync_cards(intel)
	_update_filter(intel)
	_apply_layout(intel)
	_empty_label.visible = intel.clues.is_empty()
	if _detail.visible and intel.get_clue(_detail.get_clue_id()) != null:
		_show_detail(_detail.get_clue_id())


func _sync_cards(intel: IntelState) -> void:
	var known: Dictionary[StringName, bool] = {}
	for clue: ClueRecord in intel.clues:
		known[clue.id] = true
	for clue_id: StringName in _cards.keys():
		if not known.has(clue_id):
			_cards[clue_id].queue_free()
			_cards.erase(clue_id)
	for clue: ClueRecord in intel.clues:
		if not _cards.has(clue.id):
			_cards[clue.id] = _make_card()
		_cards[clue.id].setup(clue, intel.note_for(clue.id), _text_of(clue))


func _make_card() -> ClueCard:
	var card: ClueCard = _CARD_SCENE.instantiate() as ClueCard
	_cards_root.add_child(card)
	card.activated.connect(_on_card_activated)
	card.cancelled.connect(_on_card_cancelled)
	card.moved.connect(_on_card_moved)
	card.dropped.connect(_commit_position)
	card.nudged.connect(_on_card_nudged)
	return card


func _text_of(clue: ClueRecord) -> String:
	return ClueText.format(tr(clue.text_key), clue.text_args, _glyphs.names, _glyphs.pictures)


func _update_filter(intel: IntelState) -> void:
	var tags: Array[String] = []
	for clue: ClueRecord in intel.clues:
		for tag: String in intel.note_for(clue.id).tags:
			if not tags.has(tag):
				tags.append(tag)
	tags.sort()
	if not tags.has(_filter_tag):
		_filter_tag = ""
	_filter_button.clear()
	_filter_button.add_item(tr(&"BOARD_FILTER_ALL"))
	for tag: String in tags:
		_filter_button.add_item(tag)
		_filter_button.set_item_auto_translate_mode(
			_filter_button.item_count - 1, Node.AUTO_TRANSLATE_MODE_DISABLED
		)
	_filter_button.select(0 if _filter_tag.is_empty() else tags.find(_filter_tag) + 1)


func _apply_layout(intel: IntelState) -> void:
	for clue_id: StringName in _cards:
		var card: ClueCard = _cards[clue_id]
		var note: ClueNote = intel.note_for(clue_id)
		card.visible = _filter_tag.is_empty() or note.tags.has(_filter_tag)
		card.size = Vector2(BoardLayout.CARD_SIZE)
		if not card.is_dragging() and not (_mode == Mode.MOVE and clue_id == _active_id):
			card.position = Vector2(_positions[clue_id])
	_update_links(intel)


# Sizes the scrolling area to the cards and redraws the strings between linked cards.
func _update_links(intel: IntelState) -> void:
	var content: Vector2 = Vector2(BoardLayout.content_size(_positions))
	for card: ClueCard in _cards.values():
		content = content.max(card.position + card.size + Vector2(BoardLayout.MARGIN))
	_surface.size = content
	_surface.scale = Vector2.ONE * get_zoom()
	_holder.custom_minimum_size = content * get_zoom()
	_link_layer.set_segments(LinkLayer.segments_for(_cards, intel))


func _has_focus_inside() -> bool:
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	return owner_control != null and is_ancestor_of(owner_control)


func _focus_first() -> void:
	for clue_id: StringName in get_card_ids():
		if _cards.has(clue_id) and _cards[clue_id].visible:
			_cards[clue_id].grab_focus()
			return
	_filter_button.grab_focus()


func _show_detail(clue_id: StringName) -> void:
	var intel: IntelState = _simulation.state.intel
	var record: ClueRecord = intel.get_clue(clue_id)
	var note: ClueNote = intel.note_for(clue_id)
	var link_texts: Dictionary[StringName, String] = {}
	var linked: Array[StringName] = note.links.duplicate()
	for other: ClueRecord in intel.clues:
		if intel.note_for(other.id).links.has(clue_id) and not linked.has(other.id):
			linked.append(other.id)
	for other_id: StringName in linked:
		var other: ClueRecord = intel.get_clue(other_id)
		if other != null:
			link_texts[other_id] = _text_of(other).left(_LINK_TEXT_LENGTH)
	_detail.show_clue(record, _text_of(record), note, link_texts)


func _open_detail(clue_id: StringName) -> void:
	_active_id = clue_id
	_show_detail(clue_id)
	_detail.get_default_focus().grab_focus()


func _close_detail() -> void:
	_detail.hide()
	if _cards.has(_active_id):
		_cards[_active_id].grab_focus()


func _on_clue_changed(_clue_id: StringName) -> void:
	_refresh()


func _on_zoom_pressed() -> void:
	_zoom_index = (_zoom_index + 1) % ZOOM_LEVELS.size()
	_zoom_button.text = &"BOARD_ZOOM_IN" if _zoom_index > 0 else &"BOARD_ZOOM_OUT"
	if _simulation != null:
		_update_links(_simulation.state.intel)


func _on_filter_selected(index: int) -> void:
	_filter_tag = "" if index <= 0 else _filter_button.get_item_text(index)
	if _simulation != null:
		_apply_layout(_simulation.state.intel)


func _on_card_activated(clue_id: StringName) -> void:
	match _mode:
		Mode.BROWSE:
			_open_detail(clue_id)
		Mode.MOVE:
			if clue_id == _active_id:
				_commit_position(clue_id)
				_end_mode()
		Mode.LINK:
			if clue_id != _active_id:
				_link(_active_id, clue_id)
			_end_mode()


func _on_card_cancelled(_clue_id: StringName) -> void:
	if _mode == Mode.BROWSE:
		grab_focus()
		return
	if _mode == Mode.MOVE and _cards.has(_active_id):
		_cards[_active_id].position = Vector2(_positions[_active_id])
		_update_links(_simulation.state.intel)
	_end_mode()


func _on_card_moved(_clue_id: StringName) -> void:
	_update_links(_simulation.state.intel)


func _on_card_nudged(clue_id: StringName, direction: Vector2i) -> void:
	if clue_id != _active_id:
		return
	var card: ClueCard = _cards[clue_id]
	var step: Vector2 = Vector2(direction * BoardLayout.NUDGE_STEP)
	card.position = Vector2(BoardLayout.clamp_position(Vector2i((card.position + step).round())))
	_update_links(_simulation.state.intel)


func _start_move(clue_id: StringName) -> void:
	_begin_mode(Mode.MOVE, clue_id, &"BOARD_MODE_MOVE")
	_cards[clue_id].move_mode = true


func _start_link(clue_id: StringName) -> void:
	_begin_mode(Mode.LINK, clue_id, &"BOARD_MODE_LINK")


func _begin_mode(mode: Mode, clue_id: StringName, label_key: StringName) -> void:
	_mode = mode
	_active_id = clue_id
	_mode_label.text = label_key
	_detail.hide()
	_cards[clue_id].grab_focus()


# Back to browsing: forgets the move or link in progress and focuses the card it was on.
func _end_mode() -> void:
	_mode = Mode.BROWSE
	_mode_label.text = ""
	if _cards.has(_active_id):
		_cards[_active_id].move_mode = false
		_cards[_active_id].grab_focus()


# Submits the dropped position of card [param clue_id], kept on the board; a card dropped
# where it already was submits nothing.
func _commit_position(clue_id: StringName) -> void:
	var dropped_at: Vector2i = BoardLayout.clamp_position(
		Vector2i(_cards[clue_id].position.round())
	)
	if dropped_at == _positions[clue_id]:
		_cards[clue_id].position = Vector2(dropped_at)
		return
	var note: ClueNote = ClueNote.from_dict(_simulation.state.intel.note_for(clue_id).to_dict())
	note.board_position = dropped_at
	_submit_note(clue_id, note)


# A link lives on one note, the first card's, so linking is one command. Nothing happens when
# the two cards are already linked, whichever note holds it.
func _link(first: StringName, second: StringName) -> void:
	var intel: IntelState = _simulation.state.intel
	if intel.note_for(second).links.has(first):
		return
	_set_link(first, second, true)


# Unlinking edits whichever note holds the link: one command.
func _on_unlink_requested(clue_id: StringName, other_id: StringName) -> void:
	_set_link(clue_id, other_id, false)
	_set_link(other_id, clue_id, false)


# Submits the note of [param clue_id] with a link to [param other_id] added or removed.
func _set_link(clue_id: StringName, other_id: StringName, linked: bool) -> void:
	var note: ClueNote = ClueNote.from_dict(_simulation.state.intel.note_for(clue_id).to_dict())
	if note.links.has(other_id) == linked:
		return
	if linked:
		note.links.append(other_id)
	else:
		note.links.erase(other_id)
	_submit_note(clue_id, note)


func _submit_note(clue_id: StringName, note: ClueNote) -> void:
	if _simulation != null:
		_simulation.submit(AnnotateClueCommand.create(clue_id, note))
