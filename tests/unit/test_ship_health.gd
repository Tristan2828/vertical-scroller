extends GutTest
## The ship's HP bar and the blink after hits.


func test_a_hit_costs_hp_and_gives_a_blink() -> void:
	var health := ShipHealth.new()
	health.reset(100)
	assert_true(health.take_hit(12))
	assert_eq(health.hp, 88)
	assert_true(health.is_invulnerable())
	assert_false(health.take_hit(12), "blinking: no second hit")
	health.tick(ShipHealth.HIT_SAFE_SECONDS)
	assert_true(health.take_hit(12))
	assert_eq(health.hp, 76)


func test_hp_stops_at_zero() -> void:
	var health := ShipHealth.new()
	health.reset(10)
	health.take_hit(99)
	assert_eq(health.hp, 0)
	assert_true(health.is_empty())
	assert_eq(health.ratio(), 0.0)


func test_heal_caps_at_max() -> void:
	var health := ShipHealth.new()
	health.reset(100)
	health.take_hit(30)
	health.heal(50)
	assert_eq(health.hp, 100)
