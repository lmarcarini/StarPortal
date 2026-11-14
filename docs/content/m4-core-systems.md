# M4 Core systems

The last core systems of FAR SIDE PROTOCOL: factions, conversations, requests, artefacts and a
tech tree that can grow large. Owner direction (2026-11-11): finish the core functionality
first, then refine it from playtests, then the interface, then graphics, and content last.
So M4 builds **mechanisms with just enough test content to play them by hand**. Every screen is
functional placeholder UI; the Interface phase redesigns them.

M4 is two milestones, each ending in a flow test and an owner playtest:

- **M4a Factions and contact:** story conditions and effects, factions and standing,
  conversations (hail, incoming wormhole, phone), requests.
- **M4b Artefacts and technology:** artefacts and their storage rooms, modifiers, a data-driven
  tech tree that scales to hundreds of projects.

Not in M4 (later phases): partial translation and lexicons, expedition Contact objectives and
postures, skill-check nodes in conversations, artefact fates (weaponise, declassify, seal),
incursions, failure states, ripples beyond plain effects, all authored story content.

---

## 1. One language for rules: conditions and effects

Conversations, requests, faction contacts, research and artefacts all need to ask "is this
true?" and to say "make this happen". They share one vocabulary of typed Resources, as the
bible asks ("story is conditions plus effects").

**Conditions** (all read only):

| Condition | True when |
| --- | --- |
| `FlagIs(flag, value)` | `GameState.flags[flag] == value` (missing flag = false) |
| `StandingAtLeast(faction, n)` / `StandingBelow(faction, n)` | the faction's standing (section 2) |
| `FactionMet(faction)` | the faction has been met |
| `ResearchDone(project)` | the project is finished |
| `HasArtefact(artefact)` | the player holds at least one of that artefact (any place) |
| `WorldStatusAtLeast(world, status)` | the world's progress status has reached `status` (Locked, Probed, Surveyed, Contacted) |
| `RequestIs(request, state)` | the newest instance of that request is in `state` |
| `NoDialSince(flag)` | no dial has started since the tick stored in that flag (used by "keep the Ring closed" requests) |

Each condition has a **reason key** for the UI ("Requires Kindred standing 25").

**Effects** (each changes state only through `StoryRules.apply`, from a command or a system):

| Effect | Does |
| --- | --- |
| `SetFlag(flag, value)` | sets a flag (bool, int or String) |
| `StampFlag(flag)` | sets a flag to the current tick |
| `ChangeStanding(faction, delta)` | moves standing; for the Committee it moves Confidence |
| `ChangeMoney(k)` | adds or removes funds ($k) |
| `AddDocument(document)` / `AddAddress(world)` | delivers a document / files an address |
| `OfferRequest(request)` | creates a request offer (section 4) |
| `GiveArtefact(artefact)` / `TakeArtefact(artefact)` | an artefact arrives in Gate Room holding / one is handed over |
| `UnlockResearch(project)` / `CompleteResearch(project)` | reveals a hidden project / marks it done for free |
| `StudyArtefact(artefact)` | marks the held artefact Studied (the end effect of a study project) |
| `Modifier(key, amount)` | only valid on research and artefacts: a lasting modifier (section 6) |

An effect can be marked **hidden**: it still happens, but previews show "?" instead of it. That is
the whole of "hidden ripples" for now.

Every applied effect posts an event and, where the player should know, a Log line.

---

## 2. Factions

A **faction** is a `FactionDef`: id, name, kind (`earth` or `alien`), accent colour, starting
standing, the conversations it can start itself (section 3) and the requests it can offer.

**Standing** is −100 to +100, one number per faction. The government is a faction too: the
**Committee**'s standing *is* Committee Confidence (0 to 100, the existing meter). Effects and
conditions on the Committee read and write Confidence through the existing Confidence causes,
so one system, not two.

**Attitude** is derived from standing, never stored:

