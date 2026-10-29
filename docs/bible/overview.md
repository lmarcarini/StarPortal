# FAR SIDE PROTOCOL — Design Bible

Oct 21, 2026 · @Leonardo Marcarini Borges

## Pitch

FAR SIDE PROTOCOL is a real-time-with-pause base management and discovery game. You direct Site CAIRN, a secret base built around an alien ring that opens wormholes to other worlds.

Every address is hidden in something you find: an explorer's note, a carving, a faction's gift, an artefact, a captured log. Each one is its own small puzzle. Each dial burns power, opens a door both ways, and may lead nowhere, somewhere, or somewhere hostile. Across a prologue and seven arcs you go from 8-seal addresses to the 9-seal and finally the 10-seal address that reveals what the Ring was built for.

- **Fantasy:** you decide which door humanity opens next, and you pay for it.
- **Inspiration:** Stargate SG-1 (premise), XCOM (base plus a wider world), Papers, Please (aesthetic only), Frostpunk (pressure and setbacks), FTL (the base plan), Blue Prince and Inscryption (discovery).
- **Platform:** PC with low requirements; Windows first, Linux and Steam Deck as a stretch.
- **Length target:** a 20 to 30 hour campaign, with sandbox play after the ending.
- **Team:** Claude implements; the project owner supervises, reviews and decides.

## Design pillars

Every feature must serve at least one of these six pillars; a feature that serves none gets cut.

1. **Discovery, not guessing.** Addresses are earned by reading and noticing, each from a hand-made puzzle with its own story. Brute force exists but is ruinously expensive.
2. **Trust is a resource.** Every source has an agenda. The government lies sometimes, and so do allies.
3. **Every door opens both ways.** Dialing exposes the base. Power, risk and reward all run through the Ring.
4. **Everything transforms.** Clues become addresses, worlds become allies or outposts, artefacts become technology, technology becomes money or secrecy.
5. **Arcs change the rules.** Each arc adds, removes or bends a system. Some take something away for a while.
6. **Lore rewards curiosity.** The full truth is optional, layered and consistent. Every faction is right about something.

## Locked decisions

These are settled; changing one means editing this table first, then every tab that depends on it.

| Decision | Choice |
| --- | --- |
| Title | FAR SIDE PROTOCOL. A full trademark and Steam search is due before any public page |
| Time model | Real time with pause. One tick = one in-game minute; at 1× a tick is one real second. Speeds: pause, 1×, 3×, 10×. |
| Structure | Campaign of a prologue plus seven arcs, with sandbox elements and free play after the ending |
| Setting | An unnamed Western government. Other governments appear as factions |
| Presentation | Hybrid (decided 2026-10-26). The Gate Room is one fixed illustrated view through the control room glass: the Ring is the clickable centrepiece, the dial console is the desk below it. The base is a separate three-quarter plan, FTL style; the Archive, Expeditions and Command are instrument screens. The drone feed is the one first-person, real-time low-poly view. Papers, Please-inspired look |
| Engine | Godot 4 (latest stable 4.x, pinned), statically typed GDScript, Compatibility renderer |
| Platform and store | PC, low requirements. Steam, considered only once the game proves good enough |
| Input and accessibility | Fully playable with keyboard and mouse or gamepad; every binding remappable; accessibility options from the first build |
| Difficulty | Three presets plus individual sliders |
| Languages | English and Brazilian Portuguese at launch |
| Voice | Key lines fully voiced over radio. Other lines voice only their opening words, then continue as text |
| Art plan | Grey-box placeholders first, then Claude-generated Blender art later in development. A commissioned artist only if the game proves promising |
| Content volume | About 40 authored story worlds and 300 procedural worlds; revisited at M5 |
| Address alphabet | 36 glyphs. 8 seals reach the home domain, 9 seals another domain, 10 seals the final destination |
| Intellectual property | Original names and lore throughout. Stargate is inspiration only |

## Glossary

| Term | Meaning |
| --- | --- |
| The Ring, "Object 58" | The alien gate under Site CAIRN. Object 58 is its government file name, after the year it was found |
| Glyph | One of the 36 symbols on the Ring |
| Seal | One position in an address. "Seal seven engaged." |
| Lock | A successful connection to another Ring |
| Origin glyph | The glyph that identifies the dialing Ring; always the last seal. The console fills it in, so players rarely meet it |
| Domain | A region of space with its own 36 anchor points, usually a galaxy |
| Keystone | The tenth glyph. It is not on any Ring and must be made |
| Site CAIRN | The player's base, under the decommissioned Gallow salt works |
| The Shutter | The armoured barrier over the Ring, built in Arc 1 |
| MOTH | Mobile Optical Telemetry Hover, the first probe drone |
| Threshold teams | Off-world teams, designated T-1, T-2 and so on |
| Anterite | The Builders' metal; fuel and material for advanced technology |
| The Directorate | The government agency that runs the program; the player is its Director |
| The Committee | The Joint Oversight Committee, which sets the budget |
| Continuity | A hidden intelligence office inside the government |
| Halcyon Dynamics | A defence contractor that wants the program |
| The Anteri | The vanished builders of the Rings |
| The Ossarin Hierarchate, "the Ossar" | A theocratic empire that claims the Ring network |
| The Halvane | An ancient, dwindling scholar species; generous and demanding |
| The Kindred | Human-descended peoples scattered across many worlds |
| The Murmur | Something that lives inside the network itself |
| The Dravian Federation | A rival power that wants a Ring of its own, or failing that, yours |
| The Meridian Accord | Allied nations that want a share of the program and a say in it |
| The Far Side Protocol | The Directorate's classified name for the program, taken from the 1961 file. Nobody who chose it knows what the Far Side really is |

## How to use this bible

This bible is the source of truth for implementation; code follows it, and design changes land here before they land in code.

| Tab | Holds | Wins conflicts on |
| --- | --- | --- |
| Overview | Pitch, pillars, locked decisions, names | Names and locked decisions |
| Game Design | What the player does; every system | Rules of play |
| Gate & Address Spec | Address math, where addresses come from, the dial console, dialing, puzzle rules | Anything about the Ring |
| Lore & Arcs | History, factions, campaign arcs, endings | Story and canon |
| Technical Architecture | Godot 4 structure and conventions | Code |
| Art & Audio | Look, pipeline, sound | Presentation |
| Roadmap | Milestones, process, open questions | Order of work |

- **Numbers are tunables.** Every number in this bible is a starting value. In code they live in balance data files, never as constants.
- **Milestones cite sections.** Each implementation milestone names the sections it implements, so a review can check the build against the text.
- **Open questions are tracked** at the end of the Roadmap tab until decided.
