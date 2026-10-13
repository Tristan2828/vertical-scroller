# Plan to the first playable build

> Written 2026-10-12 from the planning Q&A. `DESIGN.md` is the source of truth for *what* the game is; this file is the order of work to get there.

**Goal of the first build (v0.1.0):** one stage (Planet-side military base) played **online with friends**: 1 ship, waves, ground targets, pickups, 2 specials, a boss, then results, the shop and a replay of the stage. Asset-pack art. Built and released the same way as Medieval Survival.

Each milestone ends with something you can run, and with tests and the smoke test passing. Parts of Medieval Survival (`C:\Repos\GameTest`) are copied in **when a milestone first needs them**, trimmed, and covered by tests.

---

## M0: Project setup ✅ (done 2026-10-12)
- `git init`; a `.gitignore`/`.gitattributes` like Medieval Survival's. (A GitHub repo comes later, at M6; the owner decides.)
- Godot 4.7.2 project: `project.godot` at **960x540**, `stretch/mode = viewport`, nearest-neighbor filtering, `untyped_declaration` as an error.
- Copy: GUT addon + `.gutconfig.json`, `tools/run_tests.ps1`, `tools/build.ps1`, `export_presets.cfg` (renamed).
- `CLAUDE.md` adapted from Medieval Survival's: engine rules, multiplayer rules, verification commands, code conventions and the **Gotchas** list (all still apply).
- Folder layout by feature: `src/autoload`, `src/main`, `src/stage`, `src/player`, `src/enemies`, `src/combat`, `src/progression`, `src/ui`, `src/art`, `src/audio`, `tests/unit`, `tools`.
- **Done when:** the project opens headless, an empty main scene runs, and `run_tests.ps1` passes one sample test.

## M1: Feel test (solo, built co-op-ready)
- **Screen scaling:** Sharp (fractional + sharp-bilinear shader) and Pixel-perfect (integer + borders), switched in Settings.
- Copy and trim `GameInput` (bindings in code; keyboard default + classic alt, gamepad, mouse mode), `Settings`, `PixelFont`.
- Pure `ShipMotor` (movement, focus speed, screen bounds, mouse glide) and `ShipStats` data (`ships/*.tres`).
- Main gun with auto-fire modes (Always / Toggle / Hold) + focus shot; copy `ProjectileManager` (bullet pool) and `ShotPatterns`.
- A placeholder scrolling background (a tiled test pattern) driven by **stage time**.
- One test wave of enemies on a named path shape (S-curve) that die when shot.
- **Done when:** the ship feels good to fly and shoot on keyboard, gamepad and mouse; screenshots at 1080p and 1440p look right in both scaling modes; unit tests cover the motor, fire modes and path shapes.

## M2: Online co-op foundation
- Copy and trim `Net` (ENet, UPnP, invites, names), the lobby (ship pick placeholder, ready-up), `ClientPredictor`, the launch flags (`--solo/--host/--join`, `--autopilot`, `--local-only`, `--screenshot-dir`, `--run-for`) and `net_smoke_test.ps1`.
- A fixed tick order in the stage node; clients send input and the host simulates.
- **Shared stage clock:** scroll and scripted enemy positions are computed on every peer from stage time; the host sends spawns, damage/deaths and pattern events; own ship predicted.
- Per-player ship recolor.
- **Done when:** a headless host + client on autopilot play the test wave together; the smoke test shows the client's shots damaging enemies on the host; two real windows on one PC play smoothly.

## M3: Stage system
- **Stage data:** a `StageDef` resource (length, scroll speed, background layers, wave list, ground objects, boss, music) + a wave format (`shape, time, x, count, spacing, enemy type, gun, variant group`).
- **Path shape library:** S-curve, dive-and-retreat, circle-strafe, cross-screen, hover-and-leave; plus 2 homing types (kamikaze drone, tracking gunship).
- **Enemy types as data** (HP, speed, sprite, gun pattern, drops); enemy shot patterns as events.
- **Ground objects:** placed in stage data, scroll with the map, 2–3 turret types + a few buildings, destroyed sprites, drop Scrap; destroy events synced by id.
- **Wave variants** (random per run, from the run seed).
- Contact and bullet damage to players; HP bar; hit blink.
- Partial co-op HP scaling.
- **Done when:** a full ~4 minute Planet Base stage (gray-box art) plays start to finish, solo and online; tests cover wave timing, variants and path determinism.

## M4: Boss, specials, pickups, death
- Stage boss with an attack script (adapt `BossBrain` / `BossStep`), the scroll stopping for the boss, a boss HP bar.
- Specials: **Mega Bomb** (1 charge) and **Shield** (3 charges); charges refill per stage.
- Main gun power levels (1–5) from power orbs; 2 timed boosts (Rapid Fire, Wingmen).
- Scrap drops and pickups (copy `GemManager`'s pool idea).
- Death → respawn after a delay from the **shared respawn credit pool**; run over when everyone is down with none left.
- **Done when:** a stage can be won or lost solo and online; `--invincible` / `--weak-bosses` style flags speed up testing.

## M5: Results, shop, loop
- Results screen: stage goals (70% kills, 100% kills, no damage, all ground structures, fast boss), score, Scrap earned, payout for unused charges, personal best.
- Shop: random offers (4 personal + 1 team), **equal split of the team wallet + Chip in**, ready-up with the 60 s soft timer. Copy ideas from `ShopController` / `ShopSession`.
- Stage modifiers: 2 to start (Armored Turrets, Elite Wing).
- For v0.1.0 the "run" is: Planet Base → shop → Planet Base again (harder) → run summary.
- **Done when:** a full loop works solo and online, including a client joining at the lobby and the shop vote/timer flow.

## M6: Art pass 1 and first release
- Pick packs (ships around 32–64 px, sci-fi military base tiles, bullets, explosions); `/gamekit:pack-import`, one palette, `assets.yaml`, `CREDITS.md`.
- HUD layout for 1–4 players; title menu; pause menu; settings (volume, scaling mode, auto-fire mode, mouse mode, screen shake).
- Placeholder synth SFX/music (copy `Sfx` / `Music` / `Synth`).
- Copy the updater, feedback screen, `release.ps1`, `docs/RELEASING.md`, the Discord workflow; `docs/PLAYTEST.md` checklist. **The owner decides** on creating the GitHub repo before anything is pushed.
- **Done when:** v0.1.0 is built, released and played online by friends; playtest notes go into `DESIGN.md` §7.

## After v0.1.0
1. Stage 2 (Orbital shipyard) and stage 3 (Capital ship surface) with their bosses.
2. Stage 4 (Flagship core) final multi-phase boss → the full ~15 min run.
3. Remaining specials (Laser, Swarm Missiles), boosts, more modifiers.
4. Decide on 2D lighting, audio direction and the name.
5. A second ship; then permanent progression; then longer runs (20–25 min).
