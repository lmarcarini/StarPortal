# M2.7 Daily rhythm

Design for the M2.7 cards: money, Committee Confidence and recruitment move from months to
days, and a **Command** tab (F6) shows finances and Confidence at all times. It revises
every monthly rule in `docs/content/m26-staff-and-money.md` (sections 1 to 8, each with a
pointer note); that document wins wherever this one is silent.

It answers the owner's M2.6 playtest feedback (2026-11-07): "The month-end report was
useless. A tab with this information accessible at all times would be more useful." and "There
should be no monthly anything: everything that is monthly should be daily instead." At 10× an
in-game day lasts 2.4 real minutes, so a daily rhythm is felt; a month (72 minutes) is not.

Choices beyond the bible are PO proposals; numbers are starting values for playtesting. Units
as before: money in whole $k, one tick is one in-game minute. **The daily settlement** runs at
00:00 each day (the first on 2 January).

---

## 1. Money per day

**Allocation: paid daily (PO proposal).** A lump on a longer cycle would keep the "wait for
payday" feel the owner wants gone. The daily allocation is the monthly one ÷ 30, and it comes
out exact:

> Daily allocation = $100k × (0.5 + Confidence ÷ 100) = **$(50 + Confidence)k**

| Confidence | 20 | 35 | 50 | 65 | 80 | 100 |
| --- | --- | --- | --- | --- | --- | --- |
| Per day ($k) | 70 | 85 | 100 | 115 | 130 | 150 |
| Per 30 days ($k) | 2,100 | 2,550 | 3,000 | 3,450 | 3,900 | 4,500 |

It uses Confidence at the moment of payment, so a lock today raises tomorrow's money. One
point of Confidence is worth exactly $1k a day.

**Upkeep and salaries: charged daily.** The data keeps its numbers per 30 days (room
`upkeep_k`, salary 15 + 5 × skill), so nothing in `data/` changes meaning; the label changes
from "a month" to "per 30 days" and the UI shows the daily figure. Rules as now: a room that
is off pays half, people still arriving are paid, salaries are paid when the balance is
negative.

**Rounding: a carried remainder.** Most of these are not whole $k a day (Control Room $40k ÷
30 = $1.33k). Each settlement:

1. Add up today's costs per 30 days: rooms (halved ones rounded down as now) plus salaries.
   Call it T ($335k at the start).
2. `owed = T + carry`; charge `owed ÷ 30` (integer division) and keep `carry = owed mod 30`.

The start pays $11k on most days and $12k on 5 days in 30, exactly $335k over 30 days. The
carry (0 to 29) is saved, so results are identical after a reload. The allocation needs no
carry.

**Hiring fee: 30 days' salary.** Same amount as before ($30k for skill 3), new wording:
"Fee: 30 days' pay".

**Order at each settlement:** pay the allocation, charge costs, update the balance history,
check the commendation, apply the daily Confidence drift, check warnings. One
`budget_changed` event; no Log line.

---

## 2. Confidence per day

Confidence stays 0–100 as shown to the player, but is **kept in tenths** (0–1000) so small
daily drifts add up. The top bar and the allocation use the whole part (rounded down).

**Events: apply at once.** When it happens, not at a settlement:

| Cause | Change | Rule (unchanged) |
| --- | --- | --- |
| New world locked | +5 | First lock on a world ever |
| New world surveyed | +2 | First pole-camera survey of a world |
| Research finished | +3 | Each project |
| Reports filed | +1 per analyst | Every 15th day since the start (15 Jan, 30 Jan, ...), each analyst in a Control Room that is on |

Reports become a fixed 15-day event rather than a drift: it keeps one whole point visible as a
cause, and +2 per analyst per 30 days is a fair return on a $30k analyst (was +1).

**Steady causes: mean reversion (PO ruling).** At each settlement, after money and the
commendation check:

| Cause | Drift per day | Rule |
| --- | --- | --- |
| Settling | 0.1 toward 50 | Balance ≥ 0: above 50 it falls 0.1, below 50 it rises 0.1, at 50 nothing |
| In the red | −0.2 | Balance < 0 (no settling that day) |

