class_name GateMonitor
extends Button
## The gate monitor, bottom right on every station but the Gate (interface-reference.md
## section 4, gate_monitor): a steel plate with a CRT showing GATE, the gate's state (OPEN ·
## the world, in Ring blue, while a wormhole is open), the time left, and the Ring drawn at
## the right, its horizon lit blue while open. Redraws only while shown. A click goes to the
## Gate.
## Bible: docs/content/interface-reference.md section 4

## True on every station but the Gate (the shell sets it).
var wanted: bool = true:
	set(value):
		wanted = value
		_update()

var _simulation: Simulation = null
var _active: bool = false
var _text: String = ""


func _init() -> void:
	name = &"GateMonitor"
	focus_mode = Control.FOCUS_ALL
	for box: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(box, StyleBoxEmpty.new())


func _ready() -> void:
	HoverCard.attach(self, "FRAME_MONITOR_HINT")


## Watches [param simulation]'s Gate (after a start or a load).
func bind(simulation: Simulation) -> void:
	_simulation = simulation
	_update()


## True while the monitor shows a live gate (dialling, open, incoming, an incursion).
func is_live() -> bool:
	return visible and _active


## The look shown now (for tests).
func current_look() -> RingLook:
	if _simulation == null:
		return RingLook.new()
	var state: GameState = _simulation.state
	return RingLook.of(state.gate, state.clock.tick, state.balance.dial_duration_ticks)


func _process(_delta: float) -> void:
	_update()


func _update() -> void:
	visible = wanted
	_active = _simulation != null and is_active(_simulation.state)
	var text: String = "" if _simulation == null else GateMonitorText.line(_simulation.state)
	if visible and text != _text:
		_text = text
		queue_redraw()


## True when the Ring of [param state] is doing something worth showing: dialling, open,
## an incoming wormhole waiting, or an incursion.
static func is_active(state: GameState) -> bool:
	var gate: GateState = state.gate
	if gate.mode != GateState.RingMode.IDLE or gate.has_incoming():
		return true
	return state.incursion.is_active()


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	var screen: Rect2 = Rect2(Vector2(12, 12), size - Vector2(24, 24))
	draw_rect(screen, Color8(6, 10, 14))
	if _simulation != null:
		GateMonitorText.draw_screen(self, screen, _simulation.state)
	for y: int in range(int(screen.position.y), int(screen.end.y), 3):
		draw_line(
			Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(0, 0, 0, 0.45), 1.0
		)
	var bezel: StyleBoxFlat = StyleBoxFlat.new()
	bezel.draw_center = false
	bezel.border_color = RefPaint.EDGE
	bezel.set_border_width_all(4)
	bezel.set_corner_radius_all(10)
	draw_style_box(bezel, screen)
	if has_focus():
		RefPaint.outline(self, Rect2(Vector2.ZERO, size).grow(2.0), RefPaint.AMBER_HI, 2.0)
