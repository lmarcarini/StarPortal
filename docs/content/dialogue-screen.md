# Dialogue screen

Design for the milestone "M4.8 Dialogue screen". It answers the owner's brief of
2026-11-15: conversations are important moments, whether with aliens or with a government
official, and the side panel undersells them. The owner wants a dialogue that takes
practically the whole screen like a modal, pauses everything else, and shows an animated
portrait of whoever is talking in a window beside the text. Portraits and personalities
themselves are a follow-up; this milestone builds the screen and the frame they will live
in.

It replaces the conversation panel of `m4-core-systems.md` section 3 and the `conversation`
slow reason of `event-time.md`.

**Owner decisions on this document (2026-11-15):** no time passes during a conversation
(time passing would be annoying); lines advance on a key press; every channel uses the
video look, and some callers show a still portrait instead of a moving one; there is no
summary: at the end the player closes the screen and it just closes.

## 1. The screen

A modal over the whole game. The tabs and the base are hidden behind it; nothing else can
be clicked.

```
+------------------------------------------------------------------------------+
| 14 MAR 1997 09:42   BASE ON HOLD            TRANSMISSION · RING · MOORING    |
+----------------------------------+-------------------------------------------+
|                                  |  (earlier lines, dimmed)                  |
|                                  |  ELDER SAHRA                              |
|        PORTRAIT WINDOW           |  You opened the ring-road again.          |
|        (animated)                |                                           |
|                                  |  ELDER SAHRA                              |
|                                  |  Visitors bring gifts, or they bring      |
|                                  |  questions. Which are you?_               |
+----------------------------------+-------------------------------------------+
| ELDER SAHRA                      |  1  "Questions, mostly."                  |
| Speaker for the Kindred, Mooring |  2  "Gifts. Tell us what you need."       |
| STANDING  +10 Neutral            |  3  "Who were the soldiers?"              |
|                                  |  4  (locked) needs Kindred Dialects       |
+----------------------------------+-------------------------------------------+
```

- **Top strip.** Date and time (stopped), "BASE ON HOLD", and the channel: Ring and world,
  incoming wormhole, or secure line.
- **Left, about a quarter of the width: the portrait window** (section 3), roughly square
  and no taller than 40% of the screen (owner, 2026-11-15: the first mock-up's portrait was
  too large), and under it the **name plate**:
  the speaker's name and title, the faction, and its standing with the player (Confidence
  for the Committee).
- **Right, the other three quarters: the transcript.** The current line is large and types out; earlier lines stay
  above it, dimmed, and can be scrolled. The player's own answers appear in it as "YOU".
- **Bottom right: the answers,** up to four large buttons numbered 1 to 4. A locked answer
  is greyed with its reason, as now. While a line is still being said there are no
  answers, only **Continue**.

## 2. Time stops

**Everything else pauses** (owner decision). From the moment a conversation opens until
the player closes the screen, the clock is held: no tick runs, no money, no drain on an open
wormhole, no incursion can begin.

This changes how a conversation moves on. Today a line lasts some in-game minutes and the
next one arrives by itself. With the clock held, the player moves it on:

- A line types out (about 40 characters a second). **Space, click or (A)** shows the whole
  line at once; pressed again, it goes to the next line.
- At a choice, the player picks an answer. Nothing times out.
- A line's `minutes` in the data is no longer used and is removed.

Consequences, accepted by the owner:

- A conversation costs no in-game time and no capacitor charge. Hailing over an open
  wormhole is free once the lock is made.
- A conversation can no longer be cut off because the wormhole ran out of charge.
  "Signal lost" remains only where the story writes it.
- The M4.7 slow reason `conversation` is retired. Waiting calls and incoming wormholes
  still slow the game until answered (`awaiting_answer`), as now.

The pause menu (Esc) still opens, so the player can save or quit mid-conversation; saving
keeps the conversation at its current line.

## 3. The portrait window

The window is a small screen inside the screen. **Every channel uses the same video look**
(owner decision): scanlines, a slight roll, "VIDEO LINK · LIVE". Only the frame and label
change with the channel:

| Channel | Label | Frame accent |
| --- | --- | --- |
| Ring (hail, or an answered incoming wormhole) | VIDEO LINK · RING · world | Ring blue: the one place it appears outside the gate |
| Earth (the former telephone channel) | VIDEO LINK · SECURE LINE | CRT green |

**Moving or still, by caller.** A speaker's portrait is either animated or a **still**: a
fixed picture shown through the same video look, for callers who would not be on camera or
whose art is only a photograph. A still does not breathe, blink or move its mouth; the
frame's "LIVE" becomes "STILL".

**What this milestone builds:** the window, the video look, and a **placeholder
portrait** drawn in code: a head-and-shoulders figure tinted with the faction's colour,
with three behaviours:

- *idle:* slow breathing, an occasional blink;
- *talking:* the mouth moves while the line types, and stops when it is done;
- *mood:* a line may carry a mood (neutral, pleased, wary, angry), which changes the
  brows, the posture and a tint of the light.

**What it leaves for the follow-up:** real portraits and personalities. To make that a
content job and not a code job, this milestone adds the data they will hang on:

- `SpeakerDef`: id, name, title, faction, and a portrait id.
- `PortraitDef`: how to draw the speaker. For now one kind, `placeholder`, with a few
  parameters (skin, hair, clothing colours, build), and a `still` flag. Later kinds (layered 2D art, or a 3D
  head through the camera kit) slot in behind the same window without touching the screen.
- Each line names its speaker by id and may name a mood.

When a line is spoken by someone on the player's side (an adviser, say), the window shows
that speaker; the name plate changes with it.

## 4. Opening and closing

**Opening.** Answering or hailing fades the game out and the screen in over about a
second: the window shows static, "ESTABLISHING LINK" (Ring) or a ringing line being picked
up (telephone), then the picture settles and the first line starts.

**Closing.** When the conversation ends, the picture cuts to "LINK CLOSED" (or "SIGNAL
LOST" when the story cuts it), the transcript stays readable, and a single **Close**
button replaces the answers. Closing returns to the base and releases the clock, which
goes back to the cruise speed. There is no summary (owner decision); what changed is in
the Log and on the tabs, and the transcript is saved to the Archive as now.

## 5. Controls

1 to 4 pick an answer; Space, Enter, click or (A) continue; Up, Down, the wheel or the
right stick scroll earlier lines; D-pad or stick moves between answers. Esc or Start opens
the pause menu. There is no close button until the conversation has ended.

## 6. Look

Instrument register and palette as in `interface-pass.md`. The screen is darker and calmer
than the management tabs so the portrait and the words carry it: a near-black ground, one
framed window, large type. The transcript uses IBM Plex Mono at 20 px for the current line
(16 px for earlier lines); names and labels use Barlow Condensed. The speaker's name takes
the faction's accent colour.

A mock-up is in the interface canvas (artboard "Dialogue screen").

## 7. Data and saves

- `ConversationNodeDef`: `speaker: StringName` (a SpeakerDef id) replaces `speaker_key`;
  `mood: StringName` added; `minutes` removed.
- `ActiveConversation`: `node_tick` is no longer used for pacing; a `phase` is added
  (OPENING, LINE, CHOICE, ENDED) so a save made mid-conversation reopens in the right
  place.
- New command `AdvanceConversationCommand` (next line; close after the end).
- The clock uses a hold with the reason `conversation`.
- The save version goes up by one. The seven test conversations are converted.

## 8. Owner decisions

All settled on 2026-11-15; see the top of this document.

## 9. Cards

| Card | Title | Depends on |
| --- | --- | --- |
| M4.8-01 | This design | none |
| M4.8-02 | Conversations hold the clock and advance by command | 01 |
| M4.8-03 | Speakers, moods and portrait data | 01 |
| M4.8-04 | The dialogue screen: modal, transcript, answers | 02 |
| M4.8-05 | The portrait window and placeholder portraits | 03, 04 |
| M4.8-06 | Opening and closing | 04 |
| M4.8-07 | Flow test and playtest guide | all |
