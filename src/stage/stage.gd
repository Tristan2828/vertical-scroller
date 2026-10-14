class_name Stage
extends Node2D
## One stage being played, solo or online (DESIGN.md §3). The stage's waves,
## ground objects and boss come from its `.stage` file (StageDef).
##
## Stage time is the shared clock (DESIGN.md §2 Networking): the scroll, every
## scripted enemy and every ground object position are computed from it on
## every peer. The host owns the game: it spawns waves and the boss, aims and
## fires enemy guns, steers homing enemies, applies all damage, rolls drops,
## runs specials and respawns, and sends only events (enemy spawn records,
## redirects, kills, ground destructions, shot patterns, drops, specials) and
## small snapshots. Gameplay runs in tick(), in a fixed order; child nodes
## never run gameplay on their own.

## Host: the stage is over, won or lost; RunState.current says what's next
## (the shop, or the run summary).
signal finished
## Every peer: the stage was won or lost (the results / game over banner shows now).
signal ended

## Sent over the network: only add new phases at the end.
enum Phase { PLAYING, CLEAR, BOSS, GAME_OVER }

## Co-op scaling (DESIGN.md §5, playtest 1): each player beyond the first adds
## this much to every wave's size (more on screen), plus a small HP bump; the
## boss can't come in bigger numbers, so it gets more HP instead. Draft numbers.
const COUNT_PER_EXTRA_PLAYER: float = 0.35
## How tough and how trigger-happy enemies are overall (playtest 2: "15-20%
## harder"): HP multiplier and gun interval multiplier, for every enemy,
## ground target and the boss. Tune here.
const ENEMY_HP: float = 1.15
const ENEMY_FIRE_INTERVAL: float = 0.9
const HP_PER_EXTRA_PLAYER: float = 0.2
const BOSS_HP_PER_EXTRA_PLAYER: float = 0.5
const SHIP_START_Y: float = 460.0
## Ships start (and respawn) side by side, by slot.
const SHIP_START_X: Array[float] = [420.0, 540.0, 300.0, 660.0]
const BULLET_LIFETIME: float = 1.5
const MISSILE_LIFETIME: float = 2.5
const ENEMY_BULLET_LIFETIME: float = 6.0
## Shots from other players are fast-forwarded by how late they arrived, up to this.
const MAX_SHOT_CATCH_UP: float = 0.3
## Enemy patterns are fast-forwarded on clients up to this (see _receive_patterns).
const MAX_PATTERN_CATCH_UP: float = 0.5
const SNAPSHOT_INTERVAL_TICKS: int = 2
## Client: a clock further off than this jumps; closer, it eases in.
const CLOCK_SNAP: float = 0.25
const CLOCK_EASE: float = 0.1
## Host: how often homing enemies rethink.
const HOMING_EVERY: float = 0.5
## Trackers follow a player this long after homing starts, then leave upward.
const TRACKER_SECONDS: float = 5.5
const TRACKER_LEAVE_SPEED: float = 90.0
## Collisions count from a little outside the hitbox (ships are bigger than it).
const CONTACT_SLACK: float = 3.0
## Seconds the "game over" banner / the results panel show before the host moves on.
const END_SECONDS: float = 6.0
const RESULTS_SECONDS: float = 12.0
## The team's shared respawn credits for the run (DESIGN.md §5, draft).
const START_CREDITS: int = 3
## Boss only (lobby switch): the stage starts this long before its boss.
const BOSS_ONLY_LEAD: float = 3.0
## Where the boss appears (it flies down from there).
const BOSS_START_Y: float = -40.0
## --weak-bosses: share of the boss's HP.
const WEAK_BOSS_HP: float = 0.02
## Below this share of its core's HP the boss sinks toward the players (desperation).
const DESPERATION_HP: float = 0.3
const DESPERATION_SINK: float = 90.0
const DESPERATION_SPEED: float = 45.0
## The Mega Bomb's expanding ring.
const MEGA_BOMB_COLOR: Color = Color(1.0, 0.95, 0.75)

## Which stage (Stages.PATHS index).
var stage_index: int = 0
var def: StageDef = null
var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))
var stage_time: float = 0.0
var phase: Phase = Phase.PLAYING
var kills: int = 0
var ground_kills: int = 0
## The team's wallet (DESIGN.md §4: shared) and respawn credits.
var team_scrap: int = 0
var credits: int = START_CREDITS
## 0..1 (host: from the boss's HP; clients: from snapshots). 1 before the boss.
var boss_hp_ratio: float = 1.0
## StageModifiers.Id of this stage, and how much harder it is (RunState.difficulty).
var modifier: int = StageModifiers.Id.NONE
var difficulty: float = 1.0
## Host: what happened, for the stage goals and the score.
var stats: StageGoals.Stats = StageGoals.Stats.new()

## Host: this run's waves (variants picked), sorted by time, and the next one due.
var _waves: Array[StageDef.WaveDef] = []
var _next_wave: int = 0
var _tick: int = 0
var _end_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Host: the elite wave's index in _waves (Elite Wing), or -1.
var _elite_wave: int = -1
## Host: the boss core's pool index, when it came, and its script.
var _boss_index: int = -1
var _boss_started_at: float = 0.0
## Host: the boss's parts (pool indices), the ones that keep the core armored,
## all parts' HP at the start (for the HP bar), and whether it's sinking.
var _boss_parts: PackedInt32Array = PackedInt32Array()
var _required_parts: PackedInt32Array = PackedInt32Array()
var _boss_total_hp: int = 1
var _desperate: bool = false
## Every peer: the core is open (no longer armored).
var core_open: bool = false
var _boss_max_hp: int = 1
var _boss_brain: BossBrain = null
## Host: SPIN steps' current angles.
var _spin_angles: Dictionary[BossStep, float] = {}
## Host: peers whose stage has loaded (only they get messages).
var _ready_peers: Dictionary[int, bool] = {}
## Host: enemy patterns fired this tick, sent together.
var _pattern_ids: PackedInt32Array = PackedInt32Array()
var _pattern_origins: PackedVector2Array = PackedVector2Array()
var _pattern_aims: PackedFloat32Array = PackedFloat32Array()
var _pattern_seeds: PackedInt32Array = PackedInt32Array()
var _pattern_times: PackedFloat32Array = PackedFloat32Array()

