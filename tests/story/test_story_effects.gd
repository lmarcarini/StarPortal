## Tests for StoryRules.apply (M4-05): every effect class applied or refused, with its event,
## and the preview lines.
## Bible: docs/content/m4-core-systems.md section 1
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = StoryFixture.state()
	TranslationServer.set_locale("en")


func _apply(effect: EffectDef) -> bool:
	return StoryRules.apply(_state, effect, &"test_source")


func test_set_and_stamp_flag() -> void:
	var set_flag := SetFlagEffect.new()
	set_flag.flag = &"gift_given"
	set_flag.value = "yes"
	assert_bool(_apply(set_flag)).is_true()
	assert_str(str(_state.flags[&"gift_given"])).is_equal("yes")
	_state.clock.tick = 777
	var stamp := StampFlagEffect.new()
	stamp.flag = &"since"
	assert_bool(_apply(stamp)).is_true()
	assert_int(_state.flags[&"since"]).is_equal(777)
	assert_array(StoryFixture.event_names(_state)).is_equal([&"flag_changed", &"flag_changed"])
	assert_bool(_apply(SetFlagEffect.new())).is_false()


func test_change_standing_and_committee() -> void:
	var effect := ChangeStandingEffect.new()
	effect.faction = &"faction_kindred"
	effect.delta = 10
	assert_bool(_apply(effect)).is_true()
	assert_int(FactionRules.standing(_state, &"faction_kindred")).is_equal(10)
	effect.faction = FactionRules.COMMITTEE
	effect.delta = -2
	var before: int = _state.committee.confidence
	assert_bool(_apply(effect)).is_true()
	assert_int(_state.committee.confidence).is_equal(before - 20)
	effect.faction = &"faction_nobody"
	assert_bool(_apply(effect)).is_false()


func test_change_money() -> void:
	var effect := ChangeMoneyEffect.new()
	effect.amount_k = -300
	var before: int = _state.budget.funds_k
	assert_bool(_apply(effect)).is_true()
	assert_int(_state.budget.funds_k).is_equal(before - 300)
	assert_array(StoryFixture.event_names(_state)).is_equal([&"budget_changed"])


func test_add_document_once() -> void:
	var effect := AddDocumentEffect.new()
	effect.document = &"doc_lintel_note"
	var held: bool = _state.archive.has_document(&"doc_lintel_note")
	assert_bool(_apply(effect)).is_equal(not held)
	assert_bool(_state.archive.has_document(&"doc_lintel_note")).is_true()
	assert_bool(_apply(effect)).is_false()


func test_add_address_once() -> void:
	var effect := AddAddressEffect.new()
	effect.world = &"world_lintel"
	var count: int = _state.address_book.entries.size()
	assert_bool(_apply(effect)).is_true()
	assert_int(_state.address_book.entries.size()).is_equal(count + 1)
	assert_str(String(_state.address_book.entries[0].world_id)).is_equal("world_lintel")
	assert_bool(_apply(effect)).is_false()
	effect.world = &"world_nowhere"
	assert_bool(_apply(effect)).is_false()


func test_offer_request() -> void:
	_state.clock.tick = 100
	var effect := OfferRequestEffect.new()
	effect.request = &"request_test"
	assert_bool(_apply(effect)).is_true()
	var record: RequestRecord = _state.requests.items[0]
	assert_int(record.state).is_equal(RequestRecord.RequestState.OFFERED)
	assert_int(record.offered_tick).is_equal(100)
	assert_int(record.deadline_tick).is_equal(100 + 3 * TimeMath.TICKS_PER_DAY)
	assert_int(_state.requests.next_uid).is_equal(1)
	assert_array(StoryFixture.event_names(_state)).is_equal([&"request_offered"])
	effect.request = &"request_unknown"
	assert_bool(_apply(effect)).is_false()


func test_give_take_and_study_artefact() -> void:
	var give := GiveArtefactEffect.new()
	give.artefact = &"artefact_loom"
	var take := TakeArtefactEffect.new()
	take.artefact = &"artefact_loom"
	var study := StudyArtefactEffect.new()
	study.artefact = &"artefact_loom"
	assert_bool(_apply(take)).is_false()
	assert_bool(_apply(study)).is_false()
	assert_bool(_apply(give)).is_true()
	assert_bool(_apply(give)).is_true()
	var first: ArtefactRecord = _state.artefacts.items[0]
	assert_int(first.state).is_equal(ArtefactRecord.ArtefactState.RECOVERED)
	assert_int(first.room_uid).is_equal(ArtefactRecord.IN_HOLDING)
	assert_bool(_apply(study)).is_true()
	assert_int(_state.artefacts.items[1].state).is_equal(ArtefactRecord.ArtefactState.STUDIED)
	assert_bool(_apply(take)).is_true()
	assert_int(_state.artefacts.items.size()).is_equal(1)
	assert_int(_state.artefacts.items[0].uid).is_equal(1)
	assert_array(StoryFixture.event_names(_state)).is_equal(
		[&"artefact_arrived", &"artefact_arrived", &"artefact_studied", &"artefact_taken"]
	)


func test_unlock_and_complete_research() -> void:
	var unlock := UnlockResearchEffect.new()
	unlock.project = &"later_capacitor_lattice"
	assert_bool(_apply(unlock)).is_true()
	assert_bool(_apply(unlock)).is_false()
	assert_array(_state.research.revealed).is_equal([&"later_capacitor_lattice"])
	var complete := CompleteResearchEffect.new()
	complete.project = &"later_capacitor_lattice"
	assert_bool(_apply(complete)).is_true()
	assert_bool(_state.research.is_done(&"later_capacitor_lattice")).is_true()
	assert_bool(_apply(complete)).is_false()
	complete.project = &"research_nothing"
	assert_bool(_apply(complete)).is_false()


func test_modifier_is_refused() -> void:
	var modifier := ModifierEffect.new()
	modifier.key = &"research_speed_pct"
	modifier.amount = 10
	var before: Dictionary = _state.to_dict()
	assert_bool(_apply(modifier)).is_false()
	assert_dict(_state.to_dict()).is_equal(before)


func test_apply_all_counts() -> void:
	var good := ChangeMoneyEffect.new()
	good.amount_k = 5
	var bad := TakeArtefactEffect.new()
	bad.artefact = &"artefact_none"
	var effects: Array[EffectDef] = [good, bad, good]
	assert_int(StoryRules.apply_all(_state, effects, &"x")).is_equal(2)


func test_previews() -> void:
	var standing := ChangeStandingEffect.new()
	standing.faction = &"faction_kindred"
	standing.delta = 10
	assert_str(StoryText.preview(standing)).is_equal("faction_kindred standing +10")
	var money := ChangeMoneyEffect.new()
	money.amount_k = 500
	assert_str(StoryText.preview(money)).contains("500")
	var give := GiveArtefactEffect.new()
	give.artefact = &"artefact_loom"
	assert_str(StoryText.preview(give)).is_equal("An artefact: artefact_loom")
	give.hidden = true
	assert_str(StoryText.preview(give)).is_equal("?")
	assert_str(StoryText.preview(SetFlagEffect.new())).is_equal("")
