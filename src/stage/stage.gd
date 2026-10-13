class_name Stage
extends Node2D
## One stage being played, solo or online. M2: the M1 feel test (scrolling test
## ground, looping S-curve test wave) with 1–4 ships.
##
## Stage time is the shared clock (DESIGN.md §2 Networking): the scroll and
## every scripted enemy position are computed from it on every peer. The host
## owns the game: it spawns enemies, applies damage and sends only events
## (spawns, kills, shots) and small ship snapshots. Gameplay runs in tick(), in
## a fixed order; child nodes never run gameplay on their own.

## 1 px per tick at 60 ticks/s: the smoothest speed for pixel art scrolling.
const SCROLL_SPEED: float = 60.0
const WAVE_EVERY: float = 4.0
const FIRST_WAVE_AT: float = 1.0
const WAVE_SIZE: int = 6
const WAVE_SPACING: float = 0.35
## Test wave entry points (x), alternating each wave; odd waves are mirrored.
const WAVE_ENTRIES: Array[float] = [300.0, 660.0]
const SHIP_START_Y: float = 460.0
## Ships start side by side, by slot.
const SHIP_START_X: Array[float] = [420.0, 540.0, 300.0, 660.0]
const BULLET_LIFETIME: float = 1.5
## Shots from other players are fast-forwarded by how late they arrived, up to this.
const MAX_SHOT_CATCH_UP: float = 0.3
const SNAPSHOT_INTERVAL_TICKS: int = 2
## Client: a clock further off than this jumps; closer, it eases in.
const CLOCK_SNAP: float = 0.25
const CLOCK_EASE: float = 0.1

var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))
var stage_time: float = 0.0
var kills: int = 0

var _next_wave_time: float = FIRST_WAVE_AT
var _wave_index: int = 0
var _tick: int = 0
## Host: peers whose stage has loaded (only they get messages).
var _ready_peers: Dictionary[int, bool] = {}

@onready var background: ScrollBackground = $Background
@onready var enemies: EnemyManager = $Enemies
@onready var player_bullets: ProjectileManager = $PlayerBullets
@onready var ships_node: Node2D = $Ships
@onready var hud: StageHud = $Hud
@onready var _ship_spawner: MultiplayerSpawner = $ShipSpawner


func _ready() -> void:
	# Every peer needs the spawn function: the host calls it via spawn(), and
	# clients call it automatically with the same data when the spawn replicates.
	_ship_spawner.spawn_function = _spawn_ship
	player_bullets.bounds = play_area.grow(24.0)
	player_bullets.spawn_backtrack = absf(Ships.ALL[0].muzzle_offset.y)
	enemies.play_area = play_area
	enemies.killed.connect(_on_enemy_killed)
	if multiplayer.is_server():
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
	for ship: Ship in ships():
		ship.tick(delta)
	if is_host:
		_spawn_test_waves()
	enemies.tick(stage_time, delta)
	player_bullets.step(delta)
	player_bullets.resolve_hits(enemies, is_host)
	background.scroll = stage_time * SCROLL_SPEED
	var me := local_ship()
	hud.show_state(Settings.fire_mode, me != null and me.firing, kills, ships())
	if is_host and _tick % SNAPSHOT_INTERVAL_TICKS == 0:
		_send_snapshot()


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