@onready var background: ScrollBackground = $Background
@onready var ground: GroundManager = $Ground
@onready var enemies: EnemyManager = $Enemies
@onready var effects: EffectsLayer = $Effects
@onready var pickups: PickupManager = $Pickups
@onready var player_bullets: ProjectileManager = $PlayerBullets
@onready var enemy_bullets: ProjectileManager = $EnemyBullets
@onready var ships_node: Node2D = $Ships
@onready var hud: StageHud = $Hud
@onready var _ship_spawner: MultiplayerSpawner = $ShipSpawner


func _ready() -> void:
	var run := RunState.current
	stage_index = run.stage_index()
	modifier = run.modifier()
	difficulty = run.difficulty()
	def = Stages.get_stage(stage_index)
	for error: String in def.errors:
		push_error("Stage file %s: %s" % [Stages.PATHS[stage_index], error])
	# Every peer needs the spawn function: the host calls it via spawn(), and
	# clients call it automatically with the same data when the spawn replicates.
	_ship_spawner.spawn_function = _spawn_ship
	player_bullets.bounds = play_area.grow(24.0)
	player_bullets.spawn_backtrack = absf(Ships.ALL[0].muzzle_offset.y)
	enemy_bullets.bounds = play_area.grow(24.0)
	enemies.play_area = play_area
	enemies.killed.connect(_on_enemy_killed)
	ground.play_area = play_area
	ground.setup(def)
	ground.destroyed.connect(_on_ground_destroyed)
	pickups.play_area = play_area
	# Later stages shoot faster (draft: the interval shrinks with difficulty).
	enemies.fire_interval_scale = ENEMY_FIRE_INTERVAL / (1.0 + 0.5 * (difficulty - 1.0))
	ground.fire_interval_scale = enemies.fire_interval_scale
	_rng.randomize()
	var title := def.name if run.stages_done == 0 else "%s (stage %d)" % [def.name, run.stages_done + 1]
	if modifier != StageModifiers.Id.NONE:
		title += "\nTwist: %s - %s" % [StageModifiers.name_of(modifier), StageModifiers.HINTS[modifier]]
	hud.show_banner(title, 3.5)
	if multiplayer.is_server():
		pickups.collected.connect(_on_pickup_collected)
		team_scrap = run.team_scrap
		credits = run.credits
		stats.modifier = modifier
		stats.ground_total = ground.count()
		_waves = def.waves_for_seed(_rng.randi())
		if modifier == StageModifiers.Id.ELITE_WING:
			_elite_wave = StageModifiers.elite_wave(_waves, run.seed_value + run.stages_done)
		stage_time = LaunchOptions.start_at_seconds
		if run.boss_only and def.has_boss():
			stage_time = maxf(stage_time, def.length - BOSS_ONLY_LEAD)
		while _next_wave < _waves.size() and _waves[_next_wave].time < stage_time:
			_next_wave += 1
		multiplayer.peer_connected.connect(_add_ship)
		multiplayer.peer_disconnected.connect(_remove_ship)
		_add_ship(1)
		var peers: Array[int] = []
		peers.assign(multiplayer.get_peers())
		# Same order as the lobby, so everyone keeps their color.
		peers.sort_custom(func(a: int, b: int) -> bool: return _lobby_rank(a) < _lobby_rank(b))
		for peer_id: int in peers:
			_add_ship(peer_id)
	else:
		_notify_ready.rpc_id(1)


func _physics_process(delta: float) -> void:
	tick(delta)


func _enter_tree() -> void:
	LocalInput.autopilot_aim = _autopilot_aim_x


## --perf-log: frame timing every frame, a report line every second.
var _perf_seconds: float = 0.0


