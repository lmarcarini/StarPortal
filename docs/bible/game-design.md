# Game Design

## Core loop

The core loop is: gather clues, deduce an address, dial, probe, send a team, bring back artefacts and clues, research, then spend the results. Base, power, money and politics are the pressure around that loop.

*Diagram (see the live design doc): core loop · 6 steps inside the pressure of the base*

Dialing is the one step that spends the scarcest resource, so every other step exists to make a dial worth it.

The player moves between six views that share one clock:

| View | What the player does |
| --- | --- |
| Base | Dig levels, build rooms, route power, assign staff, defend during incursions |
| Gate Room | Dial, watch seals engage, work the Shutter, monitor an open wormhole |
| Analysis | Pin clues on the Analysis Board, build addresses in the Address Workbench, use the Star Atlas |
| Expeditions | Choose teams and loadouts, watch the drone feed, make field decisions |
| Research | Analyse artefacts, run the tech tree, decide what each technology becomes |
| Command | Budget, Committee, faction relations, requests, news |

A typical in-game day: a new dossier and a Committee request arrive. The player puts analysts on the dossier, charges the capacitors, dials a candidate address and sends the MOTH. A team goes through while research ticks along. Then an unscheduled incoming wormhole forces a decision.

## Time: real time with pause

The simulation runs on a fixed tick of one in-game minute. At 1× a tick lasts one real second, so an in-game day takes 24 real minutes. Speeds are pause, 1×, 3× and 10×, and every command works while paused.

Real time earns its place through windows and drains:

- **Open-wormhole drain.** An open connection draws power every minute, so each probe and transit is a race.
- **Maximum open time.** A wormhole closes itself after 60 in-game minutes. Teams must reach the far Ring and dial home in time.
- **Incoming wormholes.** When someone else dials CAIRN, the game auto-pauses. Within 5 in-game minutes the player closes the Shutter, checks for an identification code, or lets it open.
- **Check-ins.** Teams report on a schedule. A missed check-in opens a rescue window.
- **Calendar.** Budget arrives on the 1st of each month; the Committee reviews every quarter.
- **Parallel clocks.** Research, recruitment, construction and faction plans all advance at once, so priorities matter.

Nothing demands reflexes. Urgent events auto-pause by default, and the player can switch each auto-pause reason on or off.

## Resources and economy

Money and power are the two hard limits; the political meters decide how much of each the player gets.

| Resource | Comes from | Spent on | Edge case |
| --- | --- | --- | --- |
| Budget ($M) | Committee allocation, technology licences, Halcyon contracts, black funds | Salaries, construction, upkeep, research, purchases | Below zero at three month-ends in a row = bankruptcy |
| Power (MW output, MWh stored) | Generators and reactors; capacitor banks store it | Rooms, research, dialing, the Shutter, defences | A lock draws from storage; an open wormhole draws from output |
| Personnel | Recruitment pipelines, alien volunteers | Staffing rooms and teams | See Personnel below |
| Materials (t) | Purchases, salvage, outposts | Construction, prototypes | Ordered with a delivery delay |
| Anterite (kg) | Expeditions, trade, outposts | Advanced technology, reactors, long-range dialing | The rarest resource |
| Committee Confidence (0–100) | Results, compliance, quiet operation | Sets the monthly allocation | 0 = shutdown |
| Exposure (0–100) | Leaks, incidents, declassification, grid taps | Raises scrutiny and helps rivals | 100 before Arc 5 = exposure failure |
| Faction standing (−100 to +100) | Requests, trade, gifts, combat | Unlocks trade, gifts and joint operations | Low standing invites incursions |
| Morale (0–100, per person and base) | Rest, wins, quarters, losses | Work speed and loyalty | Low morale causes resignations and leaks |

The monthly allocation is a base amount scaled by Confidence. Licences pay monthly. Black funds come from Continuity or covert sales, and each use raises the chance of a scandal.

## Base building and power

The base is a side-on cutaway of levels dug under the salt works; the player grows it downward, and the Ring sits on the deepest original level.

- **Levels.** The game starts with three levels plus the surface. Each new level costs money, materials and days of excavation. A level holds eight room slots; lifts and stairs connect levels.
- **Rooms.** Each room has staff slots, a power draw and upkeep. Neighbours give bonuses, such as a lab beside the Archive researching faster.
- **Blast doors.** Every level has them. Their placement decides chokepoints during incursions.

| Room | Purpose |
| --- | --- |
| Gate Room | The Ring and its dialing rig; fixed |
| Control Room | Commands dialing and defence; losing it is fatal |
| Power Plant | Generates power; upgrades through tiers |
| Capacitor Bank | Stores energy for dialing |
| Labs: physics, xenobiology, linguistics, engineering | Research |
| Analysis Centre | Analysts work clues and verify sources |
| Archive | Stores dossiers and artefacts; holds the Codex |
| Workshop | Builds prototypes and equipment |
| Barracks and Armoury | House and equip soldiers |
| Infirmary | Treats injuries, illness and contamination |
| Quarters and Mess | Morale |
| Containment and Quarantine | Hold dangerous artefacts, prisoners and the exposed |
| Hangar (late) | Vehicles and, later, alien craft |

