class_name HorizonPhoto
extends Control
## The horizon photograph beside the Ring, a polaroid-like card drawn in code (about 320 x 220).
## While the pole camera goes through it shows "The pole camera is going through…" with a
## progress bar, after a short flash (softer with reduced flashing). Once the connected world's
## horizon record is taken it shows the photo generated from the world scene as it stands now
## (SceneNow and ScenePhotoRules: a recovered object no longer appears; the same scene gives the
## same photo)
## captioned "Horizon record · <world or Unknown world> · <date>", and keeps it while the
## wormhole is open; closed, it hides. Clicking it, or A / Enter with it focused, enlarges it;
## again, or B / Escape, shrinks it back. Reads the simulation only; changes no state.
## Bible: game-design.md#base-building-and-power (pole camera, horizon record),
## docs/content/presentation-and-systems.md (Gate Room; pole camera)

## Phases: HIDDEN (no open wormhole, or nothing to show), DEVELOPING (the camera is going
## through), PHOTO (the record is taken).
enum Phase { HIDDEN, DEVELOPING, PHOTO }

## The card's size, and how much bigger it is enlarged.
const FRAME_SIZE: Vector2 = Vector2(320, 220)
const ENLARGE_SCALE: float = 2.0
const FLASH_SECONDS: float = 0.25
const SOFT_FLASH_SECONDS: float = 0.6
const SOFT_FLASH_PEAK: float = 0.35
const _BORDER: float = 8.0
const _CAPTION_HEIGHT: float = 34.0
const _PAPER: Color = Color(0.86, 0.84, 0.78)
const _INK: Color = Color(0.15, 0.14, 0.13)
const _DARK: Color = Color(0.08, 0.08, 0.09)
const _BAR: Color = Color(0.85, 0.7, 0.35)

var _simulation: Simulation = null
var _phase: Phase = Phase.HIDDEN
var _params: HorizonPhotoRules.Params = null
var _caption: String = ""
var _progress: float = 0.0
var _flash: float = 0.0
var _flash_seconds: float = FLASH_SECONDS
var _is_enlarged: bool = false
var _focus_before: Control = null


func _init() -> void:
	custom_minimum_size = FRAME_SIZE
	visible = false
	set_process(false)


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.horizon_record_taken.connect(_on_record_taken)
	EventBus.wormhole_closed.connect(_on_wormhole_closed)
	EventBus.dial_resolved.connect(_on_dial_resolved)
	EventBus.world_target_changed.connect(_on_target_changed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.horizon_record_taken.disconnect(_on_record_taken)
	EventBus.wormhole_closed.disconnect(_on_wormhole_closed)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)
	EventBus.world_target_changed.disconnect(_on_target_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh()


## Connects the photo to [param simulation] and shows what its open wormhole calls for.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	refresh()


## Reads the simulation again: hidden, the camera's progress, or the photo.
func refresh() -> void:
	var phase: Phase = _phase_of(_simulation)
	_set_phase(phase)
	if phase == Phase.DEVELOPING:
		var worlds: WorldsState = _simulation.state.worlds
		var total: float = ExtendPoleCameraCommand.EXTEND_TICKS
		_progress = clampf((total - worlds.pole_camera_ticks_left) / total, 0.0, 1.0)
	elif phase == Phase.PHOTO:
		_show_photo(_simulation.state)
	queue_redraw()


## Starts the short flash that marks the camera going out; softer with reduced flashing.
func flash() -> void:
	var is_soft: bool = Settings.get_bool(&"accessibility", &"reduced_flashing")
	_flash_seconds = SOFT_FLASH_SECONDS if is_soft else FLASH_SECONDS
	_flash = SOFT_FLASH_PEAK if is_soft else 1.0
	set_process(true)
	queue_redraw()


## Enlarges the photo, or shrinks it back. Only while it shows a photo.
func toggle_enlarged() -> void:
	if _is_enlarged:
		_set_enlarged(false)
	elif _phase == Phase.PHOTO:
		_set_enlarged(true)


## Returns the current phase.
func get_phase() -> Phase:
	return _phase


## True while the photo is enlarged.
func is_enlarged() -> bool:
	return _is_enlarged


## Returns the photo's parameters; null unless a photo shows.
func get_params() -> HorizonPhotoRules.Params:
	return _params if _phase == Phase.PHOTO else null


## Returns the caption; empty unless a photo shows.
func get_caption() -> String:
	return _caption if _phase == Phase.PHOTO else ""


## Returns the flash's strength, 0 when none plays.
func get_flash() -> float:
	return _flash


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta / _flash_seconds)
	set_process(_flash > 0.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	var is_click: bool = mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if is_click or event.is_action_pressed(&"ui_accept"):
		accept_event()
		toggle_enlarged()
	elif _is_enlarged and event.is_action_pressed(&"ui_cancel"):
		accept_event()
		_set_enlarged(false)


func _draw() -> void:
	if _phase == Phase.HIDDEN:
		return
	var frame := Rect2(Vector2.ZERO, size)
	var picture := Rect2(
		Vector2(_BORDER, _BORDER), size - Vector2(_BORDER * 2.0, _BORDER + _caption_height())
	)
	draw_rect(frame, _PAPER)
	draw_rect(picture, _DARK)
	if _phase == Phase.PHOTO and _params != null:
		HorizonPainter.paint(self, picture, _params)
		_draw_text(_caption, Vector2(_BORDER, picture.end.y + 4.0), _INK)
	else:
		_draw_developing(picture)
	if has_focus():
		draw_rect(frame, _BAR, false, 2.0)
	if _flash > 0.0:
		draw_rect(frame, Color(1, 1, 1, _flash))


func _draw_developing(picture: Rect2) -> void:
	var text: String = tr(&"GATE_WORMHOLE_CAMERA_OUT")
	_draw_text(text, picture.position + Vector2(8.0, picture.size.y * 0.35), _PAPER)
	var bar := Rect2(
		picture.position + Vector2(8.0, picture.size.y * 0.7), Vector2(picture.size.x - 16.0, 6.0)
	)
	draw_rect(bar, _PAPER.darkened(0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _progress, bar.size.y)), _BAR)


