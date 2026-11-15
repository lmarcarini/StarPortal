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
| 7. Send | Send the team through the probing lock, or a later one | Ring action **Send team** |
| 8. Check in | Nothing to answer: read each check-in (every 24 h); recall the team if wanted | Message, Log, Expeditions tab |
| 9. Return or rescue | After a missed check-in, charge, dial and signal within 3 days | Rescue alert, Gate Room |
| 10. Use it | Read (Codex unlocks), dial new addresses, research the lexicon, heal | Archive, Research, Base |

Each step adds to the world's record and moves the world through its states (section 3). One
story path runs through M3: STILLWATER's anchor leads to MOORING, where the Kindred live. The
**Prologue ends** when the first team comes home: a message and Log line, "Prologue complete:
the first Threshold team is home."

**Loop timing.** One 400 MWh bank charging at 20 MW (the M2.6 opening), a 366.6 MWh world
such as STILLWATER. At 1× an in-game minute is a real second; a lock drops the clock to 1× (since M4.7: slow reasons, event-time.md).

| Stretch | In game | At 1× | At 10× |
| --- | --- | --- | --- |
| Charge the bank from empty to full | 20 h | 20 min | 2 min |
| At the open wormhole: pole camera 5, canister 10, MOTH 17, then Send team (instant) | 32 min | 32 s | 32 s (held at 1×) |
| Recover in the field (1 day; the return is its only check-in) | 24 h | 24 min | 2.4 min |
| Survey in the field (2 days; a check-in at 24 h, the return at 48 h) | 48 h | 48 min | 4.8 min |
| **Whole loop from an empty bank, Recover** | **44.5 h** | **about 45 min** | **about 5 min** |
| **Whole loop from an empty bank, Survey** | **68.5 h** | **about 69 min** | **about 7 min** |
| Rescue window | 72 h | 72 min | 7.2 min |

**Lock energy.** A dial needs the full lock energy in the bank; the open wormhole then drains
20 MWh an hour from what is left, plus live charging. A bank holding exactly the lock energy
(366.6 MWh, 18.3 h from empty) is empty after the lock, so the wormhole closes almost at once
unless charging is at least 20 MW. That is why the table charges to full: the 33.4 MWh left
holds the wormhole for 100 minutes even with no charging, past the 60-minute limit.

No other wait sits in the loop: the lent soldiers are there at the unlock and the team goes
through the lock it was probed on. A rescue needs a fresh lock plus 15 minutes of drain
(371.6 MWh). Charge rates move in 5 MW steps, so from an empty bank it needs **10 MW** or more
(37 h); 5 MW takes 74 h, past the window.

---

## 2. Probes

Three ways to look, cheapest first. All need the wormhole open and are Ring actions.

| Probe | Cost | Time | Gives |
| --- | --- | --- | --- |
| Pole camera (M1.6, unchanged) | Free | 5 min | Horizon record: one photo, air, temperature, radiation; story documents on a world's first push |
| Sample canister | $10k each, never runs out | 10 min | Biohazard (none, low, high) and a sample note |
| MOTH drone | One from the rack; replacement $150k, 1 day (since M4c: researched, rack installed, each MOTH ordered — m4c-incursions.md section 6) | Up to 20 min | Scans (below), threat estimate, scan targets |

**Sample canister.** A tethered canister is thrown through and reeled back after 10 minutes
with soil and water. It fills the **Biohazard** field, the one thing the pole camera's sampling
line cannot test. Closing the wormhole early loses it and its result.

**MOTH: a 2D scan screen in M3 (PO recommendation).** The Gate Room switches to a scan screen:
a still camcorder frame (2D, generated like the horizon photo), the battery and a list of scans,
picked one at a time. Each takes battery minutes and may lose the drone.

| Scan | Battery | Gives |
| --- | --- | --- |
| Look around | 5 min | Life and Structures at a glance; lists **targets** ("Iron object at the causeway's end"); threat confidence to fair |
| Close look (a target) | 4 min | A photo document of the target; marks it recoverable when it is an object; copies any marks or inscription into the Archive |
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
holds 2 MOTHs; a lost one is reordered automatically ($150k, 1 day).

**The 3D feed later, with honest costs.** It needs the SubViewport and shader, flight on mouse
and gamepad, an autopilot, 3D scan targeting, a biome kit per procedural biome (terrain and 10
to 20 Blender props) and a scene per story world: about 4 cards for the feed on one test biome,
3 to 4 plus art for five biome kits, and 1 per story world (five so far). That is 12 to 14 cards
and art the project lacks, against 2 for the scan screen. Both share the sim, so the 3D feed
later replaces only the view. Proposed as its own milestone after the loop iteration.

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
generated on the spot, M3 adds a **world scene** (biome, sky, life, structures, targets) that
every picture reads: `HorizonPhotoRules` and the MOTH frames read it instead of the bare world
id, so what probes and teams discover shows in later photos. Authored worlds set it in data;
procedural ones derive it. A later generator, 2D or 3D, reads the same scene.

