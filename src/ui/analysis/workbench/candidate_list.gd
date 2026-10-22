class_name CandidateList
extends VBoxContainer
## The addresses that still fit the Address Workbench draft, listed when
## CandidateSummary.LIST_LIMIT or fewer remain, each with its lock energy and "Send to dial
## queue"; above the limit, a hint to narrow the draft. Also shows the result of a send.
## Reports sends; never edits the state.
## Bible: gate-and-address-spec.md#player-tools

## The player asked to queue [param address].
signal send_requested(address: GateAddress)

const _ROW_SCENE: PackedScene = preload("res://src/ui/analysis/workbench/candidate_row.tscn")

@onready var _hint: Label = %Hint
@onready var _rows: VBoxContainer = %Rows
@onready var _message: Label = %Message


## Shows [param summary]: its rows, or the hint when too many fit. Rows already in
## [param queue] are marked. [param translate] is the caller's tr.
func show_summary(
	summary: CandidateSummary, queue: Array[GateAddress], translate: Callable
) -> void:
	for row: Node in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	_hint.visible = summary.count > CandidateSummary.LIST_LIMIT
	_hint.text = str(translate.call("WORKBENCH_CANDIDATES_TOO_MANY")).format(
		{"limit": CandidateSummary.LIST_LIMIT}
	)
	var template: String = str(translate.call("WORKBENCH_ENERGY"))
	for index: int in summary.addresses.size():
		var address: GateAddress = summary.addresses[index]
		var energy: int = roundi(summary.energies_mwh[index])
		var row: CandidateRow = _ROW_SCENE.instantiate() as CandidateRow
		_rows.add_child(row)
		row.show_candidate(
			address,
			template.format({"energy": WorkbenchText.number(energy, translate)}),
			WorkbenchText.glyph_names(address.seals(), translate)
		)
		row.send_pressed.connect(send_requested.emit)
	show_queue(queue)


## Marks the rows whose address is in [param queue].
func show_queue(queue: Array[GateAddress]) -> void:
	for row: CandidateRow in get_rows():
		row.show_queued(
			queue.any(func(queued: GateAddress) -> bool: return queued.equals(row.get_address()))
		)


## Shows [param text] under the list; "" hides it.
func show_message(text: String) -> void:
	_message.text = text
	_message.visible = not text.is_empty()


## Returns the rows, in list order.
func get_rows() -> Array[CandidateRow]:
	var rows: Array[CandidateRow] = []
	for child: Node in _rows.get_children():
		if not child.is_queued_for_deletion():
			rows.append(child as CandidateRow)
	return rows


## Returns the message shown, or "".
func get_message() -> String:
	return _message.text if _message.visible else ""


## True when the "too many to list" hint shows.
func is_hint_shown() -> bool:
	return _hint.visible
