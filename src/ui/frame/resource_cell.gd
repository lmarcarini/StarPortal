class_name ResourceCell
extends RefCounted
## One cell of the resources plate: icon, value and delta (or unit) with their colours,
## read from the state (pure) and drawn at a cell's left edge.
## Bible: docs/content/interface-reference.md section 4 (top_resources)

var icon: StringName = &""
var icon_ink: Color = RefPaint.TEXT
var value: String = ""
var value_ink: Color = RefPaint.TEXT
var delta: String = ""
var delta_ink: Color = RefPaint.DIM


## The four cells of [param state]: funds, power, charge, Confidence.
static func of(state: GameState) -> Array[ResourceCell]:
	var net: int = TopBarText.net_per_day(state)
	var funds: ResourceCell = _make(&"funds", MoneyLabel.format_k(state.budget.funds_k), net)
	funds.delta = "%s/d" % _signed(net)
	if state.budget.funds_k < 0:
		funds.value_ink = RefPaint.RED
	var used: int = roundi(PowerRules.allocated_mw(state))
	var supply: int = roundi(PowerRules.supply_mw(state))
	var power: ResourceCell = _make(&"power", "%d/%d" % [used, supply], 0)
	power.icon_ink = RefPaint.AMBER
	power.delta = "MW"
	if used > supply:
		power.value_ink = RefPaint.RED
	var charge: ResourceCell = _make(&"charge", str(floori(state.power.stored_mwh)), 0)
	charge.icon_ink = RefPaint.AMBER
	charge.delta = "MWh"
	var drift: int = CommitteeText.drift_of(state)
	var trust: ResourceCell = _make(&"confidence", str(state.committee.whole()), drift)
	trust.delta = "" if drift == 0 else CommitteeText.signed_tenths(drift)
	return [funds, power, charge, trust]


## Draws the cell with its left edge at [param x] on [param item] (60 px high).
func draw(item: CanvasItem, x: float) -> void:
	RefIcons.draw(item, icon, Rect2(x + 17, 17, 26, 26), icon_ink)
	var big: RefText = RefText.make(RefText.MONO_BOLD, 24, value_ink)
	big.draw(item, Vector2(x + 54, 30), value, "lm")
	var small: RefText = RefText.make(RefText.MONO, 16, delta_ink)
	small.draw(item, Vector2(x + 60 + big.width(value), 32), delta, "lm")


static func _make(id: StringName, text: String, trend: int) -> ResourceCell:
	var cell: ResourceCell = ResourceCell.new()
	cell.icon = id
	cell.value = text
	if trend != 0:
		cell.delta_ink = RefPaint.GREEN if trend > 0 else RefPaint.RED
	return cell


static func _signed(amount: int) -> String:
	if amount > 0:
		return "+%d" % amount
	return "%d" % amount if amount < 0 else "±0"