## Text summary for headless smoke tests (--run-for).
func debug_report() -> String:
	var lines := PackedStringArray()
	var role := "host" if multiplayer.is_server() else "client"
	lines.append("[report] peer %d (%s)  stage time %.1fs  ships: %d  kills: %d  enemies: %d  bullets: %d" % [
		multiplayer.get_unique_id(), role, stage_time, ships().size(), kills, enemies.active_count(), player_bullets.count()])
	for ship: Ship in ships():
		var line := "[report]   ship %d (%s) slot %d at %s" % [ship.peer_id, ship.display_name(), ship.slot, ship.state.position.round()]
		if ship.is_local() and not multiplayer.is_server():
			line += "  corrections=%d largest=%.2fpx" % [ship.correction_count, ship.largest_correction]
		lines.append(line)
	if multiplayer.is_server():
		lines.append("[report]   damage by peer: %s" % [enemies.damage_by_peer])
		lines.append("[report]   invite: '%s'  %s" % [Net.invite.address, Net.invite.status])
	lines.append("[report]   physics time: %.2f ms/tick" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return "\n".join(lines)


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


# --- Shots -------------------------------------------------------------------

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


# --- Enemies -----------------------------------------------------------------

## Host, M2 only: a wave of S-curve enemies every few seconds, from alternating sides.
func _spawn_test_waves() -> void:
	while stage_time >= _next_wave_time:
		var entry := Vector2(WAVE_ENTRIES[_wave_index % WAVE_ENTRIES.size()], -16.0)
		var indices := PackedInt32Array()
		for i: int in WAVE_SIZE:
			var index := enemies.spawn(PathShapes.Id.S_CURVE, _next_wave_time + i * WAVE_SPACING, entry, _wave_index % 2 == 1)
			if index >= 0:
				indices.append(index)
		_send_spawns(indices)
		_wave_index += 1
		_next_wave_time += WAVE_EVERY


## Host: tells every loaded peer about these newly spawned enemies.
func _send_spawns(indices: PackedInt32Array) -> void:
	if indices.is_empty() or _ready_peers.is_empty():
		return
	var all: Array = enemies.records()
	var wanted := PackedInt32Array()
	var shapes := PackedInt32Array()
	var times := PackedFloat32Array()
	var origins := PackedVector2Array()
	var mirrors := PackedByteArray()
	var record_indices: PackedInt32Array = all[0]
	for r: int in record_indices.size():
		if indices.has(record_indices[r]):
			wanted.append(record_indices[r])
			shapes.append((all[1] as PackedInt32Array)[r])
			times.append((all[2] as PackedFloat32Array)[r])
			origins.append((all[3] as PackedVector2Array)[r])
			mirrors.append((all[4] as PackedByteArray)[r])
	for peer_id: int in _ready_peers:
		_receive_spawns.rpc_id(peer_id, wanted.size(), wanted, shapes, times, origins, mirrors)


func _on_enemy_killed(index: int, _at: Vector2, _by_peer: int) -> void:
	kills += 1
	if multiplayer.is_server():
		for peer_id: int in _ready_peers:
			_receive_kill.rpc_id(peer_id, index)


# --- Networking --------------------------------------------------------------

func _send_snapshot() -> void:
	if _ready_peers.is_empty():
		return
	var ids := PackedInt32Array()
	var positions := PackedVector2Array()
	var acks := PackedInt32Array()
	var flags := PackedByteArray()
	for ship: Ship in ships():
		ids.append(ship.peer_id)
		positions.append(ship.state.position)
		acks.append(ship.last_processed_seq)
		flags.append(1 if ship.state.focused else 0)
	for peer_id: int in _ready_peers:
		_receive_snapshot.rpc_id(peer_id, stage_time, kills, ids, positions, acks, flags)


## Client -> host, once, when this client's stage has loaded.
@rpc("any_peer", "call_remote", "reliable")
func _notify_ready() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_ready_peers[peer_id] = true
	_add_ship(peer_id)
	# Everything already flying (a friend dropping in mid-stage).
	var all: Array = enemies.records()
	var indices: PackedInt32Array = all[0]
	_receive_spawns.rpc_id(peer_id, indices.size(), all[0], all[1], all[2], all[3], all[4])


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_snapshot(host_time: float, host_kills: int, ids: PackedInt32Array, positions: PackedVector2Array,
		acks: PackedInt32Array, flags: PackedByteArray) -> void:
	_sync_clock(host_time)
	kills = host_kills
	for i: int in mini(ids.size(), mini(positions.size(), mini(acks.size(), flags.size()))):
		var ship := ship_of(ids[i])
		if ship != null:
			ship.apply_server_state(positions[i], acks[i], flags[i] == 1)


## Client: follow the host's stage clock. Our estimate of "host time now" is the
## snapshot's time plus half the round trip.
func _sync_clock(host_time: float) -> void:
	var estimate := host_time + Net.ping_ms() / 2000.0
	if absf(estimate - stage_time) > CLOCK_SNAP:
		stage_time = estimate
	else:
		stage_time = lerpf(stage_time, estimate, CLOCK_EASE)


## The count comes first so the call is valid even with no enemies.
@rpc("authority", "call_remote", "reliable")
func _receive_spawns(count: int, indices: PackedInt32Array, shapes: PackedInt32Array, times: PackedFloat32Array,
		origins: PackedVector2Array, mirrors: PackedByteArray) -> void:
	var n := mini(count, mini(indices.size(), mini(shapes.size(), mini(times.size(), mini(origins.size(), mirrors.size())))))
	for i: int in n:
		if shapes[i] >= 0 and shapes[i] < PathShapes.Id.size():
			enemies.spawn_at(indices[i], shapes[i] as PathShapes.Id, times[i], origins[i], mirrors[i] == 1)


@rpc("authority", "call_remote", "reliable")
func _receive_kill(index: int) -> void:
	enemies.kill(index)


@rpc("authority", "call_remote", "reliable")
func _receive_shot(shooter_id: int, pattern: int, origin: Vector2, seed_value: int, focus: bool, fired_at: float) -> void:
	if pattern < 0 or pattern >= ShotPatterns.Id.size():
		return
	_spawn_shot(shooter_id, pattern, origin, seed_value, focus, clampf(stage_time - fired_at, 0.0, MAX_SHOT_CATCH_UP))
