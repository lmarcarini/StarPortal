# M2.6 Staff and money

Design for the M2.6 cards: people who work in rooms, hiring, salaries, Committee Confidence
driving the monthly allocation, and the month-end report. It is the second half of the
roadmap's M2 and builds on `docs/content/m25-lean-start.md`, which wins wherever this
document is silent. In the spirit of the owner's M2 feedback, it keeps the start lean, unlocks
things as the player goes, and keeps every effect visible.

Choices beyond the bible are PO proposals; all numbers are starting values for playtesting.
Units as before: money in $k, power in 5 MW blocks, one tick is one in-game minute.

---

## 1. People

**Roles in M2.6:** scientist, engineer and analyst. Each has a room to work in now.

**Roles that wait:** medic (M3, with the Infirmary and injuries) and soldier (M3, with
security squads and Threshold teams). Neither has anything to do in M2.6, so neither appears
in the candidate list yet. Scientists are not split into physics, xenobiology and linguistics
until those labs exist (M4); in M2.6 every scientist is a physics scientist, shown simply as
"Scientist".

**What a person has now:**

| Field | Values | Notes |
| --- | --- | --- |
| Name | Given name and surname | Drawn from a name list per pipeline |
| Role | Scientist, Engineer, Analyst | Fixed for life |
| Skill | 1 to 5 | One number; it is the role's skill |
| Salary | $k a month | 15 + 5 × skill: skill 1 = $20k, skill 3 = $30k, skill 5 = $40k |
| Assignment | A room, or Unassigned | |

Nothing is hidden: the player sees every field.

**What waits:**

| Field | When | Why it waits |
| --- | --- | --- |
| Two traits | M3 | Need expeditions and teams to matter |
| Stress | M3 | Comes from off-world work and incidents |
| Injuries | M3 | Need the Infirmary, medics and expeditions |
| Clearance level | M4 | Comes with the intelligence game and plants |
| Hidden loyalty, plants | M4 | Faction play (Continuity, Halcyon) |

---

## 2. Recruitment

**A monthly candidate list (PO proposal).** A new game starts with a list of **four
candidates**, and on the 1st of each month, with the month-end report, the game draws a new
list of four. The list replaces the previous one;
candidates not hired are gone. Each candidate shows name, role, skill, salary, pipeline,
hiring fee and arrival time.

| Pipeline | Gives | Hiring fee | Arrives after | 1× | 10× |
| --- | --- | --- | --- | --- | --- |
| Academia | Scientists | 1 month's salary | 5 days | 2 h | 12 min |
| Military | Engineers | 1 month's salary | 3 days | 72 min | 7.2 min |
| Intelligence | Analysts | 1 month's salary | 7 days | 168 min | 16.8 min |

The list always holds at least one scientist and one engineer; the other two are drawn from
any pipeline. Skill is drawn 1–5: skill 1 10%, 2 35%, 3 35%, 4 15%, 5 5%. Draws use the
recruitment system's seeded generator.

**The first list is fixed** so every new game opens the same way: Dr Ines Moreau (Scientist,
skill 3), Dr Kenji Arai (Scientist, skill 3), Sgt Dan Kowalski (Engineer, skill 3) and Cpl Sara
Lind (Engineer, skill 3), each $30k a month. The examples in section 7 hire from it.

- **Hiring:** pick a candidate, press **Hire**. The fee is paid at once, a bed is reserved, and
  the person appears in the roster as "Arriving in 3 d 4 h". On arrival they are Unassigned,
  with a Log line: "Dr Ana Ferreira (Scientist, skill 4) has arrived."
