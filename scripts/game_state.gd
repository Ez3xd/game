extends Node
## Aero-Liminal — estado global del idle (autoload GameState).

signal ondas_changed(value: float)
signal ops_changed(value: float)
signal upgrade_owned(upgrade_id: String, owned: int)
signal generators_changed(count: int)
signal dimension_complete
signal dimension_changed(dim_index: int)

const COST_MULT := 1.15
const GENERATORS_GOAL := 12
const PRESTIGE_STEP := 1.5

## Generadores / upgrades disponibles.
var upgrades: Array[Dictionary] = []

var ondas_actuales: float = 0.0
var ondas_por_segundo: float = 0.0
var dimensiones_completadas: int = 0
var prestige_mult: float = 1.0

var _passive_timer: Timer
var _dimension_cleared: bool = false


func _ready() -> void:
	_init_upgrades()
	_passive_timer = Timer.new()
	_passive_timer.name = "PassiveTimer"
	_passive_timer.wait_time = 1.0
	_passive_timer.one_shot = false
	_passive_timer.autostart = true
	_passive_timer.timeout.connect(_on_passive_tick)
	add_child(_passive_timer)


func _init_upgrades() -> void:
	upgrades = [
		{
			"id": "vinilo",
			"name": "Vinilo",
			"base_cost": 15.0,
			"cost_mult": COST_MULT,
			"ondas_per_second": 0.1,
			"owned": 0,
		},
		{
			"id": "pecera_frutiger",
			"name": "Pecera Frutiger",
			"base_cost": 100.0,
			"cost_mult": COST_MULT,
			"ondas_per_second": 1.0,
			"owned": 0,
		},
		{
			"id": "monitor_retro",
			"name": "Monitor Retro",
			"base_cost": 500.0,
			"cost_mult": COST_MULT,
			"ondas_per_second": 5.0,
			"owned": 0,
		},
	]


func get_dimension_index() -> int:
	## 0=oficina, 1=agua, 2=vaporwave (cicla).
	return dimensiones_completadas % 3


func get_total_generators() -> int:
	var total := 0
	for u in upgrades:
		total += int(u["owned"])
	return total


func add_click(amount: float = 1.0) -> void:
	ondas_actuales += amount * prestige_mult
	ondas_changed.emit(ondas_actuales)


func _on_passive_tick() -> void:
	if ondas_por_segundo <= 0.0:
		return
	ondas_actuales += ondas_por_segundo * prestige_mult
	ondas_changed.emit(ondas_actuales)


func get_upgrade(upgrade_id: String) -> Dictionary:
	for u in upgrades:
		if u["id"] == upgrade_id:
			return u
	return {}


func get_cost(upgrade_id: String) -> float:
	var u := get_upgrade(upgrade_id)
	if u.is_empty():
		return INF
	return u["base_cost"] * pow(u["cost_mult"], float(u["owned"]))


func can_buy(upgrade_id: String) -> bool:
	return ondas_actuales >= get_cost(upgrade_id)


## Compra un generador: descuenta costo, sube owned y recalcula OPS.
## Devuelve true si la compra fue exitosa.
func buy(upgrade_id: String) -> bool:
	var u := get_upgrade(upgrade_id)
	if u.is_empty():
		return false
	var cost := get_cost(upgrade_id)
	if ondas_actuales < cost:
		return false
	ondas_actuales -= cost
	u["owned"] = int(u["owned"]) + 1
	_recalc_ops()
	ondas_changed.emit(ondas_actuales)
	upgrade_owned.emit(upgrade_id, int(u["owned"]))
	var total := get_total_generators()
	generators_changed.emit(total)
	if total >= GENERATORS_GOAL and not _dimension_cleared:
		_dimension_cleared = true
		dimension_complete.emit()
	return true


func _recalc_ops() -> void:
	var total := 0.0
	for u in upgrades:
		total += float(u["ondas_per_second"]) * float(u["owned"])
	ondas_por_segundo = total
	ops_changed.emit(ondas_por_segundo)


## Soft reset: sube prestigio, reinicia progreso de la dimensión actual.
func soft_reset() -> void:
	dimensiones_completadas += 1
	prestige_mult *= PRESTIGE_STEP
	ondas_actuales = 0.0
	ondas_por_segundo = 0.0
	_dimension_cleared = false
	for u in upgrades:
		u["owned"] = 0
	_recalc_ops()
	ondas_changed.emit(ondas_actuales)
	generators_changed.emit(0)
	for u in upgrades:
		upgrade_owned.emit(u["id"], 0)
	dimension_changed.emit(get_dimension_index())
