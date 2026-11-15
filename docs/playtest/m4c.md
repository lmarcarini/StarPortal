# Playtest guide: M4c, "Incursions and failure states"

M4c lets hostile forces come through the Ring. You defend the base on the plan with
**squads** from Security Posts, **blast doors** and researched **upgrades** (the Shutter,
the MOTH rack, sentry guns, door plating). The game can now be lost: if intruders hold the
Control Room for 30 ticks, the base is **Overrun**.

Everything you see is placeholder: plain panels, test text, pt_BR strings marked `[EN]`.
Judge the systems, not the words or the look. Plan on 45 to 60 minutes.

## What changed since M4b

- **Incursions.** A hostile faction may send a wave through the Ring (a daily chance that
  rises as its standing falls, with a cooldown). A **warning** countdown comes first, then
  the **breach**. The clock is held at 1× during the breach. You can still pause. All work
  stops while it lasts, like a state of alert.
- **Three test incursions:** `incursion_test_sabotage` (4 Raiders damage the Power Plant),
  `incursion_test_theft` (they take an artefact) and `incursion_test_assault` (Raiders and
  Breachers go for the Control Room and break through the Shutter).
- **Squads.** Build a **Security Post** and give it soldiers. Its squad is ordered from the
  Security sub-tab or on the plan: *Hold*, *Move to* a cell, or *Fall back* to the post.
  Squads fight intruders in reach. Soldiers who go down are injured, never killed.
- **Blast doors.** Build one on a corridor cell (not beside the Gate Room). Seal it and
  intruders must stop and breach it, which takes time. Squads can't pass a sealed door
  either.
- **Damage and repair.** A sabotaged room is off until you repair it from its room panel.
- **Upgrades** are researched and then built on a room or a door: the **Shutter** on the
  Gate Room (closed, it stops a wave unless the wave breaches it, and it costs charge), the
  **MOTH rack** (order MOTHs for $150k each, ready in a day), **sentry guns** (fight only in
  their own room, and only while the room is on) and **door plating** (doubles breach time).
- **Alarm.** A red strip with the countdown, intruder markers where cameras and squads can
  see (sight follows power), and an after-action report when the incursion ends. The report
  is also in the Log.
- **Failure states.** Overrun ends the game: the game over screen offers *Load last save*,
  *Load…* and *Main menu*. Confidence at 0 for 7 days and funds below zero for 30 days only
  **warn** for now. **Settings → Gameplay → Failure states** turns Overrun off.
- **Blind expeditions.** You can send a team to a world you haven't probed, at more risk.

## Setup and cheats

Open the debug overlay with F12. The cheat panel has:

| Button | What it does |
| --- | --- |
| Incursion (id) | Starts a test incursion, e.g. `incursion_test_sabotage` |
| Skip the warning | Jumps to the breach |
| Down all intruders | Ends the fight at once |
| Unlock all research | Lets you build every upgrade right away |
| Fill capacitors | Charges the banks (the Shutter needs charge) |
| Add staff (id = role, value = skill) | e.g. `role_soldier`, 5 |
| Set Confidence (value) | Try 0 for the Shutdown warning |
| Heal all | Clears injuries |
| Grant artefact (id) | Gives an artefact to steal |

## Ten things to try

1. Start `incursion_test_sabotage` with no defences. Watch the Raiders walk to the Power
   Plant, damage it, and leave. Read the after-action report. Then repair the plant.
2. Build a blast door on the way to the Plant and seal it before the breach. Watch them stop
   and work the door.
3. Build a Security Post, add three soldiers, and move the squad to the cell in front of the
   sealed door. Beat the wave there.
4. Grant an artefact and start `incursion_test_theft`. Let them escape with it once, then
   stop them on a second try and see it come back.
5. Save, then start `incursion_test_assault` and let them hold the Control Room. Read the
   game over screen and use *Load last save*.
6. Research and build the Shutter, fill the capacitors, close it, and start the sabotage
   wave. Then try the assault wave, which breaks through it.
7. Set Confidence to 0 and run eight days. Watch the warnings and the countdown. Play goes on.
8. Build the MOTH rack, order a MOTH, dial a world and launch it.
9. Put a sentry gun in the Power Plant and send a small wave. Then switch the plant off and
   try again.
10. Turn Failure states off in Settings and let the assault hold the Control Room.

## Known limits

- Placeholder UI and text everywhere; pt_BR is `[EN]` + English.
- Not done yet: removing a door from the UI, the door plating button, squad hotkeys 1–9 and
  dragging squads on the plan, the 3D Shutter visual, reopening a report from the Log, and
  a camera prop for sentry guns.
- Only the three test incursions exist. There are no authored story incursions.
- The soak bot defends at random (it builds a post, hires a soldier if one is on the list,
  builds one door, then seals, opens and orders squads), and it plays with Failure states
  off. Its year run is right at the 150 s budget (about 150 s on the CI machine).

## Questions for you

- **Pacing:** is a 30-tick warning enough time to react? Does 1× with pause feel right?
- **Doors:** do sealed doors buy enough time? Should squads be able to pass their own doors?
- **Overrun:** is 30 ticks in the Control Room too quick or too slow to lose the game?
- **Shutter:** is the energy cost fair? Should every wave beat it, or only the assault?
- **Squad control:** can you find and order your squads quickly on a gamepad?
- **Theft:** losing an artefact for good, is that too harsh?
- **Soak budget:** may we raise the soak budget above 150 s now that incursions run in it?

## What to report

What you tried, what you expected, what happened (with the in-game date), and anything that
felt slow, confusing or unfair. Screenshots of the alarm strip and the report help.