There is **no idle penalty and no idle timer.** Events push Confidence above 50 and it slowly
fades back: a lock (+5) lasts 50 days, a project (+3) 30 days. Activity still matters, since
only events lift Confidence and the allocation, but a player who has used up the content, or
is saving for a long dig, is not punished: a solvent base settles at 50, the M2.5 allocation.
There is no dead end. Re-locking or re-surveying a known world earns nothing, as before.

**Cap: none (PO proposal).** The ±15 a month cap existed to stop one month-end swinging
everything. Events are now spread over time, each world or project counts once, and the drift
pulls back toward 50, so they limit themselves. Only the 0–100 bounds remain.

**Grant: the Committee commendation (PO proposal).** Replaces the quarterly review. The first
time Confidence reaches **70**, the Committee pays a one-off **$1,000k**, with a message and a
Log line: "Committee commendation: $1,000k." It is tested at once whenever an event raises
Confidence and again at the settlement **before** the drift, so a day that touched 70.0
always counts. It re-arms when Confidence falls below **60**, so dipping to 69 and back
cannot farm it. Recommended over a weekly check, which would be a smaller monthly cycle under
another name. The "notes your progress" and "questions this programme" lines go; the
warnings below cover the low end.

**Warnings: still only warnings.**

- **In the red:** 7 settlements in a row with a negative balance gives "7 days in the red.
  The Committee is concerned." (message and Log line), and again every further 7 days. Any
  settlement at or above zero resets the count. Replaces "Months in the red: 1 of 3".
- **Confidence 0:** a message and Log line when it first reaches 0; re-arms above 10.

Nothing ends the game (owner, 2026-11-02).

---

## 3. Recruitment per day

**One new candidate every 3 days (PO proposal), rolling list of 4.** On every third
settlement (4 Jan, 7 Jan, ...) a candidate arrives. The list holds four; when full, the new
one replaces the **oldest**, so a candidate stays 12 days. Each row shows "Leaves in 5 d".
Each candidate's leave day is fixed when it arrives (arrival + 12 days) and never changes, so
"Leaves in" always counts down to it. Hiring empties a row; the next arrival fills the empty
row, and the oldest still leaves on its own leave day, leaving a gap until the next arrival.

- **Draw:** as now (skill weights 10/35/35/15/5, seeded generator), but the role keeps the
  rule "at least one scientist and one engineer": if the arrival would leave no scientist (or
  no engineer) on the list, it is one.
- **The first list is fixed** (Moreau, Arai, Kowalski, Lind), each "Leaves in" 3, 6, 9 and
  12 days, so the opening stays the same.
- Arrival times (3, 5, 7 days) and beds are unchanged. A new candidate puts a dot on the
  Personnel tab; no message.

---

## 4. Command tab (F6)

**Available from the start**, after Personnel, as the bible's Command view (budget,
Committee, later factions, requests and news). The month-end report's contents move here and
stay live.

**Contents:**

- **Funds** and today's net: "Funds $4,125k (+$95k a day)".
- **Daily flows, at most 10 lines:** allocation; the **6 most expensive room types** today,
  each with its count ("Power Plant ×2"); **Other rooms** (the rest, with a count); salaries
  (with headcount); net. Each shows per day and per 30 days.
- **Trend:** balance change over the last 7 and the last 30 days, and a 30-day balance
  sparkline (one bar per day). History: 30 daily balances in the save; until 7 (or 30)
  settlements have passed, the trend compares against the starting balance ($6,000k).
- **Confidence:** the value with one decimal, today's drift and why ("−0.1 Settling toward
  50"), and a **rolling list of the last 10 causes** with dates ("9 Jan  New world locked:
  SILL  +5"); 2 show, the rest scroll.
- **Next commendation:** "At 70: $1,000k" with a bar, or "Paid. Re-arms below 60."
- **Warnings:** one row each when active (days in the red, Confidence 0), or one "none" row.

