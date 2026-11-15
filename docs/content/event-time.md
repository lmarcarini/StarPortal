# Event time

Design for a small milestone, "M4.7 Event time", to be built before M4c. It answers the
owner's playtest remark of 2026-11-14: the game plays best at 10×; the owner understands
why some events slow it, but having to set the speed back each time is bothersome, and 1×
is useless outside a few special cases. The owner approved the approach below the same day.

It replaces three rules: "a lock drops the clock to 1×" (M1.6), "conversations live at 1×"
(M4a) and the rescue alert's drop to 1× (M3). Numbers are starting values.

## 1. Cruise speed

The speed the player picks is their **cruise speed**. Nothing but the player ever changes
it. It is the saved `speed_index`, as now.

## 2. Slow reasons

Events no longer overwrite the speed. They add a **slow reason** to the clock, the same way
holds work today. While at least one slow reason is active, the clock runs at 1× (or at the
cruise speed if that is slower). When the last reason is released the clock is back at
cruise speed at once, with nothing for the player to do. Pausing works as always.

| Reason | Starts | Ends | Player can override |
| --- | --- | --- | --- |
| `dialling` | The dial sequence starts | Lock or failure | Yes |
| `gate_ops` | A lock (the gate operations panel opens, section 3) | Stand by, leaving the Gate Room tab, or the wormhole closing | Yes |
| `conversation` (retired in M4.8) | A hail, call or incoming wormhole is answered | The conversation ends | No |
| `awaiting_answer` | An incoming wormhole or phone call starts waiting; a team asks for a field decision; a rescue alert opens | Answered, ignored, dismissed or expired | Yes |
| `incursion` | The warning (M4c) | The incursion ends | No |

*Since M4.8 a conversation no longer slows the clock: it holds it (hold reason
`conversation`) until the player closes it; see dialogue-screen.md section 2.*

**Override.** While slowed, pressing **Faster** releases every reason that can be
overridden and returns to cruise speed; they do not come back for that event. The two
that cannot be overridden need the player's eyes.

**Slow speed.** 1× for every reason. One balance value, so it can be tuned.

## 3. The gate: slow follows attention

On a lock, the game switches to the Gate Room tab and the **gate operations panel** comes
up: the Ring view large, and the actions on it as big buttons (pole camera, canister, MOTH,
send team, close). This is the "in your face" moment, and `gate_ops` keeps the clock slow
while it is up.

**Stand by** closes the panel, keeps the wormhole open and releases `gate_ops`. Leaving the
Gate Room tab does the same. Coming back and pressing **Operate** on the Ring brings the
panel and the slow back.

So a first look at a new world is slow and deliberate, while keeping a wormhole open for an
expedition, or a routine dial-home, costs one click or none. The wormhole drains the
capacitors per in-game hour as before, so standing by at 10× spends the charge ten times
faster in real time. That is the player's choice.

**No tab switch** happens if the player is in a conversation or an incursion; the lock
then shows as an alert instead.

A setting, **Switch to the Gate Room on a lock** (on by default), turns the automatic tab
switch off; the slow reason then starts only when the player opens the panel.

## 4. What the player sees

The top bar's clock shows the cruise speed always, and while slowed a lamp beside it with
the reason: "SLOW · gate", "SLOW · call waiting", "SLOW · intruders". The Faster button
shows that it will override when it can.

## 5. Rules and saves

- `ClockState` gains `slows: Array[StringName]` and `overridden: Array[StringName]`, saved.
  The save version goes up by one.
- Slow reasons are added and released only by systems and commands, never by the UI. The
  gate panel sends `OperateGateCommand` and `StandByCommand`.
- `drop_to_normal_speed` and every direct write to `speed_index` outside the player's
  commands are removed.
- At cruise speeds of 1× or 0.5× nothing changes.

## 6. Cards

| Card | Title | Depends on |
| --- | --- | --- |
| M4.7-01 | This design | none |
| M4.7-02 | Clock: cruise speed, slow reasons, override | 01 |
| M4.7-03 | Conversations, waiting calls, field decisions and rescues use slow reasons | 02 |
| M4.7-04 | Dialling and the gate operations panel | 02 |
| M4.7-05 | Top bar: slow lamp and override | 02 |
| M4.7-06 | Flow test and playtest guide | all |

M4c-06 (incursion warning) uses the `incursion` reason instead of forcing 1×.
