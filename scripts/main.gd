extends Node3D
## Escena principal Aero-Liminal: click idle + UI + spawn de billboards.

@onready var ondas_label: Label = %OndasLabel
@onready var ops_label: Label = %OpsLabel
@onready var buy_buttons: VBoxContainer = %BuyButtons
@onready var vinyl: Sprite3D = %VinylSprite
@onready var spawn_root: Node3D = %SpawnRoot

## Posiciones predefinidas (locales) para spawns de generadores.
const SPAWN_SLOTS: Array[Vector3] = [
	Vector3(-2.5, 1.0, -1.5),
	Vector3(2.5, 1.0, -1.5),
	Vector3(-3.0, 1.2, 1.0),
	Vector3(3.0, 1.2, 1.0),
	Vector3(-1.5, 1.4, -3.0),
	Vector3(1.5, 1.4, -3.0),
	Vector3(0.0, 1.6, -4.0),
	Vector3(-4.0, 1.0, 0.0),
	Vector3(4.0, 1.0, 0.0),
]

const UPGRADE_TEXTURES := {
	"vinilo": "res://assets/placeholders/vinilo.png",
	"pecera_frutiger": "res://assets/placeholders/pecera.png",
	"monitor_retro": "res://assets/placeholders/monitor.png",
}

var _next_slot: int = 0
var _button_by_id: Dictionary = {}


func _ready() -> void:
	GameState.ondas_changed.connect(_on_ondas_changed)
	GameState.ops_changed.connect(_on_ops_changed)
	GameState.upgrade_owned.connect(_on_upgrade_owned)
	_build_buy_buttons()
	_ensure_click_button()
	_refresh_ui()
	if vinyl:
		vinyl.texture = load("res://assets/sprites/vinyl_clickable.png")
		vinyl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		# Prefer Area3D child for reliable picking; fall back to Sprite3D signal.
		var area := vinyl.get_node_or_null("VinylArea") as Area3D
		if area:
			area.input_event.connect(_on_vinyl_input)
		elif vinyl.has_signal("input_event"):
			vinyl.input_event.connect(_on_vinyl_input)




func _ensure_click_button() -> void:
	var existing := get_node_or_null("%ClickButton") as Button
	if existing:
		existing.pressed.connect(func(): GameState.add_click(); _pulse_vinyl())
		return
	var btn := Button.new()
	btn.name = "ClickButton"
	btn.unique_name_in_owner = true
	btn.text = "Clicar vinilo (+1 Onda)"
	btn.pressed.connect(func(): GameState.add_click(); _pulse_vinyl())
	var top := get_node_or_null("UI/Root/TopBar") as VBoxContainer
	if top:
		top.add_child(btn)


func _build_buy_buttons() -> void:
	for child in buy_buttons.get_children():
		child.queue_free()
	_button_by_id.clear()
	for u in GameState.upgrades:
		var btn := Button.new()
		btn.name = "Buy_%s" % u["id"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_buy_pressed.bind(u["id"]))
		buy_buttons.add_child(btn)
		_button_by_id[u["id"]] = btn
	_refresh_buy_labels()


func _refresh_ui() -> void:
	_on_ondas_changed(GameState.ondas_actuales)
	_on_ops_changed(GameState.ondas_por_segundo)
	_refresh_buy_labels()


func _on_ondas_changed(value: float) -> void:
	ondas_label.text = "Ondas: %s" % _format_num(value)
	_refresh_buy_labels()


func _on_ops_changed(value: float) -> void:
	ops_label.text = "Ondas/s: %s" % _format_num(value)


func _refresh_buy_labels() -> void:
	for u in GameState.upgrades:
		var btn: Button = _button_by_id.get(u["id"])
		if btn == null:
			continue
		var cost := GameState.get_cost(u["id"])
		btn.text = "Comprar %s (%s) — costo: %s Ondas" % [
			u["name"], int(u["owned"]), _format_num(cost)
		]
		btn.disabled = not GameState.can_buy(u["id"])


func _on_buy_pressed(upgrade_id: String) -> void:
	if GameState.buy(upgrade_id):
		_spawn_billboard(upgrade_id)
		_refresh_buy_labels()


func _on_upgrade_owned(_upgrade_id: String, _owned: int) -> void:
	_refresh_buy_labels()


func _on_vinyl_input(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			GameState.add_click()
			_pulse_vinyl()



func _pulse_vinyl() -> void:
	if vinyl == null:
		return
	var tw := create_tween()
	tw.tween_property(vinyl, "scale", Vector3(1.15, 1.15, 1.15), 0.06)
	tw.tween_property(vinyl, "scale", Vector3.ONE, 0.1)


func _spawn_billboard(upgrade_id: String) -> void:
	if SPAWN_SLOTS.is_empty():
		return
	var slot: Vector3 = SPAWN_SLOTS[_next_slot % SPAWN_SLOTS.size()]
	_next_slot += 1

	var sprite := Sprite3D.new()
	sprite.name = "Gen_%s_%d" % [upgrade_id, _next_slot]
	sprite.position = slot
	sprite.pixel_size = 0.02
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.double_sided = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	var path: String = UPGRADE_TEXTURES.get(upgrade_id, "res://assets/placeholders/vinilo.png")
	var tex := load(path) as Texture2D
	if tex:
		sprite.texture = tex

	spawn_root.add_child(sprite)


func _format_num(value: float) -> String:
	if value >= 1_000_000.0:
		return "%.2fM" % (value / 1_000_000.0)
	if value >= 1_000.0:
		return "%.2fK" % (value / 1_000.0)
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value