---

## 3. Worlds

| State | Reached by | Unlocks |
| --- | --- | --- |
| Unknown | (not stored) | Dial |
| Locked | First lock | Pole camera, console, canister, MOTH |
| Probed | First finished or lost MOTH run | Expeditions to it (Survey; Recover if a target is recoverable) |
| Surveyed | A team's Survey returns | Report confidence good; survey findings |
| Contacted | The first conversation with its people ends (K1 or K2, whichever comes first) | Contact again by Hail or expedition |

A world's state never goes down. The bible's later states (allied, outpost, hostile,
quarantined) wait for M4.

**Procedural worlds** (about 300) get derived facts, never saved: biome (barren, ice, desert,
steppe, forest), life, structures, true threat (guarded HIGH, about 15% of the rest MED, others
LOW) and 0 to 2 targets, from a stable hash of the world id (as `ConsoleLog`), so positions and
addresses do not change. None has people in M3. Report texts come from biome templates; a
survey of ruins may find an address (30%).

**Authored worlds.** The four M1.5 worlds gain scenes, threats and MOTH texts: SILL and LINTEL
LOW, airless; MILESTONE MED (cold, the bronze pegs as a target); STILLWATER LOW, breathable,
with two targets: the bare footprints and the **iron object** at the causeway's end.

**One new inhabited world: MOORING (PO proposal; name delegated).** A Kindred village by a
cold sea. Its address is cut into the iron object on STILLWATER, a Kindred boat anchor: Haskett
sang "Drop the hook where the water lies still, and stay." The Kindred fish STILLWATER's lake
and mark the anchor with the way home. A MOTH **Close look** at it copies its marks into the
Archive (puzzle 5), so the drone alone can reach MOORING; a **Recover** brings the anchor
itself, an object document with its own Codex entry. MOORING is named after it, by the
convention that a world takes the name of its address's source.

**Content plan.** Enough for the loop to feel real: 5 authored worlds on one path, plus the 12
procedural worlds within reach of one bank and those the consoles list.

- STILLWATER: MOTH Look around shows the footprints and the iron object; a Close look copies
  the anchor's marks.
- Puzzle 5: read the marks (small, one trick). A team may also **recover** the anchor.
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
| Soldier | Military (with engineers) | 3 days | Guards a team; hazard and threat checks |
| Medic | Academia (with scientists) | 5 days | Team specialist: turns a serious injury into a light one; staffs the Infirmary |

The rolling list (M2.7) keeps at least one scientist and one engineer; from the unlock, one
arrival in four is a soldier or medic. Traits and stress stay out of M3.

**Lent soldiers.** When Expeditions unlock, the Directorate lends Maj. Ruth Adair and Sgt Owen
Hale (soldiers, skill 3). They are available at once, take **no beds** (billeted off-base) and
draw normal salaries. If a lent soldier is lost, the Directorate lends a replacement (same
rules) 7 days later, with a Log line, so a lost team never leaves the player without soldiers.

**Unlock.** The Expeditions tab (F7) and the Infirmary appear when the first world is Probed.

**The team.** Four slots: **leader** (anyone; the player chooses, and the leader's skill is used
for contact checks), **scientist**, **soldier**, **specialist** (medic, engineer, analyst or
scientist). One expedition at a time in M3. People keep their room assignments while away: the
slot shows "Away (T-1)" and the room runs on whoever is left, at its floor rate if no one is.
On return they go back to work at once, unless injured.

**Objectives.**

| Objective | Needs | Days | Brings back |
| --- | --- | --- | --- |
| Survey | World Probed | 2 | State Surveyed; a survey report; biohazard; sometimes an address |
| Recover | A recoverable target | 1 | The object as a document (with images) and its Codex entry |
| Contact | People seen on the world | 2 | A conversation on arrival; transcript; standing; an oral history |

A Recover that fails, or a team recalled or lost before it, leaves the target where it was:
another Recover can try again.

**Departure.** With a plan ready, **Send team** appears among the Ring actions of a lock on that
world: the lock it was probed on, if it is still open, or any later one. Transit is instant
once sent, so a team is never cut off on the way; the wormhole may close right after. As a
margin, Send team is refused unless the wormhole could stay open 10 more minutes, both on its
charge (stored plus live charging against the drain) and on its 60-minute limit, with the
reason shown: "Not enough open time to send a team (10 minutes needed)."

