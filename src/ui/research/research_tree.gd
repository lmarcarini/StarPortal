class_name ResearchTree
extends Control
## The tree of one Research sub-tab (docs/content/m25-lean-start.md section 3): a
## [ResearchNode] per project or locked slot at its [ResearchTreeLayout] cell, a line from
## each need to the project that needs it, and a short labelled stub for a need in another
## category. An empty category shows "Nothing to research yet". The D-pad moves left and
## right by column (to the nearest row) and up and down within a column.
## Bible: docs/content/m25-lean-start.md section 3

## Emitted when a node takes focus.
signal project_chosen(project_id: StringName)
## Emitted on (A) or Enter on a node.
signal project_activated(project_id: StringName)
## Emitted when a stub (a need in another branch) is pressed, with that need's id.
signal stub_pressed(project_id: StringName)

## What filter() keeps bright: every node, those that can start, done ones or locked ones.
enum Filter { ALL, AVAILABLE, DONE, LOCKED }

## Room left of the first column for stubs, in pixels.
const PAD: Vector2 = Vector2(40, 20)
## Distance between columns and between rows, in pixels.
const STEP: Vector2 = Vector2(ResearchNode.SIZE.x + 48, ResearchNode.SIZE.y + 16)

var _category: StringName = &""
var _cells: Dictionary[StringName, Vector2i] = {}
var _edges: Array[Array] = []
var _nodes: Dictionary[StringName, ResearchNode] = {}
var _stubs: Array[Button] = []
var _empty: Label = Label.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_empty.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_empty.position = PAD
	add_child(_empty)


## Shows [param category]'s part of [param state]'s research; rebuilds the nodes when the
## category changes.
func show_category(state: GameState, category: StringName) -> void:
	var defs: Array[ResearchDef] = ResearchRules.visible_projects(state)
	if category != _category or _cells.size() != ResearchTreeLayout.cells(defs, category).size():
		_rebuild(state, defs, category)
	for id: StringName in _nodes:
		_nodes[id].show_project(state, state.research_defs[id])
	_empty.text = tr(&"RESEARCH_EMPTY")
	_empty.visible = _nodes.is_empty()
	queue_redraw()


## Returns the nodes in layout order: by column, then row.
func nodes() -> Array[ResearchNode]:
	var ids: Array[StringName] = _cells.keys()
	ids.sort_custom(
		func(a: StringName, b: StringName) -> bool:
			var x: Vector2i = _cells[a]
			var y: Vector2i = _cells[b]
			return x.x < y.x or (x.x == y.x and x.y < y.y)
	)
	var found: Array[ResearchNode] = []
	for id: StringName in ids:
		found.append(_nodes[id])
	return found


## Returns the node of [param project_id], or null when it is not in this sub-tab.
func node_of(project_id: StringName) -> ResearchNode:
	return _nodes.get(project_id)


## Returns the stub labels, e.g. "from Second plant".
func stub_texts() -> Array[String]:
	var found: Array[String] = []
	for stub: Button in _stubs:
		found.append(stub.text)
	return found


## Returns "Nothing to research yet" while the sub-tab is empty, else "".
func empty_text() -> String:
	return _empty.text if _empty.visible else ""


func _rebuild(state: GameState, defs: Array[ResearchDef], category: StringName) -> void:
	_category = category
	_cells = ResearchTreeLayout.cells(defs, category)
	_edges = ResearchTreeLayout.edges(defs, category)
	for old: Node in _nodes.values() + _stubs:
		remove_child(old)
		old.queue_free()
	_nodes.clear()
	_stubs.clear()
	var extent: Vector2 = Vector2.ZERO
	for id: StringName in _cells:
		var node := ResearchNode.new()
		node.position = cell_position(_cells[id])
		node.chosen.connect(project_chosen.emit)
		node.activated.connect(project_activated.emit)
		add_child(node)
		_nodes[id] = node
		extent = extent.max(node.position + ResearchNode.SIZE)
		for need: StringName in ResearchTreeLayout.stubs_in(_cells, state.research_defs[id]):
			_add_stub(node, need, ResearchText.name_of(state, need))
	custom_minimum_size = extent + Vector2(8, 8)
	_link_focus()


