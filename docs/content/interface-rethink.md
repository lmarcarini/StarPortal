# Interface rethink

A proposal, not yet a plan. It answers the owner's brief of 2026-11-15: the Gate tab is
boring, busy when the gate is open and cumbersome; the glyph panel is a hunt; actions are
split across tabs (send a team, accept a request); there is too much text everywhere; the
one-line log is a joke; and the whole thing should look like a game, not a slopified
interface. The owner asked for a complete rethink of every screen, the flow of every action
and the look, not bound by what exists.

Nothing here is carded yet; cards follow per phase (section 8). Mock-ups of the new Gate
station are in the interface canvas.

**Owner decisions (2026-11-15):** the redesign and the streamlining are approved; four
stations; dialling a complete known address is the main way to use the gate, and composing
an address glyph by glyph stays as a second way, on its own full-screen alien panel
(section 4); a team can only talk to the base through an open gate, so the old check-in
reports go (section 4); the style is **industrial**, after the owner's second mock-up
(section 7). The owner has no art yet and asked whether pre-rendered 3D is possible;
section 7 answers that.

## 1. What is wrong today

Taken from running the current build and capturing every tab (2026-11-15).

**It reads as an admin tool.** Every screen is dark grey panels, small text and tables.
The Command tab is a ledger; Personnel is a table; Research is boxes of text; the Base
plan is outlines on a grid. More than half of most screens is empty.

**The gate is not the star of its own screen.** The Ring is a flat disc in the middle of a
black rectangle. Nothing is seen going through it: no team, no drone, no arrival.

**Text does the work that pictures and controls should.** Examples on screen now:
"Click a glyph to set the next empty seal, or drag it onto a seal. Click a set seal or a
placed glyph to clear it.", "Pick a room, or (B) on the plan to reach this palette.",
"Place a glyph in each of the seven seals first." The build palette is thirteen text
buttons. Glyphs are 36 small tiles told apart mostly by their name.

**Actions are split across tabs.** Steps as the current design has them (approximate):

| The player wants to | Today | Places visited |
| --- | --- | --- |
| Send a team to a known world | Expeditions: fill the plan sheet, Ready team. Gate Room: open Address Book, load the entry, hold to dial, wait, click the portal, Send team | 2 tabs, about 9 actions |
| See a team come home | Nothing to do: the team already dials home by itself, at no charge. But it is only a line of text; nothing is seen at the gate | none |
| Accept a request made in a conversation | Finish the conversation, Command, Requests, select it, Accept | 2 screens, 4 actions; easy to miss |
| React to "lab idle" | Open the alert, Research, find a project, Start | 2 screens |
| Redial a world | Open Address Book, find the row, load, hold to dial | 4 actions |

**The frame wastes its space.** Save, Load and a debug button sit in the top bar. The log
is one line at the bottom that usually says nothing.

## 2. Principles

1. **Diegetic first, icon second, text last.** A control is a thing in the room when it can
   be (a lever, a key, a lamp, a monitor). Otherwise an icon. Words support: a label of one
   or two words, and a card on hover or hold for anyone who wants the detail. No sentence
   of instruction is ever on screen.
2. **Show it happening.** If something happens in the base, it is seen: teams walk up the
   ramp, crates arrive, the Shutter closes, staff walk to a new room.
3. **Act where you learn.** Whatever tells the player something also lets them act on it:
   a request is accepted in the conversation, an idle lab offers projects in the message
   that reports it.
4. **One verb, one place.** No action needs two screens.
5. **The game remembers.** Last team, last loadout, last destination are the default, so
   repeating something is one action.
6. **Fewer places.** Four stations instead of seven tabs.

## 3. The frame: what is always visible

The frame is thin and physical, bolted around the scene.

| Where | What | Notes |
| --- | --- | --- |
| Top left | Clock and speed | A wall clock with a date flap; three keys: pause, play, fast. The slow lamp from event time stays |
| Top right | Three gauges: funds, power and charge, Confidence | Needles and bars, one number each. Detail on hover. Click goes to the station that owns it |
| Left edge | **The wire:** the last few events as icon cards | Replaces the log line and the alert list. Each card carries its action buttons (section 6). Cards age out to a stack; the stack opens the full log |
| Bottom left | Four station keys: Gate, Base, Lab, Office | Large icons, lit when current, a lamp when something there needs the player |
| Bottom right | Gate monitor | A small live picture of the gate, on every station but Gate. Shows dialling, an open wormhole, an incoming one. Click goes to Gate |

Removed from the frame: Save and Load (pause menu), the debug button, the tab titles with
counts, the log strip.

## 4. Four stations

Each station is a place in the base with a fixed camera, drawn as a scene. The scene is
the screen; controls sit on it or on a console along the bottom edge.