**Power** is supply against demand, settled every tick. The player ranks rooms by priority, and during a shortfall the lowest-ranked shut down first. Dialing needs a full charge in the capacitors before the first seal.

Power plants upgrade through four tiers: diesel, fission, anterite cell, and the Halvane tap from Arc 4. In an emergency the player can tap the national grid. It gives instant energy, but raises Exposure and costs Confidence.

## Personnel, military and expeditions

People are the scarcest thing in the base: they take weeks to recruit and clear, and every one can be lost, hurt, or turned.

- **Roles:** scientist (physics, xenobiology or linguistics), engineer, soldier, medic, analyst.
- **Each person has** a name, two traits, skills rated 1 to 5, stress, injuries, clearance level, and a hidden loyalty. Some recruits are Continuity or Halcyon plants.
- **Recruitment** runs through pipelines: military, academia and intelligence. Each has a lead time and a cost. Skipping the clearance check is faster but riskier.
- **Military assets** are lent by the Directorate: security squads defend the base, Threshold teams go off-world, vehicles arrive mid-game. Using them on faction business costs Confidence.

A Threshold team has four members: a leader, a scientist, a soldier and a specialist. An expedition runs in six steps:

1. **Dial and lock.** The address must be known and the capacitors charged.
2. **Probe.** The MOTH or a later probe reports on the far side (see the Gate spec).
3. **Plan.** Choose the objective: survey, contact, recover, rescue, trade or establish an outpost. Then pick the team, loadout, duration and check-in schedule.
4. **Transit.** The team steps through while the open-wormhole drain runs.
5. **Field.** Events play out on a timeline. Skill checks resolve most; key moments auto-pause for a decision. News arrives only at check-ins.
6. **Return.** The team dials home inside its window, or a rescue is mounted.

Results can include artefacts, clues, first contact, resources, injuries, deaths, and Exposure if something follows the team home. A surveyed world can host an **outpost** that produces resources but must be supplied and defended.

## Research, artefacts and transformations

Everything the player finds changes state, and most state changes are choices; this is the transformation engine of the game.

An artefact moves through **Recovered, Catalogued, Analysed, Understood**. At Understood the player picks one fate:

- **Weaponise:** military technology. Confidence rises; the Ossar notice.
- **Declassify:** a public product with monthly licence income and a Confidence boost. Exposure rises, and Halcyon or the Dravian Federation gains a copy.
- **Trade:** give it to a faction for standing, anterite or clues.
- **Seal away:** store it in Containment. Safe, but nothing gained, and some sealed items do not stay quiet.

A technology then goes **Prototype, then Production**. The tech tree has four branches:

| Branch | Examples |
| --- | --- |
| Gate | Seal telemetry, the Shutter, Ring memory, the domain glyph, the Keystone cradle |
| Power | Fission plant, anterite cell, capacitor lattice, Halvane tap |
| Defence | Body armour, energy weapons, point defence, Shutter reinforcement |
| Life and language | Field medicine, xeno-pathology, translation matrices, Murmur screening |

Some technologies cannot be declassified without revealing the program; the UI says so before the choice.

The same idea, a thing moving through states, runs through the whole game:

| Thing | States |
| --- | --- |
| Clue | Found, read, applied as constraints, verified or exposed as false |
| World | Unknown, locked, probed, surveyed, contacted, then allied, outpost, hostile or quarantined |
| Technology | Secret, military, public |
| Person | Recruit, veteran, specialist; injured, changed by alien exposure, or turned |
| Base | New levels and rooms; the Ring gains the Shutter, telemetry, a ninth-seal capacitor, the Keystone cradle |
| Faction | Stranger, contact, then ally or enemy; internal splits during its arc |

## Factions, requests and politics

Every faction, the government included, wants something from the player, and helping one usually costs another.

- **Standing** runs from −100 to +100 per faction. Thresholds unlock trade, gifts and joint operations, or trigger incursions and sabotage.
- **Requests** come from the Directorate, the Committee and every faction. Each has a deadline, a reward, a cost and ripples to other factions. The ripples are shown before the player accepts, but hidden ones exist.
- **Committee reviews** happen each quarter. The player chooses which results to present. Overstating them buys Confidence now and risks a scandal later.
- **Dossiers** are the government's main output and the main source of clues. Each is a set of claims, and some are planted. Catching a lie gives the player leverage over whoever planted it.

