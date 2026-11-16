class_name ChargeGauge
extends VBoxContainer
## The console's charge: an [AnalogGauge] of stored MWh against the bank's capacity, the
## open wormhole's drain in its readout, and a need mark only when the lock estimator is
## researched. With no capacitor bank the gauge gives way to a BUILD BANK key.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Console: Power)

## The BUILD BANK key was pressed: open the Base.
signal build_bank_requested

## Research that shows the need mark. None exists yet, so the mark stays hidden.
const ESTIMATOR_RESEARCH: StringName = &"research_lock_estimator"

var _gauge: AnalogGauge = AnalogGauge.new()
var _build: BigKey = BigKey.new()


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	_gauge.name = "Gauge"
	_gauge.custom_minimum_size = Vector2(110, 124) * HwMetrics.scale_of(self)
	HoverCard.attach(_gauge, "STATION_HELP_CHARGE")
	add_child(_gauge)
	_build.name = "BuildBank"
	_build.text = "STATION_BUILD_BANK"
	_build.custom_minimum_size = HwMetrics.target(self, Vector2(130, 60))
	_build.activated.connect(build_bank_requested.emit)
	add_child(_build)


## Shows [param state]'s charge and, while a wormhole is open, its drain.
func show_state(state: GameState, need_mwh: float) -> void:
	var capacity: float = PowerRules.capacity_mwh(state)
	_build.visible = capacity <= 0.0
	_gauge.visible = capacity > 0.0
	_gauge.max_value = maxf(capacity, 1.0)
	_gauge.red_from = _gauge.max_value * 0.9
	var estimator: bool = state.research.is_done(ESTIMATOR_RESEARCH)
	_gauge.need_mark = need_mwh if estimator and need_mwh > 0.0 else -1.0e9
	var readout: String = "%.1f" % state.power.stored_mwh
	if state.gate.mode == GateState.RingMode.LOCKED and not state.gate.is_incoming_lock():
		readout += "  -%d" % roundi(PowerRules.drain_mw(state))
	_gauge.set_value(state.power.stored_mwh, readout)


## The gauge (null-safe for tests).
func get_gauge() -> AnalogGauge:
	return _gauge


## The BUILD BANK key.
func get_build_key() -> BigKey:
	return _build
