class_name LabBoard
extends Control
## The Lab's board (interface-reference.md section 9, lab_board): dark glass inside a steel
## plate with the projects of one discipline as [LabTile]s, placed by LabLayout.cells(), and
## 3 px edges from each project to what it opened. Only visible projects are drawn (ResearchRules
## never returns another); nothing locked appears. Scrolls when the projects overflow.
## Bible: docs/content/interface-reference.md section 9,
## docs/content/research-and-progression.md section 7

## A tile was clicked or took focus.
signal project_chosen(project_id: StringName)
## (A) or Enter on a tile.
signal project_activated(project_id: StringName)

const EDGE_WIDTH: float = 3.0

var _scroll: ScrollContainer = ScrollContainer.new()
var _canvas: LabBoardCanvas = LabBoardCanvas.new()
var _tiles: Dictionary[StringName, LabTile] = {}
var _discipline: StringName = &""
var _selected: StringName = &""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.name = "Scroll"
	_scroll.follow_focus = true
	_scroll.add_child(_canvas)
	add_child(_scroll)
	resized.connect(_layout)


## Shows the visible projects of [param discipline] in [param state]; rebuilds the tiles
## when the set of projects or the discipline changed, else only rereads them.
func show_discipline(state: GameState, discipline: StringName) -> void:
	var defs: Array[ResearchDef] = ResearchRules.visible_projects(state, discipline)
	var ids: Array[StringName] = []
	for def: ResearchDef in defs:
		ids.append(def.id)
	if discipline != _discipline or ids != Array(_tiles.keys(), TYPE_STRING_NAME, &"", null):
		_rebuild(defs)
	_discipline = discipline
	for def: ResearchDef in defs:
		_tiles[def.id].show_project(state, def)
	_canvas.queue_redraw()


## Marks [param project_id]'s tile selected (amber outline).
func select(project_id: StringName) -> void:
	_selected = project_id
	for id: StringName in _tiles:
		_tiles[id].selected = id == project_id


## The tiles in list order.
func tiles() -> Array[LabTile]:
	return _tiles.values()


## The tile of [param project_id], or null when it is not shown.
func tile_of(project_id: StringName) -> LabTile:
	return _tiles.get(project_id)


## The first tile, or null when the discipline shows none.
func first_tile() -> LabTile:
	return null if _tiles.is_empty() else _tiles.values()[0]


## The discipline shown.
func get_discipline() -> StringName:
	return _discipline


## The edges drawn, as [from id, to id].
func edges() -> Array[Array]:
	return _canvas.edges


func _rebuild(defs: Array[ResearchDef]) -> void:
	for tile: LabTile in _tiles.values():
		_canvas.remove_child(tile)
		tile.queue_free()
	_tiles.clear()
	var cells: Dictionary[StringName, Vector2i] = LabLayout.cells(defs)
	var extent: Vector2 = Vector2.ZERO
	var edges: Array[Array] = []
	for def: ResearchDef in defs:
		var tile: LabTile = LabTile.new()
		tile.position = LabLayout.cell_position(cells[def.id])
		tile.chosen.connect(project_chosen.emit)
		tile.activated.connect(project_activated.emit)
		_canvas.add_child(tile)
		_tiles[def.id] = tile
		extent = extent.max(tile.position + LabLayout.TILE + LabLayout.FIRST)
		for need: StringName in def.needs:
			if cells.has(need):
				edges.append([need, def.id])
	_canvas.custom_minimum_size = extent
	_canvas.edges = edges
	_canvas.tiles = _tiles
	select(_selected)


func _layout() -> void:
	var inset: float = LabLayout.GLASS_INSET
	_scroll.position = Vector2(inset, inset)
	_scroll.size = size - Vector2(inset, inset) * 2.0


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	var inset: float = LabLayout.GLASS_INSET
	var glass: Rect2 = Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	RefPaint.gradient(self, glass, 2.0, [Color8(22, 34, 30), Color8(12, 18, 16)])
	draw_rect(glass, RefPaint.EDGE, false, 2.0)