| Station | Is | Replaces | Holds |
| --- | --- | --- | --- |
| **Gate** | The control room window onto the Ring | Gate Room, Expeditions, Archive › Worlds | Dialling, destinations, probes, teams out and back, incoming wormholes, the Shutter, holding |
| **Base** | The plan table | Base, Personnel › roster | Dig, build, power, people on the plan, security |
| **Lab** | The research floor | Research, Archive › Artefacts | The tree, the queue, artefact studies |
| **Office** | The director's desk | Command, Personnel › candidates, Archive › Documents and Log | The telephone (factions, the Committee), the in-tray (requests, candidates, new documents), the ledger, the filing cabinet |

### Gate

The scene fills the screen: the Ring at the end of its ramp, seen from the control room,
with the floor, the blast door and the people in it. Everything the player sends or
receives is seen crossing that floor.

**Console along the bottom,** three parts:

- *Destination monitor (left).* The world about to be dialled: its picture from the last
  camera, name, and three or four status icons (probed, surveyed, threat, a team there).
- *Dial (centre).* One large **DIAL** key and the seven seal lamps.
- *Power (right).* The charge needle with the mark this dial needs, the drain while open,
  and the Shutter lever once it is installed.

**Destinations replace the Address Book and the Worlds list.** A rack of cards on the right
wall of the scene, one per known address, each a picture and a name. Click a card and it
is on the destination monitor; press DIAL. Redialling a world is two actions. A card
flipped over is the world's report.

**Composing an address is a second way, on its own screen (owner decision).** Most dials
are a card and the DIAL key. For an address that has to be worked out, **+ NEW ADDRESS**
opens the **alien panel**: a full-screen radial control, not part of the base, with the 36
glyphs as large stone keys in rings around a centre key.

- Glyphs are big, always in the same place, and grouped in sectors, so the hand learns
  where each one is.
- Pressing a key lights it and fills the next of the seven seal lamps across the top;
  pressing a lit key or a lamp clears it. The centre key dials.
- A **clue clip** at the side holds one document from the filing cabinet, so the clue and
  the keys are seen together. Pencilled guesses stay, drawn on the lamps.
- Typing a glyph's name still finds it (the key pulses).
- An address dialled once becomes a destination card; the panel is not needed for it
  again.

**With a wormhole open: four things to send, on one rail.** Camera, canister, MOTH and
team appear as four large icons on a rail at the foot of the ramp, greyed when not
available, each showing its own state. A handset appears when someone can be hailed. The
DIAL key becomes **CLOSE**. That is the whole panel: six controls, no list.

**Teams are staged here, not on another tab.** Each team is a card by the ramp with its
members' faces and a mission icon. Clicking **team** on the rail opens the mission sheet
in place: mission (three or four icons), how long (a dial), the team (defaults to the last
one). **Go**, and they walk up the ramp and through.

**A mission order does it in one go.** From a closed gate: pick a destination card, press
the team icon on it, confirm the sheet. The base dials, the team goes through, the gate
closes. Three actions instead of nine.

**Teams come home, and it is seen.** A team already dials home by itself at the end of
its mission, at no charge to the base, but today that is a line in the log. Now the Ring
opens as a friendly incoming wormhole, the gate monitor lights on every station, and the
team walks down the ramp. If the Shutter is closed their code opens it. A **debrief card**
follows: what they found, who is hurt, what they carried back.

**A team can only talk through an open gate (owner decision).** The automatic check-ins
that arrived as messages every 24 hours go: they made no sense with the gate closed.
Instead:

- While the base holds a wormhole open to a world with a team on it, the **hail** icon
  reaches the team: a short status (where they are in the mission, injuries) and the
  orders Carry on, Come home now, or Stay longer.
- A team in trouble opens the gate from its side and calls: an incoming wormhole with a
  distress conversation. That is how the base hears of trouble before the return.
- A team that neither returns nor calls by its time is **overdue**: a card on the wire,
  and the rescue starts from it.

### Base

The plan stays top-down but becomes a lit model: rooms as small dioramas seen from above
with their furniture and people, not outlines. Build is a tray of room models with a price
tag each, dragged onto the plan. Power is a row of breakers. People are tokens that are
dragged, as now. The roster table goes: clicking a person shows their card; a filter strip
finds people by role. Security keeps its sub-view.

### Lab

The tree stays (it is the right tool for hundreds of projects) but each project is an
icon tile with a progress ring, not a box of text; the detail card appears on selection.
The current project and queue sit on a bench at the bottom as physical trays. Artefacts
being studied are shown on the bench.

### Office

One desk, four objects:

- **The telephone:** factions and the Committee, each a card with a portrait and a
  standing needle. Calls are made and answered here (and from the wire).
- **The in-tray:** everything waiting for a decision, as papers: requests, candidates,
  new documents. Each paper has its own stamp buttons (Accept, Decline, Hire).
- **The ledger:** money as one picture: what comes in and goes out per day as two bars
  with the big items named, and Confidence as a needle with its recent causes as icons.
- **The filing cabinet:** every document, transcript and the full log.

## 5. Flows after the change

