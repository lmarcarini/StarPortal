# Art and Audio Direction

## Visual direction

The look is Cold War bureaucratic science fiction: pre-rendered rooms with baked light, pushed toward the restricted palettes, heavy shadows and blunt shapes of Papers, Please.

- **Restricted palettes.** Each area has four to six colours plus one accent. Colour carries meaning, and the player learns it.
- **The Ring's blue** is the only saturated blue in the game. When it appears, something is open.
- **Grit over shine.** Grain, slight dithering, worn paint, stencilled labels.

| Area or faction | Base tones | Accent |
| --- | --- | --- |
| Base interior | Concrete grey-green, olive | Sodium-lamp orange |
| Command and analysis | Off-white, cork brown | CRT green |
| The Ring | Gunmetal | Event-horizon blue |
| Alarms and incursions | Darkened base tones | Klaxon red |
| Ossar | Bone, bronze | Liturgical gold |
| Halvane | Pale stone | Soft violet |
| Kindred | Earth, textile colours | Hearth amber |
| The Murmur | Desaturated everything | A blue that is slightly wrong |

## Pre-rendered pipeline

Rooms and characters are modelled in Blender and rendered to sprites. This gives rich lighting at the cost of a 2D game, which suits low-end PCs.

1. **Model** each room in Blender on a shared grid, so every room fits a slot.
2. **Render** with a fixed straight top-down orthographic camera for base rooms (warm sodium lighting, concrete, furniture visible from above); staff are dots on the plan, full sprites only in the Gate Room and cutscenes (the Gate Room view is a fixed perspective shot through the control room glass) at twice the target size, with baked lighting.
3. **Post-process** in a script: palette quantisation, light dither, grain. The script is the same for every asset, so the style stays consistent.
4. **Export** variants per room: idle, active, damaged, alarm-lit.
5. **Characters:** one rigged base body with swappable uniforms, rendered as sprite sheets facing left and right, with walk, work and idle cycles.
6. **Lighting in engine:** 2D lights and tinted overlays for alarms, power cuts and the Ring's glow.

Art arrives in three stages, each replacing the last file for file with no code changes: grey-box placeholders now, Claude-generated Blender art later in development, and a commissioned artist only if the game proves promising.

## Drone feed and cutscenes

The drone feed is the one place the game goes first-person, and its low fidelity is the point: the player sees an alien world through a cheap government camera.

- **Feed rendering:** low-poly 3D, at most about 20,000 triangles per scene, in a 320 × 240 SubViewport.
- **Feed shader:** scanlines, chroma bleed, noise, and interference that rises as the signal weakens. Overlays show a timecode, battery, signal strength and scan prompts.
- **Feed scenes:** procedural worlds are assembled from biome kits and prop sets; story worlds are built by hand.
- **Cutscenes:** mostly pre-rendered stills with parallax layers, voice and radio audio. Short videos are kept for the biggest moments: the first lock, the first Ninth Seal dial, and the Tenth Seal.
- **Budget:** 8 to 12 cutscenes across the campaign.

## UI and typography

The interface looks like government equipment, not paperwork: panels, dials and labels, with documents kept to the Archive for players who want them.

- **Materials:** CRT panels, stencilled labels, label-maker tape, toggle switches and rubber-stamp confirmations for irreversible actions.
- **Fonts:** IBM Plex Mono for terminals and data; Barlow Condensed for labels and headings. Both use the SIL Open Font License.
- **Readability:** body text at least 16 px at 1080p. A UI scale setting runs from 80% to 150%.
- **Status:** colour plus shape or icon for every status, so it reads without colour.
- **Glyphs** are drawn as clean vector icons in the UI, matching the carved versions on the Ring.

## Audio direction

Sound sells the weight of the Ring and the isolation of the base; the dial sequence is the game's signature sound and gets the most care.

- **The dial:** heavy mechanical clunks for each seal over a rising hum, then the event horizon's burst. Nine and ten seals add layers that sound like strain.
- **Radio:** key lines are fully voiced through a band-pass filter, with static that grows with distance and danger. Other lines voice only their opening words, then continue as text.
- **Base ambience:** changes with depth. The surface is wind and vehicles; the deep levels are ventilation and the Ring's low drone.
- **Alerts:** a klaxon for incoming wormholes, a distinct tone for each auto-pause reason.
- **Music:** analog synthesisers and low strings in three adaptive layers: calm, tension and incursion.
- **Factions:** each has a sonic motif, such as Ossar choral drones or Halvane glass tones.

**Voice in two languages.** Key lines are recorded in English and Brazilian Portuguese. Opening-words clips are short, so both languages stay affordable.
