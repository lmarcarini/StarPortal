class_name LabPanel
extends Control
## The Lab's right panel (interface-reference.md section 9, lab_panel): the selected
## project's icon and name, discipline and tier, a GIVES box with one line per effect, tiles
## for time, cost and staff (and pieces or specimens when it spends them), NEEDS as lit keys
## for its done prerequisites, then START (amber) and ADD TO QUEUE at the foot. While the
## project runs, START reads CANCEL. A refusal shows above the keys. Emits only; the view
## submits the commands.
## Bible: docs/content/interface-reference.md section 9

## START (or CANCEL while it runs) was pressed for [param project_id].
signal start_pressed(project_id: StringName)
## ADD TO QUEUE was pressed for [param project_id].
signal queue_pressed(project_id: StringName)

const GIVES_TOP: float = 92.0
const TILE_SIZE: Vector2 = Vector2(104, 68)
const BUTTON_SIZE: Vector2 = Vector2(330, 58)

var start_key: RefKey = RefKey.new()
var queue_key: RefKey = RefKey.new()

var _def: ResearchDef = null
var _gives: Array[String] = []
var _tiles: Array[Array] = []
var _needs: Array[String] = []
var _notice: String = ""


func _init() -> void:
	name = &"LabPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	start_key.name = "Start"
	start_key.label_size = 26
	start_key.style = RefPaint.KeyStyle.AMBER
	queue_key.name = "Queue"
	queue_key.label = "LAB_ADD_TO_QUEUE"
	queue_key.label_size = 20
	for key: RefKey in [start_key, queue_key]:
		key.size = BUTTON_SIZE
		add_child(key)
	start_key.pressed.connect(func() -> void: start_pressed.emit(get_project()))
	queue_key.pressed.connect(func() -> void: queue_pressed.emit(get_project()))
	resized.connect(_layout)


## Shows [param def] as it stands in [param state] (null: nothing selected).
func show_project(state: GameState, def: ResearchDef) -> void:
	if def != _def:
		_notice = ""
	_def = def
	_gives.clear()
	_tiles.clear()
	if def != null:
		_gives = LabText.gives(def)
		_tiles = LabText.needs_tiles(def)
	_needs.clear()
	if def != null:
		for need: StringName in def.needs:
			_needs.append(ResearchText.name_of(state, need).to_upper())
	_show_keys(state)
	queue_redraw()


## Shows [param text] above the keys ("" clears it).
func show_notice(text: String) -> void:
	_notice = text
	queue_redraw()


## The project shown, or &"".
func get_project() -> StringName:
	return &"" if _def == null else _def.id


## The GIVES lines, for tests.
func gives_lines() -> Array[String]:
	return _gives


## The notice shown, for tests.
func get_notice() -> String:
	return _notice


func _show_keys(state: GameState) -> void:
	start_key.visible = _def != null
	queue_key.visible = _def != null
	if _def == null:
		return
	var running: bool = not state.research.room_running(_def.id).is_empty()
	var done: bool = state.research.is_done(_def.id)
	start_key.label = "LAB_CANCEL" if running else "LAB_START"
	start_key.style = RefPaint.KeyStyle.STEEL if running else RefPaint.KeyStyle.AMBER
	start_key.disabled = done
	queue_key.disabled = (done or running or not state.research.room_queuing(_def.id).is_empty())


func _layout() -> void:
	var x: float = (size.x - BUTTON_SIZE.x) * 0.5
	queue_key.position = Vector2(x, size.y - BUTTON_SIZE.y - 18)
	start_key.position = Vector2(x, queue_key.position.y - BUTTON_SIZE.y - 10)


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	if _def == null:
		return
	RefIcons.draw(self, LabText.icon_of(_def.discipline), Rect2(18, 18, 26, 26), RefPaint.AMBER)
	var title: RefText = RefText.make(RefText.LABEL, 24, RefPaint.TEXT, 2.5)
	title.draw(self, Vector2(52, 31), tr(_def.name_key).to_upper(), "lm")
	var dim: RefText = RefText.make(RefText.LABEL_MEDIUM, 15, RefPaint.DIM, 2.5)
	dim.draw(self, Vector2(18, 70), LabText.discipline_line(_def), "lm")
	var bottom: float = _draw_gives()
	bottom = _draw_tiles(bottom + 22.0)
	_draw_needs(bottom + 26.0, dim)
	if not _notice.is_empty():
		RefText.make(RefText.LABEL_MEDIUM, 16, RefPaint.RED, 1.0).draw(
			self, Vector2(size.x * 0.5, start_key.position.y - 20), _notice, "mm"
		)


