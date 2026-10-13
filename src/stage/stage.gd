class_name Stage
extends Node2D
## One stage being played, solo or online (DESIGN.md §3). The stage's waves and
## ground objects come from its `.stage` file (StageDef).
##
## Stage time is the shared clock (DESIGN.md §2 Networking): the scroll, every
## scripted enemy and every ground object position are computed from it on
## every peer. The host owns the game: it spawns waves, aims and fires enemy
## guns, steers homing enemies, applies all damage, and sends only events
## (enemy spawn records, redirects, kills, ground destructions, shot patterns)
## and small ship snapshots. Gameplay runs in tick(), in a fixed order; child
## nodes never run gameplay on their own.

## Host: the stage is over (back to the lobby until M4/M5 add the boss, results and shop).
signal finished

enum Phase { PLAYING, CLEAR }

## Extra enemy / ground HP per player beyond the first (DESIGN.md §5: partial scaling, draft).
const HP_PER_EXTRA_PLAYER: float = 0.6
const SHIP_START_Y: float = 460.0
## Ships start side by side, by slot.
const SHIP_START_X: Array[float] = [420.0, 540.0, 300.0, 660.0]
const BULLET_LIFETIME: float = 1.5
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
## Seconds the "stage clear" banner shows before the host moves on.
const CLEAR_SECONDS: float = 6.0

## Which stage (Stages.PATHS index).
var stage_index: int = 0
var def: StageDef = null
var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))
var stage_time: float = 0.0
var phase: Phase = Phase.PLAYING
var kills: int = 0
var ground_kills: int = 0

## Host: this run's waves (variants picked), sorted by time, and the next one due.
var _waves: Array[StageDef.WaveDef] = []
var _next_wave: int = 0
var _tick: int = 0
var _clear_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
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
@onready var player_bullets: ProjectileManager = $PlayerBullets
@onready var enemy_bullets: ProjectileManager = $EnemyBullets
@onready var ships_node: Node2D = $Ships
@onready var hud: StageHud = $Hud
@onready var _ship_spawner: MultiplayerSpawner = $ShipSpawner


func _ready() -> void:
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
	hud.show_banner(def.name, 2.5)
	if multiplayer.is_server():
		_rng.randomize()
		_waves = def.waves_for_seed(_rng.randi())
		stage_time = LaunchOptions.start_at_seconds
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


## One simulation step, in a fixed order.
func tick(delta: float) -> void:
	var is_host := multiplayer.is_server()
	_tick += 1
	stage_time += delta
	var all_ships := ships()
	for ship: Ship in all_ships:
		ship.tick(delta)
	if is_host and phase == Phase.PLAYING:
		_spawn_due_waves()
	enemies.tick(stage_time, delta)
	ground.tick(stage_time, delta, _ship_positions(all_ships), _hp_scale())
	if is_host:
		_steer_homing()
		_fire_guns()
		_apply_contact(all_ships)
	player_bullets.step(delta)
	player_bullets.resolve_hits(enemies, ground, is_host)
	enemy_bullets.step(delta)
	enemy_bullets.resolve_ship_hits(all_ships, is_host)
	background.scroll = stage_time * def.scroll_speed
	hud.show_state(self, local_ship())
	if is_host:
		_flush_patterns()
		if _tick % SNAPSHOT_INTERVAL_TICKS == 0:
			_send_snapshot()
		_check_end(delta)


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


