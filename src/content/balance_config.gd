class_name BalanceConfig
extends DefBase
## Every tunable number of the game in one definition, always with the id &"balance".
## Fields are added by the cards that need them; defaults are the bible's starting values.
## Bible: technical-architecture.md#data-model, docs/content/m2-base.md,
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
## Ticks installing one capacitor bank takes: one in-game hour (m25-lean-start.md section 5).
@export var capacitor_bank_install_ticks: int = 60
## Capacitor banks a new game may build (the starting bank cap); the Bank array research
## raises it (UnlockState.bank_cap).
@export var max_capacitor_banks: int = 1

@export_group("Base")
## Cells of every level (width × height), 3 m each (m2-base.md section 2).
@export var base_grid_size: Vector2i = Vector2i(36, 20)
## Underground levels a new game starts with, all dug; the Ring is on Level 1
## (m25-lean-start.md section 1).
@export var starting_levels: int = 1
## Cost of digging each extra level, in $k, in order (Level 2, 3, 4); its size is the most
## extra levels M2.5 allows (m25-lean-start.md section 2).
@export var dig_level_costs_k: Array[int] = [1500, 2500, 3500]
## Ticks of digging each extra level, in order: 3, 4 and 5 in-game days.
@export var dig_level_ticks: Array[int] = [4320, 5760, 7200]
## Cost of one lift segment, in $k: a lift extended into a newly dug level
## (m25-lean-start.md section 2; used by card M2.5-07).
@export var lift_segment_cost_k: int = 100
## Ticks one lift segment takes to build: one in-game hour.
@export var lift_segment_ticks: int = 60
## A blast door (M4c): cost in $k and build time in ticks.
@export var door_cost_k: int = 50
@export var door_build_ticks: int = 120
## Squads (M4c): cells walked per tick, and ticks to change level in a lift or stairs.
@export var squad_cells_per_tick: int = 2
@export var squad_level_ticks: int = 1
## Combat (M4c): a soldier's health; the seeded roll on each side's damage; the share the
## side defending a room (there first) does not take; walking cells within which squads and
## intruders in corridors fight.
@export var soldier_health: int = 10
@export var combat_roll_min: float = 0.75
@export var combat_roll_max: float = 1.25
@export var defender_reduction: float = 0.25
@export var combat_reach_cells: int = 3
## Room def ids a new game may build before any research (m25-lean-start.md section 1).
@export var starting_room_unlocks: Array[StringName] = [
	&"room_capacitor_bank",
	&"room_research_lab",
	&"room_corridor",
	&"room_quarters",
	&"room_security_post",
]

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

@export_group("Money")
## Budget a new game starts with, in thousands of dollars (m25-lean-start.md section 1).
@export var starting_budget_k: int = 6000
## Allocation paid at each daily settlement at Committee Confidence 50, in thousands of
## dollars; the paid amount scales with Confidence (m27-daily-rhythm.md section 1).
@export var daily_allocation_k: int = 100
## Salary of a skill-0 person, in $k per 30 days: salary = base + per skill × skill
## (m26-staff-and-money.md section 1: skill 1 = $20k, skill 3 = $30k, skill 5 = $40k).
@export var salary_base_k: int = 15
## Salary added per skill point, in $k per 30 days.
@export var salary_per_skill_k: int = 5

@export_group("Recruitment")
## Candidates the rolling list holds (m27-daily-rhythm.md section 3).
@export var candidates_per_list: int = 4
## Weights of a drawn candidate's skill 1 to 5, in percent (section 2: 10, 35, 35, 15, 5).
@export var candidate_skill_weights: Array[int] = [10, 35, 35, 15, 5]
## Days from hiring to arrival per role id, i.e. per pipeline (section 2: Academia 5,
## Military 3, Intelligence 7; M3: soldier 3, medic 5).
@export var hire_arrival_days: Dictionary[StringName, int] = {
	&"role_scientist": 5,
	&"role_engineer": 3,
	&"role_analyst": 7,
	&"role_soldier": 3,
	&"role_medic": 5,
}

## Factions (m4-core-systems.md sections 2 and 3): a met faction starts a contact at most once
## every this many days; an unanswered phone call expires after this many days; an incoming
## wormhole waits this many in-game minutes for Answer or Ignore.
@export var faction_contact_days: int = 4
@export var phone_expiry_days: int = 2
@export var incoming_answer_minutes: int = 5
## Artefacts Gate Room holding can keep (m4-core-systems.md section 5).
@export var holding_capacity: int = 2
## Research projects the player may queue (m4-core-systems.md section 7).
@export var research_queue_max: int = 5

## Speed index the clock drops to while a slow reason is active (event-time.md section 2).
@export var slow_speed_index: int = 1


func _init() -> void:
	id = BALANCE_ID
