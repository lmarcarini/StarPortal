class_name StationScene
extends Control
## A station on screen: its plate covering the rect, or (M5-01) its 3D scene full bleed from a
## fixed camera, live layers drawn over it, and anchors from its [StationSceneDef] mapped to
## screen pixels (local to this control) and kept up to date on resize. In 3D the anchors are
## the scene's projected Marker3D and Path3D nodes; any the scene lacks fall back to the
## plate's. Reads nothing from the simulation; layers do their own work.
## Bible: docs/content/interface-rethink.md section 7 (plate plus live layers)

## Emitted after a resize moved the anchors; layers re-read them.
signal anchors_changed
## The view switched between the plate and the 3D scene (display/stations_3d changed).
signal mode_changed

var _def: StationSceneDef = null
var _overlay: AnchorOverlay = null
var _depths: Dictionary[Node, int] = {}
var _view_3d: Station3D = null

@onready var _plate: TextureRect = %Plate
@onready var _placeholder: PlaceholderPlate = %Placeholder
@onready var _layers: Control = %Layers


## Shows [param def]: its plate, or the placeholder when it has none. A null def (content
## without stations, in a test) shows an empty placeholder.
func setup(def: StationSceneDef) -> void:
	if def == null:
		def = StationSceneDef.new()
	_def = def
	_plate.texture = def.plate
	_set_3d(def)
	_plate.visible = def.plate != null and _view_3d == null
	_placeholder.visible = def.plate == null and _view_3d == null
	_placeholder.setup(def)
	if _overlay != null:
		_overlay.setup(def)
	anchors_changed.emit()


func _enter_tree() -> void:
	Settings.setting_changed.connect(_on_setting_changed)


func _exit_tree() -> void:
	Settings.setting_changed.disconnect(_on_setting_changed)


func _on_setting_changed(section: StringName, key: StringName, _value: Variant) -> void:
	if section != &"display" or key != &"stations_3d" or _def == null or _def.scene == null:
		return
	_set_3d(_def)
	_plate.visible = _def.plate != null and _view_3d == null
	_placeholder.visible = _def.plate == null and _view_3d == null
	anchors_changed.emit()
	mode_changed.emit()


## The 3D view, or null while the plate shows.
func get_3d() -> Station3D:
	return _view_3d


func _set_3d(def: StationSceneDef) -> void:
	var wanted: bool = def.scene != null and Station3D.is_enabled()
	if not wanted:
		if _view_3d != null:
			_view_3d.free()
			_view_3d = null
		return
	if _view_3d == null:
		_view_3d = Station3D.new()
		add_child(_view_3d)
		move_child(_view_3d, 0)
	_view_3d.setup(def)


## The def shown, or null.
func get_def() -> StationSceneDef:
	return _def


## Adds a live layer [param node] at depth [param z] (higher draws later), full rect.
func add_layer(node: Control, z: int) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_depths[node] = z
	_layers.add_child(node)
	var index: int = 0
	for child: Node in _layers.get_children():
		if child != node and _depths.get(child, 0) <= z:
			index = child.get_index() + 1
	_layers.move_child(node, mini(index, _layers.get_child_count() - 1))


## Screen position (local) of point or circle centre [param anchor_name]; ZERO when absent.
func anchor(anchor_name: StringName) -> Vector2:
	if _def == null:
		return Vector2.ZERO
	var node: Node3D = _marker(anchor_name)
	if node != null:
		return _view_3d.project(node.global_position)
	if _def.points.has(anchor_name):
		return PlateSpace.to_screen(_def, _rect(), _def.points[anchor_name])
	if _def.circles.has(anchor_name):
		var c: Vector3 = _def.circles[anchor_name]
		return PlateSpace.to_screen(_def, _rect(), Vector2(c.x, c.y))
	if _def.rects.has(anchor_name):
		return PlateSpace.to_screen(_def, _rect(), _def.rects[anchor_name].get_center())
	return Vector2.ZERO


## Screen radius of circle [param anchor_name]; 0 when absent.
func radius(anchor_name: StringName) -> float:
	var node: Node3D = _marker(anchor_name)
	if node != null and node.has_meta(&"radius"):
		return _view_3d.project_radius(node)
	if _def == null or not _def.circles.has(anchor_name):
		return 0.0
	return PlateSpace.to_screen_length(_def, _rect(), _def.circles[anchor_name].z)


## Screen points of path or polygon [param anchor_name]; empty when absent.
func shape(anchor_name: StringName) -> PackedVector2Array:
	if _def == null:
		return PackedVector2Array()
	var path: Path3D = _marker(anchor_name) as Path3D
	if path != null:
		return _view_3d.project_path(path)
	if _def.paths.has(anchor_name):
		return PlateSpace.to_screen_all(_def, _rect(), _def.paths[anchor_name])
	if _def.polygons.has(anchor_name):
		return PlateSpace.to_screen_all(_def, _rect(), _def.polygons[anchor_name])
	return PackedVector2Array()


## Screen rect of rect anchor [param anchor_name]; empty when absent.
func rect_of(anchor_name: StringName) -> Rect2:
	if _def == null or not _def.rects.has(anchor_name):
		return Rect2()
	var r: Rect2 = _def.rects[anchor_name]
	var a: Vector2 = PlateSpace.to_screen(_def, _rect(), r.position)
	return Rect2(a, PlateSpace.to_screen(_def, _rect(), r.end) - a)


## Screen scale of a figure at fraction [param t] along path [param path_name].
func depth_at(path_name: StringName, t: float) -> float:
	var base: float = PlateSpace.cover_scale(Vector2(_def.plate_size), _rect()) if _def else 1.0
	if _def == null or not _def.depth_scale.has(path_name):
		return base
	var d: Vector2 = _def.depth_scale[path_name]
	return base * lerpf(d.x, d.y, clampf(t, 0.0, 1.0))


## Shows or hides the debug anchor overlay.
func set_anchors_visible(on: bool) -> void:
	if on and _overlay == null:
		_overlay = AnchorOverlay.new()
		_overlay.name = "AnchorOverlay"
		add_layer(_overlay, 1000)
		if _def != null:
			_overlay.setup(_def)
	if _overlay != null:
		_overlay.visible = on


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _def != null:
		anchors_changed.emit()


func _marker(anchor_name: StringName) -> Node3D:
	return null if _view_3d == null else _view_3d.marker(anchor_name)


func _rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)
