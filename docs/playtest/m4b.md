# Playtest guide: M4b, "Artefacts and the tech tree"

M4b adds two things. **Artefacts** come through the gate as rewards. You keep them in a
**Vault**, or in **Containment** if they are dangerous. While housed, they change how the base
runs. **Research** grows into a tree of about 36 projects across seven branches, with a queue,
studies of artefacts, and projects that stay hidden until the story reveals them.

Everything you see is placeholder: plain panels, test text, pt_BR strings marked `[EN]`.
Judge the systems, not the words or the look. Plan on 45 to 60 minutes.

## What changed since M4a

- **Modifiers.** Research speed, build speed, plant output, charge rate, dial cost, wormhole
  minutes, field checks and MOTH battery can all be raised or lowered by research and by
  housed artefacts. **Command → Overview** has a "Modifiers" line listing what is active.
- **Artefacts.** A new artefact waits in **holding**. Holding only has room for what your
  Vaults can take; anything beyond that waits **at the gate**, and you retrieve it from the
  Gate Room. **Archive → Artefacts** (4th tab) lists every artefact, where it is, and who
  studied it. The room panel of a Vault or Containment shows what it holds, with
  House / Unhouse buttons.
- **Artefact Vault** (unlocked from the start) and **Containment** (unlocked by research).
  A Vault takes safe artefacts. Containment takes safe and dangerous ones. You can't demolish
  a room while it holds an artefact.
- **Hazards.** A dangerous artefact that is not in Containment rolls its hazard once a day.
  The Ossar Effigy drains 20 MWh on a hit, and the Log records it.
- **Research tree.** It has seven branches, each with its own tab. A dot on a tab means
  something there can start. The tree has filters, search and zoom. Pan with the right stick
  or by dragging. Click a "needs" stub to jump to that project. Locked projects say what they
  need. Hidden ones appear only once revealed.
- **Queue.** You can queue up to 5 projects. Each starts when the one before it finishes.
- **Studies.** Holding an artefact unlocks its study project. Finishing the study marks the
  artefact Studied and reveals its follow-up project.

## Setup

- To get the **Kindred Loom**, hail the Kindred and accept **Kindred research** (or use the
  debug row `offer request_kindred_research`). Then finish *Capacitor lattice* (Energy).
- To get the **Resonant Lattice** and the **Ossar Effigy**, use the TOLLGATE targets on a field
  team.
- The debug overlay (F12) still has `standing`, `meet`, `flag`, `offer` and `contact`.
  There is no debug grant for artefacts yet.

## Ten things to try

1. Earn the Loom. Watch it arrive in holding (a toast, plus a line in Archive → Artefacts).
2. Build a **Vault** and house the Loom. Check that the Modifiers line and research times
   change (+15% research speed).
3. Start **Study the Loom**. When it finishes, look for the revealed follow-up in the Alien
   branch.
4. Queue three projects from different branches. Reorder them, remove one, and watch them
   start one after another.
5. Use search and the filters to find a project. Zoom out on the Alien branch and click a
   stub to jump to the project it needs.
6. Fill holding past what your Vaults can take. The extra artefact waits at the gate.
   Retrieve it once there is room.
7. Get the **Ossar Effigy** and leave it in holding (a Vault refuses it). Run some days and
   watch for the energy drain in the Log.
8. Research *Containment*, build one, and house the Effigy there. The drains stop, and the
   dial-cost bonus applies.
9. Try to demolish a Vault that holds an artefact. Unhouse the artefact first.
10. Hand an artefact over in a Kindred conversation and see the study it was feeding pause.

## Known limits

- Placeholder UI and text everywhere; pt_BR is `[EN]` + English. Most tree projects are
  placeholders with small modifier effects.
- There is no debug grant for artefacts.
- Nothing comes through a hostile incoming wormhole. Incursions and failure states are M4c.
- The soak bot only queues research and houses or retrieves artefacts. It never builds a
  Vault.

## Questions for you

- **Modifier balance:** are +15% research and +25% charge noticeable? Is −20% dial cost worth
  the Effigy's risk?
- **Hazard feel:** a 20% daily chance of losing 20 MWh. Is that too mild, too harsh, or too
  random to plan around?
- **Tree navigation:** can you find things with tabs, search, zoom and stubs on a gamepad?
  Does the queue sit where you'd look for it?
- Should holding be bigger than "what your Vaults can take"?

## What to report

What you tried, what you expected, what happened (with the in-game date), and anything that
felt slow, confusing or unfair. Screenshots of the panels help.
