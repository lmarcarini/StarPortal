# M2.7 Daily rhythm

Design for the M2.7 cards: money, Committee Confidence and recruitment move from months to
days, and a **Command** tab (F6) shows finances and Confidence at all times. It replaces
sections 2, 4 and 5 of `docs/content/m26-staff-and-money.md` and adds to section 6; that
document wins wherever this one is silent.

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
apply the daily Confidence drift, check warnings, check the commendation. One
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

**Steady causes: a small daily drift (PO proposal).** Recommended over a rolling 7-day
window, which would need a history of causes and is harder to explain. At each settlement,
after money:

| Cause | Drift per day | Rule |
| --- | --- | --- |
| Within budget | +0.1 | Balance ≥ 0 and not lower than 7 days ago |
| Spending down | 0 | Balance ≥ 0 but lower than 7 days ago |
| In the red | −0.2 | Balance < 0 |
| Idle | −0.3 | No lock, survey or finished research in the last 7 days |

"Spending down" is neutral on purpose: building is not punished, only debt and doing nothing.
Over 30 days the steady causes net: steady, solvent player +3 (was +2); in the red all month
−6 (was −5); a fully idle month −6.9 for the idle days (was −4). The idle month as a whole
nets about the same as before (section 6).

**Cap: none (PO proposal).** The ±15 a month cap existed to stop one month-end swinging
everything. Events are now spread over time and each world or project counts once, so they
limit themselves; drift is at most ±0.5 a day. Only the 0–100 bounds remain.

**Grant: the Committee commendation (PO proposal).** Replaces the quarterly review. The first
time Confidence reaches **70**, the Committee pays a one-off **$1,000k**, with a message and a
Log line: "Committee commendation: $1,000k." It re-arms when Confidence falls below **60**, so
dipping to 69 and back cannot farm it. Recommended over a weekly check, which would be a
smaller monthly cycle under another name. The "notes your progress" and "questions this
programme" lines go; the warnings below cover the low end.

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
Hiring empties a row; the next arrival fills it and replaces no one.

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

- **Funds** and today's net: "Funds $4,125k (+$89k a day)".
- **Daily flows by line:** allocation, room upkeep (one line per room type with count),
  salaries (with headcount); each per day and per 30 days.
- **Trend:** balance change over the last 7 and the last 30 days, and a small 30-day balance
  sparkline (bars, one per day). History: 30 daily balances in the save.
- **Confidence:** the value with one decimal, today's drift and why ("+0.1 Within budget,
  −0.3 Idle"), and a **rolling list of the last 10 causes** with dates ("3 Jan  New world
  locked: SILL  +5").
- **Next commendation:** "At 70: $1,000k" with a bar, or "Paid. Re-arms below 60."
- **Warnings:** days in the red, Confidence 0.

**Layout at 1280 × 720** (same frame as Personnel: list area left, side panel right):

```
+--------------------------------------------------------+-----------------+
| COMMAND   Funds $4,125k   +$89k a day   Conf. 61.4     | COMMITTEE       |
|--------------------------------------------------------| Confidence 61.4 |
| MONEY                  per day     per 30 days         | Today +0.1      |
|  Allocation (Conf. 61)   +111         +3,330           |  Within budget  |
|  Rooms (6)                -9           -270            |                 |
|  Salaries (7 people)      -7           -205            | Commendation    |
|  Net                     +95         +2,855            | at 70: $1,000k  |
|                                                        | [#######---] 61 |
| TREND   7 d -$410k   30 d +$1,330k                     |                 |
|  ▁▂▂▃▃▄▂▁▁▂▃▄▅▅▆▆▇▅▅▆▆▇▇█▇▇▇██                       | (requests,      |
|                                                        |  factions:      |
| RECENT CAUSES                                          |  later)         |
|  30 Jan  Reports filed (1 analyst)           +1        |                 |
|  22 Jan  Research finished: Excavation       +3        |                 |
|   9 Jan  New world locked: SILL              +5        |                 |
|  (7 more, scrolls)                                     |                 |
| WARNINGS  none                                         |                 |
+--------------------------------------------------------+-----------------+
```

Rows 32 px; the causes list scrolls. **Gamepad:** shoulder buttons reach the tab; D-pad
scrolls the causes list; no other actions yet. **Mouse:** hover a flow line for its
breakdown (each room or person).

**Room for later:** the side panel's lower half is reserved for Committee requests and faction
relations (M3/M4); news can become a third list section. No sub-tabs until there are two
things to switch between.

