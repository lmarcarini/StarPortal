# Dialogue screen

Design for the milestone "M4.8 Dialogue screen". It answers the owner's brief of
2026-11-15: conversations are important moments, whether with aliens or with a government
official, and the side panel undersells them. The owner wants a dialogue that takes
practically the whole screen like a modal, pauses everything else, and shows an animated
portrait of whoever is talking in a window beside the text. Portraits and personalities
themselves are a follow-up; this milestone builds the screen and the frame they will live
in.

It replaces the conversation panel of `m4-core-systems.md` section 3 and the `conversation`
slow reason of `event-time.md`. Choices beyond the brief are PO proposals **(proposal)**;
the open ones are in section 8.

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
  incoming wormhole, or telephone.
- **Left, about 40%: the portrait window** (section 3) and under it the **name plate**:
  the speaker's name and title, the faction, and its standing with the player (Confidence
  for the Committee).
- **Right: the transcript.** The current line is large and types out; earlier lines stay
  above it, dimmed, and can be scrolled. The player's own answers appear in it as "YOU".
- **Bottom right: the answers,** up to four large buttons numbered 1 to 4. A locked answer
  is greyed with its reason, as now. While a line is still being said there are no
  answers, only **Continue**.

## 2. Time stops

**Everything else pauses** (owner decision). From the moment a conversation opens until
its summary is closed, the clock is held: no tick runs, no money, no drain on an open
wormhole, no incursion can begin.

This changes how a conversation moves on. Today a line lasts some in-game minutes and the
next one arrives by itself. With the clock held, the player moves it on:

- A line types out (about 40 characters a second). **Space, click or (A)** shows the whole
  line at once; pressed again, it goes to the next line. **(proposal)**
- At a choice, the player picks an answer. Nothing times out.
- A line's `minutes` in the data is no longer used and is removed.

Consequences to accept **(proposal)**:

- A conversation costs no in-game time and no capacitor charge. Hailing over an open
  wormhole is free once the lock is made.
- A conversation can no longer be cut off because the wormhole ran out of charge.
  "Signal lost" remains only where the story writes it.
- The M4.7 slow reason `conversation` is retired. Waiting calls and incoming wormholes
  still slow the game until answered (`awaiting_answer`), as now.

The pause menu (Esc) still opens, so the player can save or quit mid-conversation; saving
keeps the conversation at its current line.

## 3. The portrait window

The window is a small screen inside the screen, and what it looks like depends on the
channel:

| Channel | Looks like | Accent |
| --- | --- | --- |
| Ring (hail, or an answered incoming wormhole) | A video link: scanlines, slight roll, "VIDEO LINK · LIVE" | Ring blue frame: the one place it appears outside the gate |
| Telephone (Earth factions) | No picture is being sent: a personnel photograph of the caller on a card, a moving audio level beside it, "SECURE LINE" | CRT green |

**What this milestone builds:** the window, both channel looks, and a **placeholder
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
  parameters (skin, hair, clothing colours, build). Later kinds (layered 2D art, or a 3D
  head through the camera kit) slot in behind the same window without touching the screen.
- Each line names its speaker by id and may name a mood.

When a line is spoken by someone on the player's side (an adviser, say), the window shows
that speaker; the name plate changes with it.

## 4. Opening and closing

**Opening.** Answering or hailing fades the game out and the screen in over about a
second: the window shows static, "ESTABLISHING LINK" (Ring) or a ringing line being picked
up (telephone), then the picture settles and the first line starts.

**Closing.** When the conversation ends, the picture cuts to "LINK CLOSED" (or "SIGNAL
LOST" when the story cuts it) and the right side shows a short **summary**: what changed
because of this conversation.

```
LINK CLOSED · Elder Sahra, the Kindred
  Standing  +10 -> +15
  New request: Medicine for Mooring (due 21 Mar)
  New document: Kindred greeting, transcribed
  [Read transcript]                       [Return to base]
```

**Return to base** closes the screen and releases the clock, which goes back to the
cruise speed. The transcript is saved to the Archive as now.

## 5. Controls

1 to 4 pick an answer; Space, Enter, click or (A) continue; Up, Down, the wheel or the
right stick scroll earlier lines; D-pad or stick moves between answers. Esc or Start opens
the pause menu. There is no close button: a conversation ends when it ends.

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
  (OPENING, LINE, CHOICE, SUMMARY) so a save made mid-conversation reopens in the right
  place.
- `TranscriptRecord` gains `outcomes`: the summary lines, recorded as effects are applied.
- New command `AdvanceConversationCommand` (next line; close the summary).
- The clock uses a hold with the reason `conversation`.
- The save version goes up by one. The seven test conversations are converted.

## 8. Owner decisions needed

1. **No time passes in a conversation** (section 2), so talking is free in time and
   charge. Or should the clock jump forward by the conversation's length when it closes?
2. **Lines advance on a key press,** with typing that can be skipped. Or advance
   automatically after a pause, with a key only to hurry?
3. **Telephone calls show a photograph and an audio level,** not a moving picture. Or the
   same video look for every channel?
4. **The summary at the end:** wanted, or just close?

## 9. Cards

| Card | Title | Depends on |
| --- | --- | --- |
| M4.8-01 | This design | none |
| M4.8-02 | Conversations hold the clock and advance by command | 01 |
| M4.8-03 | Speakers, moods and portrait data | 01 |
| M4.8-04 | The dialogue screen: modal, transcript, answers | 02 |
| M4.8-05 | The portrait window and placeholder portraits | 03, 04 |
| M4.8-06 | Opening, closing and the summary | 04 |
| M4.8-07 | Flow test and playtest guide | all |
