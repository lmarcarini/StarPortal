class_name BudgetState
extends RefCounted
## Saved state of the base's money: one amount in thousands of dollars. It may go below zero
## (upkeep can push it there); spending never does.
## Saved shape: {"funds_k"}, a whole number.
## Bible: docs/content/m2-base.md section 5, technical-architecture.md#data-model

## Error code of a spend the balance cannot cover.
const INSUFFICIENT_FUNDS: StringName = &"insufficient_funds"

## Money held, in thousands of dollars; negative when in debt.
var funds_k: int = 0


## Returns the campaign's starting budget from [param balance].
static func starting(balance: BalanceConfig) -> BudgetState:
	var budget := BudgetState.new()
	budget.funds_k = balance.starting_budget_k
	return budget


## True when [param cost_k] (at least 0) can be paid without going below zero.
func can_afford(cost_k: int) -> bool:
	return cost_k >= 0 and funds_k >= cost_k


## The error code a spend of [param cost_k] would fail with: &"" when it can be paid,
## [constant INSUFFICIENT_FUNDS] otherwise. Commands call it in validate().
func spend_error(cost_k: int) -> StringName:
	return &"" if can_afford(cost_k) else INSUFFICIENT_FUNDS


## Pays [param cost_k] and returns &"", or changes nothing and returns
## [constant INSUFFICIENT_FUNDS] when it cannot be paid. Call only from Command.apply().
func spend(cost_k: int) -> StringName:
	var error: StringName = spend_error(cost_k)
	if error.is_empty():
		funds_k -= cost_k
	return error


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {"funds_k": funds_k}


## Builds a BudgetState from saved [param data] (whole floats become ints); a missing or
## unreadable balance is 0. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> BudgetState:
	var budget := BudgetState.new()
	var value: Variant = data.get("funds_k")
	if JsonLimits.is_exact_int(value):
		budget.funds_k = type_convert(value, TYPE_INT)
	return budget


## Returns human-readable errors for saved [param data], empty when it is valid: "funds_k" a
## whole number with absolute value at most [constant JsonLimits.MAX_EXACT_INT].
static func validate_dict(data: Dictionary) -> Array[String]:
	if not JsonLimits.is_exact_int(data.get("funds_k")):
		return ["'funds_k' is missing or not a whole number"]
	return []