**Check-ins are automatic.** A team checks in **every 24 hours from departure** (+24 h, +48 h,
...), and **the return is its final check-in**, at departure plus the objective's days. So a
Recover (1 day) has only its return; a Survey or Contact (2 days) has one check-in, then the
return. The team dials home: a Log line and a non-blocking message ("T-1 checked in from
STILLWATER: one light injury."). No pause, no speed change, no answer, no energy from CAIRN; if
the player's wormhole is open, the check-in comes when it closes. **Recall team** (Expeditions
tab) turns the next due check-in into the return.

**Risk model.** One field event per field day, drawn from a pool by objective, biome and threat.
It resolves at the check-in that ends its day (for the last day, the return), which reports it.
Each names a role; the team's best person in that role rolls:

> Success = 50% + 15% × (skill − difficulty), between 10% and 95%

Difficulty is the event's own (1 to 4), +1 on MED worlds, +2 on HIGH, +1 if airless or below
−20 °C. Success gives a finding or nothing bad; failure gives the event's setback: a wasted day
(no finding), a light injury, a serious one (difficulty 4 only) or, on the worst events, a **missed
check-in**: the check-in it resolves at does not come (if that is the return, the team does not
come home). Field events (card 11) only set this outcome; check-ins and rescue (card 10) act on
it. The plan shows the risk from the report's threat and confidence. Field decisions
wait until after the loop iteration, since check-ins ask nothing.

**Injuries; the Infirmary unlocks here (PO proposal).** Light 2 days, serious 8. A person hurt in
the field stays with the team (serious counts as skill 1 in checks) and returns with it, then is
off work: in an Infirmary that is on, if it has room (4 patients), recovery is 2× faster, 3×
with a medic in it; otherwise they rest at normal speed. Healed, they return to their rooms.
The Infirmary joins the Base build palette at the unlock, not research: $300k, 6 hours, 5 MW, upkeep $40k per 30 days, 2 medic slots. No one dies in the
field in M3 except through a missed check-in: in a rescue, or in a lost team.

