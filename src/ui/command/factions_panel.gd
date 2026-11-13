class_name FactionsPanel
extends ScrollContainer
## The Command tab's Factions sub-tab: every met faction with its name in its accent colour, a
## standing bar (−100..100; the Committee's Confidence 0..100), the value and attitude, its
## open requests and its last ten standing causes with dates. Read only; rebuilt on
## standing_changed and faction_met while shown.
## Bible: docs/content/m4-core-systems.md section 2

var _simulation: Simulation = null
var _list := VBoxContainer.new()


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 12)
	add_child(_list)


## Connects the panel to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	refresh()


## Rebuilds one block per met faction, in the order they were met.
func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	for faction_id: StringName in state.factions.met:
		var faction: FactionDef = state.faction_defs.get(faction_id)
		if faction != null:
			_list.add_child(_block(state, faction))


## Returns the faction names shown, in order.
func get_names() -> Array[String]:
	var found: Array[String] = []
	for block: Node in _list.get_children():
		found.append((block.get_child(0) as Label).text)
	return found


## Returns the text of block [param index] (every label joined by new lines).
func get_block_text(index: int) -> String:
	var lines: PackedStringArray = []
	for child: Node in _list.get_child(index).get_children():
		if child is Label:
			lines.append((child as Label).text)
	return "\n".join(lines)


## Returns the standing bar of block [param index].
func get_bar(index: int) -> ProgressBar:
	for child: Node in _list.get_child(index).get_children():
		if child is ProgressBar:
			return child as ProgressBar
	return null


func _block(state: GameState, faction: FactionDef) -> VBoxContainer:
	var block := VBoxContainer.new()
	var name := _label(tr(faction.name_key))
	name.add_theme_color_override(&"font_color", faction.accent)
	name.add_theme_font_size_override(&"font_size", 18)
	block.add_child(name)
	var value: int = FactionRules.standing(state, faction.id)
	var bar := ProgressBar.new()
	bar.min_value = 0 if faction.uses_confidence else FactionRules.MIN
	bar.max_value = FactionRules.MAX
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	block.add_child(bar)
	var attitude: String = tr(FactionRules.attitude_key(FactionRules.attitude(state, faction.id)))
	block.add_child(
		_label(
			tr(&"FACTION_STANDING_LINE").format(
				{"value": value, "attitude": attitude, "requests": _open_requests(state, faction)}
			)
		)
	)
	if faction.uses_confidence:
		for cause: ConfidenceCause in state.committee.causes:
			block.add_child(_label(CommitteeText.cause_line(cause, state)))
	else:
		var causes: Array = state.factions.causes.get(faction.id, [])
		for cause: Dictionary in causes:
			block.add_child(_label(cause_line(cause)))
	return block


## "2026-01-04  Gift  +5": the date, the reason and the change of a standing cause.
static func cause_line(cause: Dictionary) -> String:
	var date: Dictionary = TimeMath.date_of(SaveFields.read_int(cause["tick"]))
	var key: StringName = StringName(str(cause["key"]))
	return (
		"%04d-%02d-%02d  %s  %s"
		% [
			date["year"],
			date["month"],
			date["day"],
			TranslationServer.translate(key),
			StoryText.signed(SaveFields.read_int(cause["delta"])),
		]
	)


static func _open_requests(state: GameState, faction: FactionDef) -> int:
	var count: int = 0
	for record: RequestRecord in state.requests.items:
		var def: RequestDef = state.request_defs.get(record.request)
		if record.is_open() and def != null and def.faction == faction.id:
			count += 1
	return count


static func _label(text: String) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	return label
