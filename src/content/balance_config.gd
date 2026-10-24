class_name BalanceConfig
extends DefBase
## Every tunable number of the game in one definition, always with the id &"balance".
## Fields are added by the cards that need them; defaults are the bible's starting values.
## Bible: technical-architecture.md#data-model,
## gate-and-address-spec.md#dialing-outcomes-and-energy, gate-and-address-spec.md#the-dial-console

## The id every BalanceConfig has.
const BALANCE_ID: StringName = &"balance"

@export_group("Gate energy")
## E_base: lock energy of an 8-seal dial at distance 0, in MWh.
@export var lock_energy_base_mwh: float = 300.0
## d_ref: distance at which the lock energy doubles, in light years.
@export var lock_reference_distance_ly: float = 10000.0
## M_seals for an 8-seal address.
@export var seal_multiplier_8: float = 1.0
## M_seals for a 9-seal address.
@export var seal_multiplier_9: float = 25.0
## M_seals for a 10-seal address.
@export var seal_multiplier_10: float = 400.0
## Power drawn while an 8-seal wormhole is open, in MW.
@export var open_drain_mw_8: float = 20.0
## Power drawn while a 9-seal wormhole is open, in MW. The 10-seal drain is set by the story.
@export var open_drain_mw_9: float = 200.0

@export_group("Starting power")
## Output of the starting diesel plant, in MW.
@export var starting_plant_output_mw: float = 30.0
## Capacitor storage a new game starts with, in MWh: none, the player installs the first bank.
@export var starting_capacity_mwh: float = 0.0

@export_group("Capacitor banks")
## Storage one installed capacitor bank adds, in MWh.
@export var capacitor_bank_capacity_mwh: float = 400.0
## Ticks installing one capacitor bank takes: six in-game hours.
@export var capacitor_bank_install_ticks: int = 360
## Capacitor banks the base has room for.
@export var max_capacitor_banks: int = 1

@export_group("Dial outcomes")
## Fraction of the lock energy spent on a No gate outcome.
@export var cost_fraction_no_gate: float = 0.10
## Fraction of the lock energy spent on a Blocked outcome.
@export var cost_fraction_blocked: float = 0.25
## Fraction of the lock energy spent on an Origin rejected outcome.
@export var cost_fraction_origin_rejected: float = 0.25
## Ticks the seals take to engage: two in-game minutes.
@export var dial_duration_ticks: int = 2
## Longest a wormhole stays open, in ticks.
@export var max_open_ticks: int = 60


func _init() -> void:
	id = BALANCE_ID
