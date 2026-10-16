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

## M1: Feel test (solo, built co-op-ready) ✅ (done 2026-10-12; the owner's feel test: "it feels great")
- **Screen scaling:** Sharp (fractional + sharp-bilinear shader) and Pixel-perfect (integer + borders), switched in Settings.
- Copy and trim `GameInput` (bindings in code; keyboard default + classic alt, gamepad, mouse mode), `Settings`, `PixelFont`.
- Pure `ShipMotor` (movement, focus speed, screen bounds, mouse glide) and `ShipStats` data (`ships/*.tres`).
- Main gun with auto-fire modes (Always / Toggle / Hold) + focus shot; copy `ProjectileManager` (bullet pool) and `ShotPatterns`.
- A placeholder scrolling background (a tiled test pattern) driven by **stage time**.
- One test wave of enemies on a named path shape (S-curve) that die when shot.
- **Done when:** the ship feels good to fly and shoot on keyboard, gamepad and mouse; screenshots at 1080p and 1440p look right in both scaling modes; unit tests cover the motor, fire modes and path shapes.

## M2: Online co-op foundation ✅ (built 2026-10-12; the owner's two-window / friend test is postponed until after M3)
- Copy and trim `Net` (ENet, UPnP, invites, names), the lobby (ship pick placeholder, ready-up), `ClientPredictor`, the launch flags (`--solo/--host/--join`, `--autopilot`, `--local-only`, `--screenshot-dir`, `--run-for`) and `net_smoke_test.ps1`.
- A fixed tick order in the stage node; clients send input and the host simulates.
- **Shared stage clock:** scroll and scripted enemy positions are computed on every peer from stage time; the host sends spawns, damage/deaths and pattern events; own ship predicted.
- Per-player ship recolor.
- **Done when:** a headless host + client on autopilot play the test wave together; the smoke test shows the client's shots damaging enemies on the host; two real windows on one PC play smoothly.

## M3: Stage system ✅ (built 2026-10-12; played in playtests 1–3)
- **Stage data:** a `StageDef` resource (length, scroll speed, background layers, wave list, ground objects, boss, music) + a wave format (`shape, time, x, count, spacing, enemy type, gun, variant group`).
- **Path shape library:** S-curve, dive-and-retreat, circle-strafe, cross-screen, hover-and-leave; plus 2 homing types (kamikaze drone, tracking gunship).
- **Enemy types as data** (HP, speed, sprite, gun pattern, drops); enemy shot patterns as events.
- **Ground objects:** placed in stage data, scroll with the map, 2–3 turret types + a few buildings, destroyed sprites, drop Scrap; destroy events synced by id.
- **Wave variants** (random per run, from the run seed).
- Contact and bullet damage to players; HP bar; hit blink.
- Partial co-op HP scaling.
- **Done when:** a full ~4 minute Planet Base stage (gray-box art) plays start to finish, solo and online; tests cover wave timing, variants and path determinism.

## M4: Boss, specials, pickups, death ✅ (built 2026-10-12; played in playtests 1–3)
- Stage boss with an attack script (adapt `BossBrain` / `BossStep`), the scroll stopping for the boss, a boss HP bar.
- Specials: **Mega Bomb** (1 charge) and **Shield** (3 charges); charges refill per stage.
- Main gun power levels (1–5) from power orbs; 2 timed boosts (Rapid Fire, Wingmen).
- Scrap drops and pickups (copy `GemManager`'s pool idea).
- Death → respawn after a delay from the **shared respawn credit pool**; run over when everyone is down with none left.
- **Done when:** a stage can be won or lost solo and online; `--invincible` / `--weak-bosses` style flags speed up testing.

## M5: Results, shop, loop ✅ (built 2026-10-12; played in playtests 1–3, released up to v0.0.8)
- Results screen: stage goals (since playtest 3: tiered kills and ground targets 50 / 75 / 90%, team loses under 25% HP, fast boss, twist), score, Scrap earned, payout for unused charges, personal best.
- Shop: random offers (4 personal + 1 team), **equal split of the team wallet + Chip in**, ready-up with the 60 s soft timer. Copy ideas from `ShopController` / `ShopSession`.
- Stage modifiers: 2 to start (Armored Turrets, Elite Wing).
- For v0.1.0 the "run" is: Planet Base → shop → Planet Base again (harder) → run summary.
- **Done when:** a full loop works solo and online, including a client joining at the lobby and the shop vote/timer flow.

## M6: Art pass 1 and first release (in progress)
Done (v0.0.10 / v0.0.11, 2026-10-15): the updater, Send feedback (Discord webhook), `release.ps1`, Discord release announcements (no commit feed), the exe icon, placeholder synth SFX + music (`Sfx` / `Music` / `Synth`), screen shake, volume sliders, opening on the widest landscape monitor.
- Pick packs (ships around 32–64 px, sci-fi military base tiles, bullets, explosions); `/gamekit:pack-import`, one palette, `assets.yaml`, `CREDITS.md`.
- **Redo `palette.hex` once the art direction is set.** It's a placeholder for now (the gray-box `PixelArt.PALETTE` colors plus `BossArt`'s steel); replace it with the chosen packs' palette so gamekit snaps new art to the real colors, and keep the player colors (`#FF00FF` / `#800080`) reserved.
- HUD layout for 1–4 players; restyle the title menu, pause menu and settings with the art (settings themselves are done: volume sliders, scaling, auto-fire, mouse mode, screen shake).
- ~~Placeholder synth SFX/music~~ (done).
- ~~The updater, feedback screen, `release.ps1`, `docs/RELEASING.md`, the Discord workflow~~ (done); still to do: the `docs/PLAYTEST.md` checklist.
- **Done when:** v0.1.0 is built, released and played online by friends; playtest notes go into `DESIGN.md` §7.

### Playtest changes so far (DESIGN.md §7)
- Playtest 1 (v0.0.5): 5 ships unlocked, a busier stage, co-op scaling by wave size, bigger power-up icons.
- Playtest 2 (v0.0.6): enemies ~18% harder, HUD at the top-left, the multi-part Fortress Gunship boss; then the lobby's Boss only mode (v0.0.8).
- Playtest 3 (released as v0.0.9; then v0.0.10 / v0.0.11 brought sound, updates and feedback): boss pixel art (`BossArt` / `BossDraw`), HUD icons (red HP bar, power arrows, bomb / shield charges, boost timers), tiered stage goals.
- Next small step: medal challenges per stage (option B, on top of the tiers).

## After v0.1.0
1. Stage 2 (Orbital shipyard) and stage 3 (Capital ship surface) with their bosses.
2. Stage 4 (Flagship core) final multi-phase boss → the full ~15 min run.
3. Remaining specials (Laser, Swarm Missiles), boosts, more modifiers.
4. Decide on 2D lighting, audio direction and the name.
5. A second ship; then permanent progression; then longer runs (20–25 min).