## Dims every node [param filter] leaves out and tints those whose name contains
## [param search] (case-insensitive; empty matches none). Returns the matching ids in list order.
func apply_view(state: GameState, filter: Filter, search: String) -> Array[StringName]:
	var matches: Array[StringName] = []
	var needle: String = search.strip_edges().to_lower()
	for id: StringName in _nodes:
		var node: ResearchNode = _nodes[id]
		var def: ResearchDef = state.research_defs[id]
		node.show_project(state, def)
		if not keeps(state, def, filter):
			node.modulate = Color(1, 1, 1, 0.25)
		if not needle.is_empty() and tr(def.name_key).to_lower().contains(needle):
			node.modulate = Color(1.0, 0.9, 0.4)
			matches.append(id)
	return matches


## True when [param filter] keeps [param def] bright.
static func keeps(state: GameState, def: ResearchDef, filter: Filter) -> bool:
	var kind: ResearchText.Kind = ResearchText.kind(state, def)
	match filter:
		Filter.AVAILABLE:
			return kind == ResearchText.Kind.START
		Filter.DONE:
			return kind == ResearchText.Kind.DONE
		Filter.LOCKED:
			return kind == ResearchText.Kind.LOCKED or kind == ResearchText.Kind.NEEDS
	return true


## Returns the stub buttons.
func get_stubs() -> Array[Button]:
	return _stubs.duplicate()


## Top-left corner of [param cell] (column, row), in pixels.
static func cell_position(cell: Vector2i) -> Vector2:
	return PAD + Vector2(cell.x * STEP.x, cell.y * STEP.y)


func _add_stub(node: ResearchNode, need: StringName, need_name: String) -> void:
	var stub := Button.new()
	stub.flat = true
	stub.focus_mode = FOCUS_NONE
	stub.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	stub.add_theme_font_size_override(&"font_size", 11)
	stub.text = tr(&"RESEARCH_STUB").format({"name": need_name})
	var earlier: int = 0
	for other: Button in _stubs:
		earlier += 1 if other.position.x == node.position.x + 8 else 0
	stub.position = node.position + Vector2(8, -20 - 14 * earlier)
	stub.pressed.connect(stub_pressed.emit.bind(need))
	add_child(stub)
	_stubs.append(stub)


func _link_focus() -> void:
	var at: Dictionary[Vector2i, ResearchNode] = {}
	for id: StringName in _cells:
		at[_cells[id]] = _nodes[id]
	for cell: Vector2i in at:
		var node: ResearchNode = at[cell]
		var above: ResearchNode = at.get(cell + Vector2i.UP)
		node.focus_neighbor_top = node.get_path_to(above) if above != null else NodePath()
		var below: ResearchNode = at.get(cell + Vector2i.DOWN)
		node.focus_neighbor_bottom = _path(node, below)
		node.focus_neighbor_left = _path(node, _nearest(at, cell.x - 1, cell.y))
		node.focus_neighbor_right = _path(node, _nearest(at, cell.x + 1, cell.y))


## The node in [param column] whose row is closest to [param row], or null.
static func _nearest(at: Dictionary[Vector2i, ResearchNode], column: int, row: int) -> ResearchNode:
	for offset: int in range(0, at.size() + 1):
		for candidate: int in [row - offset, row + offset]:
			if at.has(Vector2i(column, candidate)):
				return at[Vector2i(column, candidate)]
	return null


## A path from [param node] to [param other], or to itself when there is none, so the D-pad
## stays in the tree (up from the top row may leave it, for the sub-tabs).
static func _path(node: ResearchNode, other: ResearchNode) -> NodePath:
	return node.get_path_to(other if other != null else node)


func _draw() -> void:
	var colour := Color(1, 1, 1, 0.45)
	for edge: Array in _edges:
		var from: Vector2 = cell_position(_cells[edge[0]])
		var to: Vector2 = cell_position(_cells[edge[1]])
		var half: float = ResearchNode.SIZE.y / 2.0
		var start := Vector2(from.x + ResearchNode.SIZE.x, from.y + half)
		var end := Vector2(to.x, to.y + half)
		var bend: float = end.x - (STEP.x - ResearchNode.SIZE.x) / 2.0
		draw_polyline(
			PackedVector2Array([start, Vector2(bend, start.y), Vector2(bend, end.y), end]),
			colour,
			2.0
		)
	for stub: Button in _stubs:
		var y: float = stub.position.y + 12
		draw_line(Vector2(stub.position.x - 32, y), Vector2(stub.position.x - 4, y), colour, 2.0)
