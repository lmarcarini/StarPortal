## Tests for the artefact storage rooms (M4-25): the Vault (unlocked at the start) and
## Containment (locked until research) place, build and switch like other rooms; the validator
## pairs artefact slots with a known class.
## Bible: docs/content/m4-core-systems.md section 5 (Housing)
extends GdUnitTestSuite


func test_defs() -> void:
	var vault: RoomDef = Registry.get_def(&"room_artefact_vault") as RoomDef
	assert_int(vault.artefact_slots).is_equal(2)
	assert_str(String(vault.artefact_class)).is_equal("vault")
	var containment: RoomDef = Registry.get_def(&"room_containment") as RoomDef
	assert_int(containment.artefact_slots).is_equal(1)
	assert_str(String(containment.artefact_class)).is_equal("containment")
	assert_float(containment.power_draw_mw).is_equal(10.0)


func test_vault_unlocked_containment_not() -> void:
	var game: GameState = ConstructionFixture.state()
	assert_bool(UnlockRules.can_build_room(game, &"room_artefact_vault").is_ok).is_true()
	assert_bool(UnlockRules.can_build_room(game, &"room_containment").is_ok).is_false()


func test_vault_places_builds_and_switches() -> void:
	var game: GameState = ConstructionFixture.unlock_all(ConstructionFixture.grown())
	game.budget.funds_k = 100000
	var system := ConstructionSystem.new()
	for level: int in [1, 2]:
		for y: int in range(0, 20):
			for x: int in range(0, 40):
				var command := PlaceRoomCommand.create(
					&"room_artefact_vault", level, Vector2i(x, y)
				)
				if command.validate(game).is_ok:
					command.apply(game)
					var room: RoomState = game.base.rooms[-1]
					ConstructionFixture.advance(game, system, 400)
					assert_int(room.build_ticks_left).is_equal(0)
					var toggle := SwitchRoomCommand.create(room.id, false)
					assert_bool(toggle.validate(game).is_ok).is_true()
					toggle.apply(game)
					assert_bool(room.powered_on).is_false()
					return
	fail("no spot for a vault")


func test_validator_pairs_slots_and_class() -> void:
	var def := RoomDef.new()
	def.artefact_slots = 2
	assert_array(def.get_content_errors({})).contains(
		["needs both artefact slots and an artefact class, or neither"]
	)
	def.artefact_class = &"shelf"
	assert_array(def.get_content_errors({})).contains(
		["has artefact class 'shelf', not vault or containment"]
	)
	def.artefact_class = &"vault"
	assert_array(def.get_content_errors({})).is_empty()