- **Refused if:** funds are short ("Not enough money") or no bed is free ("No free bed. Build
  Quarters.").
- **No clearance check** yet: there is no risk to skip. The "skip clearance" choice comes with
  plants in M4.
- **Firing:** **Dismiss** (hold), from the roster. Immediate, no refund of the fee, no
  severance, no Confidence cost. Their bed frees at once. A person still arriving can be
  cancelled the same way; the fee is lost.
- **Leaving on their own:** nobody leaves in M2.6. Quitting comes with stress and loyalty (M3
  and M4).

**Salaries are paid even when the balance is negative**; going below zero is handled by
Confidence and bankruptcy (section 4).

---

## 3. Rooms and staff

**Slots.** Each staffable room shows its slots on the plan and in its SELECTED panel. Only
people of the matching role can fill a slot.

| Room | Slots | Unstaffed (floor) | Staffed effect |
| --- | --- | --- | --- |
| Research Lab | 4 scientists | Research at **25%** speed | Speed = max(25%, total skill ÷ 6), at most 200% (two skill-3 scientists = 100%); staffing is never slower than empty |
| Power Plant | 2 engineers | **20 MW** (4 blocks) | 1 engineer: 25 MW; 2 engineers: 30 MW. Skill does not matter |
| Workshop | 2 engineers | Sites and digs **10%** faster | Bonus = 10% + 2.5% × total skill, at most 35% (two skill-3 engineers = 25%) |
| Control Room | 2 analysts | Runs the Gate Room as now | Each analyst adds +1 Confidence a month ("Reports filed") |
| Gate Room, Capacitor Bank, Corridor, Stairs, Lift, Quarters | none | Works as now | |

**No room stops for lack of staff.** Every room works at its floor rate unstaffed, so nothing
locks up and the M2.5 base still runs if the player ignores the Personnel tab. A room that is
**off** gives no staff effect; its people stay assigned and idle.

**Research speed.** The M2.5 "listed time" becomes the time for a standard crew: two skill-3
scientists (total skill 6). Excavation survey (2 days) takes 8 days with an empty lab, 2 days
with the starting crew, 1.5 days with skill 8, and 1 day at the 200% cap (total skill 12).
Total skill counts the scientists in **every lab that is on**.

**Research stays one project at a time in M2.6 (PO ruling).** Scientists in all labs pool
into the one active project, so a second lab adds four scientist slots, not a second project.
The Research tab keeps its single header and the "One project at a time." refusal. The
project pauses only when no lab is on. The palette note "One lab is enough until staff
arrive." becomes "More labs hold more scientists." (pt_BR "Mais laboratórios comportam mais
cientistas."). *Later idea:* several projects at once, one per lab, with Start picking a lab.

**Engineers and building.** Engineers speed building only through the Workshop; there is no
separate per-site engineer bonus, so the speed-up stays in one place and is never counted
twice. The 25% the owner approved for the Workshop is kept as the staffed value; an empty
Workshop now gives 10%. Digs and sites still need no staff to proceed. Engineers in plants
are the other use: a second diesel plant (R4) gives only 20 MW until it is crewed, so power
growth now also costs salaries.

**Rule: supply drops take from charging first (PO ruling).** This extends the M2.5 rule for a
finishing room to every loss of plant output: a plant switched off or demolished, or an
engineer unassigned, moved or dismissed. The game first lowers Capacitor Bank charge rates,
newest bank first, by just enough. Only if zero charging is still not enough does it switch
off the newest switchable rooms. It shows a message and a Log line, as in M2.5. This changes
the M2 plant-loss rule (rooms first, then charging) for the implementation card.

*Opening case:* Gate 5 + Lab 5 + charging 20 = 30 MW. Dismissing Cpl Mendes drops the plant to
25 MW; charging falls to 15 MW ("Power Plant crew reduced: charging lowered to 15 MW."), and
the lab stays on. Dismissing both engineers leaves 20 MW and charging at 10 MW.

**Quarters: beds cap headcount.** The base starts with **6 beds** in the Control Room's crew
bunks (shown in the Personnel header, "Beds 5 / 6"). Each **Quarters** adds **4 beds**.
Headcount, counting people still arriving, can't exceed beds. Demolishing Quarters is refused
if it would leave more people than beds ("Dismiss someone first.").

**Quarters numbers, re-timed to M2.5:** 3 × 2 cells, **$150k, 2 hours**, 0 MW, upkeep
$10k. It returns to the palette **from the start** of M2.6: hiring is available from day 1,
and the first Quarters is needed as soon as the player hires a second person. Its lines are in the table below.

**New Now/Later lines** (replacing m25 section 4 for these rooms):

| Room | Now (en) | Later (en) |
| --- | --- | --- |
| Power Plant | Gives 30 MW with two engineers, 20 MW without. Upkeep is fuel. | Upgrades to fission and beyond. |
| Research Lab | Holds four scientists. More skill, faster research. | Splits into physics, xenobiology and linguistics labs. |
| Workshop | While on, sites and digs finish faster: 10% empty, 25% with two engineers. | Builds prototypes and equipment. |
| Quarters | Sleeps 4. Beds cap how many people the base holds. | Rest lowers stress. |

| Room | Agora (pt_BR) | Depois (pt_BR) |
| --- | --- | --- |
| Power Plant | Gera 30 MW com dois engenheiros, 20 MW sem eles. A manutenção é combustível. | Evolui para fissão e além. |
| Research Lab | Comporta quatro cientistas. Mais perícia, pesquisa mais rápida. | Divide-se em laboratórios de física, xenobiologia e linguística. |
| Workshop | Ligada, as obras e escavações terminam mais rápido: 10% vazia, 25% com dois engenheiros. | Constrói protótipos e equipamentos. |
| Quarters | Abriga 4 pessoas. As camas limitam quantas pessoas a base comporta. | O descanso reduz o estresse. |

**Infirmary: stays locked** until M3. Nothing in M2.6 injures anyone, and no medics exist. Its
locked row now reads "Requires expeditions (M3)".

**Fission plant:** stays a locked research row ("Requires staff" becomes "Requires
expeditions (M3)").

---

## 4. Money

**Monthly upkeep** gains salaries. At 00:00 on the 1st of each month the game pays the
allocation and charges room upkeep (half when off, as now) and all salaries, including people
still arriving.

**Committee Confidence, 0–100.** It starts at **50**. At each month-end the month's changes
are added up, capped at **±15 a month**, applied, and the new value sets the **next**
allocation:

> Allocation = $3,000k × (0.5 + Confidence ÷ 100)

| Confidence | 20 | 35 | 50 | 65 | 80 | 100 |
| --- | --- | --- | --- | --- | --- | --- |
| Allocation ($k) | 2,100 | 2,550 | 3,000 | 3,450 | 3,900 | 4,500 |

At the start (50) the allocation is the M2.5 $3,000k, so nothing changes until the player
earns or loses Confidence.

**Causes** (each shown as its own line in the month-end report):

| Cause | Change | Rule |
| --- | --- | --- |
| New world locked | +5 each | First lock on a world ever |
| New world surveyed | +2 each | First pole-camera survey of a world |
| Research finished | +3 each | Each project completed this month |
| Reports filed | +1 each | Each analyst in a Control Room that is on |
| Within budget | +2 | Balance ≥ 0 after the month-end payment |
| In the red | −5 | Balance < 0 after the month-end payment |
| Idle month | −4 | No new lock, survey or finished research this month |

**Not a cause yet: failed dials.** The player is learning addresses by trial; punishing
misses would discourage the Archive work the game is built on. Dials cost energy already.

**Quarterly review, simplest form.** On 1 April, 1 July, 1 October and 1 January (the first is 1 April of year 1; the game's start on 1 January has none), the
month-end report adds a review line from the Committee, by Confidence after the month's
change:

- **70 or more:** "The Committee is pleased." A one-off grant of **$1,000k**.
- **30 to 69:** "The Committee notes your progress." No effect.
- **Below 30:** "The Committee questions this programme." No money; a warning only.

**Order at a month-end:** pay the allocation, charge upkeep and salaries, check Within budget
or In the red, apply the Confidence change, then (in a quarter month) the review and its
grant. The grant never decides the budget check; it lands after it.

Choosing which results to present, overstating them and scandals wait for M3, with the Command
tab.

**Bankruptcy (PO proposal: count now, end the game later).** The month-end report tracks
"Months in the red: 1 of 3", reset by any month-end at or above zero. In M2.6, reaching 3
gives a strong warning and a pause, not a game over: there is no end screen yet, and testers
should keep playing. Confidence 0 likewise only warns. Both become real game overs in M3,
when the game-over screen exists (open question 2).

---

## 5. Month-end report

At each month-end the game **pauses** and shows a short report, then writes the same lines to
the Log. It replaces the M2 one-line "Month-end:" Log entry and closes the M2 follow-up
"month-end Log line". Continue (A / Enter) closes it.

```
+------------------------------------------------------+
| MONTH-END  1 February                                |
|------------------------------------------------------|
| Allocation                               +$3,000k    |
| Room upkeep                                -$270k    |
| Salaries (7 people)                        -$205k    |
| Balance                       $2,390k ->  $4,915k    |
|------------------------------------------------------|
| COMMITTEE CONFIDENCE                  50 -> 65       |
|   New world locked: SILL                     +5      |
|   Research finished (4)                     +12      |
|   Reports filed (1 analyst)                  +1      |
|   Within budget                              +2      |
|   Capped at +15 a month                      -5      |
| Next allocation                          $3,450k     |
|------------------------------------------------------|
| 4 new candidates.  [Personnel]        [Continue]     |
+------------------------------------------------------+
```

The **Personnel** button opens the Personnel tab on the candidate list. In a quarter month a
review line is added under the Confidence block. Settings gets one toggle, "Pause at
month-end" (on by default); off, the report goes to the Log only.

---

## 6. UI

**A Personnel tab (F5), available from the start (PO proposal).** It follows the owner's
ruling that research is a place of its own: staff are a list of people with a side panel,
which reads better full-width than squeezed beside the plan. Unlike Research, it is shown
from the start, since staff exist on day 1. **Command, planned for F5, moves to F6** when it
arrives (M3); the bible's tab list needs that one change.

```
+------------------------------------------------------------+----------------+
| PERSONNEL   Staff 5   Beds 5/6   Salaries $145k/month      | SELECTED       |
| [Roster]  [Candidates (4)]                                 | Dr A. Ferreira |
|------------------------------------------------------------| Scientist      |
| > Dr Ana Ferreira    Scientist  ***    $30k  Research Lab  | Skill 3  $30k  |
|   Dr Tom Okafor      Scientist  ***    $30k  Research Lab  | Research Lab   |
|   Sgt Lena Brandt    Engineer   ***    $30k  Power Plant   |  (Level 1)     |
|   Cpl Raul Mendes    Engineer   **     $25k  Power Plant   |                |
|   Mira Kovacs        Analyst    ***    $30k  Control Room  | [Assign...]    |
|                                                            | [Unassign]     |
|                                                            | [Dismiss(hold)]|
+------------------------------------------------------------+----------------+
```

Rows are 48 px, as in Research; at 1280 × 720, ten rows fit before the list scrolls. Skill
shows as 1–5 stars with the number in the tooltip. The Candidates sub-tab has the same layout,
with pipeline, fee and arrival time, and **Hire** in the SELECTED panel.

**Assigning.**

- **Mouse:** in Personnel, select a person, press **Assign…**: a list of rooms with a free
  slot of their role, each with its effect ("Research Lab, L1: 2/4, speed 100% → 150%").
  Click one. **From the Base tab** too: a staffable room's SELECTED panel lists its slots;
  an empty slot's **+** opens the matching unassigned people.
- **Gamepad:** shoulder buttons reach the tab; D-pad moves rows; A opens Assign… on the
  focused person; D-pad and A pick the room; B backs out. Y toggles Roster and Candidates.
- Assigning to a full room is not offered; moving someone is just assigning them elsewhere.
- **Arrival hint:** a newly arrived Unassigned person puts a dot on the Personnel tab until
  assigned.

**On the plan:** each staffable room shows small pips for its slots (filled or empty), so
an unstaffed plant or lab is visible at a glance. The power strip shows a crewless plant as
"20 / 30 MW (needs engineers)".

---

## 7. Numbers

**Starting staff: five (PO proposal).**

| Person | Role | Skill | Salary | Room |
| --- | --- | --- | --- | --- |
| Dr Ana Ferreira | Scientist | 3 | $30k | Unassigned (no lab yet) |
| Dr Tom Okafor | Scientist | 3 | $30k | Unassigned (no lab yet) |
| Sgt Lena Brandt | Engineer | 3 | $30k | Power Plant |
| Cpl Raul Mendes | Engineer | 2 | $25k | Power Plant |
| Mira Kovacs | Analyst | 3 | $30k | Control Room |

The scientists wait for the Research Lab and are **assigned to it automatically** when the
first lab finishes (Log: "Research Lab staffed: 2 scientists."); after that, assignment is
manual. With these five, every M2.5 number holds: the plant gives 30 MW, the lab runs at
100%, the opening lock times are unchanged.

- **Salaries at start:** $145k a month. **Beds:** 5 of 6.
- **Starting Confidence:** 50. **Starting funds:** $6,000k (unchanged).
- **Upkeep at start:** $190k rooms + $145k salaries = **$335k**.

**A 30-day example (1 January to the 1 February month-end).** Two players, same start.

| | A: research rush | B: power and people |
| --- | --- | --- |
| Capacitor Bank, Research Lab | 1,400 | 1,400 |
| Research | R1, R4, R6, R7: 2,000 | R4, R6: 1,100 |
| Second Power Plant | – | 2,000 |
| Second Capacitor Bank | – | 600 |
| Quarters | 150 | 150 |
| Hires (first list) | Moreau, Arai: 60 | Kowalski, Lind: 60 |
| **Spent** | **3,610** | **5,310** |
| Balance before month-end | 2,390 | 690 |
| Upkeep (rooms) | 270 | 430 |
| Salaries (7 people) | 205 | 205 |
| Balance after month-end | 4,915 | 3,055 |
| Confidence | +5 SILL, +12 research, +1, +2 = +20, capped +15 → **65** | +5 SILL, +6 research, +1, +2 = +14 → **64** |
| Next allocation | 3,450 | 3,420 |
| Power | 30 MW: Gate 5, Lab 5, one bank at 20 MW (R6 done, second bank not built) | 60 MW: Gate 5, Lab 5, banks at 30 + 20 MW |

A's four scientists put R1, R4, R6 and R7 through in about 9 days (200% once the hires arrive),
but the base still has one plant and 20 MW of charging. B fills two banks at 50 MW, more
than double A's rate, and its four engineers crew both plants, but it ran two projects, ends
the month with $1,860k less and a slightly smaller allocation.

**Standing still.** An idle month with the starting crew scores −4 idle, +2 within budget
and +1 reports = **−1**, about −$30k of allocation a month. PO proposal: keep it mild. The
real pressure is the + causes the player did not earn: a month with a lock and two projects
is worth +11, about $330k more a month. That is the M2 done-when: power and money balanced
with real trade-offs over a 30-day run.

**Room upkeep check** for A: Control 40 + Plant 150 + Bank 10 + Lab 60 + Quarters 10 = 270.
For B: + second Plant 150 + second Bank 10 = 430 (R5 brings each plant to 100).

---

## 8. Saves and open questions

**Saves: clean break, v13.** The save gains the roster (people, assignments, arrival times),
the candidate list and its random seed, Confidence, and months in the red.
A v12 base has staffable rooms with no one in them, which would load at floor rates and
surprise the player. As in M2 and M2.5, testers can start a new game in a minute; older saves get
the existing "earlier build" message.

**Decided here as PO proposals:** three roles now (medic and soldier wait); salary 15 + 5 ×
skill; four candidates a month; one-month hiring fee; floor rates for every staffable room;
Quarters back in the palette from the start; Infirmary locked; research one project at a time with pooled scientists;
supply drops take from charging first; Workshop 10% empty, 25%
with a standard crew; five starting staff; Confidence 50 with the formula above; quarterly
grant at 70+; Personnel on F5, Command to F6; save v13.

**Open questions for the owner:**

1. **Unstaffed plant at 20 MW.** It makes engineers matter and makes a second plant cost
   people, but a crewless plant is a power drop players may not expect. Keep it, or have plants
   run at full output regardless of staff?
2. **Bankruptcy and Confidence 0.** Count and warn in M2.6, game over from M3 (proposed), or
   game over now?
3. **Month-end pause.** A paused report each month (proposed, with a Settings toggle), or a
   Log entry only?