func _draw_text(text: String, top_left: Vector2, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = roundi(12.0 * _scale())
	var width: float = size.x - top_left.x - _BORDER
	draw_multiline_string(
		font,
		top_left + Vector2(0.0, font.get_ascent(font_size)),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		font_size,
		2,
		color
	)


func _scale() -> float:
	return ENLARGE_SCALE if _is_enlarged else 1.0


func _caption_height() -> float:
	return _CAPTION_HEIGHT * _scale()


static func _phase_of(simulation: Simulation) -> Phase:
	if simulation == null or simulation.state.gate.mode != GateState.RingMode.LOCKED:
		return Phase.HIDDEN
	var worlds: WorldsState = simulation.state.worlds
	var world_id: StringName = simulation.state.gate.connected_world_id
	if worlds.is_pole_camera_out() and worlds.pole_camera_world_id == world_id:
		return Phase.DEVELOPING
	if worlds.is_horizon_record_taken(world_id):
		return Phase.PHOTO
	return Phase.HIDDEN


func _set_phase(phase: Phase) -> void:
	_phase = phase
	visible = phase != Phase.HIDDEN
	var is_photo: bool = phase == Phase.PHOTO
	focus_mode = Control.FOCUS_ALL if is_photo else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if is_photo else Control.MOUSE_FILTER_IGNORE
	if not is_photo and _is_enlarged:
		_set_enlarged(false)


func _show_photo(state: GameState) -> void:
	var world_id: StringName = state.gate.connected_world_id
	var scene: WorldScene = SceneNow.of(state, world_id)
	if scene != null:
		_params = ScenePhotoRules.params_for(scene)
	else:
		_params = HorizonPhotoRules.params_for(world_id)
	_caption = HorizonPhotoText.caption(state, world_id)


func _set_enlarged(is_enlarged: bool) -> void:
	_is_enlarged = is_enlarged
	top_level = is_enlarged
	if is_enlarged:
		_focus_before = get_viewport().gui_get_focus_owner()
		var area: Vector2 = get_viewport_rect().size
		size = (FRAME_SIZE * ENLARGE_SCALE).min(area * 0.9)
		global_position = (area - size) / 2.0
		grab_focus()
	else:
		size = FRAME_SIZE
		if get_parent() is Container:
			(get_parent() as Container).queue_sort()
		if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
			_focus_before.grab_focus()
		_focus_before = null
	queue_redraw()


func _on_tick_advanced(_tick: int) -> void:
	if _phase == Phase.DEVELOPING or _phase != _phase_of(_simulation):
		refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	refresh()


func _on_record_taken(_world_id_taken: StringName) -> void:
	refresh()


func _on_wormhole_closed(_reason: StringName) -> void:
	refresh()


func _on_target_changed(_world: StringName, _target: StringName, _state: int) -> void:
	refresh()
