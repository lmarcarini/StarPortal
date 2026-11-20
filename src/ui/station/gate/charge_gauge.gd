class_name ChargeGauge
extends Control
## The charge gauge (interface-reference.md section 5, charge_gauge): a steel plate with a
## cream analogue dial of stored MWh against the bank's capacity (red zone at the low end,
## the needle, MWh), the value below in mono 20 and, while a wormhole is open, its drain in
## red. With Gate calibration (S01) an amber mark shows what the selected dial needs. With
## no capacitor bank the dial gives way to a BUILD BANK key.
## Bible: docs/content/interface-reference.md section 5

## The BUILD BANK key was pressed: open the Base.
signal build_bank_requested

## Dial sweep: from 200 degrees, 140 degrees wide (PIL angles, clockwise from 3 o'clock).
const SWEEP_FROM: float = 200.0
const SWEEP: float = 140.0

var _build: BigKey = BigKey.new()
var _share: float = 0.0
var _value: String = ""
var _drain: String = ""
var _has_bank: bool = true
var _need_share: float = -1.0


func _ready() -> void:
	_build.name = "BuildBank"
	_build.text = "STATION_BUILD_BANK"
	_build.label_size = 24
	_build.activated.connect(build_bank_requested.emit)
	add_child(_build)
	HoverCard.attach(self, "STATION_HELP_CHARGE")
	resized.connect(func() -> void: _build.position = Vector2(14, 12))
	_build.size = Vector2(212, 106)
	_build.position = Vector2(14, 12)


## Shows [param state]'s charge and, while a wormhole is open, its drain.
func show_state(state: GameState, need_mwh: float) -> void:
	var capacity: float = PowerRules.capacity_mwh(state)
	_has_bank = capacity > 0.0
	_need_share = -1.0
	if need_mwh > 0.0 and ResearchPerks.has(state, ResearchPerks.GATE_CALIBRATION):
		_need_share = clampf(need_mwh / maxf(capacity, 1.0), 0.0, 1.0)
	_build.visible = not _has_bank
	_share = clampf(state.power.stored_mwh / maxf(capacity, 1.0), 0.0, 1.0)
	_value = str(floori(state.power.stored_mwh))
	_drain = ""
	if state.gate.mode == GateState.RingMode.LOCKED and not state.gate.is_incoming_lock():
		_drain = "−%d/H" % roundi(PowerRules.drain_mw(state))
	queue_redraw()


## The BUILD BANK key.
func get_build_key() -> BigKey:
	return _build


## The needle's share of the dial, 0 to 1.
func get_share() -> float:
	return _share


## The share of the dial the selected dial needs (Gate calibration, S01), or -1 when no mark.
func get_need_share() -> float:
	return _need_share


func _draw() -> void:
	RefPaint.steel_plate(self, Rect2(Vector2.ZERO, size), false, true)
	RefText.make(RefText.MONO_BOLD, 20, RefPaint.TEXT).draw(
		self, Vector2(18, size.y - 20), _value, "lm"
	)
	var drain: RefText = RefText.make(RefText.LABEL_MEDIUM, 18, RefPaint.RED, 1.0)
	drain.draw(self, Vector2(size.x - 18, size.y - 20), _drain, "rm")
	if _has_bank:
		_draw_dial(Rect2(14, 12, size.x - 28, size.y - 50))


func _draw_dial(face: Rect2) -> void:
	RefPaint.gradient(self, face, 8.0, [Color8(236, 230, 208), Color8(206, 198, 172)])
	RefPaint.outline(self, face, RefPaint.EDGE, 3.0)
	var c: Vector2 = Vector2(face.get_center().x, face.end.y - 14.0)
	var r: float = face.size.y - 30.0
	for k: int in 11:
		var a: float = deg_to_rad(SWEEP_FROM + k * 14.0)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		draw_line(c + dir * (r - 10.0), c + dir * r, RefPaint.INK, 2.0, true)
	draw_arc(
		c,
		r - 4.0,
		deg_to_rad(SWEEP_FROM),
		deg_to_rad(SWEEP_FROM + 28.0),
		12,
		RefPaint.RED,
		8.0,
		true
	)
	if _need_share >= 0.0:
		var mark: Vector2 = Vector2.from_angle(deg_to_rad(SWEEP_FROM + _need_share * SWEEP))
		draw_line(c + mark * (r - 18.0), c + mark * (r + 2.0), RefPaint.AMBER, 5.0, true)
	var needle: float = deg_to_rad(SWEEP_FROM + _share * SWEEP)
	draw_line(c, c + Vector2(cos(needle), sin(needle)) * (r - 6.0), RefPaint.INK, 4.0, true)
	draw_circle(c, 6.0, RefPaint.INK)
	RefText.make(RefText.LABEL, 20, RefPaint.INK, 2.0).draw(self, c - Vector2(0, 34), "MWh", "mm")