**Missed check-in and rescue.** A missed check-in is a due check-in, or the return, that does
not come; a team that comes home before any check-in fell due never opens a rescue. When one is
missed, the game **pauses**, the speed
is set to 1× for when it resumes (since M4.7 an `awaiting_answer` slow reason until the
Signal: see event-time.md section 2), and a rescue alert opens with a **3-day** countdown (it stays
on the top bar's alert stack). The rescue is a normal dial of the world at its normal lock
energy, then the Ring action **Signal T-1**: the team reaches the Ring in 15 minutes and comes
through; closing early fails, and the player can try again within the window.

**A rescue is not a sure thing (owner, 2026-11-07).** Whether everyone comes back depends on
what is on the world. When the team reaches the Ring after a Signal, each member rolls to have
survived (seeded):

> Survival = 95% (LOW true threat), 85% (MED) or 70% (HIGH); −10% if airless or below −20 °C;
> −15% for a member seriously injured; −5% per full day since the missed check-in; +5% for
> each soldier on the team who survived, rolled first (at most +10%). Between 10% and 99%.

Those who survived come through as above; the rest are **deceased**: they leave the roster, a
Log line names each ("Sgt Owen Hale (T-1) did not survive on STILLWATER."), Confidence −3 each,
and a lent soldier is replaced as for a lost one. If nobody survived, the Signal gets no answer
after its 15 minutes: "No answer from T-1." The team is lost (below) and the window closes.
The rescue alert says plainly that the outcome is not certain and that waiting lowers the odds;
it shows no percentages, only the world's threat as the report knows it.

The alert also forecasts the charge: the lock energy plus 15 minutes of drain, against the
stored charge and the current charge rate.

- **On time:** "Charge for the rescue dial: 371.6 MWh, ready in 19 h. Window: 72 h."
- **Too slow:** "At the current charge rate the bank will not be ready before the window
  closes," and a **Charge at maximum** button that sets every bank to its highest rate the
  supply allows (lowering nothing else). If even that is not enough: "Not enough even at
  maximum. Switch rooms off in the Base."

If the window runs out, the team is **lost**: all four leave the roster, Confidence −10, a Log
line. Rescue teams wait for M4.

**What comes back.** Documents (survey reports, objects, oral histories, transcripts),
addresses, findings, standing and Confidence. New causes, applied at once (M2.7 rules):

| Cause | Change |
| --- | --- |
| New world surveyed (team) | +3 |
| First contact with a people (once per people, at the first conversation) | +5 |
| Team lost | −10 |
| Member deceased in a rescue | −3 each |

Artefact states and fates wait for M4: a recovered object is a document, and some unlock a
research project.

---

## 5. Contact

**One people, three conversations.** The Kindred only, with the format and timing of
presentation-and-systems.md section 6 (live at 1×, right-third panel, built transcripts).

| # | Channel | Needs | Gives |
| --- | --- | --- | --- |
| K1 First hail | **Hail** at an open wormhole | People seen on MOORING | The worked example (section 6 there); standing ±5 to 10 |
| K2 The hearth | Contact expedition, on arrival | A Contact plan | The leader speaks (a check on the leader's skill); an oral history document, "The taking", on return; standing |
| K3 Return hail | **Hail** | Kindred lexicon I researched | The kinship choice opens; the dark-moon timing; one procedural address the keepers avoid |

**On an expedition** the hearth-keeper meets the team at the far Ring as it arrives, while the
player's wormhole is still open: the player speaks through the leader live, at 1×, as with a
hail. The team then stays its two days. Postures wait for M4. Either K1 or K2, whichever
comes first, makes MOORING Contacted and earns First contact.

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
were taken through it), shown as two versions side by side, as the bible asks, each linked to
its source; at 1280 × 720 each column is about 300 px. **Glyph
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
| PLAN  T-1               | T-1 STILLWATER  Survey           | CHECK-IN 2 Jan  |
| World  [STILLWATER   v] | 1 Jan 14:00      3 Jan 14:00     | 14:00 1 injured |
| Threat LOW (fair)       | |=|---------o---------|          | "Walked the     |
| Objective               |  out      check-in    return     |  causeway to    |
|  (o) Survey             |           2 Jan 14:00            |  the island.    |
|  ( ) Recover: iron obj. |                                  |  Hale sprained  |
|  ( ) Contact: no people | LOG                              |  a knee."       |
| Team                    | 1 Jan 14:00 Through to STILLW.   |                 |
|  Leader  Maj. Adair  3  | 2 Jan 14:00 Check-in, 1 injured  | Injured: Hale   |
|  Science Dr Okafor   3  |                                  |  (light, 2 d)   |
|  Soldier Sgt Hale    3  |                                  |                 |
|  Special Medic Lund  2  |                                  | [Open report]   |
| Risk LOW   2 days       |                                  |                 |
| [Ready team]            | [Recall team]                    |                 |
+-------------------------+----------------------------------+-----------------+
```

Picking a team slot opens the roster filtered by role, each with skill and what the base loses
("Research 150% → 100%"). **Ready team** greys with the reason (world not Probed, slot empty,
person injured). A ready plan adds **Send team** to that world's Ring actions.

**Rescue alert** (over the current tab, paused; not modal).

```
+------------------------------------------------------------------------------+
| T-1 MISSED ITS CHECK-IN (STILLWATER)                Window: 71 h 58 min      |
| Rescue: dial STILLWATER, then Signal T-1 from the Ring.                      |
| Charge needed 371.6 MWh   Stored 0 MWh   Charging 5 MW: ready in 74 h        |
| At the current charge rate the bank will not be ready in time.               |
| [Charge at maximum]      [Go to Gate Room]                         [Close]   |
+------------------------------------------------------------------------------+
```

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

**Gamepad.** Shoulders reach every tab. Expeditions: D-pad moves; A opens a slot's roster or
picks; Y readies the team. The rescue alert takes focus; A presses a button, B closes it (it
stays on the alert stack). MOTH: D-pad picks a scan, A runs it, B recalls.
Conversation: D-pad picks a choice, A says it; X on a word in script opens its pencil guess. Worlds: A on a world opens its record; **Plan expedition**
opens F7 with that world chosen (the button belongs to card 12, the Expeditions tab).

---

## 8. Card plan

Sizes are S (a day or less of agent work) or M; nothing is L. "Needs" lists direct
dependencies. **The split falls at the first playable whole loop.** M3a ends with the playtest
**"The first Threshold team"**: dial, probe, plan, send, check-ins, return or rescue, on the
M1.5 worlds and procedural ones. M3b adds MOORING and contact.

**M3a: Probes and teams**

| Card | Title | Size | Needs |
| --- | --- | --- | --- |
| M3-01 | This design | M | |
| M3-03 | World facts and states (Probed, Surveyed, Contacted), derived facts for procedural worlds, authored fields, the world scene, save v15 | M | 01 |
| M3-04 | Archive Worlds section and the World Report | M | 03 |
| M3-05 | Probes sim: canister, MOTH (battery, scans, targets, recoverable marks, losses, rack) | M | 03 |
| M3-06 | MOTH scan screen and generated frames; the horizon photo reads the world scene | M | 03, 05 |
| M3-07 | Content: World Report texts and biome templates; MOTH texts and targets for the four M1.5 worlds | S | 04, 05 |
| M3-08 | Soldiers and medics, lent soldiers and replacements, injuries, recovery, the Infirmary and its unlock | M | 03 |
| M3-09 | Expedition sim: plans, team, Survey and Recover, departure (instant, the 10-minute margin), field days, return, room assignments | M | 05, 08 |
| M3-10 | Check-ins and rescue sim: check-ins every 24 h, the return as the last, Recall, missed check-in, rescue window, Signal, charge forecast, survival rolls and deceased members, lost team | M | 09 |
| M3-11 | Field events: checks, setbacks (the missed check-in through card 10's hook), findings, the pool and its texts (about 15) | M | 10 |
| M3-12 | Expeditions tab (F7), and **Plan expedition** on the World Report | M | 04, 10 |
| M3-13 | Gate Room and alerts: Send team and Signal T-1 Ring actions, check-in messages, the rescue alert with Charge at maximum | M | 10 |
| M3-14 | Playtest guide: "The first Threshold team" | S | 06, 07, 11, 12, 13 |

**M3b: MOORING and contact**

| Card | Title | Size | Needs |
| --- | --- | --- | --- |
| M3-02 | Design: puzzle 5 (the anchor's marks), MOORING, conversations K1 to K3, the lexicon | M | 01 |
| M3-15 | Conversation format and sim: ConversationDef with line, choice, check and end nodes; conditions FlagIs and StandingAtLeast; effects ChangeStanding, SetFlag, AddDocument, AddAddress; live line timing and "(signal lost)"; the Contact objective; standing; transcripts recorded as paths; save | M | 09 |
| M3-16 | Conversation UI: the panel and its gamepad paths, Hail through an open wormhole, the Contact arrival channel, the transcript view in the Archive | M | 13, 15 |
| M3-17 | Partial translation: lexicon, word tokens, the WordKnown condition, guesses, lexicon research, newly readable transcripts | M | 16 |
| M3-18 | Archive Codex section, the UnlockCodexEntry effect, contested entries side by side | M | 04, 17 |
| M3-19 | Content: the anchor, puzzle 5, MOORING (world, scene, dossier, MOTH texts) | S | 02, 07 |
| M3-20 | Content: K1 to K3, about 20 words, about 12 Codex entries | M | 02, 18, 19 |
| M3-21 | Playtest guide M3b | S | 14, 20 |

M3-02 can be written during M3a; the owner approves it before 19 and 20. In M3a, STILLWATER's
iron object is already a target, but its marks arrive with 19. After M3: iterate the loop, then
decide on the 3D feed.

---

## 9. Saves and owner decisions

**Saves: clean break, v15** (after M2.7's v14): world states and report fields, the MOTH rack
and probes in flight, new roles, injuries and lent-soldier replacements, the expedition (plan,
team, timeline, seeded generator, rescue window), the open conversation, transcripts, words and
guesses, Codex entries and standing. Older saves get the "earlier build" message.

Everything else marked as a PO proposal or ruling above stands unless the owner objects.

**Owner decisions (2026-11-07).**

1. **The MOTH:** a 2D scan screen in M3; the real-time 3D camera feed comes later as its own
   milestone.
2. **Rescue:** dial and Signal within 3 days, as proposed, but success depends on the world and
   some of the team may not have survived (section 4, "A rescue is not a sure thing").
3. **Infirmary:** built from the Base palette when Expeditions unlock.

---

## 10. Superseded elsewhere

For later cards to mark in those files; nothing is changed here. In presentation-and-systems.md:

- **Keys:** Expeditions F4 and Command F5 become F7 and F6; Research is its own tab (F4), not
  inside the Base.
- **Drone feed (section 1):** the 3D 320 × 240 feed and its slowed clock are not in M3; the MOTH
  is the scan screen of section 2 here.
- **Expeditions sketch:** loadout, posture and field decisions wait; the plan sheet replaces
  them.
- **Contact:** the linguistics lab becomes lexicon research in M3; letters at standing changes
  move to M4.

In m26-staff-and-money.md and m27-daily-rhythm.md:

- **Confidence:** the pole-camera cause "New world surveyed" (+2) is renamed "Horizon record
  taken"; "New world surveyed" now means a team's survey (+3, section 4).