**Layout at 1280 × 720** (same frame as Personnel: list area left, side panel right). Below
the 56 px top bar and the ~40 px tab bar there are about 624 px: **19 rows of 32 px**. The
left column uses **19** in the worst case (10 money lines, 2 causes, both warnings); the
sketch shows 18 with no warning:

```
+--------------------------------------------------------+-----------------+
| COMMAND   Funds $4,125k   +$95k a day   Conf. 61.4     | COMMITTEE       | 1
| MONEY                  per day     per 30 days         | Confidence 61.4 | 2
|  Allocation (Conf. 61)   +111         +3,330           | Today -0.1      | 3
|  Power Plant ×1         -5.0           -150            |  Settling       | 4
|  Research Lab ×1        -2.0            -60            |   toward 50     | 5
|  Control Room ×1        -1.3            -40            |                 | 6
|  Capacitor Bank ×1      -0.3            -10            | Commendation    | 7
|  Quarters ×1            -0.3            -10            | at 70: $1,000k  | 8
|  Corridor ×12              0              0            | [#######---] 61 | 9
|  Other rooms ×0            0              0            |                 | 10
|  Salaries (7 people)    -6.8           -205            | (requests,      | 11
|  Net                     +95         +2,855            |  factions:      | 12
| TREND   7 d -$410k   30 d +$1,330k                     |  later)         | 13
|  ▁▂▂▃▃▄▂▁▁▂▃▄▅▅▆▆▇▅▅▆▆▇▇█▇▇▇██                       |                 | 14
| RECENT CAUSES                                 (scroll) |                 | 15
|  30 Jan  Reports filed (1 analyst)           +1        |                 | 16
|  22 Jan  Research finished: Excavation       +3        |                 | 17
| WARNINGS  none                                         |                 | 18
+--------------------------------------------------------+-----------------+
```

(Per-day costs show one decimal, the per-30-days figure ÷ 30; the actual daily charge uses
the carry of section 1. Rows with ×0 are not shown, so a small base uses fewer rows.)

**Gamepad and mouse:** the money lines and the causes are **focusable rows**. Shoulder
buttons reach the tab; D-pad moves between rows; **A on a money line** opens its breakdown
(each room, or each person for salaries) in the side panel, B closes it. The mouse does the
same with a click; hover shows it as a tooltip. The causes list scrolls with the focus.

**Room for later:** the side panel's lower half is reserved for Committee requests and faction
relations (M3/M4); news can become a third list section. No sub-tabs until there are two
things to switch between.

**Top bar: keep "Conf." (PO proposal agreed).** It shows the whole value with a ▲/▼ for
today's drift; clicking it (or A when focused) opens Command. The funds readout becomes a
focusable button too (today `MoneyLabel` is a Label) and opens Command the same way. The
hover tooltip on Conf. shows the last three causes.

---

## 5. What goes away

**All monthly code is removed:** the month-end report, the monthly allocation, the monthly
candidate list and the quarterly review. Concretely:

