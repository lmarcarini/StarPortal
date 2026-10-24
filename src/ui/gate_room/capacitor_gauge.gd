class_name CapacitorGauge
extends VBoxContainer
## The capacitors, in one of three states. With none installed: "No capacitors installed" and
## the hold-to-confirm "Install capacitor bank (6 h)" button, which posts an
## InstallCapacitorsCommand. While a bank is being installed: the time left and a bar of the
## install's progress. Then: a bar of the stored energy against the capacity, and the two
## numbers. It never shows the charge an address needs: the player judges that from the
## outcome.
## Bible: gate-and-address-spec.md#the-dial-console,
## gate-and-address-spec.md#dialing-outcomes-and-energy, game-design.md#core-loop

## Posted after the install button's hold started an install (the button then hides).
signal install_started

## What the gauge shows.
enum Mode { EMPTY, INSTALLING, CHARGE }

const _MINUTES_PER_HOUR: int = 60

var _simulation: Simulation = null

@onready var _bar_area: Control = %BarArea
@onready var _bar: ProgressBar = %Bar
@onready var _values: Label = %Values
@onready var _install_button: HoldButton = %InstallButton


func _ready() -> void:
	_install_button.confirmed.connect(_on_install_confirmed)
	_refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.dial_resolved.connect(_on_dial_resolved)
	EventBus.capacitors_installed.connect(_on_capacitors_installed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)
	EventBus.capacitors_installed.disconnect(_on_capacitors_installed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Connects the gauge to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	if is_node_ready():
		_refresh()


## Returns what the gauge shows for [param power]: EMPTY with no capacity and no install
## running, INSTALLING while one runs, CHARGE otherwise.
static func mode_of(power: PowerState) -> Mode:
	if power.install_ticks_left > 0:
		return Mode.INSTALLING
	if power.capacity_mwh <= 0.0:
		return Mode.EMPTY
	return Mode.CHARGE


## Returns what the gauge shows now; EMPTY before setup().
func get_mode() -> Mode:
	if _simulation == null:
		return Mode.EMPTY
	return mode_of(_simulation.state.power)


## Returns the bar's current value: MWh stored, or install ticks done.
func get_bar_value() -> float:
	return _bar.value


## Returns the bar's maximum: MWh of capacity, or the install's ticks.
func get_bar_max() -> float:
	return _bar.max_value


## Returns the status text: "stored of capacity", the install's time left, or "No capacitors
## installed".
func get_values_text() -> String:
	return _values.text


## Returns the install button; visible only while no capacitors are installed.
func get_install_button() -> HoldButton:
	return _install_button


func _refresh() -> void:
	if _simulation == null:
		_bar.value = 0.0
		_values.text = ""
		_install_button.visible = false
		return
	var power: PowerState = _simulation.state.power
	var mode: Mode = mode_of(power)
	_bar_area.visible = mode != Mode.EMPTY
	_install_button.visible = mode == Mode.EMPTY
	match mode:
		Mode.EMPTY:
			_show_empty()
		Mode.INSTALLING:
			_show_installing(power)
		_:
			_show_charge(power)


func _show_empty() -> void:
	_values.text = tr("GATE_DIAL_NO_CAPACITORS")
	_install_button.text = (tr("GATE_GAUGE_INSTALL").format(
		{"duration": _duration(_install_ticks())}
	))


func _show_installing(power: PowerState) -> void:
	var total: int = maxi(_install_ticks(), power.install_ticks_left)
	_bar.max_value = maxf(float(total), 1.0)
	_bar.value = float(total - power.install_ticks_left)
	_values.text = (tr("GATE_GAUGE_INSTALLING").format(
		{"left": _duration(power.install_ticks_left)}
	))


func _show_charge(power: PowerState) -> void:
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


## Ticks one install takes, from the balance; 0 without one.
func _install_ticks() -> int:
	var balance: BalanceConfig = _simulation.state.balance
	return balance.capacitor_bank_install_ticks if balance != null else 0


## [param ticks] as "6 h" when they are whole hours, else as GateRoomFormat.duration().
func _duration(ticks: int) -> String:
	if ticks >= _MINUTES_PER_HOUR and ticks % _MINUTES_PER_HOUR == 0:
		return tr("GATE_DURATION_WHOLE_HOURS").format({"hours": ticks / _MINUTES_PER_HOUR})
	return GateRoomFormat.duration(ticks)


func _on_install_confirmed() -> void:
	if _simulation == null:
		return
	var result: CommandResult = _simulation.submit(InstallCapacitorsCommand.new())
	_refresh()
	if result.is_ok:
		install_started.emit()


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_refresh()


func _on_capacitors_installed(_capacity_mwh: float) -> void:
	_refresh()
