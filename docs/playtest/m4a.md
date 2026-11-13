# Playtest guide: M4a, "Factions and contact"

M4a gives the galaxy people to talk to. Three factions now exist: the **Committee** (your
government, whose standing *is* Committee Confidence), the **Kindred** (friendly aliens at
HEARTH) and the **Ossar** (hostile aliens at TOLLGATE). They talk to you in three ways: you
**Hail** a world through an open wormhole, an alien faction opens an **incoming wormhole**
to you, and the Committee **phones**. Conversations can offer **requests**, which you accept
or decline in the Command tab.

Everything you see is placeholder: plain panels, test text, pt_BR strings marked `[EN]`.
Judge the systems, not the words or the look. Plan on 30 to 45 minutes.

## What changed since M3

- **Call waiting** lamp on the time bar when the Committee phones. Click it (or focus it with
  the keyboard or gamepad and press Enter / (A)) to answer.
- **Conversation panel** on the right third of the screen. Lines arrive in game time (the
  clock drops to 1× while a conversation runs; you can still pause). Answers are buttons;
  keys **1 to 4** pick them too. Greyed answers show what they need.
- **Hail** on the open wormhole's actions, for worlds held by a faction or with people.
- **Incoming wormhole** banner on the Gate Room with **Answer** and **Ignore**. The game
  pauses when one arrives. You have 5 in-game minutes; ignoring costs that faction 2 standing.
  An answered incoming wormhole costs CAIRN no energy, but closes after the usual 60 minutes.
- **Command tab (F6)** has three sub-tabs: **Overview** (as before), **Requests** (offers,
  active and closed, with Accept / Decline) and **Factions** (standing bars, attitude,
  recent causes). The tab title shows **(!)** while there's a new offer.
- **Transcripts** of every conversation in the Archive's Documents (kind "Transcript").
- World Reports show **Held by** once you've met the faction and probed the world.
- **Debug overlay** (F12, debug builds only) has a row to set standing, meet a faction, set a
  flag, offer a request or queue a conversation. Each use writes a "(debug)" Log line.

## Ten things to try

1. Start a new game and run to **day 2**. The Committee calls. Answer it: both new
   addresses (HEARTH, TOLLGATE) land in the Address Book and **Survey HEARTH** is offered.
2. Open **Command → Requests**. Read the offer: objective, reward, deadline. Accept it.
3. Build the Capacitor Bank as usual, dial **HEARTH** and press **Hail**. Meet the Kindred and
   try both first answers on different games (one raises standing, one lowers it).
4. Look at **Command → Factions**: the Kindred appear only after you've met them.
5. Hail HEARTH again on a later lock: the Kindred offer two requests, and a **greyed**
   hand-over answer shows what it needs.
6. Close the wormhole **in the middle of a conversation**. The panel shows "(signal lost)";
   the transcript in the Archive ends the same way.
7. Dial **TOLLGATE** and hail the Ossar. Notice their standing going down.
8. Let Ossar standing fall below −9 (or use the debug row: `standing faction_ossar -20`) and
   wait for the **incoming wormhole** with the demand. Answer it and accept **Keep the Ring
   closed**; then don't dial for 5 days and watch it succeed. Try once dialing anyway.
9. Leave a Committee call unanswered for 2 days: it expires and Confidence drops by 1.
10. Survey HEARTH with a team (or debug-raise it) and see the request fulfil, the toast, the
    money and Confidence reward, and the Committee's check-in call.

## Known limits

- Placeholder UI and text everywhere; pt_BR is `[EN]` + English.
- No artefacts yet (M4b): the Kindred hand-over is gated on a test flag
  (`relic_in_hand`, set it with the debug row to see the choice unlock).
- There is no per-reason auto-pause setting yet; incoming wormholes always pause.
- Nothing comes through a hostile incoming wormhole (owner decision; incursions are M4c).
- Procedural worlds have no faction.

## Questions for you

- Does 1× during conversations feel right, or should lines wait for a click?
- Is 5 minutes enough to answer an incoming wormhole?
- Are the Requests and Factions sub-tabs where you'd look for them?
- Does losing 1 Confidence per missed call feel fair, and is 2 days long enough?
- Should repeated hails of the same faction always find something to say?

## What to report

What you tried, what you expected, what happened (with the in-game date), and anything that
felt slow, confusing or unfair. Screenshots of the panels help.
