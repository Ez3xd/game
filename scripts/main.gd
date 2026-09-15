extends Node3D
## Escena principal Aero-Liminal: intro, idle, objetivo y final melancólico.

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

const INTRO_BG := "res://assets/ui/intro_panel_frutiger.png"
const ENDING_BG := "res://assets/ui/ending_panel_melancholic.png"

var _next_slot: int = 0
var _button_by_id: Dictionary = {}
var _objective_label: Label
var _intro_layer: CanvasLayer
var _ending_layer: CanvasLayer
var _gameplay_started: bool = false
var _ending_dismissed: bool = false


func _ready() -> void:
	GameState.ondas_changed.connect(_on_ondas_changed)
	GameState.ops_changed.connect(_on_ops_changed)
	GameState.upgrade_owned.connect(_on_upgrade_owned)
	GameState.generators_changed.connect(_on_generators_changed)
	GameState.dimension_complete.connect(_on_dimension_complete)
	_build_buy_buttons()
	_ensure_click_button()
	_ensure_objective_label()
	_build_intro_overlay()
	_build_ending_overlay()
	_refresh_ui()
	_on_generators_changed(GameState.get_total_generators())
	if vinyl:
		vinyl.texture = load("res://assets/sprites/vinyl_clickable.png")
		vinyl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var area := vinyl.get_node_or_null("VinylArea") as Area3D
		if area:
			area.input_event.connect(_on_vinyl_input)
		elif vinyl.has_signal("input_event"):
			vinyl.input_event.connect(_on_vinyl_input)
	_show_intro()


func _ensure_click_button() -> void:
	var existing := get_node_or_null("%ClickButton") as Button
	if existing:
		existing.pressed.connect(_on_click_pressed)
		return
	var btn := Button.new()
	btn.name = "ClickButton"
	btn.unique_name_in_owner = true
	btn.text = "Clicar vinilo (+1 Onda)"
	btn.pressed.connect(_on_click_pressed)
	var top := get_node_or_null("UI/Root/TopBar") as VBoxContainer
	if top:
		top.add_child(btn)


func _on_click_pressed() -> void:
	if not _gameplay_started:
		return
	GameState.add_click()
	_pulse_vinyl()


func _ensure_objective_label() -> void:
	var top := get_node_or_null("UI/Root/TopBar") as VBoxContainer
	if top == null:
		return
	_objective_label = top.get_node_or_null("ObjectiveLabel") as Label
	if _objective_label == null:
		_objective_label = Label.new()
		_objective_label.name = "ObjectiveLabel"
		_objective_label.add_theme_font_size_override("font_size", 16)
		top.add_child(_objective_label)


func _build_intro_overlay() -> void:
	_intro_layer = CanvasLayer.new()
	_intro_layer.name = "IntroLayer"
	_intro_layer.layer = 20
	add_child(_intro_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_layer.add_child(root)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = load(INTRO_BG) as Texture2D
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -420
	center.offset_right = 420
	center.offset_top = -160
	center.offset_bottom = 160
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 16)
	root.add_child(center)

	var title := Label.new()
	title.text = "Aero-Liminal"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	center.add_child(title)

	var body := Label.new()
	body.text = "Despiertas en una sala vacía. El eco no responde. En el centro hay un vinilo: cada clic libera una Onda. Con Ondas traes ecos del pasado —vinilos, peceras, pantallas— y la sala deja de estar tan sola."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	center.add_child(body)

	var start_btn := Button.new()
	start_btn.text = "Empezar"
	start_btn.custom_minimum_size = Vector2(180, 40)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.pressed.connect(_on_intro_start)
	center.add_child(start_btn)


func _build_ending_overlay() -> void:
	_ending_layer = CanvasLayer.new()
	_ending_layer.name = "EndingLayer"
	_ending_layer.layer = 21
	_ending_layer.visible = false
	add_child(_ending_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ending_layer.add_child(root)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = load(ENDING_BG) as Texture2D
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -420
	center.offset_right = 420
	center.offset_top = -180
	center.offset_bottom = 180
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	root.add_child(center)

	var title := Label.new()
	title.text = "Primera dimensión completa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	center.add_child(title)

	var body := Label.new()
	body.text = "La sala se llenó… y aun así el eco sigue vacío. Algo más allá de estas paredes espera. Puedes quedarte un rato, o cruzar y empezar de nuevo con lo que aprendiste."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 18)
	center.add_child(body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)

	var stay_btn := Button.new()
	stay_btn.text = "Seguir un momento"
	stay_btn.custom_minimum_size = Vector2(200, 40)
	stay_btn.pressed.connect(_on_ending_stay)
	row.add_child(stay_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Cambiar de dimensión"
	reset_btn.custom_minimum_size = Vector2(220, 40)
	reset_btn.pressed.connect(_on_ending_soft_reset)
	row.add_child(reset_btn)


func _show_intro() -> void:
	_gameplay_started = false
	_intro_layer.visible = true
	_ending_layer.visible = false


func _on_intro_start() -> void:
	_intro_layer.visible = false
	_gameplay_started = true


func _on_dimension_complete() -> void:
	if _ending_dismissed:
		return
	_ending_layer.visible = true


func _on_ending_stay() -> void:
	_ending_dismissed = true
	_ending_layer.visible = false


func _on_ending_soft_reset() -> void:
	_ending_dismissed = false
	_ending_layer.visible = false
	_clear_spawns()
	GameState.soft_reset()
	_refresh_ui()
	_on_generators_changed(0)


func _clear_spawns() -> void:
	_next_slot = 0
	if spawn_root == null:
		return
	for child in spawn_root.get_children():
		child.queue_free()


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
	var shown := value * GameState.prestige_mult
	ops_label.text = "Ondas/s: %s" % _format_num(shown)


func _on_generators_changed(count: int) -> void:
	if _objective_label == null:
		return
	_objective_label.text = "Llena la sala: %d/%d generadores (primera dimensión)" % [
		count, GameState.GENERATORS_GOAL
	]


func _refresh_buy_labels() -> void:
	for u in GameState.upgrades:
		var btn: Button = _button_by_id.get(u["id"])
		if btn == null:
			continue
		var cost := GameState.get_cost(u["id"])
		btn.text = "Comprar %s (%s) — costo: %s Ondas" % [
			u["name"], int(u["owned"]), _format_num(cost)
		]
		btn.disabled = (not _gameplay_started) or (not GameState.can_buy(u["id"]))


func _on_buy_pressed(upgrade_id: String) -> void:
	if not _gameplay_started:
		return
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
	if not _gameplay_started:
		return
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
