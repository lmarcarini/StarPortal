class_name StaffNames
extends RefCounted
## Seeded staff names (docs/content/m26-staff-and-money.md section 1): a title of the role, a
## given name and a surname drawn from the name list with the caller's own generator, so the
## same seed always gives the same names. Hiring (card M2.6-06) draws candidates with it.
## Bible: docs/content/m26-staff-and-money.md section 1


## Returns a name for a person of [param role] and [param sex] ("female" or "male") drawn with
## [param rng] from [param names]: "<title> <given> <surname>", or "<given> <surname>" for an
## empty title. The given name comes from the sex's list plus the unisex names (M8-01). Draws,
## in order, the title, the given name and the surname, each with one rng.randi_range().
static func draw(
	rng: RandomNumberGenerator, names: StaffNameListDef, role: RoleDef, sex: String
) -> String:
	var title: String = _pick(rng, role.titles)
	var given: String = _pick(rng, names.given_names_for(sex))
	var surname: String = _pick(rng, names.surnames)
	var parts: Array[String] = [given, surname]
	if not title.is_empty():
		parts.push_front(title)
	return " ".join(parts)


static func _pick(rng: RandomNumberGenerator, options: Array[String]) -> String:
	if options.is_empty():
		return ""
	return options[rng.randi_range(0, options.size() - 1)]
