extends Node
## Captures the 2D-HD staff in the 3D Gate hall (M8-04) for the PR (the team leaves the
## scientists free for the console posts): the team on the ramp
## (staff_ramp.png), the frames of its walk into the horizon and of a return with one
## injured member (gif/*.png, joined into a GIF by the caller), and the frame time with
## and without six sprites (only that when STAFF_TIMING=1). Writes into STAFF_OUT
## (default build/staff_3d/). Not part of the game.
## Reference: docs/content/portraits.md

const SCENARIO: String = "res://data/scenarios/scenario_gate_station.json"
const GIF_STEP: float = 1.0 / 8.0

var _view: Station3D = null
var _ramp: TeamOnRamp = null
var _out: String = ""


func _ready() -> void:
	Station3D.force_enabled = true
	Station3D.skip_lightmaps = true
	_out = OS.get_environment("STAFF_OUT")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("res://build/staff_3d/")
	DirAccess.make_dir_recursive_absolute(_out + "/gif")
	var loaded: Result = SaveService.load_file(SCENARIO, GameDefs.from_registry(Registry))
	var state: GameState = loaded.value
	SimClock.start(Simulation.new(state))
	SimClock.simulation.state.clock.mode = ClockState.Mode.PAUSED
	_view = Station3D.new()
	_view.size = Vector2(1280, 720)
	add_child(_view)
	_view.setup(Registry.get_def(&"station_gate") as StationSceneDef)
	_ramp = _view.get_root().get_node(^"TeamOnRamp") as TeamOnRamp
	_ramp.set_process(false)
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("STAFF_TIMING") == "1":
		await _timing()
		get_tree().quit()
		return
	var team: Array[StringName] = _team(4)
	_ramp.show_ramp_team(team)
	_ramp.refresh_posts(SimClock.simulation.state)
	while StaffSprite3D.pending() > 0:
		StaffSprite3D.build_next()
	await _frames(6)
	_save("staff_ramp.png")
	var shot: int = 0
	_ramp.send(team)
	for i: int in 44:
		_ramp.advance(GIF_STEP)
		await _frames(1)
		_save("gif/%03d.png" % shot)
		shot += 1
	_ramp.bring_back(team, [team[1]])
	for i: int in 64:
		_ramp.advance(GIF_STEP)
		await _frames(1)
		if i % 2 == 0:
			_save("gif/%03d.png" % shot)
			shot += 1
	await _timing()
	get_tree().quit()


func _timing() -> void:
	_ramp.show_ramp_team(_team(4))
	_ramp.refresh_posts(SimClock.simulation.state)
	while StaffSprite3D.pending() > 0:
		StaffSprite3D.build_next()
	var shown: int = 0
	for child: Node in _ramp.get_children():
		if (child as StaffSprite3D).visible:
			shown += 1
	var with_ms: float = await _frame_ms(30)
	_ramp.visible = false
	var without_ms: float = await _frame_ms(30)
	_ramp.visible = true
	var start: int = Time.get_ticks_usec()
	for i: int in 1000:
		_ramp.advance(1.0 / 60.0)
	var cpu_us: float = (Time.get_ticks_usec() - start) / 1000.0
	var text: String = (
		"sprites shown %d\nframe with %.2f ms\nframe without %.2f ms\nadvance() %.1f us/frame\n"
		% [shown, with_ms, without_ms, cpu_us]
	)
	print(text)
	var file: FileAccess = FileAccess.open(_out + "/timing.txt", FileAccess.WRITE)
	file.store_string(text)


func _frame_ms(count: int) -> float:
	await _frames(10)
	RenderingServer.force_draw()
	var start: int = Time.get_ticks_usec()
	await _frames(count)
	return (Time.get_ticks_usec() - start) / 1000.0 / count


func _team(count: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	var people: Array[PersonState] = SimClock.simulation.state.staff.people
	for scientists: bool in [false, true]:
		for person: PersonState in people:
			var fits: bool = (person.role == &"role_scientist") == scientists
			if fits and not person.appearance.is_empty() and ids.size() < count:
				ids.append(person.id)
	return ids


func _frames(count: int) -> void:
	for i: int in count:
		await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	var image: Image = _view.get_viewport_3d().get_texture().get_image()
	image.save_png(_out + "/" + file_name)