func _draw_gives() -> float:
	var text: RefText = RefText.make(RefText.LABEL_MEDIUM, 18, RefPaint.TEXT, 1.0)
	var rows: Array[String] = []
	for line: String in _gives:
		rows.append_array(LabPanel.wrap(text, line, size.x - 28 - 64))
	var height: float = 56 + 30 * maxi(1, rows.size()) + 14 * maxi(0, _gives.size() - 1)
	var box: Rect2 = Rect2(14, GIVES_TOP, size.x - 28, height)
	RefPaint.recess(self, box)
	RefText.make(RefText.LABEL_MEDIUM, 14, RefPaint.DIM, 2.5).draw(
		self, box.position + Vector2(14, 22), tr(&"LAB_GIVES"), "lm"
	)
	var y: float = box.position.y + 60
	var icon: StringName = LabText.icon_of(_def.discipline)
	for line: String in _gives:
		RefIcons.draw(self, icon, Rect2(30, y - 11, 22, 22), RefPaint.AMBER)
		for row: String in LabPanel.wrap(text, line, size.x - 28 - 64):
			text.draw(self, Vector2(64, y), row, "lm")
			y += 30
		y += 14
	return box.end.y


## [param line] broken at spaces into rows no wider than [param width] in [param style].
static func wrap(style: RefText, line: String, width: float) -> Array[String]:
	var rows: Array[String] = []
	var row: String = ""
	for word: String in line.split(" ", false):
		var next: String = word if row.is_empty() else row + " " + word
		if style.width(next) > width and not row.is_empty():
			rows.append(row)
			next = word
		row = next
	if not row.is_empty():
		rows.append(row)
	return rows


func _draw_tiles(top: float) -> float:
	var per_row: int = 3
	var gap: float = (size.x - 28 - per_row * TILE_SIZE.x) / (per_row - 1)
	var ink: RefText = RefText.make(RefText.MONO_BOLD, 15, RefPaint.TEXT, 1.0)
	for index: int in _tiles.size():
		var at: Vector2 = Vector2(
			14 + (index % per_row) * (TILE_SIZE.x + gap),
			top + (index / per_row) * (TILE_SIZE.y + 8)
		)
		var rect: Rect2 = Rect2(at, TILE_SIZE)
		RefPaint.recess(self, rect)
		var icon: StringName = _tiles[index][0]
		RefIcons.draw(
			self, icon, Rect2(rect.get_center() + Vector2(-11, -26), Vector2(22, 22)), RefPaint.TEXT
		)
		ink.draw(self, rect.get_center() + Vector2(0, 18), str(_tiles[index][1]), "mm")
	var rows: int = ceili(_tiles.size() / float(per_row))
	return top + rows * (TILE_SIZE.y + 8)


func _draw_needs(top: float, dim: RefText) -> void:
	if _needs.is_empty():
		return
	dim.draw(self, Vector2(18, top), tr(&"LAB_NEEDS"), "lm")
	var key: RefText = RefText.make(RefText.LABEL, 15, RefPaint.AMBER, 2.5)
	var x: float = 18.0
	var y: float = top + 20.0
	for need: String in _needs:
		var width: float = key.width(need) + 40.0
		if x + width > size.x - 14 and x > 18.0:
			x = 18.0
			y += 48.0
		var rect: Rect2 = Rect2(x, y, width, 38)
		RefPaint.key(self, rect, RefPaint.KeyStyle.LIT)
		key.draw(self, rect.get_center() + Vector2(0, 1), need, "mm")
		x += width + 10.0
