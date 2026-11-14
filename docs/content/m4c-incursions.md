# M4c Incursions and failure states

Design for M4c: hostile forces come through the Ring and the player defends the base on the
plan, and the game can now be lost. It builds on the interface pass
(`interface-pass.md`: tokens, walking, camera feeds, alerts) and on the bible's
[Threats, invasions and failure states](../bible/game-design.md#threats-invasions-and-failure-states).

**Owner decisions this builds on (2026-11-13):** defence is commanded through squads, not
individuals; incursions come only through the gate; no morale system. The owner raised no
objection to: civilians act on their own, the clock drops to 1× on a breach with pausing
allowed, and losing the Control Room ends the game.

**Owner decisions on this document (2026-11-14):** people are only injured, never killed;
Confidence 0 and bankruptcy keep only warning, so Overrun is the one way to lose for now;
the Shutter is in, as an **upgrade that is researched and then built**, and the MOTH and
other defensive measures become upgrades of the same kind (section 6); all work stops
during an incursion, like a state of alert; the clock is held at 1× with no auto-pause;
sight follows power.

Everything else is a PO proposal; numbers are starting values in `balance_config`. One tick is one in-game minute, which is one second at 1×, so an
incursion of 60 to 120 ticks lasts one to two minutes of play, plus pauses.

**Out of M4c:** surface attacks, sabotage and plants, outpost raids, accidents, the Murmur,
the self-destruct, Ironman, and any authored story incursion. M4c ships three test
incursions.

---

## 1. The shape of an incursion

```
WARNING (30 ticks)  ->  BREACH  ->  intruders move to their objective  ->  ENDS
unscheduled incoming    arrive in    fight squads, breach doors,          killed, driven
wormhole, countdown     Gate Room    do the objective, then leave         off or gone home
```

1. **Trigger.** A faction whose standing is Hostile (−50 or lower) may launch one. Each day
   at 00:00 a hostile faction with an `IncursionDef` rolls against a chance that grows with
   how hostile it is (2% a day at −50, 10% at −100), never within 10 days of its last one.
   Demands the player refuses can also start one as a request penalty (a new effect).
2. **Warning.** The Ring opens from outside: "UNSCHEDULED INCOMING" with a countdown of 30
   ticks. The clock drops to 1×; the alarm state begins (section 7). This replaces the M4
   rule that a hostile incoming wormhole sends nothing through.
3. **Breach.** At zero the intruders appear in the Gate Room as one or more groups. Their
   wormhole stays open until they leave or are all down. The player cannot dial out or
   close it.
4. **End.** The incursion ends when no intruder is left on base. An after-action report
   lists what happened.

**The Shutter** (section 6) can stop a wave before it arrives, once it is built.

## 2. Who fights

**Soldiers** (the existing `role_soldier`) are hired like anyone else. A new room, the
**Security Post** (2 × 2, 4 slots, no research needed, $200k, 1 MW), turns its soldiers
into one **squad**. A squad exists while its post has at least one soldier; it is numbered
by post (Squad 1, Squad 2). Soldiers on an expedition are not in a squad.

**Intruder groups** come from the `IncursionDef`: a count of units, a unit type and an
objective.

| Unit | Health | Attack per tick | Notes |
| --- | --- | --- | --- |
| Soldier | 10 | 1 + skill ÷ 2 (1.5 to 3.5) | Down at 0 health |
| Raider (test intruder) | 8 | 2 | |
| Breacher (test intruder) | 12 | 2 | Opens sealed doors twice as fast |

**Combat** happens when a squad and a group are in the same room, or within 3 walking
cells of each other in a corridor. Each tick each side deals its summed attack, times a
seeded roll between 0.75 and 1.25, to the other side, spread from the front unit back. The
defender of a room (whoever was there first) takes 25% less. It is automatic: the player's
part is where squads stand, when they fall back and which doors are sealed.

A soldier at 0 health is **down**: out of the fight with a serious injury, treated by the
existing injury rules. **Nobody dies** (owner decision). A squad with everyone down is
out until someone recovers.

## 3. Moving

Both sides walk the same cell paths the staff tokens use, now computed in the simulation
(the path code moves out of the UI). Speed is 2 cells a tick; a lift or stairs takes 1 tick
per level.

**Squad orders** (commands, usable while paused):

- **Move to** a room or corridor cell. The squad walks there and holds.
- **Hold** where it is. This is the default.
- **Fall back** to its Security Post.

A squad fights whatever comes within reach; it never chases.

**Intruders** head for their objective by the shortest open path, not for the nearest
soldier (bible). They fight squads that are in reach and otherwise keep walking. When no
path is open, they breach the sealed door on the shortest path.

## 4. Blast doors

A **blast door** is built on a corridor cell from the Build palette ($50k, 2 hours, no
power). It is OPEN or SEALED; a click or a command toggles it, also while paused.

- A sealed door blocks everyone, staff and squads included.
- Intruders breach a sealed door in 15 ticks (Breachers in 8). A breached door is
  destroyed and must be rebuilt.
- The Gate Room's own doorway cannot be sealed; the Shutter is what closes the Ring.

Doors buy time and force a route. Sealing every route to the Control Room gives about
15 ticks per door to bring a squad round.

## 5. What intruders want

Each `IncursionDef` names one objective. When it is done, or when half the units are down,
the survivors walk back to the Ring and leave.

| Objective | They go to | On reaching it | Cost to the player |
| --- | --- | --- | --- |
| Sabotage | Power Plant | 10 ticks uncontested, then the room is **damaged** | The plant gives nothing until repaired |
| Theft | A Vault or Containment holding an artefact (else Gate Room holding) | 5 ticks, then they carry one artefact out | The artefact is lost if they reach the Ring; recovered if the carrier goes down |
| Assault | Control Room | They hold it | **Overrun** after 30 ticks held (section 8) |

**Damaged rooms.** A damaged room is off and does nothing. **Repair** costs 25% of the
room's price and takes a quarter of its build time, speeded by the Workshop as building is.

**Civilians.** On the warning, everyone who is not a soldier stops work and all research
and construction pause until the incursion ends. A civilian in a room intruders enter is
hit on a 1 in 4 roll (light injury; serious on a second hit). Tokens show them sheltering
in place; they do not need orders.

**What it costs politically.** After an incursion: Confidence −3 if anything was damaged or
stolen, −8 if a soldier went down and nothing was stopped, +3 if every intruder was stopped
with no loss.

## 6. Installations: the Shutter, the MOTH rack and defences

**Installations** are upgrades fitted to a room or a door. Each is unlocked by research,
then **built** from the room's panel (**Install…**) for money and time, like a small
construction site inside the room; the Workshop speeds it up as it does building. An
installation works while its room is on, can be removed (50% refund) and is lost if the
room is demolished. A damaged room's installations stop until it is repaired.

| Installation | Fitted to | Research | Install | What it does |
| --- | --- | --- | --- | --- |
| The Shutter | Gate Room | The Shutter, $600k, 4 days | $400k, 1 day | Closes the Ring (below) |
| MOTH rack | Gate Room | Survey drones, $200k, 2 days | $150k, 12 hours | Holds 2 MOTHs; each MOTH is built at the rack for $150k and 1 day |
| Sentry gun | Any room except corridors, one per room | Automated defence, $500k, 4 days | $250k, 1 day | Attacks intruders in its room: 3 a tick, health 15; destroyed at 0 and must be reinstalled |
| Door plating | A blast door | Automated defence | $100k, 6 hours | The door takes twice as long to breach |

More can be added as data later (for example gas vents, a second Shutter layer, a camera
battery that keeps sight when a room is off); none are in M4c.

**The Shutter.** Once installed, the Gate Room has **Close Shutter** and **Open Shutter**.

- Closed, nothing arrives and the player cannot dial or send anything through.
- Each wave it stops takes 100 MWh from the capacitors. If they hold less, the Shutter
  fails and the wave comes through.
- An `IncursionDef` may be marked `breaches_shutter`; the test Assault is. The warning says
  so ("They have a way through the Shutter").
- Closing it during the warning counts: the wave is stopped at zero.

**The MOTH becomes something the player builds.** Today the base starts with a rack of two
and a lost MOTH is reordered automatically. Now the player researches Survey drones (first
row of the tree, cheap), installs the rack and orders each MOTH; a lost one is not replaced
until the player orders another. The existing MOTH research (batteries, shielding) requires
Survey drones. Until then, a new world is looked at with the pole camera and the canister.
**Sending a team without probing is allowed but ill-advised (owner decision 2026-11-14).**
A Survey can go to a world that is only Locked: a **blind** expedition. The plan screen
warns and asks to confirm; every risk roll treats the threat as one step higher, and the
first check-in comes one interval late. Missions that need a known target still need a
probe or a survey. The Expeditions tab and the Infirmary unlock on the first lock. Old saves keep their MOTHs: migration grants the research and the
rack.

**Sentry guns** fight like a unit that never moves. They need the room on, so power is
also defence.

## 7. What the player sees

**Alarm state.** From the warning until the end: darkened ground, red rules, a red strip in
the top bar with the countdown or "INTRUDERS ON LEVEL 1", an alert that opens Base,
Security. The game does not auto-pause (the owner's standing preference); it drops to 1×.

**On the plan.** Squads are numbered square tags; intruder groups are red diamonds with a
unit count. Doors show open or sealed by shape. The objective room, once known, carries a
target mark.

**What can be seen.** Intruders are shown where they are while they are in a room that is
switched on, or in a corridor next to one, or in reach of a squad. Elsewhere a fading
marker shows where they were last seen. Power is therefore sight: switching rooms off to
feed the Shutter or the capacitors blinds the cameras there.

**Base, Security sub-tab.** Left: squads (strength, order, where) and doors (state,
toggle). Selecting a squad then a room issues Move to; buttons for Hold and Fall back.
The detail column shows the camera of the selected squad's room.

**Cameras.** Feeds show intruders and soldiers as figures, and a room where a fight is
happening flashes. A feed in a room that is off shows NO SIGNAL.

**After-action report.** A panel when it ends: who came, the objective, what was lost or
saved, who is injured, the Confidence change. It is also written to the Log.

## 8. Failure states

Three failures are tracked, each with a warning well before (bible); for now only the first ends the game.

| Failure | Trigger | Warnings | Ends the game |
| --- | --- | --- | --- |
| Overrun | Intruders hold the Control Room for 30 ticks in a row | A countdown in the alarm strip from the moment they enter; it resets if a squad contests the room | Yes |
| Shutdown | Confidence is 0 at seven daily settlements in a row | Committee message at 20 and at 10; a daily countdown alert from the first day at 0 | No (warns) |
| Bankruptcy | Funds are below zero at thirty daily settlements in a row | The existing 7-day red warning; a daily countdown alert from day 15 | No (warns) |

**Owner decision (2026-11-14):** only Overrun ends the game in M4c. Shutdown and Bankruptcy
stay as warnings: the counters, Committee messages and countdown alerts are built, and at
the end of the count the alert reads "The Committee would close the site" (or "The site
would be bankrupt") and nothing else happens. Turning them into real endings later is one
flag each in `balance_config`. The bible's other failures (Destruction, Exposure, Takeover,
Contagion) wait for their systems.

**When the game ends** the simulation stops for good: `GameState.outcome` goes from RUNNING
to FAILED with a cause, no command is accepted, and autosave stops (so the last autosave is
from before the end). The **game over screen** names the cause, shows the date and a few
figures (days survived, worlds locked, research done), and offers **Load last save**,
**Load…** and **Main menu**.

A setting, **Failure states** (on by default), turns Overrun off for free play and
testing.

## 9. Data and saves

- `IncursionDef` (resource): faction, groups (unit type, count), objective, warning ticks,
  `breaches_shutter`. `UnitDef`: health, attack, door breach ticks.
- `IncursionState` (saved): phase (NONE, WARNING, BREACH, RETREAT), def id, countdown,
  groups (units with health, cell, level, carried artefact), last-seen markers, per-faction
  last incursion day.
- `SecurityState` (saved): squads (post room, order, target, cell, level), unit health.
- `InstallationDef` (resource): host (room type or door), research, cost, time, effect.
- `BaseState`: doors (cell, level, state, plating); rooms gain `damaged` and a list of
  installations (def id, state SITE or BUILT, progress, health).
- `OutcomeState` (saved): RUNNING or FAILED, cause, tick; the two day counters.
- The save version goes up by one, with a migration that adds the empty sections.

All randomness uses a new seeded stream for incursions.

## 10. Owner decisions

Settled on 2026-11-14: injuries only; Shutdown and Bankruptcy only warn; the Shutter is in,
as a built upgrade, with the MOTH rack, sentry guns and door plating; all work stops during
an incursion; 1× with no auto-pause; sight follows power.

Also settled: a team may be sent without probing, at more risk (section 6).

## 11. Cards

Milestone "M4c Incursions and failure states". This document is M4c-01.

| Card | Title | Depends on |
| --- | --- | --- |
| M4c-02 | Contract: defs, state and save for incursions, security, doors, outcome | 01 |
| M4c-03 | Path finding in the simulation, with doors | 02 |
| M4c-04 | Blast doors: build, seal, open | 03 |
| M4c-05 | Security Post and squads | 03 |
| M4c-06 | Incursion trigger, warning and breach | 02 |
| M4c-07 | Intruder movement, objectives and retreat | 03, 06 |
| M4c-08 | Combat and door breaching | 05, 07 |
| M4c-09 | Alarm effects: work stops, civilians, damage and repair, Confidence | 07 |
| M4c-10 | The Shutter (an installation) | 06, 18 |
| M4c-11 | Alarm state and the plan: squads, intruders, doors, sight | 04, 08 |
| M4c-12 | Security sub-tab and squad orders | 11 |
| M4c-13 | Cameras show the fight; after-action report | 11 |
| M4c-14 | Failure rules and the end of the simulation | 02 |
| M4c-15 | Game over screen and the Failure states setting | 14 |
| M4c-16 | Test incursions and debug triggers | 08, 10 |
| M4c-17 | Flow tests, soak bot and playtest guide | all |
| M4c-18 | Installations: defs, state, install and remove | 02 |
| M4c-19 | Installations in the room panel | 18 |
| M4c-20 | The MOTH rack: researched, installed, MOTHs built to order | 18 |
| M4c-21 | Sentry guns and door plating | 08, 18 |
| M4c-22 | Send a team without probing (blind expeditions) | 20 |
