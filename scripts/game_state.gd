extends Node
## Aero-Liminal — estado global del idle (autoload GameState).

signal ondas_changed(value: float)
signal ops_changed(value: float)
signal upgrade_owned(upgrade_id: String, owned: int)

const COST_MULT := 1.15

## Generadores / upgrades disponibles.
var upgrades: Array[Dictionary] = []

var ondas_actuales: float = 0.0
var ondas_por_segundo: float = 0.0

var _passive_timer: Timer


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


func add_click(amount: float = 1.0) -> void:
	ondas_actuales += amount
	ondas_changed.emit(ondas_actuales)


func _on_passive_tick() -> void:
	if ondas_por_segundo <= 0.0:
		return
	ondas_actuales += ondas_por_segundo
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
	return true


func _recalc_ops() -> void:
	var total := 0.0
	for u in upgrades:
		total += float(u["ondas_per_second"]) * float(u["owned"])
	ondas_por_segundo = total
	ops_changed.emit(ondas_por_segundo)
