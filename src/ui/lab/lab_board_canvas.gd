class_name LabBoardCanvas
extends Control
## What scrolls inside the Lab board's glass: the tiles and, under them, the 3 px edges from
## each project to what it opened (amber into a project running or queued, green out of a
## done one, else steel). Drawn by [LabBoard].
## Bible: docs/content/interface-reference.md section 9

## Edges as [from id, to id].
var edges: Array[Array] = []
## The board's tiles by project id.
var tiles: Dictionary[StringName, LabTile] = {}


func _init() -> void:
	name = "Canvas"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for edge: Array in edges:
		var from: LabTile = tiles.get(edge[0])
		var to: LabTile = tiles.get(edge[1])
		if from == null or to == null:
			continue
		var a: Vector2 = from.position + Vector2(from.size.x, from.size.y * 0.5)
		var b: Vector2 = to.position + Vector2(0.0, to.size.y * 0.5)
		var mid: float = a.x + (b.x - a.x) * 0.5
		var ink: Color = Color8(70, 74, 64)
		if from.get_status() == LabText.Status.DONE:
			ink = Color8(64, 110, 72)
		var points: PackedVector2Array = [a, Vector2(mid, a.y), Vector2(mid, b.y), b]
		draw_polyline(points, ink, LabBoard.EDGE_WIDTH)
