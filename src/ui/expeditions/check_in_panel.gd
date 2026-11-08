class_name ExpeditionCheckInPanel
extends VBoxContainer
## The right column of the Expeditions tab (docs/content/m3-beyond-the-ring.md section 7): the
## latest check-in (its date and its line) and who on the team is injured, with the time left
## to recover. Reads state only.
## Bible: docs/content/m3-beyond-the-ring.md section 7

var _title := Label.new()
var _line := Label.new()
var _injured := Label.new()


func _init() -> void:
	custom_minimum_size.x = 260
	add_theme_constant_override(&"separation", 8)
	add_child(_title)
	add_child(_line)
	add_child(_injured)
	for label: Label in [_title, _line, _injured]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Rereads [param state].
func show_state(state: GameState) -> void:
	var entry: LogEntry = ExpeditionTripText.latest_check_in(state)
	if entry == null:
		_title.text = tr(&"EXPEDITION_CHECK_IN_TITLE_NONE")
		_line.text = ""
	else:
		_title.text = tr(&"EXPEDITION_CHECK_IN_TITLE").format(
			{"date": ExpeditionText.date(entry.tick)}
		)
		var world: String = AddressBookText.name_of_world(entry.world_id, state)
		_line.text = ExpeditionLogText.line(entry.args, world)
	var injured: Array[String] = []
	if state.expedition.is_out():
		injured = ExpeditionTripText.injured(state)
	_injured.text = "\n".join(injured)
	_line.visible = not _line.text.is_empty()
	_injured.visible = not _injured.text.is_empty()


## Returns the shown texts: title, line, injured.
func texts() -> Array[String]:
	return [_title.text, _line.text, _injured.text]
