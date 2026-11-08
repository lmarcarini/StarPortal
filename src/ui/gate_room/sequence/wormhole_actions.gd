class_name WormholeActions
extends VBoxContainer
## The open portal's action panel, beside the Ring: Extend the pole camera (posts an
## ExtendPoleCameraCommand; while the camera goes through it shows its progress, then "Horizon
## record taken" and View the horizon photo; it says so at once, the same frame), Read the far
## Ring's console (ConsoleFinds), Read in the Archive (only when this lock delivered documents),
## Open the Address Book, Send the MOTH (posts a LaunchMothCommand; the MothScreen opens over the
## Gate Room; disabled with the reason when the rack is empty or a MOTH is out) and Close the
## wormhole (hold to confirm, posts a CloseWormholeCommand). Changes no state itself beyond
## submitting those commands.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## game-design.md#base-building-and-power (the pole camera, horizon record)

## The player asked to see the Address Book.
signal book_requested
## The player asked to read [param document_id] in the Archive.
signal archive_requested(document_id: StringName)
## The buttons that can take focus changed.
signal focus_changed
## The pole camera was just sent through (same frame as the press).
signal camera_extended
## The player asked to see the horizon photo enlarged.
signal photo_requested

var _simulation: Simulation = null

@onready var _camera_button: Button = %PoleCameraButton
@onready var _camera_progress: ProgressBar = %CameraProgress
@onready var _camera_note: Label = %CameraNote
@onready var _photo_button: Button = %PhotoButton
@onready var _console: ConsoleFinds = %ConsoleFinds
@onready var _archive_button: Button = %ArchiveButton
@onready var _book_button: Button = %BookButton
@onready var _moth_button: Button = %MothButton
@onready var _moth_note: Label = %MothNote
@onready var _close_button: HoldButton = %CloseButton


func _ready() -> void:
	_camera_button.pressed.connect(_on_camera_pressed)
	_archive_button.pressed.connect(_on_archive_pressed)
	_photo_button.pressed.connect(photo_requested.emit)
	_book_button.pressed.connect(book_requested.emit)
	_close_button.confirmed.connect(_on_close_confirmed)
	_moth_button.pressed.connect(_on_moth_pressed)
	_console.focus_changed.connect(focus_changed.emit)


## Connects the panel to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_console.setup(simulation)


## Shows the actions for the open wormhole of [param state].
func render(state: GameState) -> void:
	if not is_node_ready():
		return
	_show_camera(state.worlds, state.gate.connected_world_id)
	_archive_button.visible = not WormholeText.new_documents(state).is_empty()
	_console.render()
	_show_moth(state)


## Returns the buttons that can take focus now, in order.
func get_focusables() -> Array[Control]:
	var found: Array[Control] = []
	if not _camera_button.disabled:
		found.append(_camera_button)
	if _photo_button.visible:
		found.append(_photo_button)
	found.append_array(_console.get_focusables())
	if _archive_button.visible:
		found.append(_archive_button)
	found.append(_book_button)
	if not _moth_button.disabled:
		found.append(_moth_button)
	found.append(_close_button)
	return found


## Returns the far Ring's console panel.
func get_console() -> ConsoleFinds:
	return _console


## Returns the Extend the pole camera button.
func get_camera_button() -> Button:
	return _camera_button


## Returns the pole camera's progress note; empty unless it is going through.
func get_camera_note() -> String:
	return _camera_note.text if _camera_note.visible else ""


## Returns the View the horizon photo button.
func get_photo_button() -> Button:
	return _photo_button


## Returns the Read in the Archive button.
func get_archive_button() -> Button:
	return _archive_button


## Returns the Open the Address Book button.
func get_book_button() -> Button:
	return _book_button


## Returns the Send the MOTH button.
func get_moth_button() -> Button:
	return _moth_button


## Returns the Close the wormhole hold button.
func get_close_button() -> HoldButton:
	return _close_button


## Shows the pole camera for [param world_id]: Extend while the camera is in and the record not
## taken; while it goes through, its progress; once taken, "Horizon record taken" (disabled).
func _show_camera(worlds: WorldsState, world_id: StringName) -> void:
	var is_out: bool = worlds.is_pole_camera_out()
	var key: StringName = &"GATE_WORMHOLE_EXTEND_CAMERA"
	if is_out:
		key = &"GATE_WORMHOLE_CAMERA_OUT"
	elif worlds.is_horizon_record_taken(world_id):
		key = &"GATE_WORMHOLE_CAMERA_DONE"
	_camera_button.text = key
	_camera_button.disabled = key != &"GATE_WORMHOLE_EXTEND_CAMERA"
	_camera_button.focus_mode = Control.FOCUS_NONE if _camera_button.disabled else Control.FOCUS_ALL
	_photo_button.visible = key == &"GATE_WORMHOLE_CAMERA_DONE"
	_camera_progress.visible = is_out
	_camera_note.visible = is_out
	if not is_out:
		return
	var total: int = ExtendPoleCameraCommand.EXTEND_TICKS
	_camera_progress.max_value = total
	_camera_progress.value = total - worlds.pole_camera_ticks_left
	_camera_note.text = tr(&"GATE_WORMHOLE_CAMERA_PROGRESS").format(
		{"left": GateRoomFormat.duration(worlds.pole_camera_ticks_left)}
	)


func _on_camera_pressed() -> void:
	if _simulation == null or _camera_button.disabled:
		return
	_simulation.submit(ExtendPoleCameraCommand.new())
	render(_simulation.state)
	camera_extended.emit()
	focus_changed.emit()


func _on_archive_pressed() -> void:
	if _simulation == null:
		return
	var document_ids: Array[StringName] = WormholeText.new_documents(_simulation.state)
	if not document_ids.is_empty():
		archive_requested.emit(document_ids[0])


func _on_close_confirmed() -> void:
	if _simulation != null:
		_simulation.submit(CloseWormholeCommand.new())


## Shows Send the MOTH for [param state]: enabled with the drones in the rack, else disabled
## with the reason (the MOTH is out, or the rack is empty until the replacement arrives).
func _show_moth(state: GameState) -> void:
	var is_ok: bool = LaunchMothCommand.new().validate(state).is_ok
	_moth_button.disabled = not is_ok
	_moth_button.focus_mode = Control.FOCUS_ALL if is_ok else Control.FOCUS_NONE
	var note: String = tr(&"GATE_WORMHOLE_MOTH_RACK").format({"count": state.probes.rack})
	if state.probes.is_moth_out():
		note = tr(&"GATE_WORMHOLE_MOTH_OUT")
	elif state.probes.rack <= 0:
		note = tr(&"GATE_WORMHOLE_MOTH_EMPTY")
	_moth_note.text = note


func _on_moth_pressed() -> void:
	if _simulation == null or _moth_button.disabled:
		return
	_simulation.submit(LaunchMothCommand.new())
	render(_simulation.state)
	focus_changed.emit()
