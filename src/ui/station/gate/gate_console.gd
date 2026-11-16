class_name GateConsole
extends SteelPanel
## The Gate station's console along the bottom: the destination monitor (left), the seal
## lamps over one big key (centre: DIAL when idle, CLOSE while open, ANSWER with an IGNORE
## key while an incoming wormhole waits) and the charge gauge with the Shutter lever (right).
## It submits DialCommand, CloseWormholeCommand, AnswerIncomingCommand,
## IgnoreIncomingCommand and SetShutterCommand; a refusal shows as the key's hover reason and
## a shake, never as text.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Console)

## The BUILD BANK key was pressed.
signal build_bank_requested

## The main key's text for each MainKeyRules.Mode.
const _KEY_TEXT: Array[String] = ["HW_KEY_DIAL", "HW_KEY_CLOSE", "HW_KEY_ANSWER", "HW_KEY_DIAL"]

var _simulation: Simulation = null
var _destination: GateDestination = null
var _refusal: StringName = &""
var _close_busy: Callable = Callable()
var _shake: Tween = null
var _ignore: IconKey = IconKey.new()

@onready var _monitor: DestinationMonitor = %DestinationMonitor
@onready var _seals: SealLampRow = %SealLamps
@onready var _key: BigKey = %MainKey
@onready var _charge: ChargeGauge = %Charge
@onready var _lever: Lever = %ShutterLever


func _ready() -> void:
	_key.activated.connect(press_main_key)
	_lever.toggled.connect(_on_lever)
	HoverCard.attach(_lever, "STATION_HELP_SHUTTER")
	_charge.build_bank_requested.connect(build_bank_requested.emit)
	_ignore.name = "IgnoreKey"
	_ignore.icon_id = &"close"
	_ignore.visible = false
	_ignore.set_help("GATE_INCOMING_IGNORE")
	_ignore.pressed.connect(ignore_incoming)
	_key.get_parent().add_child(_ignore)
	_ignore.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	set_process(false)


## Reads [param simulation] from now on.
func setup(simulation: Simulation) -> void:
	_simulation = simulation
	_refusal = &""
	set_process(true)
	refresh(RingLook.new())


## Extra check that makes CLOSE ask to be held (the floor actors' cue in progress).
func set_close_busy_check(check: Callable) -> void:
	_close_busy = check


## Puts [param destination] on the monitor and makes it the one DIAL dials (null clears).
func select_destination(destination: GateDestination) -> void:
	_destination = destination
	_refusal = &""
	_monitor.show_destination(destination)


## Shows NEW ADDRESS on the monitor with [param address] (being composed) as the one to dial.
func select_composing(address: GateAddress) -> void:
	_destination = GateDestination.of(address, "")
	_refusal = &""
	_monitor.show_composing()


## The destination selected, or null.
func get_destination() -> GateDestination:
	return _destination


## Presses the main key: dials, or closes the wormhole.
func press_main_key() -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var address: GateAddress = _destination.address if _destination != null else null
	match MainKeyRules.mode_of(state, address):
		MainKeyRules.Mode.CLOSE:
			_simulation.submit(CloseWormholeCommand.new())
		MainKeyRules.Mode.ANSWER:
			_simulation.submit(AnswerIncomingCommand.new())
		MainKeyRules.Mode.DIAL:
			var result: CommandResult = _simulation.submit(DialCommand.create(address))
			if not result.is_ok:
				_refuse(MainKeyRules.refusal_key(result.error_code))
		MainKeyRules.Mode.OFF:
			_refuse(MainKeyRules.reason_of(state, address))
	refresh(RingLook.of(state.gate, state.clock.tick, _dial_ticks()))


## Lets the incoming wormhole ring out (IgnoreIncomingCommand).
func ignore_incoming() -> void:
	if _simulation != null:
		_simulation.submit(IgnoreIncomingCommand.new())


## The IGNORE key, shown while an incoming wormhole waits.
func get_ignore_key() -> IconKey:
	return _ignore


## The hover reason shown on the key now (a refusal or why it is off); "" for none.
func get_key_reason() -> String:
	var card: HoverCard = _key.find_child("HoverCard", false, false) as HoverCard
	return card.get_text() if card != null else ""


## The main key.
func get_main_key() -> BigKey:
	return _key


## The destination monitor.
func get_monitor() -> DestinationMonitor:
	return _monitor


## The seal lamps.
func get_seal_lamps() -> SealLampRow:
	return _seals


## The charge gauge.
func get_charge() -> ChargeGauge:
	return _charge


## The Shutter lever.
func get_lever() -> Lever:
	return _lever


func _process(_delta: float) -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	refresh(RingLook.of(state.gate, state.clock.tick, _dial_ticks()))


## Redraws every part for the state and [param look].
func refresh(look: RingLook) -> void:
	if _simulation == null:
		return
	var state: GameState = _simulation.state
	var address: GateAddress = _destination.address if _destination != null else null
	var mode: MainKeyRules.Mode = MainKeyRules.mode_of(state, address)
	_seals.show_look(look)
	var need: float = GateQueries.lock_energy_mwh(state, address) if address != null else 0.0
	_charge.show_state(state, need)
	_key.text = _KEY_TEXT[mode]
	_key.key_style = (
		BigKey.KeyStyle.HAZARD if mode == MainKeyRules.Mode.CLOSE else BigKey.KeyStyle.AMBER
	)
	_ignore.visible = mode == MainKeyRules.Mode.ANSWER
	var busy: bool = MainKeyRules.close_needs_confirm(state)
	if _close_busy.is_valid():
		var extra: bool = _close_busy.call()
		busy = busy or extra
	_key.hold_to_confirm = mode == MainKeyRules.Mode.CLOSE and busy
	var reason: StringName = MainKeyRules.reason_of(state, address)
	if mode == MainKeyRules.Mode.CLOSE or mode == MainKeyRules.Mode.ANSWER:
		reason = &""
	_set_key_reason(_refusal if _refusal != &"" else reason)
	_lever.visible = ShutterRules.is_installed(state)
	_lever.set_pressed_no_signal(ShutterRules.is_closed(state))


func _set_key_reason(key: StringName) -> void:
	var card: HoverCard = _key.find_child("HoverCard", false, false) as HoverCard
	var help: String = String(key) if key != &"" else "STATION_HELP_MAIN_KEY"
	if card == null:
		HoverCard.attach(_key, help)
		return
	card.set_text(help)


func _refuse(key: StringName) -> void:
	_refusal = key
	_set_key_reason(key)
	if _shake != null:
		_shake.kill()
	var start: float = _key.position.x
	_shake = create_tween()
	for dx: float in [6.0, -6.0, 4.0, -4.0, 0.0]:
		_shake.tween_property(_key, "position:x", start + dx, 0.04)


func _on_lever(down: bool) -> void:
	if _simulation == null:
		return
	var result: CommandResult = _simulation.submit(SetShutterCommand.create(down))
	if not result.is_ok:
		_lever.set_pressed_no_signal(not down)


func _dial_ticks() -> int:
	var balance: BalanceConfig = _simulation.state.balance
	return balance.dial_duration_ticks if balance != null else 1