| Example request | From | Reward | Ripple |
| --- | --- | --- | --- |
| Arm a Kindred village against an Ossar patrol | Kindred | Kindred +20, a clue | Ossar −15, Exposure +2 |
| Hand over the first energy weapon for testing | Committee (Sen. Vosk) | Confidence +10, $40M | Halcyon gets a copy |
| Close the Ring for 30 days during a toll dispute | Ossar | Ossar +15, no incursions for the period | Kindred −10, research delayed |
| Let Continuity interview a returned team alone | Continuity | Black funds | Team morale −20, one hidden fact lost |
| Escort a Halvane archivist to a dead world and back | Halvane | A sky chart of a key world | None visible; the Halvane remember broken promises |

## Threats, invasions and failure states

Threats come through the Ring, from inside the base, and from the surface; each failure state has warning signs well before it ends the game.

- **Incursions** come through the Ring. The Shutter stops most of them, until the Ossar learn to breach it in Arc 3.
- **Sabotage and leaks** come from plants, low morale or careless declassification.
- **Outpost raids** hit worlds the player holds.
- **Accidents:** reactor faults, and overloads when dialing nine or ten seals.
- **Contamination** by the Murmur, from Arc 6.

Incursions play out in the base cutaway in real time. The player assigns squads to levels, seals blast doors, falls back, and protects the Control Room and the Power Plant. Enemies path toward objectives, not toward the nearest soldier.

| Failure | Trigger |
| --- | --- |
| Bankruptcy | Budget below zero at three month-ends in a row |
| Shutdown | Committee Confidence reaches 0 |
| Overrun | Enemies hold the Control Room for 30 in-game minutes |
| Destruction | Reactor meltdown, Ring overload, or the self-destruct |
| Exposure | Exposure reaches 100 before Arc 5; after that Exposure becomes public opinion |
| Takeover | Continuity's coup succeeds in Arc 2 |
| Contagion | A Murmur breach spreads past Quarantine |

Losing a team, an ally or an outpost hurts but never ends the game. Saving is free by default; an optional Ironman mode keeps one save that updates every in-game day.

## Campaign and sandbox

The campaign gives the game its spine; the sandbox elements keep the space between story beats open and replayable.

- **Campaign.** A prologue and seven arcs, detailed in the Lore & Arcs tab. Each arc has goals, a rule change and an exit condition. Arcs begin when milestones are met; the player can linger, but faction clocks keep running.
- **Faction arcs** advance on their own triggers and timers, alongside the main arc. They can collide with it.
- **Procedural worlds** fill the network between authored story worlds. They come with generated clue sets, so exploration never runs dry.
- **Side mysteries** are optional chains of clues with lore and technology rewards.
- **After the ending,** play continues in the same save with the arcs closed.
- **Sandbox mode** is a separate start with arcs switched off, a chosen seed and adjustable rules.

## Difficulty and accessibility

Difficulty changes how forgiving the base is, never how the puzzle works; accessibility makes the whole game playable for more people, and both are designed in from the first build.

**Difficulty** offers three presets plus a slider for every setting. Choosing a slider value turns the preset label to Custom.

| Setting | Analyst (easy) | Director (normal) | Black Budget (hard) |
| --- | --- | --- | --- |
| Budget allocation | 130% | 100% | 80% |
| Power and dialing costs | 75% | 100% | 120% |
| Failed-dial energy cost | 5% | 10% | 20% |
| Clue redundancy | Extra clue per address | Standard | Standard |
| Analyst hints | Frequent | On request | Off |
| Planted clues | Fewer, easier to catch | Standard | More frequent |
| Incursion strength | 70% | 100% | 130% |
| Research speed | 125% | 100% | 85% |

The address rule and the puzzle tuning rules never change with difficulty.

**Input.** The whole game plays with keyboard and mouse or with a gamepad, and the player can switch at any moment.

- Every action is remappable, with two bindings per action per device.
- Hold or toggle can be chosen for every held action.
- On a gamepad, menus use focus navigation and on-screen prompts follow the last device used.
- The Workbench and Analysis Board support click-to-pick and click-to-place as well as dragging.
- Drone piloting has adjustable sensitivity, dead zones and axis inversion.
- Hold-to-confirm durations are adjustable.

**Visual.**

- UI scale from 80% to 150% and a separate text size setting.
- Colour-blind modes; every status also uses a shape or icon.
- A high-contrast UI mode.
- Individual toggles for scanlines, grain, chroma bleed, screen shake and flicker on the drone feed and in cutscenes.
- A reduced-flashing option that softens the event-horizon burst and alarm lights.
- An optional dyslexia-friendly font.

**Audio.**

- Subtitles on by default, with speaker names and an adjustable size and background.
- Captions for important sounds, such as the klaxon and an incoming wormhole.
- A visual cue for every audio alert.
- Separate volume sliders for music, effects, voice and ambience.

**Time and focus.**

- No action requires fast reactions; urgent events auto-pause by default.
- An extra 0.5× speed.
- An objectives journal and glossary tooltips on game terms.
- The tutorial can be replayed from the Codex.
