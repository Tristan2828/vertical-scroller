# Game Design Document

> Name: working title **vertical-scroller** (the real name comes later).
> Last updated: 2026-10-12 (planning Q&A, before any code)

A pixel-art vertical scrolling space shoot'em up roguelite for online co-op with friends. Mostly **Sky Force Reloaded** (destructible ground, an HP bar, pickups, stage goals, readable bullets), with a bit of **Jamestown** (co-op on one shared screen, distinct ships, focus mode). You fly through enemy facilities and outposts, not empty sky.

Items marked **(draft)** are proposals written up from the Q&A that haven't been confirmed yet. Confirm or change them, then drop the mark.

---

## 1. Vision

- **Pillars**
  1. **The world is the target.** You fly over facilities that shoot back, and you can wreck them. The background is half the level.
  2. **Readable danger.** Sky Force-level bullet density: aimed shots and clear patterns, where danger comes from many sources at once rather than walls of bullets.
  3. **Better with friends.** Online co-op for 1–4 players on one shared screen; solo is fully supported.
  4. **Simple hands.** The gun fires by itself. Move, focus, and one special button.
  5. **A different run each time, on familiar ground.** Hand-made stages that you learn; random shop offers, drops, wave variants and modifiers keep runs fresh.
- **Audience:** me and my friends; not for sale. The long-term goal is a complete game.
- **Platform:** Windows PC.

## 2. Tech

| Item | Decision |
|---|---|
| Engine | Godot 4.7.2, as in Medieval Survival |
| Language | GDScript, **statically typed** throughout |
| Development | AI-assisted coding; everything text-editable and verifiable with `godot --headless` |
| Code reuse | Proven parts of Medieval Survival (`C:\Repos\GameTest`) are **copied in when first needed** and trimmed to fit. No shared library and no rewrite from scratch (see §8) |
| Networking | Godot high-level multiplayer (ENet), host-authoritative, direct IP + UPnP, invite paste. Solo = offline peer acting as host |
| Input | Keyboard, gamepad and mouse are all first-class (§3 *Controls*) |
| Base resolution | **960x540**, full-width 16:9 play field |
| Scaling | 1080p = 2x, 4K = 4x (crisp). 1440p = 2.67x: **"Sharp" (default)** fills the screen with fractional scaling plus a sharp-bilinear shader; **"Pixel-perfect"** draws 2x with black borders. A Settings toggle switches between them |
| Tests | GUT (with the `run_tests.ps1` wrapper), plus a headless host+client smoke test |
| Builds | `build.ps1` / `release.ps1` / in-game updater / Discord announcements, copied from Medieval Survival |

### Networking approach
A vertical scroller is friendlier to netcode than an arena game: everyone shares one screen, and most of the world is scripted.
- **Stage time is the shared clock.** The scroll position, ground object positions and scripted enemy positions are all pure functions of stage time, so every peer computes them itself. Nothing about them is sent each frame.
- **Scripted enemies:** the host sends *spawn* (wave id, variant, seed, time), *damage/death* events and drops. Peers compute the flight paths.
- **Homing enemies** (a few types): small position snapshots, or deterministic homing on synced player positions.
- **Ground objects:** fixed in the stage data with ids; the host sends "object #47 destroyed".
- **Bullets:** pattern events only (pattern id, origin, aim, seed, time), simulated on every peer, as in Medieval Survival.
- **Own ship:** client-predicted with the same pure motor code; corrected from host snapshots.
- Rules carried over: keep unreliable RPCs under ~1390 bytes, never send an empty `PackedByteArray` as the only argument, use pools for everything, and keep append-only registries for anything sent as an id.

## 3. Core gameplay

