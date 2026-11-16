extends RefCounted
## Test fixture for the Gate station tests: a paused simulation over the dialing fixture galaxy
## (every world has a designation, so a test can check where a designation appears), the
## address that gives each outcome, and a few tree-walking helpers.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const VIEW_SCENE: String = "res://src/ui/station/gate/gate_station_view.tscn"
const DESIGNATIONS: Dictionary[StringName, String] = {
	DialFixture.OPEN_ID: "P3X-111",
	DialFixture.BURIED_ID: "P3X-222",
	DialFixture.SHIELDED_ID: "P3X-333",
	DialFixture.GUARDED_ID: "P3X-444",
}
## Size of the area the shell gives a view at the minimum window size.
const VIEW_SIZE: Vector2 = Vector2(1280, 600)


## Returns a paused simulation over the fixture galaxy with a full bank.
static func simulation() -> Simulation:
	var state: GameState = DialFixture.state(null, true)
	for id: StringName in DESIGNATIONS:
		state.galaxy.get_world(id).designation = DESIGNATIONS[id]
	return DialFixture.simulation(state)


## Returns the fixture address that gives [param outcome] when dialed.
static func address_for(state: GameState, outcome: int) -> GateAddress:
	match outcome:
		DialOutcome.Kind.NO_GATE:
			return state.galaxy.address_of(state.galaxy.home().id, state.galaxy.home().origin_glyph)
		DialOutcome.Kind.BLOCKED:
			return DialFixture.address_of(state.galaxy, DialFixture.BURIED_ID)
		DialOutcome.Kind.ORIGIN_REJECTED:
			var right: GateAddress = DialFixture.address_of(state.galaxy, DialFixture.OPEN_ID)
			for glyph: int in GateAddress.GLYPH_COUNT:
				if not right.seals().has(glyph):
					return GateAddress.create(right.coordinates, glyph)
		DialOutcome.Kind.HOSTILE_LOCK:
			return DialFixture.address_of(state.galaxy, DialFixture.GUARDED_ID)
	return DialFixture.address_of(state.galaxy, DialFixture.OPEN_ID)


## Returns a Control of [constant VIEW_SIZE] that holds a new Gate station view, as the shell's
## view area does. The caller adds the holder to the tree and frees it.
static func mount_view() -> Control:
	var holder := Control.new()
	holder.size = VIEW_SIZE
	holder.add_child((load(VIEW_SCENE) as PackedScene).instantiate())
	return holder


## Returns the Gate station view inside [param holder] from [method mount_view].
static func view_of(holder: Control) -> GateStationView:
	return holder.get_child(0) as GateStationView


## Returns every visible text the player can read under [param root], translated as the
## engine does when it draws: labels, button and drop-down texts and tooltips.
static func visible_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	_collect(root, texts)
	return texts


static func _collect(node: Node, texts: Array[String]) -> void:
	if node is Control and (node as Control).is_visible_in_tree():
		var control: Control = node as Control
		if not control.tooltip_text.is_empty():
			texts.append(control.tooltip_text)
		if control is Label:
			texts.append(control.tr((control as Label).text))
		elif control is Button:
			texts.append(control.tr((control as Button).text))
	for child: Node in node.get_children():
		_collect(child, texts)


## Returns every visible control under [param root] that takes focus, in tree order.
static func focusable(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	_collect_focusable(root, found)
	return found


static func _collect_focusable(node: Node, found: Array[Control]) -> void:
	if node is Control:
		var control: Control = node as Control
		if control.is_visible_in_tree() and control.focus_mode == Control.FOCUS_ALL:
			found.append(control)
	for child: Node in node.get_children():
		_collect_focusable(child, found)
