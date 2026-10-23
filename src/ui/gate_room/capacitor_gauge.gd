class_name CapacitorGauge
extends VBoxContainer
## The capacitor bank: a bar of the stored energy against the capacity, and the two numbers.
## It never shows the charge an address needs: the player judges that from the outcome.
## Bible: gate-and-address-spec.md#the-dial-console,
## gate-and-address-spec.md#dialing-outcomes-and-energy, game-design.md#core-loop

var _simulation: Simulation = null

@onready var _bar: ProgressBar = %Bar
@onready var _values: Label = %Values


func _ready() -> void:
	_refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.dial_resolved.connect(_on_dial_resolved)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Connects the gauge to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	if is_node_ready():
		_refresh()


## Returns the bar's current value in MWh.
func get_bar_value() -> float:
	return _bar.value


## Returns the "stored of capacity" text.
func get_values_text() -> String:
	return _values.text


func _refresh() -> void:
	if _simulation == null:
		_bar.value = 0.0
		_values.text = ""
		return
	var power: PowerState = _simulation.state.power
	_bar.max_value = maxf(power.capacity_mwh, 1.0)
	_bar.value = power.stored_mwh
	_values.text = (
		tr("GATE_GAUGE_VALUES")
		. format(
			{
				"stored": GateRoomFormat.energy(power.stored_mwh),
				"capacity": GateRoomFormat.energy(power.capacity_mwh),
			}
		)
	)


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_refresh()