| Standing | Attitude | What it means in M4 |
| --- | --- | --- |
| −100 to −50 | Hostile | Sends demands with penalties; hails may be refused |
| −49 to −10 | Unfriendly | Demands, few offers |
| −9 to +24 | Neutral | Occasional requests |
| +25 to +59 | Friendly | Requests and gifts |
| +60 to +100 | Allied | More gifts, better rewards |

The Committee uses its own bands on Confidence (below 30 Unfriendly, 30 to 69 Neutral, 70 and
up Friendly), so its attitude reads the same way.

**Met.** An alien faction is unknown until the first conversation with it. Before that it is not
listed anywhere and its worlds show no owner. Earth factions start met.

**Standing causes.** The last ten changes per faction are kept with their reason, as Confidence
causes are, and shown in the Factions panel.

**Worlds held by factions.** `WorldDef.controller` names the faction that holds an authored
world. The World Report shows "Held by: Kindred" once the faction is met and the world is
probed. Procedural worlds have no controller in M4 (the generator can assign them later).

**Faction-initiated contact.** Once a day, each met faction checks whether it wants to speak:
at most once every `faction_contact_days` (balance, default 4) and only if it has nothing
pending. It picks the first of its own conversations, by priority, whose conditions hold and
that is not used up (`once`). Attitude is just a condition on those conversations
(`StandingAtLeast`, `StandingBelow`), so a gift is a conversation a friendly faction starts, and a
demand is one a hostile faction starts. The chosen conversation becomes a **pending contact**:
alien factions dial in (an incoming wormhole), Earth factions phone.

---

## 3. Conversations

The format in presentation-and-systems.md section 6 stands, cut down for M4: Line, Choice and
End nodes (no Check nodes yet), conditions and effects from section 1, no word tokens.

