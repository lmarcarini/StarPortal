class_name SoakReloads
extends RefCounted
## When the soak's reloading run takes an extra save and load (M4.9-18, #484): at a few seeded
## random ticks a year, and while a conversation runs (at most once a quarter), on top of the
## month closes and mid-scan reloads. Its draws come from its own generator, never from the
## game's streams, so both runs stay identical.
## Bible: technical-architecture.md#testing-and-tooling (Soak test),
## technical-architecture.md#save-system

## Random reload moments a year.
const RANDOM_MOMENTS: int = 4
## Months between two mid-conversation reloads.
const CONVERSATION_EVERY_MONTHS: int = 3

## Ticks still to reload at, earliest first.
var random_ticks: Array[int] = []
## Reloads taken at random ticks and mid-conversation.
var random_switches: int = 0
var conversation_switches: int = 0


## Picks [constant RANDOM_MOMENTS] ticks in 1..[param year_ticks] from [param seed].
func _init(seed: int, year_ticks: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for index: int in RANDOM_MOMENTS:
		random_ticks.append(rng.randi_range(1, year_ticks - 1))
	random_ticks.sort()


## True (and counted) when [param state], [param months_closed] months in, is due a reload.
func take(state: GameState, months_closed: int) -> bool:
	if not random_ticks.is_empty() and state.clock.tick >= random_ticks[0]:
		random_ticks.pop_front()
		random_switches += 1
		return true
	var due: bool = conversation_switches * CONVERSATION_EVERY_MONTHS <= months_closed
	if state.conversations.active != null and due:
		conversation_switches += 1
		return true
	return false


## Counts the ticks in 1..[param year_ticks] that TimeMath says start a day.
static func expected_day_starts(year_ticks: int) -> int:
	var count := 0
	for tick: int in range(1, year_ticks + 1):
		if TimeMath.is_day_start(tick):
			count += 1
	return count


## Removes the folder at [param path] and its files.
static func remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
