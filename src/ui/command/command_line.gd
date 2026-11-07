class_name CommandLine
extends RefCounted
## One money line of the Command tab (docs/content/m27-daily-rhythm.md section 4): the
## allocation, a room type with its count, Other rooms, salaries with the headcount, or the
## net. Amounts are signed (income positive, costs negative). Read-only data built by
## [CommandLedger]; the rooms or people it covers make its breakdown.
## Bible: docs/content/m27-daily-rhythm.md section 4

## What the line stands for.
enum Kind { ALLOCATION, ROOM_TYPE, OTHER_ROOMS, SALARIES, NET }

var kind: Kind = Kind.NET
## The room def of a ROOM_TYPE line; empty otherwise.
var def_id: StringName = &""
## Rooms (or people for SALARIES) the line covers.
var count: int = 0
## Per day in tenths of $k, signed.
var per_day_tenths: int = 0
## Per 30 days in $k, signed.
var per_period_k: int = 0
## The rooms (ROOM_TYPE, OTHER_ROOMS) or people (SALARIES) of the breakdown, by id.
var item_ids: Array[StringName] = []
## Each item's own signed amount per 30 days in $k, matching [member item_ids].
var item_amounts: Array[int] = []


## A line of [param line_kind] costing or earning [param per_period_k] per 30 days, with the
## per-day figure being that ÷ 30 to one decimal.
static func create(line_kind: Kind, per_period: int) -> CommandLine:
	var line := CommandLine.new()
	line.kind = line_kind
	line.per_period_k = per_period
	line.per_day_tenths = roundi(per_period * 10.0 / ConfidenceRules.PERIOD_DAYS)
	return line


## Adds [param id] with [param amount_k] (signed, per 30 days) to the breakdown.
func add_item(id: StringName, amount_k: int) -> void:
	item_ids.append(id)
	item_amounts.append(amount_k)