A `ConversationDef` holds: id, faction, channels (`wormhole`, `incoming`, `phone`), the worlds it
may run at (empty = any of the faction's worlds), its own conditions, priority, `once`, a start
node and nodes. A choice may be `show_locked`: greyed with its reason instead of hidden.

**Running.** One conversation at a time. Opening one forces the clock down to 1× (the player can
still pause). *Since M4.7 this is the `conversation` slow reason: see event-time.md section 2.* A line appears, then the next one after its minutes have passed in game time. At a
choice the clock keeps running; the wormhole keeps draining. The End node applies its effects.
If the wormhole closes (timeout, energy, player) the conversation ends "(signal lost)": effects
on nodes already reached stay applied, the End node's do not.

**Three channels.**

- **Hail** (outgoing): with a wormhole locked to a world that has a controller or people, the
  portal actions gain **Hail**. The game starts the best conversation for that faction, world and
  channel `wormhole`. With none available, the hail gets "No answer." in the Log.
- **Incoming wormhole**: a pending alien contact makes the Ring activate from the far side. The
  game auto-pauses (new pause reason, switchable). The player has 5 in-game minutes to
  **Answer** (the wormhole opens from their side; CAIRN pays no energy; the conversation runs)
  or **Ignore** (the far side gives up; standing −2 and the contact is dropped). While the Ring
  is busy (dialing, locked, incoming) a pending contact waits. No Shutter yet.
- **Phone**: a pending Earth contact lights a **call waiting** lamp on the time bar. The player
  answers whenever; unanswered calls expire after `phone_expiry_days` (balance, default 2) with
  Committee Confidence −1.

**Transcripts.** Every conversation, finished or cut off, is saved as a transcript: the
conversation id, the channel, the tick and the path (nodes reached, choices made). The Archive
renders it from the path, so later changes such as translation (a later phase) apply to old
transcripts.

---

## 4. Requests

A `RequestDef`: id, faction, title and text keys, **objective** (a list of conditions that must
all hold), optional deadline in days (0 = none), offer lifetime in days, and three effect lists:
**reward**, **penalty** (on failure) and **on decline**.

Lifecycle (an explicit state machine):

```
OFFERED --accept--> ACTIVE --objective holds--> FULFILLED (reward)
   |                   \--deadline passes-----> FAILED   (penalty)
   |--decline---------> DECLINED (on decline)
   \--offer lifetime--> LAPSED   (on decline)
```

- Offers come only from the `OfferRequest` effect: in a conversation, a gift, a demand, or a
  research or flag trigger. The same request can be offered again once its last instance is closed.
- The objective is checked every in-game hour while active and right after the commands that
  most often complete one (hand-over, research done, world status raised). Fulfilment is
  automatic, with a Log line and a non-pausing message.
- A hand-over is done in a conversation: the faction's conversation has a choice with
  `HasArtefact` and `TakeArtefact`, which sets the flag the objective reads.
- Previews show the reward, penalty and decline effects in plain words, hidden ones as "?".

**Kinds of objective the test content covers:** reach a world status (survey this world),
finish a research project, hand over an artefact, keep the Ring closed for N days (`StampFlag`
at accept, `NoDialSince` plus a deadline that counts as success: a request can set
`deadline_succeeds`, so reaching the deadline with the objective still holding fulfils it).

---

## 5. Artefacts

An `ArtefactDef`: id, name and description keys, **storage class** (`vault` or `containment`),
modifiers while housed, and an optional **hazard**.

**Where they come from.** `GiveArtefact` (rewards, gifts, conversations) and recovering a world
target whose `WorldTargetDef.artefact_id` names one.

**Holding.** A new artefact arrives in **Gate Room holding** (on the Ring floor, capacity 2 from
balance). There it is inert. Holding can never go over capacity. If holding is full, an arriving
artefact **waits at the gate**: it is kept, listed as "at the gate", and cannot be housed or
studied. When holding has a free place, the player **retrieves** it into holding (nothing is ever
lost, and there is no Confidence cost).

**Housing.** Storage rooms are new rooms with **artefact slots**:

| Room | Size | Slots | Draw | Class |
| --- | --- | --- | --- | --- |
| Artefact Vault | 4 × 3 | 2 | 5 MW | vault |
| Containment | 3 × 3 | 1 | 10 MW | containment (also holds vault class) |

The player moves an artefact from holding into a free slot of a fitting room (and back).
A housed artefact's modifiers apply while its room is built and switched on. A room with an
artefact cannot be demolished until it is emptied.

**Hazard.** An artefact may have a hazard: while it is *not* in Containment (holding or a vault),
each day it rolls `hazard_chance`; on a hit its hazard effects apply (for example −10 MWh stored,
Confidence −2, an injury) with a Log line and an alert. Containment makes it safe.

**States.** Recovered (just arrived) → Housed → Studied. Studying is research: a project that
requires `HasArtefact(x)` and on completion sets the artefact Studied and unlocks the next
projects. Fates (weaponise, declassify, trade, seal) are left for a later phase; trading is
already possible through requests.

---

## 6. Modifiers

A modifier is a key and an amount. Sources: housed, powered artefacts and finished research.
`ModifierRules.total(state, key)` sums them. Keys in M4:

| Key | Unit | Read by |
| --- | --- | --- |
| `research_speed_pct` | % | research progress |
| `build_speed_pct` | % | construction and digging |
| `allocation_k` | $k per day | daily economy |
| `upkeep_pct` | % | daily upkeep |
| `plant_output_mw` | MW per plant | power |
| `charge_rate_pct` | % | capacitor charging cap |
| `dial_cost_pct` | % | dial and hold energy |
| `wormhole_minutes` | minutes | maximum open time |
| `field_check_bonus` | points | expedition field checks |
| `moth_battery_pct` | % | MOTH battery |

Percent keys add up and are clamped (−90 % to +300 %). The total is cached and recomputed only
when a source changes (artefact moved, room switched or built, research done, load).

---

## 7. A tech tree that can be huge

Today's research is seven projects, with their effects duplicated in code (`UnlockRules.PROJECTS`)
and "Unknown" locked slots. For hundreds of projects:

1. **Effects as data only.** `ResearchDef.effects` become effect Resources (section 1) plus the
   existing unlock effects (`unlock_room`, `dig_depth`, `bank_cap`, `plant_upkeep`) and
   `Modifier`. The code table goes.
2. **Requirements beyond projects.** `ResearchDef.requires` is a list of conditions
   (artefact held, standing, flag, world status) on top of `needs`. `reveal` says whether an
   unmet project is **hidden** or **shown locked** with its reasons. The `lock` slots go;
   `UnlockResearch` reveals a hidden one.
3. **Branches.** Categories become the bible's branches plus the existing ones: Construction,
   Energy, Gate, Defence, Life and language, Alien, Staff. Data only.
4. **Queue.** The player queues up to 5 projects; the next starts when the current one finishes
   and its cost can be paid, otherwise it waits with a reason.
5. **A tree view for 200+ nodes.** Pan and zoom, filter (available, done, locked), search by name,
   cross-branch stubs that jump to their branch, and a performance budget checked by a test with
   generated defs.
6. **A tree validator.** No cycles, no project that can never become available, unique orders,
   a size report per branch.

Test content: about 36 projects over the seven branches, mostly modifiers and room unlocks,
including three artefact studies, so the tree is big enough to exercise the view.

---

## 8. Test content (minimal)

Placeholder English text; pt_BR strings copy the English with a `[EN]` prefix until the
Content phase (PO ruling, so the localisation tests pass).

- **Factions:** the Committee (government, earth), the Kindred (alien, start +10), the Ossar
  (alien, start −40).
- **Worlds:** two small authored test worlds: HEARTH (Kindred settlement, people, low threat)
  and TOLLGATE (Ossar outpost, structures, high threat), with targets, one recoverable artefact.
- **Conversations (about 7):** Committee briefing by phone (gives both addresses, offers
  request 1); Kindred first hail; Kindred return hail (offers request 2; hand-over choice);
  Kindred gift (incoming, friendly); Ossar hail (hostile); Ossar demand (incoming, offers the
  keep-closed request); Committee check-in (phone, after a request).
- **Requests (4):** survey HEARTH within 10 days (Committee, reward Confidence +5, $500k);
  finish a research project (Kindred, no deadline, reward an artefact); hand over an artefact
  (Kindred, reward standing +20 and `UnlockResearch`); keep the Ring closed 5 days (Ossar,
  reward standing +15, ripple Kindred −5, penalty Ossar −10).
- **Artefacts (3):** Resonant Lattice (vault, charge rate +25 %), Kindred Loom (vault, research
  speed +15 %), Ossar Effigy (containment, dial cost −20 %, hazard: −20 MWh stored, 20 % a day
  outside containment).
- **Tech tree:** section 7.

A debug overlay button may grant any artefact, standing or flag, to test quickly.

---

## 9. Save format

All new saved data arrives in one contract card (save v16) so feature cards do not collide on
version bumps: `factions`, `conversations`, `requests`, `artefacts`, `research.queue`,
`research.revealed` and `gate.incoming`. A later card that must change a saved shape bumps the
version itself and says so in its PR.

## 10. Open questions for the owner

1. **Incursions and failure states** — *Owner decision 2026-11-12:* a short M4c after M4b.
2. **Ignore an incoming wormhole** costs standing −2. *Owner decision 2026-11-12:* a hostile
   wormhole cannot send anything through in M4. *Since M4c, a hostile faction can send an
   incursion through the Ring: see m4c-incursions.md section 1.*
3. **Over-capacity holding** — *Owner decision 2026-11-12:* holding cannot go over capacity;
   an artefact that arrives while holding is full waits at the gate and can be retrieved once
   there is room. No Confidence cost.

## 11. Cards

M4a: #252 to #271 (M4-01 to M4-20). M4b: #272 to #287 (M4-21 to M4-36). Each card is self-contained and links back here.
