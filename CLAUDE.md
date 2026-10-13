# CLAUDE.md

**Vertical Scroller** (working title). Online co-op (1–4 players) pixel-art vertical scrolling space shoot'em up roguelite, mostly Sky Force Reloaded with a bit of Jamestown: destructible ground facilities, an HP bar, auto-fire + focus, one special button, a shop between stages. **Read `DESIGN.md` before starting work.** It is the source of truth for game design decisions; update it when a decision changes or an open question gets answered, and confirm items marked **(draft)** with the owner before treating them as decided. **`PLAN.md`** is the milestone plan (M0–M6 to v0.1.0); tick work off there as milestones finish.

## Context
- The owner is new to Godot and game dev; AI writes most of the code. Explain engine concepts briefly when introducing them, prefer simple, readable solutions, and give a comparison table when the owner has to make a choice.
- Target: Windows PC only. Input: keyboard, gamepad and mouse, all first-class.
- **Code comes from Medieval Survival** (`C:\Repos\GameTest`, its own `CLAUDE.md` describes it): proven parts are copied in **when a milestone first needs them**, trimmed to fit, and covered by tests. No shared library. Read the original before copying, and don't copy features this game doesn't need.
- Current state: M1 (feel test) built: solo ship, auto-fire modes + focus, mouse mode, Sharp / Pixel-perfect scaling, a scrolling test background and a looping S-curve test wave; the owner's feel test passed ("it feels great"). Next: M2 (online co-op foundation). No GitHub repo yet: **ask the owner before creating one or pushing anything** (planned for M6).

## Engine & language rules
- **Godot 4.x only.** Never use Godot 3 syntax or APIs (e.g. use `@export`, `@onready`, `super()`, `CharacterBody2D`, `velocity` property + `move_and_slide()` with no args, `signal.connect(callable)`, `@rpc`, `FileAccess`, `Tween` via `create_tween()`).
- When unsure about a Godot API, look up current Godot 4 docs rather than guessing.
- **Statically typed GDScript everywhere:** typed variables, parameters, and return types (`func take_damage(amount: int) -> void:`). `untyped_declaration` is an error in project settings, so type `for` loop variables too (`for i: int in n:`).
- Keep the project text-editable: scenes in `.tscn`, data in `.tres`. If a step truly requires the editor, say so explicitly.
- Pixel art: nearest-neighbor texture filtering, **960x540** base resolution (`ScreenFit.BASE`). The whole game (stage + menus) draws into `GameViewport`, a 960x540 SubViewport in `main.tscn`; `Main._fit_view()` scales that picture to the window: "Sharp" (fractional + `sharp_bilinear.gdshader`, default) or "Pixel-perfect" (whole multiples, black borders). The window itself is not stretched (`stretch/mode = disabled`). A SubViewport defaults to linear filtering, so `GameViewport` sets nearest itself (tested).

## Multiplayer rules
- Godot built-in high-level multiplayer (ENet), direct IP + UPnP, invite paste. **Host-authoritative.** Solo = an offline peer acting as host.
- **Stage time is the shared clock:** scroll position, ground objects and scripted enemy positions are pure functions of stage time, computed on every peer; never sent each frame.
- Clients send input; the host simulates and sends events (spawns, damage/deaths, drops, pattern events) and small snapshots. Your own ship is client-predicted with the same pure motor code.
- Never sync bullets individually: send pattern events (pattern id, origin, aim, seed, stage time) and simulate deterministically on each peer.
- Pool enemies, bullets, and pickups.
- Every gameplay feature must work in solo **and** online co-op. Design for networking from the start; don't bolt it on later.
- RPC channels: 0 = reliable events, 1 = host snapshots, 2 = client inputs. The host only sends to peers whose scene has loaded.
- Registries whose index is a network id are **append only**: `Ships.ALL`, `ShotPatterns.Id`, `PathShapes.Id` (and `ShipStats.gun_pattern` / `focus_pattern`, stored as numbers in `.tres` files).

## Verification
- Godot 4.7.2 is **not on PATH**. Use the full path to the console build:
  `& "C:\Code Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . <args>`
  (`Godot_v4.7.2-stable_win64.exe` in the same folder is the GUI editor.)
