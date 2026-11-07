class_name CommandText
extends RefCounted
## Words and figures of the Command tab (docs/content/m27-daily-rhythm.md section 4) in the
## current locale: the header, money line names and amounts, the trend, cause rows with their
## date, the commendation and each line's breakdown.
## Bible: docs/content/m27-daily-rhythm.md section 4


## "Funds $4,125k (+$95k a day)" for [param state].
static func funds_line(state: GameState) -> String:
	var net: CommandLine = CommandLedger.lines(state).back()
	var per_day: int = roundi(net.per_day_tenths / 10.0)
	var signed: String = ("+" if per_day >= 0 else "") + MoneyLabel.format_k(per_day)
	return _tr(&"COMMAND_FUNDS").format(
		{"funds": MoneyLabel.format_k(state.budget.funds_k), "net": signed}
	)


## The name of [param line]: "Allocation (Conf. 61)", "Power Plant ×2", "Other rooms ×3",
## "Salaries (7 people)", "Net".
static func line_name(state: GameState, line: CommandLine) -> String:
	match line.kind:
		CommandLine.Kind.ALLOCATION:
			return _tr(&"COMMAND_LINE_ALLOCATION").format({"value": state.committee.whole()})
		CommandLine.Kind.ROOM_TYPE:
			var def: RoomDef = state.room_defs.get(line.def_id)
			var name: String = String(line.def_id) if def == null else _tr(def.name_key)
			return _tr(&"COMMAND_LINE_ROOM").format({"name": name, "count": line.count})
		CommandLine.Kind.OTHER_ROOMS:
			return _tr(&"COMMAND_LINE_OTHER").format({"count": line.count})
		CommandLine.Kind.SALARIES:
			var key: StringName = (
				&"COMMAND_LINE_SALARIES_ONE" if line.count == 1 else &"COMMAND_LINE_SALARIES"
			)
			return _tr(key).format({"count": line.count})
	return _tr(&"COMMAND_LINE_NET")


## [param line]'s per-day figure: whole for the allocation, else one decimal ("-5.0"); "0"
## for nothing.
static func per_day(line: CommandLine) -> String:
	var tenths: int = line.per_day_tenths
	if tenths == 0:
		return "0"
	if line.kind == CommandLine.Kind.ALLOCATION:
		return signed_number(tenths / 10)
	var sign: String = "+" if tenths > 0 else "-"
	return "%s%s.%d" % [sign, group(absi(tenths) / 10), absi(tenths) % 10]


## [param amount] with its sign and thousands grouped: "+3,330", "-150", "0".
static func signed_number(amount: int) -> String:
	if amount == 0:
		return "0"
	return ("+" if amount > 0 else "-") + group(absi(amount))


## [param amount] (not negative) with thousands grouped: "3,330".
static func group(amount: int) -> String:
	var digits: String = str(amount)
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return digits + grouped


## A signed $k change: "+$1,330k", "-$410k", "$0k".
static func signed_money(amount_k: int) -> String:
	return ("+" if amount_k > 0 else "") + MoneyLabel.format_k(amount_k)


## "TREND   7 d -$410k   30 d +$1,330k" for [param state].
static func trend_line(state: GameState) -> String:
	return (
		_tr(&"COMMAND_TREND")
		. format(
			{
				"short": signed_money(CommandLedger.trend_k(state, CommandLedger.TREND_SHORT_DAYS)),
				"long": signed_money(CommandLedger.trend_k(state, CommandLedger.TREND_LONG_DAYS)),
			}
		)
	)


## "9 Jan" for [param tick].
static func short_date(tick: int) -> String:
	var date: Dictionary = TimeMath.date_of(maxi(tick, 0))
	return "%d %s" % [date["day"], _tr(StringName("COMMAND_MONTH_%d" % date["month"]))]


## The commendation line: "At 70: $1,000k", or "Paid. Re-arms below 60.".
static func commendation(state: GameState) -> String:
	if state.committee.commendation_paid:
		return _tr(&"COMMAND_COMMENDATION_PAID").format(
			{"below": ConfidenceRules.COMMENDATION_REARM_BELOW / ConfidenceRules.TENTHS}
		)
	return (
		_tr(&"COMMAND_COMMENDATION_AT")
		. format(
			{
				"at": ConfidenceRules.COMMENDATION_AT / ConfidenceRules.TENTHS,
				"amount": MoneyLabel.format_k(ConfidenceRules.COMMENDATION_K),
			}
		)
	)


## The breakdown of [param line], one string per room or person ("Power Plant (Level 1)
## -$150k"), or how the allocation and the net are made.
static func breakdown(state: GameState, line: CommandLine) -> PackedStringArray:
	var out: PackedStringArray = []
	match line.kind:
		CommandLine.Kind.ALLOCATION:
			out.append(_allocation_detail(state))
			return out
		CommandLine.Kind.NET:
			(
				out
				. append(
					(
						_tr(&"COMMAND_NET_DETAIL")
						. format(
							{
								"income":
								MoneyLabel.format_k(CommandLedger.allocation_k(state) * 30),
								"costs": MoneyLabel.format_k(CommandLedger.costs_k(state)),
							}
						)
					)
				)
			)
			return out
	for index: int in line.item_ids.size():
		out.append(
			"%s  %s" % [_item_name(state, line, index), signed_money(line.item_amounts[index])]
		)
	return out


static func _allocation_detail(state: GameState) -> String:
	var base: int = 0 if state.balance == null else state.balance.daily_allocation_k
	return (
		_tr(&"COMMAND_ALLOCATION_DETAIL")
		. format(
			{
				"base": MoneyLabel.format_k(base),
				"value": state.committee.whole(),
				"amount": MoneyLabel.format_k(CommandLedger.allocation_k(state)),
			}
		)
	)


static func _item_name(state: GameState, line: CommandLine, index: int) -> String:
	var id: StringName = line.item_ids[index]
	if line.kind == CommandLine.Kind.SALARIES:
		var person: PersonState = state.staff.find_person(id)
		return String(id) if person == null else person.name
	var room: RoomState = state.base.find_room(id)
	return String(id) if room == null else PersonnelText.room_name(state, room)


static func _tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