### Format
- A **run** is a fixed sequence of stages (§3 *Stages*). The first target is **~15 minutes**; later, **20–25 minutes** (more stages).
- Each stage scrolls upward at its own speed, holds for the **boss** at the end, then shows results and the **shop**.
- A Vampire Survivors-style mode may come later as a **separate game mode** (Medieval Survival's code can help).

### Stages (first run)
| # | Stage | Length | Boss |
|---|---|---|---|
| 1 | **Planet-side military base**: bunkers, radar dishes, runways, tank columns | ~4 min | Stage boss |
| 2 | **Orbital shipyard**: half-built hulls, cranes, docking bays, hangars that launch fighters | ~4 min | Stage boss |
| 3 | **Capital ship surface**: fly over the flagship's hull, tearing off turrets | ~4 min | Stage boss |
| 4 | **Flagship core**: a boss-only arena stage | ~2–3 min | Final multi-phase boss |

The story escalates: hit the planet base, then the shipyard building the fleet, then the flagship itself.

**Stage timeline (draft):** intro (10 s) → air waves mixed with ground sections → a mid-stage set piece (e.g. a hangar opening, a convoy) → more waves → the scroll stops → boss (60–90 s).

### Variety between runs
- **Random shop offers** (§4).
- **Random pickup drops**: which timed boosts drop, and where.
- **Wave variants**: some waves in each stage have 2–3 versions, picked at random.
- **Stage modifiers**: a random twist per stage with a bonus reward. Draft list: *Elite Wing* (one wave replaced by elites), *Armored Turrets* (ground objects have more HP), *Ion Storm* (darker screen, lightning flashes), *Reinforcements* (extra ground turrets).

### Controls
| Action | Keyboard (default) | Keyboard (classic alt) | Gamepad | Mouse mode (optional) |
|---|---|---|---|---|
| Move | WASD / Arrows | Arrows | Left stick / D-pad | Ship glides toward the cursor |
| Focus (hold) | Shift | Z | RT or A | Right click |
| Special | Space | X | B / RB | Left click |
| Fire toggle (if enabled) | F | C | Y | Middle click |
| Pause | Esc | Esc | Start | Esc |

- **Auto-fire setting:** **Always** (default; you never hold a button) / **Toggle** (adds the on/off key) / **Hold** (classic).
- **Focus:** while held, the ship moves slower and the main gun narrows into a stronger forward stream; the hitbox dot is shown. Focus always fires, even if auto-fire is toggled off.
- Gamepad works in every menu (carry over Medieval Survival's `ui_accept` + A fix).

### Player ship
- **HP bar** (Sky Force-style chip damage). Draft numbers: 100 HP, enemy bullets 8–20 damage, contact damage on collision, a short invulnerability blink after each hit.
- **Hitbox** much smaller than the sprite (a few pixels), shown during focus.
- **Ships are data:** main gun + stats (HP, speed, focus speed, hitbox) + sprite, like the heroes in Medieval Survival. **Start with 1 ship**; each later ship is mostly a new main gun, some numbers and a sprite.
- In co-op, each player's ship is recolored per player (the `P`/`p` palette recolor trick from Medieval Survival).

### Main gun power
- **Power levels for the run (draft: 1–5)**, raised by power orbs dropped by enemies. Each level adds bullets, spread or damage, defined per ship. Draft: dying loses 1 level.
- **Timed boosts** (draft, 10–15 s each): *Rapid Fire*, *Wingmen* (two side drones fire with you), *Magnet* (pulls in drops), *Piercing Shot*. Random drops.

### Specials (one button, equippable on any ship)
- One special is equipped at a time; you choose it before the run and can swap it in the shop.
- **Charges refill at the start of each stage; the number of charges differs per special.** Pickups (rare) and the shop add charges. **Unused charges pay out as currency** at the end of a stage, so holding one is a real choice.
- Draft list:
  | Special | Charges | Effect |
  |---|---|---|
  | Mega Bomb | 1 | Clears enemy bullets on screen, heavy damage to everything |
  | Shield | 3 | 3 s of invulnerability; bullets touching it are destroyed |
  | Laser | 2 | 4 s piercing beam straight ahead |
  | Swarm Missiles | 2 | A volley of homing missiles |
- First build: Mega Bomb + Shield.

### Enemies
- **Air enemies fly scripted paths** (classic waves and formations), plus **a few homing types** (kamikaze drones, a tracking gunship) that turn toward the nearest player.
- **Waves are written as text data:** a library of **named path shapes** in code (S-curve, dive-and-retreat, circle-strafe, cross-screen, hover-and-leave...) and stage files that say *which shape, when, where, how many, which gun*. Easy for both the owner and Claude to edit.
- **Ground objects** (destructible, Sky Force-style): turrets, tanks, bunkers and buildings placed in the stage map. They scroll with the background, shoot up, take hits, show a destroyed version, and drop currency. Drawn under the air layer, with a clear visual language: darker, desaturated ground, bright enemy bullets. **Staged rollout:** the first build has 2–3 turret types and a few buildings; each stage adds more.
- Player bullets hit both air and ground.
- **Bullet density: Sky Force level.**

### Bosses
- Every stage ends in a boss; the final stage is a bigger multi-phase boss (the flagship's core).
- Bosses run attack scripts (steps of patterns and movement), like Medieval Survival's `BossBrain` / `BossStep`. Draft: destructible parts (turrets on the boss) that weaken it when shot off.

## 4. Progression

### Currency (draft name: **Scrap**)
Scrap (Sky Force's stars) is dropped by enemies and ground objects, paid for stage goals, and paid for unused special charges. It's called Scrap so it isn't confused with *respawn credits*.

### Shop (after every stage)
- **Random offers each visit** (draft: 4 personal items + 1 team item).
- Draft items. *Personal:* main gun power +1, repair HP, max HP up, special charge +1, swap special, speed up. *Team:* respawn credit +1, a team boost for the next stage.
- **Co-op wallet:** one shared team wallet. When the shop opens it's **split evenly** between players; each spends their share, and **"Chip in"** adds your Scrap to a teammate's purchase. Leftovers return to the pool.
- **Ready-up:** the next stage starts when everyone is ready; a **60 s soft timer** starts once half the team is ready.

### Stage goals (Sky Force medals) + light score
- Each stage has 3–4 goals that pay Scrap. Draft list: destroy 70% of enemies, destroy 100%, nobody on the team takes damage, destroy every ground structure, beat the boss within X s. Stage modifiers add a bonus goal.
- A simple **score** (kills, ground objects, goals) and a **personal best** are shown on the results screen.
- Later, goals may also earn permanent progression (like Sky Force's medals).

### Meta (later)
Permanent progression comes later: unlock ships, specials and boosts; maybe medals as unlock currency. Not in the first builds.

## 5. Co-op rules
- 1–4 players, one shared screen, one scroll speed.
- **Death:** a downed ship respawns at the bottom of the screen **after a short delay** (draft: 3 s, with 2 s of invulnerability), using a **shared team pool of respawn credits** (draft: 3 per run; more can be bought in the shop). (Revive-by-hovering from Medieval Survival doesn't fit a scroller.)
- A player who goes down with the pool empty spectates until the next stage (draft); the **run ends when every player is down with no credits left**.
- **Scaling:** enemy and boss HP rise **partially** per extra player (draft: +60%, tuned in playtests); bullet patterns stay the same. Co-op-only bonus waves may come later as data.
- Scrap is shared (§4); pickups such as power orbs and boosts go to whoever touches them (draft).

## 6. Art & audio
- **Pixel art at 960x540**, plain at first; **2D normal-map lighting** (lit explosions, engine glow) is decided once the game is playable.
- The **game logic doesn't depend on how it's drawn** (pure simulation code), so a different look (even low-poly 3D) stays possible later.
- **First art source: downloaded asset packs** (sci-fi shmup ships, bullets, tilesets), imported and recolored to one palette with gamekit (`/gamekit:pack-import`, `assets.yaml`). Pick packs made for this resolution: ships about **32–64 px**, not 16 px.
- Parallax layers (ground, structures, clouds/debris) for depth.
- **Audio: decided later.** Placeholder synth sounds and music from Medieval Survival's `Synth` until then.

## 7. History and status
- **2026-10-12:** planning Q&A held; this document written. No code yet. Next: `PLAN.md` milestone M0.
- **2026-10-12:** M0 done: Godot 4.7.2 project at 960x540, GUT tests, build script, `CLAUDE.md`; local git repo only. Next: M1 (feel test).
- **2026-10-12:** M1 built: placeholder ship ("Striker": 3-stream spread, focus = 2 tight parallel streams), auto-fire Always / Toggle / Hold, mouse mode, Sharp / Pixel-perfect scaling, scrolling test ground, looping S-curve test wave. Ship and gun numbers are first guesses for the owner to tune by feel.
- **2026-10-12:** owner's feel test of M1: "it feels great". The Striker's numbers stay as they are. Next: M2 (online co-op foundation).
- **2026-10-12:** M2 built: title menu (name, solo, host, join) -> lobby (ready-up, ship placeholder) -> stage for 1–4 players, drop-in mid-stage. The host sends only enemy spawn records, kills, shot events and small ship snapshots; enemies and scroll come from the shared stage clock. Player colors: Blue, Purple, Green, Gold (Medieval Survival's red would look like the red enemies). Headless smoke test and a two-window run on one PC pass.
- **2026-10-12:** M3 built: the Planet Base stage (~4 min, gray-box) as a plain text stage file: 6 path shapes, 4 air enemies (drone, fighter, tracking gunship, kamikaze), 5 ground types (turret, heavy turret, tank, bunker, radar dish), 3 variant groups, a mid-stage tank convoy. Enemy guns (slow, readable patterns), contact and bullet damage with an HP bar and a 1 s blink (draft numbers), co-op HP scaling +60% per extra player (draft). At 0 HP the ship keeps flying until M4 adds death. Stage clear returns to the lobby until M4/M5 add the boss, results and shop.
- **2026-10-12:** M4 built (all numbers draft): the scroll stops at 4:00 and the Command Gunship (8000 HP, +60% per extra player) flies in with a two-phase attack script written in the stage file. Mega Bomb (1 charge: clears bullets, 250 damage to everything on screen) and Shield (3 charges: 3 s, eats bullets), picked in the lobby. Power levels 1–5 (3/5/5/7/7 spread streams, more damage at 3 and 5; dying costs a level). Rapid Fire and Wingmen boosts (12 s). Scrap into the shared team wallet (pulled in from 80 px; power-ups must be touched). Death: respawn after 3 s from a shared pool of 3 credits, 2 s of safety; game over when everyone is down with none left. Destructible boss parts are still to come.
- **2026-10-12:** M5 built (all numbers draft): a run = Planet Base -> shop -> Planet Base again (enemy HP x1.3, guns 15% faster, a random twist) -> run summary. HP, power and upgrades carry over between stages; a ship shot down at the end comes back repaired. Results: stage goals (70% kills +30, all kills +60, no damage +50, all ground +50, boss under 60 s +40, twist +40) and 15 Scrap per unused special charge; score = kills (10 per Scrap value) + 500 per goal + 2000 for the boss; personal best per PC. Shop: the wallet is split evenly; 4 personal offers each (Power +1 40, Repair 25, Hull +20 50, Special +1 30, Swap special 20, Engines +8% 35) and 1 team offer (Spare ship 60, Rapid Fire start 45); Chip in gives a teammate 10 Scrap at a time (a simple version of chipping in to a purchase); a 60 s timer starts when half the team is ready; leftovers go back to the team. Twists: Armored Turrets (ground HP x1.6), Elite Wing (one wave of gold elites: x2.5 HP, faster guns, double Scrap); the first stage has none.

## 8. Decisions log (why)
- **Pixel art over hi-res 2D or low-poly 3D:** it reuses the owner's gamekit pipeline, Claude can draw and edit it, and asset packs mix well under one palette. 3D (with Kenney/Quaternius CC0 kits) was the closest look to Sky Force, but it's the biggest effort and a second engine to learn.
- **960x540 over 640x360:** a full-width vertical scroller needs vertical room; 360 px was too short. The cost is the 1440p scaling (solved by the Sharp/Pixel-perfect setting) and more pixels to draw per asset.
- **Copy parts over a shared library:** the two games will drift apart; a shared addon adds version and testing overhead for a hobby project. gamekit already shares the asset tooling.
- **Auto-fire setting instead of a fire button:** a toggle with no gameplay reason to stop firing is a button nobody presses.
- **Charges per stage for specials:** easiest to read and balance, fair in co-op, and it gives the shop and pickups something to offer; the payout for unused charges fixes hoarding.
- **Respawn with a shared pool instead of revive-by-hovering:** a downed ship in a scroller would drift off-screen or block a lane.
- **Partial HP scaling:** adding more enemies would bury the shared screen under 4 players' shots.
- **Scripted paths:** the genre's own approach; learnable; the cheapest and smoothest netcode.

## 9. Open questions
- Exact numbers: HP, damage, power levels, charges, prices, respawn credits, HP scaling (all marked draft).
- Main gun design of the first ship.
- What happens to a player who goes down with no respawn credits left (spectate until the next stage?).
- Power orbs and boosts in co-op: whoever touches them, or shared?
- Boss designs for each stage.
- HUD layout for 4 players on a full-width screen.
- Audio direction (synthwave, orchestral, chiptune...).
- Whether to add 2D lighting.
- The real name.
- Hosting: a new public GitHub repo for playtest releases, as with Medieval Survival?

## 10. Ideas for later
- Rescue mechanic (Sky Force): stranded crew in the facilities, a stage goal.
- Permanent progression (unlock ships, specials, boosts; medals).
- More stages for 20–25 min runs (asteroid mining outpost, alien hive/derelict station, moon research facility).
- More ships (Jamestown-style distinct main guns).
- A Vampire Survivors-style game mode.
- 2D normal-map lighting.
- Co-op-only bonus waves.
- An in-game wave preview tool for editing stages.
