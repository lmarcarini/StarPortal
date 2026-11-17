extends Node
## Captures the game in the three reference states at the window size (1920 x 1080 in
## scripts/reference.sh): gate_idle (SILL selected), gate_open (wormhole to SILL, mission
## sheet open) and other_station (Base). Writes <state>.png into REF_OUT (default
## build/reference/). Not part of the game: lives in tools/, never in src/.
## Reference: docs/content/interface-reference.md section 6

const SCENARIO: String = "res://data/scenarios/scenario_gate_station.json"
const SILL: StringName = &"world_sill"
const SETTLE_FRAMES: int = 24

var _shell: Node = null
var _frame: int = 0
var _step: int = 0
var _out: String = ""


func _ready() -> void:
	_out = OS.get_environment("REF_OUT")
	if _out.is_empty():
		_out = ProjectSettings.globalize_path("res://build/reference/")
	DirAccess.make_dir_recursive_absolute(_out)
	var loaded: Result = SaveService.load_file(SCENARIO, GameDefs.from_registry(Registry))
	var state: GameState = loaded.value
	GameStart.start_scenario(&"reference", state)
	var scene: PackedScene = load("res://src/scenes/shell/shell.tscn")
	_shell = scene.instantiate()
	add_child(_shell)


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % SETTLE_FRAMES != 0:
		return
	var steps: Array[Callable] = [
		_to_idle,
		_shoot.bind("gate_idle"),
		_to_open,
		_shoot.bind("gate_open"),
		_to_other,
		_shoot.bind("other_station"),
		get_tree().quit,
	]
	if _step < steps.size():
		steps[_step].call()
		_step += 1


func _switcher() -> ViewSwitcher:
	var switcher: Object = _shell.get("view_switcher")
	return switcher as ViewSwitcher


func _gate() -> GateStationView:
	_switcher().show_station(&"gate")
	return _switcher().get_view(ViewSwitcher.GATE_ROOM) as GateStationView


func _to_idle() -> void:
	SimClock.pause()
	for card: DestinationCard in _gate().get_rack().get_cards():
		if card.get_destination().world_id == SILL:
			card.selected.emit(card)


func _to_open() -> void:
	var gate_view: GateStationView = _gate()
	var sim: Simulation = SimClock.simulation
	var gate: GateState = sim.state.gate
	gate.incoming_faction = &"team"
	gate.incoming_until_tick = sim.state.clock.tick + 10
	RingControl.answer_incoming(gate, SILL, sim.state.clock.tick)
	gate_view.open_mission_sheet()


func _to_other() -> void:
	_switcher().show_station(&"base")


func _shoot(state_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(state_name + ".png"))
	print("reference: wrote ", state_name)