- the month-end report message, the report window and its **View** button
  (`MonthReportPanel`, `MonthReportNotice`, and `ConfidenceReadout`'s report link);
- `MonthEnd`, `MonthReport`, the six kept reports, `months_in_red`, the review keys and
  `month_report_filed`;
- the month hook itself: `Simulation.month_closed`, `EventBus.month_closed`,
  `SimSystem.on_month`, `EconomySystem.on_month` (now the daily settlement in `on_day`),
  `RecruitmentSystem.on_month`, `TimeMath.is_month_start` and the month entries in
  `LogRules`. Nothing else uses the hook;
- "Capped at +15 a month", "Next allocation", "Months in the red", and every "a month"
  label: salaries and upkeep read "per 30 days" where totals are shown, and Personnel's
  header shows "Salaries $7k a day".

**The Log** keeps one line per notable event: a lock, a survey, a finished project, reports
filed, a commendation, a warning. New candidates are not logged (the tab dot is enough).
Nothing is logged per day.

---

## 6. Numbers

Computed with a throwaway day-by-day script (outside the repository): allocation paid from
the whole part of Confidence at each settlement, then the commendation check, then drift.

**Opening (M2.5) recheck.** Starting funds stay $6,000k and the day-1 build (bank and lab,
$1,400k) is paid from them before the first settlement. The first week nets about +$89k a day
($100k allocation − $11k costs), so by 8 January the player has about $620k more than under
monthly pay, where nothing came until 1 February. Lock times are unchanged (staff, power and
research are untouched). By day 30 an idle player is where monthly pay left them; an active
one has collected a little more, because raised Confidence pays from the next day instead of
next month.

**The m26 example over 30 days (1 to 31 January, 30 settlements).** Same two players, same
purchases. A finishes R1, R4, R6, R7 on about days 2, 5, 8 and 10 (hires arrive day 6) and
locks SILL on day 9; B finishes two projects on days 3 and 8 and locks on day 9. Each has one
analyst (reports on 15 and 30 January). Rounded to $10k.

| | A: research rush | B: power |
| --- | --- | --- |
| Spent | 3,610 | 5,100 |
| Allocation over 30 days | 3,370 | 3,230 |
| Costs over 30 days (grow as rooms and hires arrive) | ~400 | ~470 |
| **Balance on day 30** | **~5,360** | **~3,660** |
| Events | +5 SILL, +12 research, +2 reports = +19 | +5, +6, +2 = +13 |
| Confidence peak | 66.7 (day 15) | 60.8 (day 15) |
| Confidence on day 30 | **66.1** | **60.2** |
| Commendation | not yet | not yet |
| Allocation per day at the end | 116 | 110 |

Old monthly result, for comparison: A 4,915 at 65, B 3,335 at 64.

**The trade-offs hold.** A still trades power for science: one plant, 20 MW of charging. B
still has more than double the charging rate, idle engineers and less money. The gap is about
$1,700k (was $1,580k); A leads on Confidence by 6 (was 1), because the cap no longer clips
its research.

**Commendation timing.** Nobody reaches 70 in month 1. A who also surveys SILL peaks at 68.7.
A reaches 70 when it adds about one more world in month 2 (a lock and survey are +7) before
the January gains fade: realistically in February. It stays a reward for a run of discoveries,
not for a single good week.

**Standing still, 90 days.** No events, solvent, one analyst: Confidence 50 → **50.9** (each
report is +1 and fades over 10 days). With two analysts it creeps up about +1 per 30 days
(+2 per 15 days against 1.5 of fade): 54.4 at day 90. Never a slide toward 0.

**In the red, 90 days.** Balance negative all along, one analyst: 50 → **38** (−0.2 a day,
reports +6), allocation $88k a day by the end; without an analyst 32. The first warning comes
on day 7, then every 7 days.

---

## 7. Saves

**Clean break, v14 (PO proposal).** The committee state changes shape: Confidence in tenths,
the cost carry, 30 daily balances, the cause list, days in the red, the commendation flag and
candidates with a leave day. Monthly reports and `months_in_red` go. Converting a v13 save
would mean inventing history; testers start a new game in a minute, as in M2, M2.5 and M2.6.
Older saves get the existing "earlier build" message.

---

## 8. Open questions for the owner

1. **Commendation mark.** With mean reversion it comes in about the second month of steady
   discovery, not the first. PO proposal: keep 70. Lower it to 65 if playtest shows it is
   never seen.
2. **Candidates every 3 days.** That is 10 a month instead of 4. PO proposal: keep, since each
   only stays 12 days and beds still cap hiring; every 5 days if the list feels noisy.

**Decided as PO proposals** (unless the owner objects): daily allocation $(50 + Confidence)k;
costs per 30 days charged daily with a carried remainder; fee 30 days' pay; Confidence in
tenths; events at once; reports every 15 days; drift 0.1 toward 50 while solvent, −0.2 in the
red, no idle penalty; no cap; commendation at 70 (tested before drift), re-arms below 60; red
warning after 7 days; one candidate every 3 days, list of 4; Command on F6 from the start;
"Conf." and funds stay and open Command; all monthly code removed; save v14.
