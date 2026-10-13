class_name Stage
extends Node2D
## One stage being played. M1 is the feel test: one ship, a scrolling test
## background and a looping test wave of S-curve enemies.
##
## Stage time is the shared clock (DESIGN.md §2 Networking): the scroll and
## every scripted enemy position are computed from it. Gameplay runs in tick(),
## in a fixed order; child nodes never run gameplay on their own.

## 1 px per tick at 60 ticks/s: the smoothest speed for pixel art scrolling.
const SCROLL_SPEED: float = 60.0
const WAVE_EVERY: float = 4.0
const FIRST_WAVE_AT: float = 1.0
const WAVE_SIZE: int = 6
const WAVE_SPACING: float = 0.35
## Test wave entry points (x), alternating each wave; odd waves are mirrored.
const WAVE_ENTRIES: Array[float] = [300.0, 660.0]
const SHIP_START: Vector2 = Vector2(480, 460)
const BULLET_LIFETIME: float = 1.5
## Peer id of the local player (solo = host = 1).
const LOCAL_PEER: int = 1
## Player 1's ship color (per-player colors come with co-op in M2).
const PLAYER_TINT: Color = Color(0.25, 0.65, 0.95)

var play_area: Rect2 = Rect2(Vector2.ZERO, Vector2(ScreenFit.BASE))
var stage_time: float = 0.0
var kills: int = 0

var _next_wave_time: float = FIRST_WAVE_AT
var _wave_index: int = 0
var _local_input: LocalInput = LocalInput.new()

@onready var background: ScrollBackground = $Background
@onready var enemies: EnemyManager = $Enemies
@onready var player_bullets: ProjectileManager = $PlayerBullets
@onready var ship: Ship = $Ship
@onready var hud: StageHud = $Hud


func _ready() -> void:
	ship.setup(Ships.ALL[0], PLAYER_TINT)
	ship.state.position = SHIP_START
	ship.position = SHIP_START
	player_bullets.bounds = play_area.grow(24.0)
	player_bullets.spawn_backtrack = absf(ship.stats.muzzle_offset.y)
	enemies.play_area = play_area
	enemies.killed.connect(func(_at: Vector2) -> void: kills += 1)


func _physics_process(delta: float) -> void:
	tick(_local_input.sample(ship.state, ship.stats, get_local_mouse_position(), delta), delta)


## One simulation step, in a fixed order.
func tick(input: ShipInput, delta: float) -> void:
	stage_time += delta
	if ship.tick(input, play_area, delta) & ShipMotor.FIRED:
		_fire(ship, input, LOCAL_PEER)
	_spawn_test_waves()
	enemies.tick(stage_time, delta)
	player_bullets.step(delta)
	player_bullets.resolve_hits(enemies, true)
	background.scroll = stage_time * SCROLL_SPEED
	hud.show_state(Settings.fire_mode, input.fire, kills)


func _fire(shooter: Ship, input: ShipInput, peer_id: int) -> void:
	var stats := shooter.stats
	var pattern := (stats.focus_pattern if input.focus else stats.gun_pattern) as ShotPatterns.Id
	var damage := stats.focus_bullet_damage if input.focus else stats.bullet_damage
	var origin := shooter.state.position + stats.muzzle_offset
	var bullets := ShotPatterns.build(pattern, -PI / 2.0, ShotPatterns.make_seed(peer_id, input.seq), 1, stats.bullet_speed)
	for i: int in range(0, bullets.size(), ShotPatterns.STRIDE):
		var velocity := Vector2.from_angle(bullets[i]) * bullets[i + 1]
		var offset := Vector2(bullets[i + 3], bullets[i + 4])
		player_bullets.spawn(origin + offset, velocity, damage, BULLET_LIFETIME, peer_id, 0, -bullets[i + 2])


## M1 only: a wave of S-curve enemies every few seconds, from alternating sides.
func _spawn_test_waves() -> void:
	while stage_time >= _next_wave_time:
		var entry := Vector2(WAVE_ENTRIES[_wave_index % WAVE_ENTRIES.size()], -16.0)
		for i: int in WAVE_SIZE:
			enemies.spawn(PathShapes.Id.S_CURVE, _next_wave_time + i * WAVE_SPACING, entry, _wave_index % 2 == 1)
		_wave_index += 1
		_next_wave_time += WAVE_EVERY
