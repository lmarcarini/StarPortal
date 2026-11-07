# M3 Beyond the Ring

Design for the M3 cards: the core loop past the Ring, from a locked world to a returned team
and the first people out there. It is lean on purpose: the owner wants to play the whole loop
with placeholder art and iterate on it before M4's consequence systems.

Bible: [gate-and-address-spec.md#probing-the-unknown](../bible/gate-and-address-spec.md#probing-the-unknown),
[game-design.md](../bible/game-design.md) (Personnel, military and expeditions; Factions,
requests and politics; Research), [lore-and-arcs.md](../bible/lore-and-arcs.md) (Prologue,
Arc 1, the Kindred, Lore delivery). Builds on [presentation-and-systems.md](presentation-and-systems.md)
(section 10 lists what is superseded), [m15-puzzles.md](m15-puzzles.md),
[m26-staff-and-money.md](m26-staff-and-money.md) and the pending M2.7 daily rhythm
(`m27-daily-rhythm.md`, PR #207), which this document assumes.

Choices beyond the bible are PO proposals; numbers are starting values for playtesting. One
tick is one in-game minute; at 10× a day lasts 2.4 real minutes. Money in $k.

---

## 1. The loop in one page

| Step | The player chooses | Where |
| --- | --- | --- |
| 1. Find an address | Which document or console address to try | Archive, Address Book |
| 2. Dial and lock | When to spend the charge | Gate Room |
| 3. Look | Push the pole camera (free, once per lock), read the far console | Ring actions |
| 4. Probe | Canister or not; MOTH scans, recall, risk | Ring actions, MOTH scan screen |
| 5. Read | Threat, confidence, targets for a team | World Report (Archive, Worlds) |
| 6. Plan | Objective and four people (whom the base loses) | Expeditions tab (F7) |
| 7. Send | Dial again and send the ready team | Ring action **Send team** |
| 8. Check in | Each morning: continue or come home; field decisions; contact | Expeditions tab, conversation panel |
| 9. Return or rescue | After a missed check-in, dial and signal within 2 days | Gate Room |
| 10. Use it | Read (Codex unlocks), dial new addresses, research the lexicon, heal | Archive, Research, Base |

Each step adds to the world's record and moves the world through its states (section 3). One
story path runs through M3: STILLWATER's anchor leads to MOORING, where the Kindred live.

---

## 2. Probes

Three ways to look, cheapest first. All need the wormhole open and are Ring actions.

| Probe | Cost | Time | Gives |
| --- | --- | --- | --- |
| Pole camera (M1.6, unchanged) | Free | 5 min | Horizon record: one photo, air, temperature, radiation; story documents on a world's first push |
| Sample canister | $10k each, never runs out | 10 min | Biohazard (none, low, high) and a sample note |
| MOTH drone | One from the rack; replacement $150k, 1 day | Up to 20 min | Scans (below), threat estimate, scan targets |

**Sample canister.** A tethered canister is thrown through and reeled back after 10 minutes
with soil and water. It fills the **Biohazard** field, the one thing the pole camera's sampling
line cannot test. Closing the wormhole early loses it and its result.

**MOTH: a 2D scan screen in M3 (PO recommendation).** The Gate Room switches to a scan screen:
a still camcorder frame (2D, generated like the horizon photo), the battery and a list of scans,
picked one at a time. Each takes battery minutes and may lose the drone.

| Scan | Battery | Gives |
| --- | --- | --- |
| Look around | 5 min | Life and Structures at a glance; lists **targets** ("Iron object at the causeway's end"); threat confidence to fair |
| Close look (a target) | 4 min | A photo document of the target; marks it recoverable when it is an object; captures inscriptions |
| Sky | 2 min | A sky photo document |
| Ring | 4 min | The deeper console scan: 1 to 2 more addresses from the console's older log |
| Recall | 2 min | The drone flies back; needs 2 min of battery left |

With 20 minutes of battery, Look around, one Close look, Ring and Sky leave 3 to spare: a
second Close look means no recall, and the drone is lost when the battery runs out (its scans
are kept). Closing the wormhole with the MOTH out asks first and loses it. The clock stays at
1× (set by the lock), so a 4-minute scan takes 4 real seconds; the bible's slowed clock belongs
to the 3D feed.

**Losses.** Each scan has a seeded chance to lose the drone by the world's true threat: LOW 0%,
MED 5%, HIGH 20%, doubled for a Close look. A loss ends the run ("SIGNAL LOST"), keeps the
finished scans and raises threat confidence one step: a drone shot down is information. The rack
holds 2 MOTHs; a lost one is reordered automatically ($150k, 1 day), like the pole camera rig.

**The 3D feed later, with honest costs.** A flyable feed needs the SubViewport and shader,
mouse and gamepad flight, an autopilot, 3D scan targeting, a biome kit per procedural biome
(terrain and 10 to 20 Blender props) and a hand-built scene per story world. Estimate: about 4
cards for the feed on one test biome, 3 to 4 cards plus art for five biome kits, and 1 card per
story world (five so far): 12 to 14 cards and art the project does not have, against 2 cards
for the scan screen. Both use the same sim (battery, scans, targets, losses), so the 3D feed can
later replace only the view. Proposed as its own milestone after the loop iteration.

**World Report fields.** One report per world, in the Archive's Worlds record, filled by every
source; each field names its source and date.

| Field | Values | Filled by |
| --- | --- | --- |
| Atmosphere | none, thin, breathable, toxic | Pole camera |
| Temperature | °C | Pole camera |
| Radiation | normal, raised, high | Pole camera |
| Biohazard | unknown, none, low, high | Canister, team survey |
| Life | unknown, none, plants, animals, people | MOTH, team |
| Structures | unknown, none, ruins, worked stone, settlement | MOTH, team |
| Targets | named things a team can go to | MOTH Look around |
| Ring console | addresses read | Read far console, MOTH Ring |
| Threat | LOW, MED or HIGH, shown by confidence | Every source |

**Threat and confidence never lie.** The world has a true threat; the report shows it narrowed
by confidence: **none** (lock only) shows UNKNOWN; **poor** (horizon record) shows a two-step
range such as LOW–MED; **fair** (MOTH Look around, or a lost MOTH) and **good** (team survey)
show the true value, good adding the reasons. Confidence only goes up.

**The pole camera's place.** It stays the free first look. For the owner's later pole photos
generated on the spot, M3 adds a **world scene**: derived data (biome, sky, life, structures,
targets) that every picture reads. `HorizonPhotoRules` now draws from the world id alone; in M3
it and the MOTH frames read the scene, so what probes and teams discover (a causeway, a
settlement) shows in later photos. Authored worlds set their scene in data; procedural ones
derive it. A later generator, 2D or 3D, reads the same scene.

---

## 3. Worlds

| State | Reached by | Unlocks |
| --- | --- | --- |
| Unknown | (not stored) | Dial |
| Locked | First lock | Pole camera, console, canister, MOTH |
| Probed | First finished or lost MOTH run | Expeditions to it (Survey; Recover if a target is recoverable) |
| Surveyed | A team's Survey returns | Report confidence good; survey findings |
| Contacted | A conversation with its people ends | Contact again by Hail or expedition |

A world's state never goes down. The bible's later states (allied, outpost, hostile,
quarantined) wait for M4.

**Procedural worlds** (about 300) get derived facts, never saved: biome (barren, ice, desert,
steppe, forest), life, structures, true threat (guarded worlds HIGH, about 15% of the rest MED,
others LOW) and 0 to 2 targets, drawn from a stable hash of the world id (as `ConsoleLog`
does), so world positions and addresses do not change. No procedural world has people in M3.
Their report texts come from short templates per biome; a survey of one with ruins may find
an address (30%).

**Authored worlds.** The four M1.5 worlds gain scenes, threats and MOTH texts: SILL and LINTEL
LOW, airless; MILESTONE MED (cold, the bronze pegs as a target); STILLWATER LOW, breathable,
with two targets: the bare footprints and the **iron object** at the causeway's end.

**One new inhabited world: MOORING (PO proposal; name delegated).** A Kindred village by a
cold sea. Its address is cut into the iron object on STILLWATER, a Kindred boat anchor: Haskett
sang "Drop the hook where the water lies still, and stay." The Kindred fish STILLWATER's lake
and mark the anchor with the way home. Recovering it gives puzzle 5; MOORING is named after it,
by the convention that a world takes the name of its address's source.

**Content plan.** Enough for the loop to feel real: 5 authored worlds on one path, plus the 12
procedural worlds within reach of one bank and those the consoles list.

- STILLWATER: MOTH Look around shows the footprints and the iron object.
- A team **recovers** the anchor: an object document with its marks.
- Puzzle 5: read the anchor (small, one trick).
- Dial MOORING. MOTH shows fields and people.
- **Hail** (conversation 1), then a **Contact** expedition (conversation 2).
- Lexicon research, then hail again (conversation 3).

Puzzle 5 and MOORING's position need their own design card, as M1.5's puzzles had: the address
must be dialable within one bank and, per m15's constraint, STILLWATER's origin glyph must not
be among MOORING's seven.

---

## 4. Expeditions

**People.** M3 adds two roles, both drawn on the candidate list:

| Role | Pipeline | Arrives after | Does |
| --- | --- | --- | --- |
| Soldier | Military (with engineers) | 3 days | Leads or guards a team; hazard and threat checks |
| Medic | Academia (with scientists) | 5 days | Team specialist: turns a serious injury into a light one; staffs the Infirmary |

The rolling list (M2.7) keeps at least one scientist and one engineer; from the unlock, one
arrival in four is a soldier or medic. **The Directorate lends two soldiers** at the unlock,
Maj. Ruth Adair and Sgt Owen Hale (skill 3). They arrive like hires, on normal salaries, and
need two free beds ("Two beds needed for the Threshold team. Build Quarters."). Traits and
stress stay out of M3.

**Unlock.** The Expeditions tab (F7) and the Infirmary appear when the first world is Probed.

**The team.** Four slots: **leader** (a soldier), **scientist**, **soldier**, **specialist**
(medic, engineer, analyst or scientist). People on an expedition leave their rooms; the base
runs at its floor rates without them, which is the cost of sending a team. One expedition at a
time in M3.

**Objectives.**

| Objective | Needs | Days | Brings back |
| --- | --- | --- | --- |
| Survey | World Probed | 2 | State Surveyed; a survey report; biohazard; sometimes an address |
| Recover | A recoverable target | 1 | The object as a document (with images), and what it unlocks |
| Contact | People seen on the world | 2 | A conversation at the check-in; transcript; standing; state Contacted |

**Timeline.** The player readies a plan, dials the world and presses **Send team**; the team
walks through in 10 minutes, then the wormhole may close. Check-ins come at 09:00 each morning;
the team returns at departure time plus the objective's days. Check-ins and the return are
**incoming wormholes from the team**, identified at once and costing CAIRN no energy; if the
player's own wormhole is open, the team waits for it to close. At a check-in the player answers
**Continue** or **Come home** (within the hour).

**Risk model.** One field event per day, drawn from a pool by objective, biome and threat. Each
names a role; the team's best person in that role rolls:

> Success = 50% + 15% × (skill − difficulty), between 10% and 95%

Difficulty is the event's own (1 to 4), +1 on MED worlds, +2 on HIGH, +1 if airless or below
−20 °C. Success gives a finding or nothing bad; failure gives the event's setback: a lost half
day, a light injury, a serious one (difficulty 4 only) or, on the worst events, a **missed
check-in**. The plan shows the risk from the report's threat and confidence. Some events carry a **field decision** (Go / Hold /
Leave), which auto-pauses the check-in that brings it.

**Injuries; the Infirmary unlocks here (PO proposal).** Light 2 days, serious 8; the injured
cannot work or travel. Recovery is 2× faster with an Infirmary on, 3× with a medic in it. It
joins the Base build palette at the unlock, not research: $300k, 6 hours, 5 MW, upkeep $40k, 2
medic slots. No one dies in the field in M3, except in a lost team.

**Missed check-in and rescue.** "T-1 missed its 09:00 check-in." A 2-day **rescue window**
opens on the top bar's alerts. The player dials the world and uses the Ring action **Signal
T-1**: the team reaches the Ring in 15 minutes and comes through; closing early fails. If the
window runs out, the team is **lost**: all four leave the roster, Confidence −10, a Log line.
Rescue teams wait for M4.

**What comes back.** Documents (survey reports, objects, oral histories, transcripts),
addresses, findings, standing and Confidence. New causes, applied at once (M2.7 rules):

| Cause | Change |
| --- | --- |
| New world surveyed (team) | +3 |
| First contact with a people | +5 |
| Team lost | −10 |

M2.6's pole-camera "New world surveyed" (+2) becomes **Horizon record taken**. Artefact states
and fates wait for M4: a recovered object is a document, and some unlock a research project.

---

## 5. Contact

**One people, three conversations.** The Kindred only, with the format and timing of
presentation-and-systems.md section 6 (live at 1×, right-third panel, built transcripts).

| # | Channel | Needs | Gives |
| --- | --- | --- | --- |
| K1 First hail | **Hail** at an open wormhole | People seen on MOORING | The worked example (section 6 there); standing ±5 to 10 |
| K2 The hearth | Contact expedition, at its check-in | A Contact plan | The leader speaks (a check on the leader's skill); an oral history document, "The taking"; standing; state Contacted |
| K3 Return hail | **Hail** | Kindred lexicon I researched | The kinship choice opens; the dark-moon timing; one procedural address the keepers avoid |

**On an expedition** the check-in wormhole is open, so the player speaks through the leader
live, as with a hail: the check-in auto-pauses, then the conversation runs at 1×. Postures wait
for M4.

**Partial translation with word tokens,** as designed: Kindred speech is mostly readable; words
taken from the Ossar are in script. About 20 words over levels 1 to 3; pencilled guesses stay.

**Linguistics: research, not a lab (PO proposal).** Scientists stay unsplit until M4, so the
Alien category gains **Kindred lexicon I** (needs 1 Kindred transcript; level 2) and **II**
(needs 2; level 3). Each reveals words and marks transcripts newly readable.

**Standing.** One number for the Kindred, −100 to +100, starting at 0, changed by conversation
effects and read by their conditions; shown in Command's side panel and on the Kindred Codex
entry. No thresholds, requests, letters or ripples (M4).

---

## 6. Codex

The Codex is the Archive's third section: Documents, Worlds, **Codex**, Log. Entries of 150 words
or fewer, unlocked or extended by reading documents and transcripts.

| Category | M3 entries |
| --- | --- |
| People | Ellery, Pell, Haskett, Dunmore, the hearth-keeper |
| Peoples | The Kindred; "the keepers" (named only as heard) |
| Places | Gallow, the Buried Ring (Earth's Ring) |
| Words | One entry per revealed Kindred word, with every occurrence |

About 12 entries. Worlds stay in the Worlds section, not the Codex. One entry is **contested**:
the Buried Ring (the Directorate says never used before 1961; the Kindred say their ancestors
were taken through it), shown as two versions stacked, each linked to its source. **Glyph
names** wait for the Anteri inscriptions (later).

---

## 7. UI

**Tabs.** F1 Gate Room, F2 Archive, F3 Base, F4 Research, F5 Personnel, F6 Command (M2.7),
**F7 Expeditions** (from the unlock). Q and E cycle them. The MOTH scan screen and the
conversation panel are modes, not tabs. Nothing needs Esc to escape: every mode has a visible
**Recall** or **Close**, B on the gamepad.

**Expeditions tab.** Plan sheet on the left, timeline in the middle, latest check-in on the
right. Rows are 32 px; the sheet fits without scrolling.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+-------------------------+----------------------------------+-----------------+
| PLAN  T-1               | T-1 STILLWATER  Recover          | CHECK-IN 2 Jan  |
| World  [STILLWATER   v] | 1 Jan 14:00      2 Jan 14:00     | 09:00 1 injured |
| Threat LOW (fair)       | |=|---------o---------|          | "Anchor lifted  |
| Objective               |  out      check-in    home       |  from the mud.  |
|  ( ) Survey             |           2 Jan 09:00            |  Marks on the   |
|  (o) Recover: iron obj. |                                  |  shank. Hale    |
|  ( ) Contact: no people | [!] Field decision: the shank is |  sprained a     |
| Team                    |     stuck under the causeway.    |  knee."         |
|  Leader  Maj. Adair  3  |     [Dig it out] [Leave it]      | Injured: Hale   |
|  Science Dr Okafor   3  |                                  |  (light, 2 d)   |
|  Soldier Sgt Hale    3  |                                  | [Continue]      |
|  Special Medic Lund  2  |                                  | [Come home]     |
| Risk LOW   1 day        |                                  | [Open report]   |
| [Ready team]            |                                  |                 |
+-------------------------+----------------------------------+-----------------+
```

Picking a team slot opens the roster filtered by role, each with skill and what the base loses
("Research 150% → 100%"). **Ready team** greys with the reason (world not Probed, slot empty,
person injured). A ready plan adds **Send team** to that world's Ring actions.

**World Report (Archive, Worlds).**

```
+---------------------------+--------------------------------------------------+
| [DOCUMENTS][WORLDS][CODEX][LOG]                 SEARCH [____________]        |
+---------------------------+--------------------------------------------------+
| > STILLWATER   PROBED     | STILLWATER                      PROBED           |
|   MILESTONE    LOCKED     | Address [35][10][24][19][29][8][15][2]  [Load]   |
|   R-0147       LOCKED     | Threat LOW   confidence FAIR (MOTH 2 Jan)        |
|   SILL         PROBED     | Atmosphere breathable  11 °C  radiation normal   |
|                           | Biohazard  none (canister 2 Jan)                 |
|                           | Life  people?  footprints     (MOTH)             |
|                           | Structures  worked stone: causeway               |
|                           | Targets  iron object (recoverable), footprints   |
|                           | Photos [horizon] [sky] [iron object]             |
|                           | Linked  Field Note 31, dossier, MOTH report      |
|                           | [Plan expedition]                                |
+---------------------------+--------------------------------------------------+
```

**MOTH scan screen** (over the Gate Room; the top bar stays).

```
+---------------+----------------------------------------------+---------------+
| SCANS         |  REC 00:07   STILLWATER                      | BATTERY       |
| [Look around] |                                              | [######----]  |
|  5 min  done  |      (generated still, scanlines)            |  11 min left  |
| [Close look]  |                                              |               |
|  iron object  |                                              | Recall needs  |
|  4 min        |      [ SCANNING: iron object ]               |  2 min        |
| [Sky]  2 min  |                                              |               |
| [Ring] 4 min  |                                              | [RECALL]      |
+---------------+----------------------------------------------+---------------+
```

**Conversation panel.** The right third, over any tab (presentation-and-systems.md section 6).

```
+--------------------------------------------+---------------------------------+
| (current tab stays usable)                 | MOORING  hearth-keeper  1x      |
|                                            | Wormhole 41:10   Kindred +5     |
|                                            |---------------------------------|
|                                            | "You came through the old ring. |
|                                            |  Are you people of the ▚▞▟?"    |
|                                            | "The ▙▚▞ come at the ▞▟▙. Close |
|                                            |  your door before then."        |
|                                            |---------------------------------|
|                                            | > We come in peace. Who are the |
|                                            |   ▙▚▞?                          |
|                                            |   Close the wormhole.           |
+--------------------------------------------+---------------------------------+
```

**Gamepad.** Shoulders reach every tab. Expeditions: D-pad moves through the sheet; A opens a
slot's roster or picks an option; Y readies the team; the field decision and check-in buttons
take focus when they appear. MOTH: D-pad picks a scan, A runs it, B recalls (with confirm when
the battery is too low to return). Conversation: D-pad picks a choice, A says it; X on a word
in script opens its pencil guess. Worlds: A on a world opens its record; **Plan expedition**
opens F7 with that world chosen.

---

## 8. Card plan

Split in two. **Playtest points:** optional after M3-07 (probing); **first real playtest after
M3-11**: dial, probe, plan, check in, return or rescue, on the M1.5 worlds and procedural ones;
contact joins at the end of M3b.

**M3a: Probes and worlds**

| Card | Title | Needs |
| --- | --- | --- |
| M3-01 | This design | |
| M3-02 | Design: puzzle 5 (the anchor), MOORING, the Kindred conversations and lexicon | 01 |
| M3-03 | World facts and states: Probed, Surveyed, Contacted; derived facts for procedural worlds; authored fields; the world scene; save v15 | 01 |
| M3-04 | Archive Worlds section and the World Report (fields, threat by confidence, sources) | 03 |
| M3-05 | Probes sim: canister, MOTH (battery, scans, targets, losses, rack and reorder) | 03 |
| M3-06 | MOTH scan screen and generated frames; the horizon photo reads the world scene | 05 |
| M3-07 | Content: World Report texts and templates; MOTH texts for the five authored worlds | 02, 04 |

**M3b: Teams and contact**

| Card | Title | Needs |
| --- | --- | --- |
| M3-08 | Soldiers and medics, the lent soldiers, injuries and recovery, the Infirmary | 03 |
| M3-09 | Expedition sim: plans, Send team, check-ins as incoming, return, missed check-in, Signal, lost team | 08 |
| M3-10 | Field events: checks, setbacks, field decisions, findings, with the event pool's texts (about 15) | 09 |
| M3-11 | Expeditions tab (F7) | 09 |
| M3-12 | Contact: conversations, the panel, Hail, the check-in channel, transcripts, standing | 09 |
| M3-13 | Partial translation: lexicon, word tokens, guesses, lexicon research | 12 |
| M3-14 | Archive Codex section, contested entries | 04 |
| M3-15 | Content: the anchor, puzzle 5, MOORING, K1 to K3, words, Codex entries | 02, 13, 14 |
| M3-16 | Playtest guide M3 | all |

M3-02 runs beside 03 to 06; the owner approves it before 07 and 15. Cards 10 to 12 can run in
parallel once 09 lands. After M3: iterate the loop, then decide on the 3D feed.

---

## 9. Saves and open questions

**Saves: clean break, v15** (after M2.7's v14). New: world states, report fields and sources,
threat confidence, the MOTH rack, probes in flight, new roles and injuries, the expedition (plan,
team, timeline, seeded generator, rescue window), the open conversation, transcripts as paths,
revealed words and guesses, Codex entries and Kindred standing. Older saves get the "earlier
build" message.

**Decided as PO proposals** (unless the owner objects): everything marked so above, notably
threat as a true range narrowed by confidence, MOORING and the anchor, two lent soldiers, one
expedition at a time, 09:00 check-ins as incoming wormholes, no field deaths, lexicon research
instead of a lab, no glyph names, Expeditions on F7 and save v15.

**Open questions for the owner.**

1. **The MOTH.** A 2D scan screen in M3 and the real-time 3D feed as its own milestone after the
   loop iteration (about 12 to 14 cards plus art)? PO proposal: yes.
2. **Rescue.** Dial and **Signal** the team within 2 days, rather than sending a second team?
   PO proposal: yes for M3; rescue teams with M4.
3. **Infirmary.** Built from the Base palette when Expeditions unlock, rather than researched?
   PO proposal: yes, in line with "constructions in the Base tab".

---

## 10. Superseded in presentation-and-systems.md

For a later card to mark in that file; nothing is changed here.

- **Keys:** Expeditions F4 and Command F5 become F7 and F6; Research is its own tab (F4), not
  inside the Base.
- **Drone feed (section 1):** the 3D 320 × 240 feed and its slowed clock are not in M3; the MOTH
  is the scan screen of section 2 here.
- **Expeditions sketch:** loadout and posture wait for M4; the plan sheet replaces them.
- **Contact:** the linguistics lab becomes lexicon research in M3; letters at standing changes
  move to M4.
- **Confidence:** "New world surveyed" (pole camera) is renamed "Horizon record taken".