| The player wants to | After | Actions |
| --- | --- | --- |
| Send a team to a known world | Destination card, team icon, Go | 3 |
| Accept a request made in a conversation | Pick "Accept" as an answer | 1 |
| React to "lab idle" | Pick a project on the wire card | 1 |
| Redial a world | Destination card, DIAL | 2 |
| Hire a candidate | Stamp on the wire card or in the in-tray | 1 |

## 6. Act where you learn

The wire card for each event carries the action:

| Event | Buttons on the card |
| --- | --- |
| Lab idle, research finished | The three best next projects as icons; "tree" |
| Candidate arrived | Hire, pass |
| Request offered (outside a conversation) | Accept, decline |
| Artefact arrived | House it (picks the fitting room), study |
| Room finished | Switch on, assign (offers the best free people) |
| Team overdue | Start rescue |
| Incoming wormhole, call waiting | Answer, ignore |
| Funds low, charge low | Go to the place that fixes it |

**In conversations,** an offer is answered in the conversation: the answers include
Accept and Decline (and "I will think about it", which puts the paper in the in-tray).

## 7. The look

**Style: industrial (owner decision).** After the owner's second mock-up: an underground
hall of concrete and riveted steel, catwalks, hazard stripes, sodium and fluorescent
lamps, wet floor reflections. The interface is part of that world: steel plates with
bolts, stencilled labels, worn paint, a hazard-striped main key, an analogue gauge, a
green CRT for the destination, indicator lamps for the seals. The Ring's blue stays the
one cold bright thing.

Layout taken from that mock-up, which follows the proposal: resources along the top, the
wire top left, the destination and world cards on the right, the team card low on the
left, and one bottom bar holding the four station keys, the destination monitor, the
DIAL/CLOSE key with its seal lamps, the gauge and the Shutter lever. The names stay the
game's own: the Ring, Site CAIRN.

**Where the pictures come from.** The owner asked whether pre-rendered 3D is possible
instead of painted backdrops, with no dedicated graphics card needed.

- *Pre-rendered 3D and a painted backdrop are the same thing to the game:* a finished
  picture of the room that the game shows. It costs nothing to draw, so any computer runs
  it. The difference is only how the picture was made.
- *Real-time 3D* is also fine on a modern integrated card at this scale. It is not the
  limit either.
- *The limit is who makes the art.* A pre-render needs a modelled, lit 3D scene; so does
  real-time 3D. Neither the owner nor the agents have that today.

So the design does not depend on the source. Each station is a **plate plus live layers**:

- The **plate** is one picture of the empty room (gate idle, nobody in it).
- **Live layers** are drawn by the game over it: the seal lamps, the event horizon and its
  light on the floor, people walking, the Shutter, blinking monitors, arriving crates.
- A small data file per station ties them together: where the Ring's centre and edge are
  in the picture, the path up the ramp, where doors and lamps are.

A plate can then be swapped (a generated image now, a real pre-render or a commissioned
painting later) without touching code. Three sources, in order of how soon they are
available:

| Source | Now? | Quality | Notes |
| --- | --- | --- | --- |
| Generated images, like the owner's mock-ups, made without the interface on them | Yes | Already the look the owner wants | One plate per station; consistency between plates needs care |
| Free 3D kits (industrial and sci-fi sets under open licences) assembled and rendered | Weeks | Consistent, generic | Gives true pre-rendered 3D and matching angles |
| A commissioned 3D scene or painting | Later | Best | Drops in with no code change |

Until a plate exists, a placeholder plate drawn in code stands in, so work is not blocked.

**The interface hardware** (plates, bolts, keys, lamps, the gauge, hazard stripes) is made
as small textures generated by script and nine-sliced, so it does not wait for art either.

Text rules: labels of one or two words in the stencil face; numbers only on gauges and
monitors; body text only in documents, conversations and hover cards.

## 8. Phases

Each phase is playable on its own. Cards are written per phase once the direction is set.

1. **Gate** (milestone M4.9): the plate and live layers, the console, destinations, the
   alien panel, the send rail, team staging and mission orders, talking through an open
   gate, teams seen coming home with a debrief.
2. **Frame:** clock, gauges, the wire with actions, station keys, gate monitor; requests
   answered in conversations.
3. **Base:** lit plan, build tray, breakers, people cards.
4. **Lab and Office.**
5. **Text purge:** every remaining sentence on screen is cut, shortened or moved to a
   hover card.

## 9. Owner decisions

Settled on 2026-11-15 and 16: four stations; direct dialling first, the alien panel for
composing; talk only through an open gate (hail the team while a wormhole is open to their
world; a team in trouble dials in and calls; neither return nor call means overdue);
industrial style; plate plus live layers; the owner generates the plates from
`plate-prompts.md`. The first plate, the Gate hall, is `art/plates/gate_hall.png`
(1672 × 941, supplied 2026-11-16). Phase order: Gate first, then the frame and the wire.
