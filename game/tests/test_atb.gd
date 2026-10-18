extends GutTest
var cfg: BalanceConfig
func _c(id: StringName, spd: int) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1, spd, 1, 1)), id, Vector2.ZERO, cfg)
func before_each() -> void:
	cfg = Fixtures.cfg()
func test_faster_fills_sooner() -> void:
	var fast := _c(&"f", 30); var slow := _c(&"s", 0)
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	var ready := AtbClock.new(cfg).advance(2.0, [fast, slow], q)
	assert_eq(ready, [fast])
func test_queue_orders_by_speed() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new([0.5, 0.5]))
	var a := _c(&"a", 5); var b := _c(&"b", 9)
	q.push(a, 1); q.push(b, 1)
	assert_eq(q.pop_next(), b)
func test_tie_drawn_once_and_kept() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new([0.9, 0.1]))
	var a := _c(&"a", 5); var b := _c(&"b", 5)
	q.push(a, 1); q.push(b, 1)
	assert_eq(q.ordered(), [b, a])
	assert_eq(q.ordered(), [b, a])
func test_equal_speed_earlier_tick_first() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new([0.9, 0.1]))
	var a := _c(&"a", 5); var b := _c(&"b", 5)
	q.push(a, 1); q.push(b, 2)
	assert_eq(q.pop_next(), a)
func test_queue_skips_downed() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	var a := _c(&"a", 9); var b := _c(&"b", 1)
	q.push(a, 1); q.push(b, 1); a.hp = 0
	assert_eq(q.pop_next(), b)
func test_speed_change_reorders_queue() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	var a := _c(&"a", 9); var b := _c(&"b", 5)
	q.push(a, 1); q.push(b, 1)
	a.equipment_mods = Stats.make(0, -8, 0, 0)
	assert_eq(q.peek(), b)
