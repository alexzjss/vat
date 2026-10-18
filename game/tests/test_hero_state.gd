extends GutTest

## Descanso (stand-in do ponto de descanso no M1): HP/AP cheios via StatCalculator.

func test_rest_restores_full_hp_ap_with_allocation_and_level() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2)), cfg)
	h.level = 3
	h.allocated = Stats.make(0, 0, 2, 1)
	h.hp = 4
	h.ap = 1
	h.rest(cfg)
	# Vitalidade 7 * 10 + nível 3 * 5 = 85; Aura 3 * 5 = 15.
	assert_eq(h.hp, 85)
	assert_eq(h.ap, 15)

func test_rest_revives_downed() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2)), cfg)
	h.hp = 0
	h.ap = 0
	h.rest(cfg)
	assert_eq(h.hp, 55)
	assert_eq(h.ap, 10)

func test_create_starts_at_full() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2)), cfg)
	assert_eq(h.hp, 55)
	assert_eq(h.ap, 10)

func test_snapshot_restore_roundtrip() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2)), cfg)
	h.xp = 30
	h.level = 2
	h.pending_points = 1
	h.allocated = Stats.make(1, 0, 2, 0)
	var snap: Dictionary = h.snapshot()
	h.hp = 1
	h.ap = 0
	h.xp = 999
	h.level = 7
	h.pending_points = 5
	h.allocated.strength = 9
	h.restore(snap)
	assert_eq([h.hp, h.ap, h.xp, h.level, h.pending_points], [55, 10, 30, 2, 1])
	assert_eq([h.allocated.strength, h.allocated.speed, h.allocated.vitality, h.allocated.aura], [1, 0, 2, 0])
	assert_ne(h.allocated, snap["allocated"])
