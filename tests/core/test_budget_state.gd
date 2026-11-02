## Tests for BudgetState: starting value, the spend contract and save data.
## Bible: docs/content/m2-base.md section 5
extends GdUnitTestSuite


func test_new_game_starts_with_the_doc_budget() -> void:
	var state := GameState.new_game(1, BalanceConfig.new())
	assert_int(state.budget.funds_k).is_equal(6000)
	assert_int(BalanceConfig.new().monthly_allocation_k).is_equal(3000)


func test_spend_pays_when_covered() -> void:
	var budget := BudgetState.new()
	budget.funds_k = 800
	assert_str(String(budget.spend(800))).is_empty()
	assert_int(budget.funds_k).is_equal(0)


func test_spend_refuses_when_short() -> void:
	var budget := BudgetState.new()
	budget.funds_k = 650
	assert_bool(budget.can_afford(800)).is_false()
	assert_str(String(budget.spend_error(800))).is_equal("insufficient_funds")
	assert_str(String(budget.spend(800))).is_equal("insufficient_funds")
	assert_int(budget.funds_k).is_equal(650)


func test_negative_balance_blocks_any_cost() -> void:
	var budget := BudgetState.new()
	budget.funds_k = -10
	assert_bool(budget.can_afford(0)).is_false()
	assert_bool(budget.can_afford(-5)).is_false()


func test_round_trip_through_json_keeps_negative_balance() -> void:
	var budget := BudgetState.new()
	budget.funds_k = -240
	var data: Dictionary = JSON.parse_string(JSON.stringify(budget.to_dict()))
	assert_array(BudgetState.validate_dict(data)).is_empty()
	assert_int(BudgetState.from_dict(data).funds_k).is_equal(-240)


func test_validate_rejects_bad_balance() -> void:
	assert_array(BudgetState.validate_dict({})).is_not_empty()
	assert_array(BudgetState.validate_dict({"funds_k": 1.5})).is_not_empty()
	assert_array(BudgetState.validate_dict({"funds_k": "12"})).is_not_empty()


func test_game_state_round_trip_keeps_budget() -> void:
	var state := GameState.new_game(1, BalanceConfig.new())
	state.budget.funds_k = 4321
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	assert_int(GameState.from_dict(data).budget.funds_k).is_equal(4321)


func test_credit_adds_even_when_in_debt() -> void:
	var budget := BudgetState.new()
	budget.funds_k = -50
	budget.credit(80)
	assert_int(budget.funds_k).is_equal(30)
