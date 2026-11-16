## The text rules on the frame and the Gate station (M4.10-06, interface-rethink.md section 7):
## every visible label and key outside hover cards, documents and conversations is at most
## three words. Scans the frame and the Gate station idle, with a wormhole open and with the
## mission sheet and the alien panel up.
## Bible: docs/content/interface-rethink.md section 7
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const SCENARIO: String = "res://data/scenarios/scenario_gate_station.json"
## Most words a visible label may have.
const MAX_WORDS: int = 3
## Where sentences are allowed: hover cards, documents and conversations.
const SENTENCE_HOSTS: Array[String] = [
	"HoverCard",
	"DocumentReader",
	"ClueClip",
	"DialogueScreen",
	"TeamReportScreen",
	"WorldReportPanel",
	"RequestTermsCard",
]

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null


func before_test() -> void:
	var loaded: Result = SaveService.load_file(SCENARIO, GameDefs.from_registry(Registry))
	var state: GameState = loaded.value
	GameStart.start_scenario(&"text", state)
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_runner = scene_runner(_shell)
	await _runner.simulate_frames(3)


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	GameStart.reset()


## Texts over MAX_WORDS shown under [param root], as "path: text".
static func long_texts(root: Node) -> Array[String]:
	var found: Array[String] = []
	_scan(root, found)
	return found


static func _scan(node: Node, found: Array[String]) -> void:
	var item: CanvasItem = node as CanvasItem
	if item != null and not item.is_visible_in_tree():
		return
	if _hosts_sentences(node):
		return
	var text: String = _text_of(node)
	if text.strip_edges().split(" ", false).size() > MAX_WORDS:
		found.append("%s: %s" % [node.get_path(), text])
	for child: Node in node.get_children():
		_scan(child, found)


static func _hosts_sentences(node: Node) -> bool:
	var script: Script = node.get_script()
	var name: String = "" if script == null else script.get_global_name()
	return SENTENCE_HOSTS.has(name)


static func _text_of(node: Node) -> String:
	var label: Label = node as Label
	if label != null:
		return (
			label.tr(label.text)
			if label.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED
			else label.text
		)
	var button: Button = node as Button
	if button != null:
		return (
			button.tr(button.text)
			if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED
			else button.text
		)
	var rich: RichTextLabel = node as RichTextLabel
	if rich != null:
		return rich.get_parsed_text()
	return ""


func _gate() -> GateStationView:
	return _shell.view_switcher.get_view(ViewSwitcher.GATE_ROOM) as GateStationView


func test_frame_and_gate_idle() -> void:
	var found: Array[String] = long_texts(_shell.frame)
	found.append_array(long_texts(_gate()))
	assert_array(found).is_empty()


func test_gate_open_with_the_sheet() -> void:
	var simulation: Simulation = SimClock.simulation
	var state: GameState = simulation.state
	var world: StringName = state.address_book.entries[0].world_id
	var address: GateAddress = state.galaxy.address_of(world, state.galaxy.home().origin_glyph)
	state.power.stored_mwh = PowerRules.capacity_mwh(state)
	assert_bool(simulation.submit(DialCommand.create(address)).is_ok).is_true()
	for tick: int in state.balance.dial_duration_ticks + 2:
		simulation.advance_tick()
	assert_int(state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	_shell.frame.refresh()
	await _runner.simulate_frames(3)
	_gate().open_mission_sheet()
	await _runner.simulate_frames(2)
	var found: Array[String] = long_texts(_shell.frame)
	found.append_array(long_texts(_gate()))
	assert_array(found).is_empty()


func test_alien_panel() -> void:
	_gate().open_alien_panel()
	await _runner.simulate_frames(2)
	assert_array(long_texts(_gate().get_alien_panel())).is_empty()


func test_other_stations_show_short_frame_text() -> void:
	_shell.view_switcher.show_station(&"base")
	await _runner.simulate_frames(2)
	assert_array(long_texts(_shell.frame)).is_empty()
