class_name PersonnelText
extends RefCounted
## Text of the Personnel tab (docs/content/m26-staff-and-money.md section 6): the header
## ("Staff 5 · Beds 5/6 · Salaries $5k a day"), a person's role, skill stars, salary and
## room ("Research Lab", "Unassigned", "Arriving in 3 d 4 h"), a candidate's pipeline, fee and
## arrival time, a room on the Assign… list with its slots and effect, and a refused hire,
## dismiss or assign in plain words. Pure: reads the state, never changes it.
## Bible: docs/content/m26-staff-and-money.md section 6

## A skill star. ASCII, because the default font has no ★ (the layout sketch uses "***").
const STAR: String = "*"


## "Staff 5 · Beds 5/6 · Salaries $5k a day" for [param state]: salaries per 30 days ÷ 30,
## rounded (docs/content/m27-daily-rhythm.md section 5).
static func header(state: GameState) -> String:
	return (
		_tr(&"STAFF_HEADER")
		. format(
			{
				"staff": StaffRules.headcount(state),
				"used": StaffRules.beds_used(state),
				"beds": StaffRules.beds(state),
				"salaries": MoneyLabel.format_k(daily_k(StaffRules.salaries_k(state))),
			}
		)
	)


## The translated name of [param role] ("Scientist"), or the id when unknown.
static func role_name(role: StringName) -> String:
	var key: String = "STAFF_ROLE_%s" % String(role).trim_prefix("role_").to_upper()
	var text: String = _tr(StringName(key))
	return String(role) if text == key else text


## "***" for [param skill] (1 to PersonState.MAX_SKILL stars).
static func stars(skill: int) -> String:
	return STAR.repeat(clampi(skill, 0, PersonState.MAX_SKILL))


## "Skill 3" (the stars' tooltip).
static func skill(skill_level: int) -> String:
	return _tr(&"STAFF_SKILL").format({"n": skill_level})


## [param per_period_k] (an amount per 30 days) as a daily amount, rounded to whole $k.
static func daily_k(per_period_k: int) -> int:
	return roundi(float(per_period_k) / ConfidenceRules.PERIOD_DAYS)


## "$30k / 30 d" (per 30 days) for [param salary_k].
static func salary(salary_k: int) -> String:
	return _tr(&"STAFF_SALARY").format({"money": MoneyLabel.format_k(salary_k)})


## Where [param person] is in [param state]: the room's name, "Unassigned", or
## "Arriving in 3 d 4 h"; an injury first ("Light injury: 1 d 4 h to recover · Workshop", at
## 1x) and "Lent" last for a lent soldier (m3-beyond-the-ring.md section 4).
static func where(state: GameState, person: PersonState) -> String:
	var parts: Array[String] = []
	if person.is_injured():
		var key: StringName = &"STAFF_INJURED_LIGHT"
		if person.injury == PersonState.Injury.SERIOUS:
			key = &"STAFF_INJURED_SERIOUS"
		parts.append(_tr(key).format({"time": ResearchText.duration(person.recovery_left)}))
	parts.append(_place(state, person))
	if person.lent:
		parts.append(_tr(&"STAFF_LENT"))
	return " · ".join(parts)


static func _place(state: GameState, person: PersonState) -> String:
	var now: int = state.clock.tick
	if not person.is_on_base(now):
		var left: String = ResearchText.duration(person.arrives_tick - now)
		return _tr(&"STAFF_ARRIVING").format({"time": left})
	if not person.is_assigned():
		return _tr(&"STAFF_UNASSIGNED")
	return room_name(state, state.base.find_room(person.room_id))


## "Research Lab (Level 1)" for [param room], or "" for null.
static func room_name(state: GameState, room: RoomState) -> String:
	if room == null:
		return ""
	var def: RoomDef = state.room_defs.get(room.def_id)
	var name: String = _tr(def.name_key) if def != null else String(room.def_id)
	return _tr(&"STAFF_ROOM").format({"room": name, "level": room.level})


## "Leaves in 5 d · Academia · Fee: 30 days' pay ($30k) · arrives in 3 d" for
## [param candidate] in [param state] (docs/content/m27-daily-rhythm.md section 3).
static func candidate_line(state: GameState, candidate: CandidateState) -> String:
	return "%s · %s" % [leaves(state, candidate), offer(candidate)]


## "Leaves in 5 d": whole days from today to [param candidate]'s leave day in [param state].
static func leaves(state: GameState, candidate: CandidateState) -> String:
	var days: int = maxi(0, candidate.leaves_day - TimeMath.day_index(state.clock.tick))
	return _tr(&"STAFF_LEAVES").format({"days": days})


## "Academia · Fee: 30 days' pay ($30k) · arrives in 3 d" for [param candidate].
static func offer(candidate: CandidateState) -> String:
	return (
		_tr(&"STAFF_OFFER")
		. format(
			{
				"pipeline": _tr(RecruitmentRules.pipeline_key(candidate.role)),
				"fee": MoneyLabel.format_k(RecruitmentRules.fee_k(candidate)),
				"time": ResearchText.duration(candidate.arrival_ticks),
			}
		)
	)


## "Research Lab (Level 1): 2/4 · speed 100% to 150%" for [param room] in the Assign… list of
## [param person].
static func room_option(state: GameState, room: RoomState, person: PersonState) -> String:
	var used: int = StaffRules.assigned(state, room).size()
	var text: String = _tr(&"STAFF_ROOM_SLOTS").format(
		{"room": room_name(state, room), "used": used, "slots": StaffRules.slots(state, room)}
	)
	var effect: String = StaffEffect.of_assign(state, room, person)
	return text if effect.is_empty() else "%s · %s" % [text, effect]


## The plain words for refusal [param code] of a hire, dismiss or assign command.
static func refusal(code: StringName) -> String:
	match code:
		RecruitmentRules.NO_FREE_BED:
			return _tr(&"STAFF_HIRE_ERR_NO_FREE_BED")
		&"insufficient_funds":
			return _tr(&"STAFF_HIRE_ERR_NO_MONEY")
	var key: String = "STAFF_ERR_%s" % String(code).to_upper()
	var text: String = _tr(StringName(key))
	return _tr(&"STAFF_ERR_OTHER") if text == key else text


static func _tr(key: StringName) -> String:
	return TranslationServer.translate(key)