**Top bar: keep "Conf." (PO proposal agreed).** It shows the whole value with a ▲/▼ for
today's drift; clicking it (or A when focused) opens Command. The funds readout opens Command
the same way. The hover tooltip shows the last three causes.

---

## 5. What goes away

- The month-end report message, the report window and its **View** button.
- `MonthReport`, the six kept reports, `months_in_red`, the quarterly review and
  `month_report_filed`; `EconomySystem.on_month()` becomes a daily settlement.
- "Capped at +15 a month", "Next allocation", "Months in the red".
- Every "a month" label: salaries and upkeep read "per 30 days" where totals are shown;
  Personnel's header shows "Salaries $7k a day".

**The Log** keeps one line per notable event: a lock, a survey, a finished project, reports
filed, a commendation, a warning. New candidates are not logged (the tab dot is enough).
Nothing is logged per day.

---

## 6. Numbers

**Opening (M2.5) recheck.** Starting funds stay $6,000k and the day-1 build (bank and lab,
$1,400k) is paid from them before the first settlement. The first week now nets about +$89k
a day ($100k allocation − $11k costs), so by 8 January the player has about $620k more than
under monthly pay, where nothing came until 1 February. Lock times are unchanged (staff,
power and research are untouched). The opening is a little more comfortable mid-month and the
same at day 30.

**The m26 example over 30 days (1 January to 31 January).** Same two players, same
purchases. Figures are approximate (events happen on rough days; drift depends on the
spending pattern) and rounded to $10k.

| | A: research rush | B: power |
| --- | --- | --- |
| Spent | 3,610 | 5,100 |
| Allocation over 30 days | ~3,330 (average Confidence ~61) | ~3,150 (average ~55) |
| Costs over 30 days (they grow as rooms and hires arrive) | ~400 | ~470 |
| Commendation | +1,000 (reaches 70 around day 28) | – |
| **Balance on day 30** | **~6,320** | **~3,580** |
| Confidence | +5 SILL, +12 research, +2 reports, ~+1.5 drift → **~70** | +5, +6, +2, ~+1.5 → **~64** |
| Allocation per day at the end | 120 | 114 |

Old monthly result, for comparison: A 4,915 at 65, B 3,335 at 64.

**The trade-offs hold.** A still trades power for science: one plant, 20 MW of charging. B
still has more than double the charging rate, idle engineers and less money. The gap widens
(about $2,700k against $1,580k) because the research rush now reaches the commendation
without the ±15 cap. That rewards the Committee's favourite activity, which is the point, but
it is the main number to watch in playtest (open question 1).

**Standing still.** An idle 30 days with the starting crew: +3 within budget, +2 reports,
−6.9 idle = **about −2** (was −1), about −$60k of allocation a month by the end. Still mild;
the real pressure remains the events not earned: a lock and two projects are +11, worth $11k
a day from the moment they happen.

**In the red.** A player at −$500k loses 0.2 a day plus idle if stalled, and is warned after
7 days instead of after three month-ends (90 days).

---

## 7. Saves

**Clean break, v14 (PO proposal).** The committee state changes shape: Confidence in tenths,
the cost carry, 30 daily balances, the cause list, days in the red, the commendation flag, the
last-event day for idle, and candidates with an arrival day. Monthly reports and
`months_in_red` go. Converting a v13 save would mean inventing history; testers start a new
game in a minute, as in M2, M2.5 and M2.6. Older saves get the existing "earlier build"
message.

---

## 8. Open questions for the owner

1. **Commendation in the first month.** Without the monthly cap a research rush reaches 70
   and $1,000k around day 28. PO proposal: keep it, it rewards what the Committee wants. If
   it feels too generous, raise the mark to 75 or the payment to $500k.
2. **Candidates every 3 days.** That is 10 a month instead of 4. PO proposal: keep, since each
   only stays 12 days and beds still cap hiring; every 5 days if the list feels noisy.

**Decided as PO proposals** (unless the owner objects): daily allocation $(50 + Confidence)k;
costs per 30 days charged daily with a carried remainder; fee 30 days' pay; Confidence in
tenths; events at once; reports every 15 days; daily drift +0.1 / 0 / −0.2 / −0.3; no cap;
commendation at 70, re-arms below 60; red warning after 7 days; one candidate every 3 days,
list of 4; Command on F6 from the start; "Conf." stays and opens Command; month-end report
removed; save v14.
