class_name PersonnelRow
extends PanelContainer
## One 48 px row of the Personnel tab (docs/content/m26-staff-and-money.md section 6): the
## face from the portrait at 1:1 (docs/content/portraits.md, M8-02), then a
## person (name, role, skill stars, salary, room or "Arriving in …") or a candidate (name,
## role, stars, salary, days until leaving, pipeline, fee,
## arrival time). The stars' tooltip gives the skill
## as a number. The row takes focus (D-pad, click); focusing it emits [signal chosen], and
## (A) or Enter on it emits [signal activated].
## Bible: docs/content/m26-staff-and-money.md section 6

## Emitted when the row takes focus.
signal chosen(id: StringName)
## Emitted on (A) or Enter while the row has focus.
signal activated(id: StringName)

## Height of a row, in pixels.
const HEIGHT: int = 48
## Widths of the role, stars and salary columns; the name and the last column share the rest.
const WIDTHS: Array[int] = [120, 96, 120]

var id: StringName = &""
var _name: Label = _label(16, 0)
var _role: Label = _label(16, WIDTHS[0])
var _stars: Label = _label(16, WIDTHS[1])
var _salary: Label = _label(16, WIDTHS[2])
var _where: Label = _label(14, 0)
var _portrait := StaffPortrait.new()


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	var box := HBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 12)
	_name.size_flags_horizontal = SIZE_EXPAND_FILL
	_name.size_flags_stretch_ratio = 1.2
	_where.size_flags_horizontal = SIZE_EXPAND_FILL
	_stars.mouse_filter = MOUSE_FILTER_PASS
	_portrait.crop = StaffPortrait.FACE
	box.add_child(_portrait)
	for part: Label in labels():
		box.add_child(part)
	add_child(box)
	focus_entered.connect(_on_focus)
	focus_exited.connect(queue_redraw)


## Shows [param person] as it stands in [param state].
func show_person(state: GameState, person: PersonState) -> void:
	id = person.id
	_fill(person.name, person.role, person.skill, person.salary_k)
	_portrait.show_record(person.id, person.appearance)
	_where.text = PersonnelText.where(state, person)
	modulate = Color(1, 1, 1, 0.6) if not person.is_on_base(state.clock.tick) else Color.WHITE


## Shows [param candidate] as it stands in [param state] ("Leaves in 5 d · ...").
func show_candidate(state: GameState, candidate: CandidateState) -> void:
	id = candidate.id
	_fill(candidate.name, candidate.role, candidate.skill, candidate.salary_k)
	_portrait.show_record(candidate.id, candidate.appearance)
	_where.text = PersonnelText.candidate_line(state, candidate)
	modulate = Color.WHITE


## Returns the row's labels, left to right: name, role, stars, salary, where.
func labels() -> Array[Label]:
	return [_name, _role, _stars, _salary, _where]


## Returns the row's portrait (the face window).
func get_portrait() -> StaffPortrait:
	return _portrait


## Returns the row's texts, left to right.
func texts() -> Array[String]:
	var found: Array[String] = []
	for label: Label in labels():
		found.append(label.text)
	return found


func _fill(name: String, role: StringName, skill: int, salary_k: int) -> void:
	_name.text = name
	_role.text = PersonnelText.role_name(role)
	_stars.text = PersonnelText.stars(skill)
	_stars.tooltip_text = PersonnelText.skill(skill)
	_salary.text = PersonnelText.salary(salary_k)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		accept_event()
		activated.emit(id)


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 2.0)


func _on_focus() -> void:
	queue_redraw()
	chosen.emit(id)


static func _label(font_size: int, width: int) -> Label:
	var label := Label.new()
	label.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	label.custom_minimum_size.x = width
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	return label