## Text summary for headless smoke tests (--run-for).
func debug_report() -> String:
	var lines := PackedStringArray()
	var role := "host" if multiplayer.is_server() else "client"
	lines.append("[report] peer %d (%s)  %s  stage time %.1fs  phase %s  ships: %d  kills: %d  ground: %d/%d  enemies: %d  bullets: %d / enemy %d" % [
		multiplayer.get_unique_id(), role, def.name, stage_time, Phase.keys()[phase], ships().size(), kills,
		ground_kills, ground.count(), enemies.active_count(), player_bullets.count(), enemy_bullets.count()])
	for ship: Ship in ships():
		var line := "[report]   ship %d (%s) slot %d at %s  hp %d/%d" % [ship.peer_id, ship.display_name(), ship.slot,
			ship.state.position.round(), ship.health.hp, ship.health.max_hp]
		if ship.is_local() and not multiplayer.is_server():
			line += "  corrections=%d largest=%.2fpx" % [ship.correction_count, ship.largest_correction]
		lines.append(line)
	if multiplayer.is_server():
		lines.append("[report]   damage by peer: %s  ground: %s" % [enemies.damage_by_peer, ground.damage_by_peer])
		lines.append("[report]   invite: '%s'  %s" % [Net.invite.address, Net.invite.status])
	lines.append("[report]   physics time: %.2f ms/tick" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return "\n".join(lines)


func _hp_scale() -> float:
	return 1.0 + HP_PER_EXTRA_PLAYER * maxi(ships().size() - 1, 0)


static func _ship_positions(list: Array[Ship]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for ship: Ship in list:
		points.append(ship.state.position)
	return points


# --- Ships -------------------------------------------------------------------

## Host: a ship for this peer (at the start, or a friend dropping in).
func _add_ship(peer_id: int) -> void:
	if ship_of(peer_id) != null:
		return
	_ship_spawner.spawn({"peer_id": peer_id, "slot": _free_slot(), "ship": RunSetup.ship_for(peer_id)})


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
	ship.setup(int(info["peer_id"]), slot, ship_id, Vector2(SHIP_START_X[slot], SHIP_START_Y), play_area)
	ship.fired.connect(_on_ship_fired)
	return ship


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


# --- Player shots ------------------------------------------------------------

## Runs on the host for every ship's shot, and on a client for its own
## predicted shots. Only the host tells other peers about it.
func _on_ship_fired(ship: Ship, seq: int, focus: bool) -> void:
	var stats := ship.stats
	var pattern := stats.focus_pattern if focus else stats.gun_pattern
	var origin := ship.state.position + stats.muzzle_offset
	var seed_value := ShotPatterns.make_seed(ship.peer_id, seq)
	_spawn_shot(ship.peer_id, pattern, origin, seed_value, focus, 0.0)
	if multiplayer.is_server():
		for peer_id: int in _ready_peers:
			# The shooter already predicted this shot itself.
			if peer_id != ship.peer_id:
				_receive_shot.rpc_id(peer_id, ship.peer_id, pattern, origin, seed_value, focus, stage_time)


func _spawn_shot(shooter_id: int, pattern: int, origin: Vector2, seed_value: int, focus: bool, start_age: float) -> void:
	var shooter := ship_of(shooter_id)
	var stats := shooter.stats if shooter != null else Ships.ALL[0]
	var damage := stats.focus_bullet_damage if focus else stats.bullet_damage
	var bullets := ShotPatterns.build(pattern as ShotPatterns.Id, -PI / 2.0, seed_value, 1, stats.bullet_speed)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		var velocity := Vector2.from_angle(bullets[i]) * bullets[i + 1]
		var offset := Vector2(bullets[i + 3], bullets[i + 4])
		player_bullets.spawn(origin + offset, velocity, damage, BULLET_LIFETIME, shooter_id, 0, start_age - bullets[i + 2])


# --- Host: waves, guns, homing, collisions -------------------------------------

func _spawn_due_waves() -> void:
	while _next_wave < _waves.size() and _waves[_next_wave].time <= stage_time:
		var wave := _waves[_next_wave]
		_next_wave += 1
		var indices := PackedInt32Array()
		for i: int in wave.count:
			var origin := wave.origin + Vector2(wave.dx * i, 0.0)
			var index := enemies.spawn(wave.type_id, wave.shape as PathShapes.Id, wave.time + i * wave.spacing, origin,
				wave.mirror, wave.pace, _hp_scale())
			if index >= 0:
				indices.append(index)
		if not indices.is_empty() and not _ready_peers.is_empty():
			var data := enemies.records(indices)
			for peer_id: int in _ready_peers:
				_receive_enemies.rpc_id(peer_id, indices.size(), data)


## Aims at the nearest ship (straight down if there are none).
func _aim_from(origin: Vector2) -> float:
	var target := GroundManager.nearest(origin, _ship_positions(ships()))
	return (target - origin).angle() if target.is_finite() else PI / 2.0


func _fire_guns() -> void:
	if phase != Phase.PLAYING:
		return
	for index: int in enemies.take_ready_guns(stage_time):
		var type := enemies.type_of(index)
		var origin := enemies.position_of(index)
		_fire_pattern(type.shot_pattern, origin, _aim_from(origin), type.bullet_damage)
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


func _on_enemy_killed(index: int, _at: Vector2, _by_peer: int) -> void:
	kills += 1
	if multiplayer.is_server():
		for peer_id: int in _ready_peers:
			_receive_kill.rpc_id(peer_id, index)


func _on_ground_destroyed(index: int, _at: Vector2, _by_peer: int) -> void:
	ground_kills += 1
	if multiplayer.is_server():
		for peer_id: int in _ready_peers:
			_receive_ground_destroyed.rpc_id(peer_id, index)


## Host: once the waves are over and the sky is empty, the stage is clear.
func _check_end(delta: float) -> void:
	if phase == Phase.PLAYING:
		if stage_time >= def.length and enemies.active_count() == 0 and _next_wave >= _waves.size():
			phase = Phase.CLEAR
			_clear_left = CLEAR_SECONDS
			_show_clear()
			for peer_id: int in _ready_peers:
				_receive_clear.rpc_id(peer_id, kills, ground_kills)
	elif phase == Phase.CLEAR:
		_clear_left -= delta
		if _clear_left <= 0.0:
			set_physics_process(false)
			finished.emit()


func _show_clear() -> void:
	phase = Phase.CLEAR
	enemy_bullets.clear()
	hud.show_banner("Stage clear!\n%d kills, %d of %d ground targets\n(The boss arrives in M4.)" % [
		kills, ground_kills, ground.count()], CLEAR_SECONDS)


# --- Networking --------------------------------------------------------------

func _send_snapshot() -> void:
	if _ready_peers.is_empty():
		return
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var acks := PackedInt32Array()
	var hp := PackedInt32Array()
	var max_hp := PackedInt32Array()
	var flags := PackedByteArray()
	for ship: Ship in ships():
		ids.append(ship.peer_id)
		positions.append(ship.state.position)
		acks.append(ship.last_processed_seq)
		hp.append(ship.health.hp)
		max_hp.append(ship.health.max_hp)
		flags.append((1 if ship.state.focused else 0) | (2 if ship.health.is_invulnerable() else 0))
	for peer_id: int in _ready_peers:
		_receive_snapshot.rpc_id(peer_id, stage_time, kills, ground_kills, ids, positions, acks, hp, max_hp, flags)


## Client -> host, once, when this client's stage has loaded.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_ready_peers[peer_id] = true
	_add_ship(peer_id)
	# Everything already flying and already wrecked (a friend dropping in mid-stage).
	var data := enemies.records()
	_receive_enemies.rpc_id(peer_id, (data[0] as PackedInt32Array).size(), data)
	var wrecked := ground.destroyed_indices()
	_receive_wrecks.rpc_id(peer_id, wrecked.size(), wrecked)
	if phase == Phase.CLEAR:
		_receive_clear.rpc_id(peer_id, kills, ground_kills)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_snapshot(host_time: float, host_kills: int, host_ground_kills: int, ids: PackedInt32Array,
		positions: PackedVector2Array, acks: PackedInt32Array, hp: PackedInt32Array, max_hp: PackedInt32Array,
		flags: PackedByteArray) -> void:
	_sync_clock(host_time)
	kills = host_kills
	ground_kills = host_ground_kills
	var n := ids.size()
	for array_size: int in [positions.size(), acks.size(), hp.size(), max_hp.size(), flags.size()]:
		n = mini(n, array_size)
	for i: int in n:
		var ship := ship_of(ids[i])
		if ship != null:
			ship.apply_server_state(positions[i], acks[i], (flags[i] & 1) != 0, hp[i], max_hp[i], (flags[i] & 2) != 0)


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
	enemies.kill(index)


@rpc("authority", "call_remote", "reliable")
func _receive_ground_destroyed(index: int) -> void:
	ground.destroy(index)


@rpc("authority", "call_remote", "reliable")
func _receive_wrecks(_count: int, indices: PackedInt32Array) -> void:
	for index: int in indices:
		ground.destroy(index)


@rpc("authority", "call_remote", "reliable")
func _receive_clear(host_kills: int, host_ground_kills: int) -> void:
	kills = host_kills
	ground_kills = host_ground_kills
	_show_clear()


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
func _receive_shot(shooter_id: int, pattern: int, origin: Vector2, seed_value: int, focus: bool, fired_at: float) -> void:
	if not ShotPatterns.is_ship_pattern(pattern):
		return
	_spawn_shot(shooter_id, pattern, origin, seed_value, focus, clampf(stage_time - fired_at, 0.0, MAX_SHOT_CATCH_UP))
