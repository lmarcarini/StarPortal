class_name CapacitorGauge
extends VBoxContainer
## The capacitors, in one of two states. With no Capacitor Bank built: "No capacitors
## installed" (the bank is built as a room in the Base tab). Then: a bar of the stored energy
## against the capacity, and the two numbers. It never shows the charge an address needs: the
## player judges that from the outcome. While no bank exists or is being built, a
## Build capacitor bank button asks (through [signal build_bank_requested]) for the Base tab
## with the bank's ghost on the nearest valid spot.
## Bible: gate-and-address-spec.md#the-dial-console, docs/content/m2-base.md sections 2 and 3

## Emitted when the player presses Build capacitor bank.
signal build_bank_requested

## What the gauge shows.
enum Mode { EMPTY, CHARGE }

var _simulation: Simulation = null

@onready var _bar_area: Control = %BarArea
@onready var _bar: ProgressBar = %Bar
@onready var _values: Label = %Values
@onready var _build: Button = %BuildBank


func _ready() -> void:
	_build.pressed.connect(build_bank_requested.emit)
	_refresh()


func _enter_tree() -> void:
	EventBus.tick_advanced.connect(_on_tick_advanced)
	EventBus.dial_resolved.connect(_on_dial_resolved)
	EventBus.capacitors_installed.connect(_on_capacitors_installed)
	EventBus.room_build_started.connect(_on_room_changed)
	EventBus.room_demolished.connect(_on_room_changed)
	EventBus.budget_changed.connect(_on_budget_changed)


func _exit_tree() -> void:
	EventBus.tick_advanced.disconnect(_on_tick_advanced)
	EventBus.dial_resolved.disconnect(_on_dial_resolved)
	EventBus.capacitors_installed.disconnect(_on_capacitors_installed)
	EventBus.room_build_started.disconnect(_on_room_changed)
	EventBus.room_demolished.disconnect(_on_room_changed)
	EventBus.budget_changed.disconnect(_on_budget_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Connects the gauge to [param simulation].
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	if is_node_ready():
		_refresh()


## Returns what the gauge shows for [param state]: EMPTY with no capacity, CHARGE otherwise.
static func mode_of(state: GameState) -> Mode:
	return Mode.EMPTY if PowerRules.capacity_mwh(state) <= 0.0 else Mode.CHARGE


## Returns what the gauge shows now; EMPTY before setup().
func get_mode() -> Mode:
	if _simulation == null:
		return Mode.EMPTY
	return mode_of(_simulation.state)


## Returns the bar's current value: MWh stored.
func get_bar_value() -> float:
	return _bar.value


## Returns the bar's maximum: MWh of capacity.
func get_bar_max() -> float:
	return _bar.max_value


## Returns the status text: "stored of capacity", or "No capacitors installed".
func get_values_text() -> String:
	return _values.text


## True while [param state] has no Capacitor Bank, built or being built: the gauge then
## offers Build capacitor bank.
static func needs_bank(state: GameState) -> bool:
	for room: RoomState in state.base.rooms:
		if room.def_id == StartingBase.CAPACITOR_BANK_DEF:
			return false
	return true


## Returns the Build capacitor bank button.
func get_build_button() -> Button:
	return _build


func _refresh() -> void:
	if _simulation == null:
		_bar.value = 0.0
		_values.text = ""
		_build.visible = false
		return
	var state: GameState = _simulation.state
	_build.visible = needs_bank(state)
	var mode: Mode = mode_of(state)
	_bar_area.visible = mode != Mode.EMPTY
	if mode == Mode.EMPTY:
		_values.text = tr("GATE_DIAL_NO_CAPACITORS")
		return
	var capacity: float = PowerRules.capacity_mwh(state)
	_bar.max_value = maxf(capacity, 1.0)
	_bar.value = state.power.stored_mwh
	_values.text = (
		tr("GATE_GAUGE_VALUES")
		. format(
			{
				"stored": GateRoomFormat.energy(state.power.stored_mwh),
				"capacity": GateRoomFormat.energy(capacity),
			}
		)
	)


func _on_tick_advanced(_tick: int) -> void:
	_refresh()


func _on_dial_resolved(_outcome: int, _address_key: String) -> void:
	_refresh()


func _on_capacitors_installed(_capacity_mwh: float) -> void:
	_refresh()


func _on_room_changed(_site_id: StringName) -> void:
	_refresh()


## A cancel or a demolition posts only budget_changed: refresh at once, also while paused.
func _on_budget_changed(_budget_k: int) -> void:
	_refresh()