func _process(delta: float) -> void:
	if not PerfLog.enabled:
		return
	PerfLog.frame()
	_perf_seconds += delta
	if _perf_seconds >= 1.0:
		var extra := "t=%.0fs  bullets %d+%d  enemies %d  pickups %d  objects %d  nodes %d  draws %d  mem %.0f MB  video %.0f MB" % [
			stage_time, player_bullets.count(), enemy_bullets.count(), enemies.active_count(), pickups.count(),
			Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
		print(PerfLog.report(_perf_seconds, extra))
		_perf_seconds = 0.0


func _exit_tree() -> void:
	LocalInput.autopilot_aim = Callable()


## Autopilot (tests, videos): the lowest air enemy above the ship, else the
## nearest standing ground target ahead of it; NAN if there's nothing.
func _autopilot_aim_x(from: Vector2) -> float:
	var best_y := -INF
	var best_x := NAN
	for index: int in enemies.alive_indices():
		var at := enemies.position_of(index)
		if at.y < from.y - 40.0 and at.y > best_y and play_area.has_point(at):
			best_y = at.y
			best_x = at.x
	if not is_nan(best_x):
		return best_x
	var nearest := INF
	for index: int in ground.count():
		var at := ground.position_of(index)
		if ground.is_alive(index) and at.y > 0.0 and at.y < from.y and absf(at.x - from.x) < nearest:
			nearest = absf(at.x - from.x)
			best_x = at.x
	return best_x


## One simulation step, in a fixed order.
func tick(delta: float) -> void:
	var is_host := multiplayer.is_server()
	_tick += 1
	stage_time += delta
	var all_ships := ships()
	var t := PerfLog.start()
	for ship: Ship in all_ships:
		ship.tick(delta)
	PerfLog.stop(&"ships", t)
	t = PerfLog.start()
	if is_host and phase == Phase.PLAYING:
		_spawn_due_waves()
		if def.has_boss() and stage_time >= def.length and _next_wave >= _waves.size():
			_start_boss()
	var ship_points := _ship_positions(all_ships)
	enemies.aim_targets = ship_points
	enemies.tick(stage_time, delta)
	ground.tick(stage_time, delta, ship_points, _ground_hp_scale())
	pickups.tick(stage_time, delta, _collectors(all_ships), is_host)
	PerfLog.stop(&"enemies", t)
	t = PerfLog.start()
	if is_host:
		_steer_homing()
		_fire_guns()
		_tick_boss(delta)
		_apply_contact(all_ships)
		_tick_respawns(all_ships, delta)
	PerfLog.stop(&"host", t)
	t = PerfLog.start()
	player_bullets.steer(enemies, delta)
	player_bullets.step(delta)
	player_bullets.resolve_hits(enemies, ground, is_host)
	enemy_bullets.step(delta)
	_apply_shields(all_ships)
	enemy_bullets.resolve_ship_hits(all_ships, is_host)
	PerfLog.stop(&"bullets", t)
	t = PerfLog.start()
	background.scroll = def.scroll_distance(stage_time)
	hud.show_state(self, local_ship())
	PerfLog.stop(&"hud", t)
	t = PerfLog.start()
	if is_host:
		var peers := _ready_peer_list()
		_flush_patterns()
		pickups.flush_events(peers)
		if _tick % SNAPSHOT_INTERVAL_TICKS == 0:
			_send_snapshot()
		_check_end(all_ships, delta)
	PerfLog.stop(&"network", t)


func ships() -> Array[Ship]:
	var list: Array[Ship] = []
	for child: Node in ships_node.get_children():
		var ship := child as Ship
		if ship != null and not ship.is_queued_for_deletion():
			list.append(ship)
	return list


func ship_of(peer_id: int) -> Ship:
	return ships_node.get_node_or_null(str(peer_id)) as Ship


func local_ship() -> Ship:
	return ship_of(multiplayer.get_unique_id())


## 0..1 through the stage's waves.
func progress() -> float:
	return clampf(stage_time / maxf(def.length, 1.0), 0.0, 1.0)


func boss_name() -> String:
	return EnemyTypes.ALL[def.boss_type].display_name if def.has_boss() else ""


## Text summary for headless smoke tests (--run-for).
func debug_report() -> String:
	var lines := PackedStringArray()
	var role := "host" if multiplayer.is_server() else "client"
	lines.append("[report] peer %d (%s)  %s  stage time %.1fs  phase %s  ships: %d  kills: %d  ground: %d/%d  enemies: %d  bullets: %d / enemy %d" % [
		multiplayer.get_unique_id(), role, def.name, stage_time, Phase.keys()[phase], ships().size(), kills,
		ground_kills, ground.count(), enemies.active_count(), player_bullets.count(), enemy_bullets.count()])
	lines.append("[report]   scrap %d  credits %d  boss hp %.0f%%  pickups on screen %d" % [team_scrap, credits, boss_hp_ratio * 100.0, pickups.count()])
	for ship: Ship in ships():
		var line := "[report]   ship %d (%s) slot %d at %s  hp %d/%d  power %d  %s x%d%s" % [ship.peer_id, ship.display_name(),
			ship.slot, ship.state.position.round(), ship.health.hp, ship.health.max_hp, ship.state.power,
			Specials.NAMES[ship.special_kind], ship.special_charges, "  DOWN" if ship.is_down() else ""]
		if ship.is_local() and not multiplayer.is_server():
			line += "  corrections=%d largest=%.2fpx" % [ship.correction_count, ship.largest_correction]
		lines.append(line)
	if multiplayer.is_server():
		lines.append("[report]   damage by peer: %s  ground: %s" % [enemies.damage_by_peer, ground.damage_by_peer])
		lines.append("[report]   invite: '%s'  %s" % [Net.invite.address, Net.invite.status])
	lines.append("[report]   physics time: %.2f ms/tick" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return "\n".join(lines)


func _extra_players() -> int:
	return maxi(ships().size() - 1, 0)


## Enemy HP: co-op scaling and the run's difficulty.
func _hp_scale() -> float:
	return (1.0 + HP_PER_EXTRA_PLAYER * _extra_players()) * difficulty * ENEMY_HP


## How many enemies a wave of `count` has with this many players.
func _wave_count(count: int) -> int:
	return roundi(count * (1.0 + COUNT_PER_EXTRA_PLAYER * _extra_players()))


func _ground_hp_scale() -> float:
	return _hp_scale() * (StageModifiers.ARMOR_HP if modifier == StageModifiers.Id.ARMORED_TURRETS else 1.0)


func _ready_peer_list() -> Array[int]:
	var peers: Array[int] = []
	peers.assign(_ready_peers.keys())
	return peers


## Positions of the ships still flying (enemies aim at these).
static func _ship_positions(list: Array[Ship]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for ship: Ship in list:
		if not ship.is_down():
			points.append(ship.state.position)
	return points


static func _collectors(list: Array[Ship]) -> Dictionary[int, Vector2]:
	var map: Dictionary[int, Vector2] = {}
	for ship: Ship in list:
		if not ship.is_down():
			map[ship.peer_id] = ship.state.position
	return map


# --- Ships -------------------------------------------------------------------

## Host: a ship for this peer (at the start, or a friend dropping in).
func _add_ship(peer_id: int) -> void:
	if ship_of(peer_id) != null:
		return
	var player := RunState.current.player(peer_id)
	_ship_spawner.spawn({"peer_id": peer_id, "slot": _free_slot(), "ship": player.ship, "special": player.special,
		"run": player.to_dict()})


func _remove_ship(peer_id: int) -> void:
	_ready_peers.erase(peer_id)
	var ship := ship_of(peer_id)
	if ship != null:
		ship.queue_free()


func _spawn_ship(data: Variant) -> Node:
	var info: Dictionary = data
	var slot: int = clampi(int(info.get("slot", 0)), 0, Net.MAX_PLAYERS - 1)
	var ship_id: int = int(info.get("ship", 0))
	if ship_id < 0 or ship_id >= Ships.ALL.size():
		ship_id = 0
	var ship := Ship.new()
	var run_data: Variant = info.get("run", {})
	ship.setup(int(info["peer_id"]), slot, ship_id, _start_of(slot), play_area, int(info.get("special", 0)),
		run_data if run_data is Dictionary else {})
	ship.fired.connect(_on_ship_fired)
	ship.special_requested.connect(_use_special)
	ship.downed.connect(func(downed: Ship) -> void:
		effects.blast(downed.state.position, 2.5)
		if multiplayer.is_server():
			RunState.current.player(downed.peer_id).downs += 1
		if downed.is_local():
			hud.show_banner("Shot down!", 1.5))
	ship.hurt.connect(func(_hurt: Ship, amount: int) -> void: stats.damage_taken += amount)
	stats.team_max_hp += ship.health.max_hp
	# The team's Rapid Fire from the shop, for the start of the stage.
	ship.state.rapid_fire_left = RunState.current.team_rapid_fire
	return ship


static func _start_of(slot: int) -> Vector2:
	return Vector2(SHIP_START_X[slot], SHIP_START_Y)


func _free_slot() -> int:
	var used: Array[int] = []
	for ship: Ship in ships():
		used.append(ship.slot)
	for slot: int in Net.MAX_PLAYERS:
		if not used.has(slot):
			return slot
	return 0


func _lobby_rank(peer_id: int) -> int:
	var index := RunSetup.order.find(peer_id)
	return index if index >= 0 else 1000 + peer_id


## Host: downed ships come back after a delay while the team has credits.
func _tick_respawns(list: Array[Ship], delta: float) -> void:
	if phase == Phase.CLEAR or phase == Phase.GAME_OVER:
		return
	for ship: Ship in list:
		if not ship.is_down() or ship.respawn_left <= 0.0:
			continue
		ship.respawn_left = maxf(ship.respawn_left - delta, 0.0)
		if ship.respawn_left > 0.0:
			continue
		if credits > 0:
			credits -= 1
			ship.respawn(_start_of(ship.slot))
		# Out of credits: it stays down (spectating) until the next stage.


# --- Player shots ------------------------------------------------------------

## Runs on the host for every ship's shot, and on a client for its own
## predicted shots. Only the host tells other peers about it.
func _on_ship_fired(ship: Ship, seq: int, focus: bool) -> void:
	var stats := ship.stats
	var pattern := stats.focus_pattern if focus else stats.gun_pattern
	var origin := ship.state.position + stats.muzzle_offset
	var seed_value := ShotPatterns.make_seed(ship.peer_id, seq)
	var power := ship.state.power
	var wingmen := ship.state.wingmen_left > 0.0
	_spawn_shot(ship.peer_id, pattern, origin, seed_value, focus, power, wingmen, 0.0)
	if multiplayer.is_server():
		for peer_id: int in _ready_peers:
			# The shooter already predicted this shot itself.
			if peer_id != ship.peer_id:
				_receive_shot.rpc_id(peer_id, ship.peer_id, pattern, origin, seed_value, focus, power, wingmen, stage_time)


func _spawn_shot(shooter_id: int, pattern: int, origin: Vector2, seed_value: int, focus: bool, power: int,
		wingmen: bool, start_age: float) -> void:
	var shooter := ship_of(shooter_id)
	var stats := shooter.stats if shooter != null else Ships.ALL[0]
	var damage := ShipMotor.damage(stats, power, focus)
	var streams := ShipMotor.streams(stats, power, focus)
	var pierce := stats.focus_pierce if focus else stats.pierce
	var style := (stats.focus_bolt_style if focus else stats.bolt_style) as ProjectileManager.Style
	var bullets := ShotPatterns.build(pattern as ShotPatterns.Id, -PI / 2.0, seed_value, streams, stats.bullet_speed)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		var velocity := Vector2.from_angle(bullets[i]) * bullets[i + 1]
		var offset := Vector2(bullets[i + 3], bullets[i + 4])
		player_bullets.spawn(origin + offset, velocity, damage, BULLET_LIFETIME, shooter_id, pierce,
			start_age - bullets[i + 2], style)
	_spawn_missiles(shooter_id, stats, origin, seed_value, power, start_age)
	if wingmen:
		var up := Vector2(0.0, -stats.bullet_speed)
		for side: float in [-1.0, 1.0]:
			var drone := origin - stats.muzzle_offset + Vector2(side * Ship.WINGMAN_OFFSET.x, Ship.WINGMAN_OFFSET.y - 4.0)
			player_bullets.spawn(drone, up, damage, BULLET_LIFETIME, shooter_id, 0, start_age)


## Homing missiles (Hornet): some shots come with a volley, picked from the
## shot's seed so every peer agrees which ones.
func _spawn_missiles(shooter_id: int, stats: ShipStats, origin: Vector2, seed_value: int, power: int,
		start_age: float) -> void:
	var count: int = stats.missiles[clampi(power, 1, stats.missiles.size()) - 1]
	if count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if rng.randf() >= stats.missile_chance:
		return
	var center := origin - stats.muzzle_offset
	for i: int in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := 1.0 + floorf(i / 2.0) * 0.6
		var direction := Vector2(side * 0.5 * spread, -1.0).normalized()
		player_bullets.spawn(center + Vector2(side * 9.0, 2.0), direction * stats.missile_speed, stats.missile_damage,
			MISSILE_LIFETIME, shooter_id, 0, start_age, ProjectileManager.Style.MISSILE, stats.missile_turn)


# --- Specials ------------------------------------------------------------------

## Host: a ship pressed its special button.
func _use_special(ship: Ship) -> void:
	if ship.special_charges <= 0 or ship.is_down() or phase == Phase.CLEAR or phase == Phase.GAME_OVER:
		return
	ship.special_charges -= 1
	match ship.special_kind:
		Specials.Kind.MEGA_BOMB:
			for index: int in enemies.alive_indices():
				if play_area.has_point(enemies.position_of(index)):
					enemies.damage(index, Specials.BOMB_DAMAGE, ship.peer_id)
			for index: int in ground.count():
				if ground.is_alive(index) and play_area.has_point(ground.position_of(index)):
					ground.damage(index, Specials.BOMB_DAMAGE, ship.peer_id)
			ship.health.invulnerable_left = maxf(ship.health.invulnerable_left, Specials.BOMB_SAFE_SECONDS)
		Specials.Kind.SHIELD:
			ship.state.shield_left = Specials.SHIELD_SECONDS
	_show_special(ship.peer_id, ship.special_kind, ship.state.position)
	for peer_id: int in _ready_peers:
		_receive_special.rpc_id(peer_id, ship.peer_id, ship.special_kind, ship.state.position)


## Every peer: what a special looks like (and the Mega Bomb's bullet clear).
func _show_special(peer_id: int, kind: int, at: Vector2) -> void:
	match kind:
		Specials.Kind.MEGA_BOMB:
			enemy_bullets.clear()
			effects.ring(at, 620.0, MEGA_BOMB_COLOR)
			effects.blast(at, 3.0)
		Specials.Kind.SHIELD:
			var ship := ship_of(peer_id)
			if ship != null:
				ship.state.shield_left = Specials.SHIELD_SECONDS


## Every peer: enemy bullets touching a shield vanish.
func _apply_shields(list: Array[Ship]) -> void:
	for ship: Ship in list:
		if ship.state.shield_left > 0.0 and not ship.is_down():
			enemy_bullets.clear_near(ship.state.position, Specials.SHIELD_RADIUS)


# --- Host: waves, guns, homing, collisions, drops -------------------------------

func _spawn_due_waves() -> void:
	while _next_wave < _waves.size() and _waves[_next_wave].time <= stage_time:
		var wave := _waves[_next_wave]
		var elite := _next_wave == _elite_wave
		_next_wave += 1
		var indices := PackedInt32Array()
		# Extra co-op enemies follow the formation (same path, a little later).
		for i: int in _wave_count(wave.count):
			var origin := wave.origin + Vector2(wave.dx * i, 0.0)
			var index := enemies.spawn(wave.type_id, wave.shape as PathShapes.Id, wave.time + i * wave.spacing, origin,
				wave.mirror, wave.pace, _hp_scale(), elite)
			if index >= 0:
				indices.append(index)
				stats.air_spawned += 1
		_send_enemies(indices)


func _send_enemies(indices: PackedInt32Array) -> void:
	if indices.is_empty() or _ready_peers.is_empty():
		return
	var data := enemies.records(indices)
	for peer_id: int in _ready_peers:
		_receive_enemies.rpc_id(peer_id, indices.size(), data)


## Aims at the nearest ship still flying (straight down if there are none).
func _aim_from(origin: Vector2) -> float:
	var target := GroundManager.nearest(origin, _ship_positions(ships()))
	return (target - origin).angle() if target.is_finite() else PI / 2.0


func _fire_guns() -> void:
	if phase == Phase.CLEAR or phase == Phase.GAME_OVER:
		return
	for index: int in enemies.take_ready_guns(stage_time):
		var type := enemies.type_of(index)
		var origin := enemies.position_of(index)
		_fire_pattern(type.shot_pattern, origin, _aim_from(origin), type.bullet_damage)
	for index: int in enemies.take_ready_launches(stage_time):
		var launcher := enemies.type_of(index)
		var launched := EnemyTypes.from_key(launcher.launches)
		var shape := PathShapes.from_name(launcher.launch_shape)
		if launched < 0 or shape < 0:
			continue
		var spawned := enemies.spawn(launched, shape as PathShapes.Id, stage_time, enemies.position_of(index), false,
			1.0, _hp_scale())
		if spawned >= 0:
			stats.air_spawned += 1
			_send_enemies(PackedInt32Array([spawned]))
	for index: int in ground.take_ready_guns(stage_time):
		var type := ground.type_of(index)
		var origin := ground.position_of(index)
		_fire_pattern(type.shot_pattern, origin, _aim_from(origin), type.bullet_damage)


## Host: an enemy gun fires here; every peer gets the pattern event.
func _fire_pattern(pattern: int, origin: Vector2, aim: float, damage: int) -> void:
	var seed_value := _rng.randi() & 0x7fffffff
	_spawn_pattern(pattern, origin, aim, seed_value, damage, 0.0)
	_pattern_ids.append(pattern)
	_pattern_origins.append(origin)
	_pattern_aims.append(aim)
	_pattern_seeds.append(seed_value)
	_pattern_times.append(stage_time)


## `age` > 0 starts the pattern partway through (clients catching up on lag).
## Only the host's bullets deal damage, so clients pass 0.
func _spawn_pattern(pattern: int, origin: Vector2, aim: float, seed_value: int, damage: int, age: float) -> void:
	if pattern < 0 or pattern >= ShotPatterns.Id.size() or ShotPatterns.is_ship_pattern(pattern):
		return
	if pattern == ShotPatterns.Id.LASER:
		effects.warning(origin, aim, ShotPatterns.LASER_WARNING - age)
	var bullets := ShotPatterns.build(pattern as ShotPatterns.Id, aim, seed_value)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		var offset := Vector2(bullets[i + 3], bullets[i + 4])
		enemy_bullets.spawn(origin + offset, Vector2.from_angle(bullets[i]) * bullets[i + 1], damage,
			ENEMY_BULLET_LIFETIME, 0, 0, age - bullets[i + 2])


func _flush_patterns() -> void:
	if _pattern_ids.is_empty():
		return
	for peer_id: int in _ready_peers:
		_receive_patterns.rpc_id(peer_id, _pattern_ids, _pattern_origins, _pattern_aims, _pattern_seeds, _pattern_times)
	_pattern_ids.clear()
	_pattern_origins.clear()
	_pattern_aims.clear()
	_pattern_seeds.clear()
	_pattern_times.clear()


## Kamikazes lock onto the nearest ship once and fly straight through; trackers
## slide toward the nearest ship's side for a while, then leave upward.
func _steer_homing() -> void:
	var targets := _ship_positions(ships())
	for index: int in enemies.take_due_homing(stage_time, HOMING_EVERY):
		var type := enemies.type_of(index)
		var at := enemies.position_of(index)
		var target := GroundManager.nearest(at, targets)
		match type.homing:
			EnemyType.Homing.KAMIKAZE:
				if enemies.has_redirect(index) or not target.is_finite():
					continue
				_redirect(index, at, target, type.homing_speed, true)
			EnemyType.Homing.TRACKER:
				if enemies.is_leaving(index):
					continue
				if stage_time - enemies.spawn_time_of(index) > type.homing_delay + TRACKER_SECONDS:
					_redirect(index, at, Vector2(at.x, -80.0), TRACKER_LEAVE_SPEED, true)
					enemies.mark_leaving(index)
				elif target.is_finite():
					_redirect(index, at, Vector2(target.x, at.y), type.homing_speed, false)


func _redirect(index: int, from: Vector2, target: Vector2, speed: float, keep_going: bool) -> void:
	enemies.redirect(index, stage_time, from, target, speed, keep_going)
	for peer_id: int in _ready_peers:
		_receive_redirect.rpc_id(peer_id, index, stage_time, from, target, speed, keep_going)


## Ships touching air enemies lose HP; kamikazes blow up on contact.
func _apply_contact(list: Array[Ship]) -> void:
	for index: int in enemies.alive_indices():
		var type := enemies.type_of(index)
		var at := enemies.position_of(index)
		for ship: Ship in list:
			var reach := type.radius + ship.stats.hitbox_radius + CONTACT_SLACK
			if ship.state.position.distance_squared_to(at) > reach * reach:
				continue
			if ship.take_hit(type.contact_damage) and type.dies_on_contact:
				enemies.damage(index, enemies.hp_of(index), 0)
				break


func _on_enemy_killed(index: int, at: Vector2, by_peer: int) -> void:
	kills += 1
	if not multiplayer.is_server():
		return
	var type := enemies.type_of(index)
	var scrap_scale := StageModifiers.ELITE_SCRAP if enemies.is_elite(index) else 1
	if not type.is_boss and not type.boss_part:
		stats.air_killed += 1
	stats.kill_score += type.scrap * scrap_scale * StageGoals.SCORE_PER_SCRAP
	if by_peer > 0:
		RunState.current.player(by_peer).kills += 1
	_drop(type, at, scrap_scale)
	for peer_id: int in _ready_peers:
		_receive_kill.rpc_id(peer_id, index)
	if index == _boss_index:
		_on_boss_defeated(at)


func _on_ground_destroyed(index: int, at: Vector2, by_peer: int) -> void:
	ground_kills += 1
	if not multiplayer.is_server():
		return
	stats.ground_destroyed += 1
	stats.kill_score += ground.type_of(index).scrap * StageGoals.SCORE_PER_SCRAP
	if by_peer > 0:
		RunState.current.player(by_peer).kills += 1
	_drop(ground.type_of(index), at)
	for peer_id: int in _ready_peers:
		_receive_ground_destroyed.rpc_id(peer_id, index)


## Host: what a wreck leaves behind.
func _drop(type: EnemyType, at: Vector2, scrap_scale: int = 1) -> void:
	var drops := Pickups.roll_drops(type, _rng, scrap_scale)
	for i: int in range(0, drops.size(), 2):
		pickups.spawn_host(drops[i], drops[i + 1], at, stage_time)


## Host: someone touched a pickup.
func _on_pickup_collected(kind: int, value: int, peer_id: int) -> void:
	var ship := ship_of(peer_id)
	match kind:
		Pickups.Kind.SCRAP:
			team_scrap += value
		Pickups.Kind.POWER_ORB:
			if ship != null and ship.state.power < ShipMotor.MAX_POWER:
				ship.state.power += 1
			else:
				team_scrap += Pickups.MAX_POWER_SCRAP
		Pickups.Kind.RAPID_FIRE:
			if ship != null:
				ship.state.rapid_fire_left = Pickups.BOOST_SECONDS
		Pickups.Kind.WINGMEN:
			if ship != null:
				ship.state.wingmen_left = Pickups.BOOST_SECONDS
		Pickups.Kind.SPECIAL_CHARGE:
			if ship != null:
				ship.special_charges += 1


# --- Host: boss -------------------------------------------------------------------

## The waves are over: the scroll stops (StageDef.scroll_distance) and the boss flies in.
func _start_boss() -> void:
	phase = Phase.BOSS
	_boss_started_at = stage_time
	var hp_scale := (1.0 + BOSS_HP_PER_EXTRA_PLAYER * _extra_players()) * difficulty * ENEMY_HP
	hp_scale *= WEAK_BOSS_HP if LaunchOptions.weak_bosses else 1.0
	var path := EnemyTypes.ALL[def.boss_type].boss_path as PathShapes.Id
	var origin := Vector2(def.boss_x, BOSS_START_Y)
	_boss_index = enemies.spawn(def.boss_type, path, stage_time, origin, false, 1.0, hp_scale)
	_boss_max_hp = maxi(enemies.hp_of(_boss_index), 1) if _boss_index >= 0 else 1
	_boss_total_hp = _boss_max_hp
	_boss_brain = BossBrain.new(def.boss_steps_one, def.boss_steps_two)
	var spawned := PackedInt32Array([_boss_index])
	# The parts fly the same path from their offsets, so they move with the core.
	for part: StageDef.BossPartDef in def.boss_parts:
		var index := enemies.spawn(part.type_id, path, stage_time, origin + part.offset, false, 1.0, hp_scale)
		if index < 0:
			continue
		_boss_parts.append(index)
		spawned.append(index)
		_boss_total_hp += enemies.hp_of(index)
		if part.required:
			_required_parts.append(index)
	core_open = _required_parts.is_empty()
	if _boss_index >= 0:
		enemies.set_armored(_boss_index, not core_open)
	_show_boss_warning()
	_send_enemies(spawned)


func _show_boss_warning() -> void:
	hud.show_banner("WARNING\n%s" % boss_name(), 3.0)


func _tick_boss(delta: float) -> void:
	if phase != Phase.BOSS or _boss_index < 0 or not enemies.is_alive(_boss_index):
		return
	var left := enemies.hp_of(_boss_index)
	for part: int in _boss_parts:
		if enemies.is_alive(part):
			left += enemies.hp_of(part)
	boss_hp_ratio = clampf(float(left) / _boss_total_hp, 0.0, 1.0)
	if not core_open:
		for part: int in _required_parts:
			if enemies.is_alive(part):
				return  # The core stays armored and quiet until every required part is gone.
		core_open = true
		enemies.set_armored(_boss_index, false)
		_show_core_open()
	var core_ratio := clampf(float(enemies.hp_of(_boss_index)) / _boss_max_hp, 0.0, 1.0)
	if not _desperate and core_ratio < DESPERATION_HP:
		_desperate = true
		# Everything still standing sinks toward the players together.
		for index: int in PackedInt32Array([_boss_index]) + _boss_parts:
			if enemies.is_alive(index):
				var at := enemies.position_of(index)
				_redirect(index, at, at + Vector2(0.0, DESPERATION_SINK), DESPERATION_SPEED, false)
	var step := _boss_brain.tick(delta, core_ratio)
	if step == null:
		return
	var origin := enemies.position_of(_boss_index) + step.offset
	var damage := enemies.type_of(_boss_index).bullet_damage
	match step.aim:
		BossStep.Aim.FIXED:
			_fire_pattern(step.pattern, origin, step.angle, damage)
		BossStep.Aim.AT_NEAREST:
			_fire_pattern(step.pattern, origin, _aim_from(origin), damage)
		BossStep.Aim.AT_EACH:
			for target: Vector2 in _ship_positions(ships()):
				_fire_pattern(step.pattern, origin, (target - origin).angle(), damage)
		BossStep.Aim.SPIN:
			var angle: float = _spin_angles.get(step, step.angle)
			_spin_angles[step] = angle + BossStep.SPIN_STEP
			_fire_pattern(step.pattern, origin, angle, damage)


func _show_core_open() -> void:
	hud.show_banner("The core is open!", 2.0)


func _on_boss_defeated(at: Vector2) -> void:
	boss_hp_ratio = 0.0
	stats.boss_seconds = stage_time - _boss_started_at
	# Whatever's left of the boss goes down with the core (and drops its loot).
	for part: int in _boss_parts:
		if enemies.is_alive(part):
			enemies.damage(part, enemies.hp_of(part), 0)
	effects.chain(at, Vector2(30, 16), 10, _rng)
	enemy_bullets.clear()
	_end(Phase.CLEAR)


# --- End of the stage ---------------------------------------------------------------

## Host: the stage is won (boss down; or, without a boss, the waves are over and
## the sky is empty) or lost (everyone down and no credits left).
func _check_end(list: Array[Ship], delta: float) -> void:
	if phase == Phase.PLAYING or phase == Phase.BOSS:
		if not list.is_empty() and credits <= 0 and list.all(func(ship: Ship) -> bool: return ship.is_down()):
			_end(Phase.GAME_OVER)
		elif phase == Phase.PLAYING and not def.has_boss() and stage_time >= def.length \
				and enemies.active_count() == 0 and _next_wave >= _waves.size():
			_end(Phase.CLEAR)
	else:
		_end_left -= delta
		if _end_left <= 0.0:
			set_physics_process(false)
			finished.emit()


func _end(result: Phase) -> void:
	phase = result
	_end_left = RESULTS_SECONDS if result == Phase.CLEAR else END_SECONDS
	var results := _finish_run_stage(result)
	_show_end(result, results)
	for peer_id: int in _ready_peers:
		_receive_end.rpc_id(peer_id, result, kills, ground_kills, team_scrap, results)


## Host: the stage's goals and payout go into the run, and every ship's
## power, HP and stats are kept for the next stage. Returns what the results
## panel shows (also sent to clients).
func _finish_run_stage(result: Phase) -> Dictionary:
	var run := RunState.current
	for ship: Ship in ships():
		stats.unused_charges += ship.special_charges
		var player := run.player(ship.peer_id)
		player.power = ship.state.power
		# Shot down at the end: the ship comes back repaired next stage.
		player.hp = -1 if ship.is_down() or ship.health.hp >= ship.health.max_hp else ship.health.hp
		player.extra_charges = 0
		player.damage += enemies.damage_by_peer.get(ship.peer_id, 0) + ground.damage_by_peer.get(ship.peer_id, 0)
	run.team_rapid_fire = 0.0
	run.credits = credits
	var results := {"cleared": result == Phase.CLEAR}
	if result == Phase.CLEAR:
		var goals := StageGoals.met(stats)
		var payout := StageGoals.payout(stats)
		var stage_score := StageGoals.score(stats)
		team_scrap += payout
		run.score += stage_score
		run.stages_done += 1
		if not run.has_next_stage():
			run.result = "won"
		results.merge({"goals": goals, "unused_charges": stats.unused_charges, "payout": payout,
			"stage_score": stage_score, "run_score": run.score, "next": "shop" if run.has_next_stage() else "summary"})
	else:
		run.result = "lost"
	run.team_scrap = team_scrap
	return results


func _show_end(result: Phase, results: Dictionary = {}) -> void:
	phase = result
	print("[stage] %s ended: %s at %.1fs, %d kills, %d Scrap" % [def.name, Phase.keys()[result], stage_time, kills, team_scrap])
	enemy_bullets.clear()
	for ship: Ship in ships():
		ship.controls_enabled = false
	ended.emit()
	if result == Phase.GAME_OVER:
		hud.show_banner("Game over\nThe team ran out of ships.", END_SECONDS)
	else:
		hud.show_results(results, RESULTS_SECONDS)


# --- Networking --------------------------------------------------------------

## A ship's host-owned extras as bytes: power, special charges, then Rapid
## Fire, Wingmen, Shield and respawn countdown in tenths of a second.
static func pack_ship_extra(ship: Ship) -> PackedByteArray:
	var extra := PackedByteArray()
	extra.append(ship.state.power)
	extra.append(clampi(ship.special_charges, 0, 255))
	for seconds: float in [ship.state.rapid_fire_left, ship.state.wingmen_left, ship.state.shield_left, ship.respawn_left]:
		extra.append(clampi(ceili(seconds * 10.0), 0, 255))
	return extra


func _send_snapshot() -> void:
	if _ready_peers.is_empty():
		return
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var acks := PackedInt32Array()
	var hp := PackedInt32Array()
	var max_hp := PackedInt32Array()
	var flags := PackedByteArray()
	var extras := PackedByteArray()
	for ship: Ship in ships():
		ids.append(ship.peer_id)
		positions.append(ship.state.position)
		acks.append(ship.last_processed_seq)
		hp.append(ship.health.hp)
		max_hp.append(ship.health.max_hp)
		flags.append((1 if ship.state.focused else 0) | (2 if ship.health.is_invulnerable() else 0))
		extras.append_array(pack_ship_extra(ship))
	var team := PackedInt32Array([kills, ground_kills, team_scrap, credits, phase, 1 if core_open else 0])
	var boss_ids := PackedInt32Array()
	var boss_ratios := PackedByteArray()
	if phase == Phase.BOSS:
		for index: int in _boss_parts:
			if enemies.is_alive(index):
				boss_ids.append(index)
				boss_ratios.append(roundi(enemies.hp_ratio(index) * 255.0))
	for peer_id: int in _ready_peers:
		_receive_snapshot.rpc_id(peer_id, stage_time, team, boss_hp_ratio, ids, positions, acks, hp, max_hp, flags, extras,
			_boss_index, boss_ids, boss_ratios)


## Client -> host, once, when this client's stage has loaded.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_ready_peers[peer_id] = true
	_add_ship(peer_id)
	# Everything already flying, wrecked or floating (a friend dropping in mid-stage).
	var data := enemies.records()
	_receive_enemies.rpc_id(peer_id, (data[0] as PackedInt32Array).size(), data)
	var wrecked := ground.destroyed_indices()
	_receive_wrecks.rpc_id(peer_id, wrecked.size(), wrecked)
	pickups.send_full_state(peer_id)
	if phase == Phase.CLEAR or phase == Phase.GAME_OVER:
		_receive_end.rpc_id(peer_id, phase, kills, ground_kills, team_scrap, {"cleared": phase == Phase.CLEAR})


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_snapshot(host_time: float, team: PackedInt32Array, host_boss_hp: float, ids: PackedInt32Array,
		positions: PackedVector2Array, acks: PackedInt32Array, hp: PackedInt32Array, max_hp: PackedInt32Array,
		flags: PackedByteArray, extras: PackedByteArray, boss_core: int, boss_ids: PackedInt32Array,
		boss_ratios: PackedByteArray) -> void:
	_sync_clock(host_time)
	if team.size() >= 6:
		kills = team[0]
		ground_kills = team[1]
		team_scrap = team[2]
		credits = team[3]
		if team[4] == Phase.BOSS and phase == Phase.PLAYING:
			phase = Phase.BOSS
			_show_boss_warning()
		if phase == Phase.BOSS and boss_core >= 0 and boss_core < EnemyManager.CAPACITY:
			var open := team[5] == 1
			if open and not core_open:
				_show_core_open()
			core_open = open
			enemies.set_armored(boss_core, not open)
	for b: int in mini(boss_ids.size(), boss_ratios.size()):
		enemies.show_hp_ratio(boss_ids[b], boss_ratios[b] / 255.0)
	boss_hp_ratio = host_boss_hp
	var n := ids.size()
	for array_size: int in [positions.size(), acks.size(), hp.size(), max_hp.size(), flags.size(), extras.size() / 6]:
		n = mini(n, array_size)
	for i: int in n:
		var ship := ship_of(ids[i])
		if ship != null:
			ship.apply_server_state(positions[i], acks[i], (flags[i] & 1) != 0, hp[i], max_hp[i], (flags[i] & 2) != 0,
				extras.slice(i * 6, i * 6 + 6))


## Client: follow the host's stage clock. Our estimate of "host time now" is the
## snapshot's time plus half the round trip.
func _sync_clock(host_time: float) -> void:
	var estimate := host_time + Net.ping_ms() / 2000.0
	if absf(estimate - stage_time) > CLOCK_SNAP:
		stage_time = estimate
	else:
		stage_time = lerpf(stage_time, estimate, CLOCK_EASE)


## Enemy spawn records (EnemyManager.records()). The count comes first so the
## call is valid even with no enemies.
@rpc("authority", "call_remote", "reliable")
func _receive_enemies(_count: int, data: Array) -> void:
	enemies.apply_records(data)


@rpc("authority", "call_remote", "reliable")
func _receive_redirect(index: int, time: float, origin: Vector2, target: Vector2, speed: float, keep_going: bool) -> void:
	enemies.redirect(index, time, origin, target, speed, keep_going)


@rpc("authority", "call_remote", "reliable")
func _receive_kill(index: int) -> void:
	var boss := enemies.is_alive(index) and enemies.type_of(index).is_boss
	var at := enemies.position_of(index)
	enemies.kill(index)
	if boss:
		effects.chain(at, Vector2(30, 16), 10, _rng)


@rpc("authority", "call_remote", "reliable")
func _receive_ground_destroyed(index: int) -> void:
	ground.destroy(index)


@rpc("authority", "call_remote", "reliable")
func _receive_wrecks(_count: int, indices: PackedInt32Array) -> void:
	for index: int in indices:
		ground.destroy(index)


@rpc("authority", "call_remote", "reliable")
func _receive_special(peer_id: int, kind: int, at: Vector2) -> void:
	_show_special(peer_id, kind, at)


@rpc("authority", "call_remote", "reliable")
func _receive_end(result: int, host_kills: int, host_ground_kills: int, host_scrap: int, results: Dictionary) -> void:
	kills = host_kills
	ground_kills = host_ground_kills
	team_scrap = host_scrap
	_show_end(Phase.GAME_OVER if result == Phase.GAME_OVER else Phase.CLEAR, results)


## Client: enemy patterns fired on the host. They're fast-forwarded to where
## they will be when our own inputs reach the host (about one round trip after
## the host fired them), so what we dodge on screen matches what the host checks.
## (From Medieval Survival.)
@rpc("authority", "call_remote", "reliable")
func _receive_patterns(patterns: PackedInt32Array, origins: PackedVector2Array, aims: PackedFloat32Array,
		seeds: PackedInt32Array, fire_times: PackedFloat32Array) -> void:
	var dodge_time := stage_time + Net.ping_ms() / 2000.0
	var n := patterns.size()
	for array_size: int in [origins.size(), aims.size(), seeds.size(), fire_times.size()]:
		n = mini(n, array_size)
	for i: int in n:
		var age := clampf(dodge_time - fire_times[i], 0.0, MAX_PATTERN_CATCH_UP)
		_spawn_pattern(patterns[i], origins[i], aims[i], seeds[i], 0, age)


@rpc("authority", "call_remote", "reliable")
func _receive_shot(shooter_id: int, pattern: int, origin: Vector2, seed_value: int, focus: bool, power: int,
		wingmen: bool, fired_at: float) -> void:
	if not ShotPatterns.is_ship_pattern(pattern):
		return
	_spawn_shot(shooter_id, pattern, origin, seed_value, focus, clampi(power, 1, ShipMotor.MAX_POWER), wingmen,
		clampf(stage_time - fired_at, 0.0, MAX_SHOT_CATCH_UP))
