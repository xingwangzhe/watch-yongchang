extends Node
## 补给链：弹药产出、费用支付与断供停火判定。

const AMMO_PER_TICK := 3
const POWER_CAP := 6
const POWER_COST_PER_TOWER := 2

var ammo_stock: int = 0
var powered: bool = true
var halted: bool = false
var tick_accum: float = 0.0

func reset() -> void:
	ammo_stock = GameState.START_AMMO
	powered = true
	halted = false
	tick_accum = 0.0

func can_fire() -> bool:
	return powered and ammo_stock > 0 and not halted

func consume_ammo(n: int = 1) -> bool:
	if ammo_stock < n:
		_set_halt(true, "ammo_empty")
		return false
	ammo_stock -= n
	GameState.ammo = ammo_stock
	if ammo_stock == 0:
		_set_halt(true, "ammo_empty")
	return true

func produce(delta: float) -> void:
	tick_accum += delta
	if tick_accum < 1.0:
		return
	tick_accum -= 1.0
	ammo_stock = mini(ammo_stock + AMMO_PER_TICK, 999)
	GameState.add_grain(4)
	GameState.add_silver(2)
	GameState.ammo = ammo_stock
	if ammo_stock >= AMMO_PER_TICK and halted:
		_set_halt(false, "supply_restored")
	print("[SUPPLY] tick grain+4 silver+2 ammo=%d" % ammo_stock)

func set_power(v: bool) -> void:
	if powered != v:
		powered = v
		_set_halt(not v, "power_lost" if not v else "power_restored")

func _set_halt(v: bool, reason: String) -> void:
	if halted == v:
		return
	halted = v
	EventBus.tower_halt.emit(reason)
	print("[SUPPLY] halt firing=%s reason=%s" % [str(not v).to_lower(), reason])