- **Tests:** `pwsh tools/run_tests.ps1` (GUT 9.7.1 in `addons/gut`). Don't call GUT directly: it silently skips test files that fail to parse and still says "All tests passed"; the wrapper catches that. It also runs `--import` first, which is needed after adding a `class_name` script.
- **Run the game headless briefly:** `... --headless --path . -- --autopilot --run-for=5` checks the game starts and plays without errors.
- **Launch flags** (after `--`; see `src/main/launch_options.gd`): `--autopilot` (the ship weaves and shoots by itself), `--run-for=<s>`, `--screenshot-dir=<folder>`, `--window=<w>x<h>` (windowed at that size), `--scaling=sharp|pixel`, `--fire-mode=always|toggle|hold`, `--mouse-mode` (overrides are not saved).
- **Seeing visuals:** headless runs can't render. Run in a window, e.g. `& $godot --path . --screen 1 -- --autopilot --window=2560x1440 --scaling=sharp --screenshot-dir=<folder> --run-for=15`: three gameplay PNGs named `<w>x<h>_<mode>_<n>.png`, then `pause_menu.png` and `settings.png`. The owner's PC has two 4K monitors and screen 0 is portrait (2160 wide), so use `--screen 1` for windows wider than 2160. `-s some_script.gd` runs do NOT get autoloads.
- **Build:** `pwsh tools/build.ps1` writes `builds/windows/VerticalScroller.exe` (one file) and `builds/VerticalScroller-<version>-windows.zip` (with `tools/README-friends.txt`), and stamps the git-ignored `build_info.cfg`. Needs the 4.7.2 export templates in `%APPDATA%\Godot\export_templates\4.7.2.stable\`. The exe icon (`make_icon.gd`) and the feedback webhook are not copied yet.
- Coming from Medieval Survival when needed: network launch flags (`--solo/--host/--join`, `--local-only`...), `tools/net_smoke_test.ps1` (M2), `release.ps1` + updater + Discord workflow (M6).
- Report failures honestly.

## Project layout
Folders are grouped by feature. Each scene (`.tscn`) sits next to its script.
- `src/autoload/`: global singletons. `GameInput` (all bindings in code: default keyboard, classic keyboard and gamepad are all on at once; mouse buttons have their own `mouse_*` actions, read only in mouse mode), `Settings` (user://settings.cfg: volumes, fullscreen, scaling mode, auto-fire mode, mouse mode; `changed` signal; installs the pixel font). Later `Net`, `Sfx`, `Music`.
- `src/main/`: root scene `main.tscn` (`GameView` SubViewportContainer > `GameViewport` > `Stage` + `PauseMenu`), pure `ScreenFit` (where the picture goes in the window), `sharp_bilinear.gdshader`, `LaunchOptions`.
- `src/stage/`: `Stage` (the fixed tick order; stage time is the shared clock; M1's looping test wave), `ScrollBackground` (placeholder tiled ground scrolled from stage time, 1 px per tick), `StageHud` (M1's bare HUD). Later `StageDef` data, waves, ground objects.
- `src/player/`: `Ship` node, pure `ShipMotor` (movement, focus speed, screen edges, fire rate, `glide_move` for mouse mode), `ShipInput` / `ShipState`, pure `FireControl` (auto-fire Always / Toggle / Hold; focus always fires), `LocalInput` (keyboard / gamepad / mouse -> `ShipInput`, applies the auto-fire setting and mouse mode, `--autopilot`), `ShipStats` + `ships/*.tres` in `Ships.ALL`.
- `src/enemies/`: pure `PathShapes` (named flight paths: position = f(age, origin, mirror)), `EnemyManager` (pooled spawn records; positions computed from stage time; M1: one look and HP for all).
- `src/combat/`: `ProjectileManager` (flat-array bullet pool; `bolt_size` draws player bolts), `ShotPatterns` (`build()` returns 5 floats per bullet: angle, speed, delay, offset x/y; ship patterns so far).
- `src/progression/`: Scrap, pickups, shop, stage goals (later).
- `src/ui/`: `PauseMenu` (Esc / Start; pauses solo), `SettingsPanel` (buttons that step through choices, gamepad-friendly), `PixelFont` (**every glyph as text rows**; font sizes 9 / 18 / 27 only), `theme/game_theme.tres` (Medieval Survival's theme, still purple: restyle in the art pass).
- `src/art/pixel_art.gd`: **every sprite as text rows** (placeholder ship and drone; `P`/`p` recolored per player), `disc_texture` / `bolt_texture` baked shapes, `draw()` helpers. `src/audio/`: later.
- `tests/unit/`: GUT tests (`test_*.gd`, extend `GutTest`).
- `tools/`: `run_tests.ps1`, `build.ps1`, `README-friends.txt`.

## Code conventions
- Gameplay simulation that must match across peers goes in **pure static functions or RefCounted classes** (e.g. `ShipMotor`, path shapes, `ShotPatterns`) so it's deterministic and unit-testable. Nodes call into it.
- Nodes don't run their own `_physics_process` for gameplay; the stage node calls `tick()` in a fixed order. `_process` is for visuals only.
- The game logic doesn't depend on how it's drawn (DESIGN.md §6).
- Visual effects (particles, explosions, screen shake, hit flashes) are spawned locally on every peer from events they already see; never send effects over the network.
- Gamepad must work in every menu. Godot's default `ui_accept` has no gamepad button, so `GameInput` adds A to it (with a test guarding it).
- Test helpers must not reuse Node callback names (`_input`, `_process`, `_ready`...): `GutTest` is a Node.
- Commits use the GitHub noreply email (set in the repo's git config).

## Gotchas (learned the hard way in Medieval Survival)
- Keep each **unreliable** RPC under ~1390 bytes (ENet's MTU). Bigger ones are split into fragments and the whole message is lost if any fragment is, so they drop far more often online. Send big snapshots in chunks.
- An **empty** `PackedByteArray` sent as an RPC's only argument arrives as "no arguments" and the call fails. Always send a count or another argument alongside packed data.
- Never remove or free the stage (or other ticking nodes) in the middle of its own tick; defer it (`CONNECT_DEFERRED` / `call_deferred`).
- A negative width in `draw_texture_rect` does NOT mirror in Godot 4; it shifts the image a full width sideways. Flip with a helper (Medieval Survival's `PixelArt.draw_rect_flipped()`).
- Packed arrays are values: putting them in an Array and calling `resize()` in a loop only resizes copies. Resize each one directly.
- Constants can't call constructors (e.g. `PackedStringArray([...])` in a `const`); use plain arrays.
- `draw_circle` (and other shape calls) in `_draw()` builds a polygon and its own draw call every time: fine for a few, a frame-rate killer for hundreds. For many repeated shapes draw one baked texture and skip off-screen items. Redraws requested with `queue_redraw()` run during the physics step, so heavy `_draw` shows up as physics time.
- When editing with scripts, replace exact text and verify the result: large regex or slice edits have deleted neighbouring functions before. Review `git diff` after big edits.
