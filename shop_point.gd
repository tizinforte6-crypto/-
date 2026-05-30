#________________________________Точка магазина________________________________
extends Area3D

@export var shop_menu_path: NodePath = ^"../ShopCanvasLayer/ShopMenu" # путь к меню
@export var shop_hint_path: NodePath = ^"../HintCanvasLayer/ShopHintLabel" # путь к подсказке
var shop_mobile_button: Button = null # кнопка открытия на телефоне
@onready var shop_menu: Control = get_node_or_null(shop_menu_path)
@onready var shop_hint_label: Label = get_node_or_null(shop_hint_path)

var player_inside: Node3D = null # игрок внутри зоны


func _ready() -> void: #-----подготовка точки магазина-----

	monitoring = true # ловим вход в область
	monitorable = true # область видима для проверок

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_find_shop_mobile_button()
	_hide_hint()

	print("Точка магазина готова")
	print("Слой точки магазина: ", collision_layer)
	print("Маска точки магазина: ", collision_mask)


func _process(_delta: float) -> void: #-----ожидание клавиши-----
	if player_inside == null:
		return

	if Input.is_action_just_pressed("interact"):
		open_shop()


func _on_body_entered(body: Node3D) -> void: #-----игрок вошёл в зону-----
	print("В зону магазина вошёл: ", body.name)

	if not body.is_in_group("player") and not body.is_in_group("drone"):
		print("Это не игрок и не дрон")
		return

	print("Игрок вошёл в зону магазина")
	_show_shop_mobile_button()

	player_inside = body
	_show_hint()


func _on_body_exited(body: Node3D) -> void: #-----игрок вышел из зоны-----
	print("Из зоны магазина вышел: ", body.name)

	if body != player_inside:
		return

	player_inside = null
	_hide_hint()
	_hide_shop_mobile_button()

	if shop_menu != null and shop_menu.has_method("close_shop"):
		shop_menu.close_shop()


func open_shop() -> void: #-----открытие магазина-----
	if shop_menu == null:
		push_warning("ShopPoint: ShopMenu не найден. Проверь путь ../ShopCanvasLayer/ShopMenu")
		return
	_hide_shop_mobile_button()
	if player_inside == null:
		return

	print("Магазин открыт")

	_hide_hint()

	if shop_menu.has_method("open_shop"):
		shop_menu.open_shop(player_inside)
	else:
		shop_menu.visible = true


func _show_hint() -> void: #-----показ подсказки-----
	if shop_hint_label == null:
		push_warning("ShopPoint: ShopHintLabel не найден. Проверь путь ../HintCanvasLayer/ShopHintLabel")
		return

	shop_hint_label.visible = true
	shop_hint_label.text = "Чтобы открыть магазин нажмите 'E'"


func _hide_hint() -> void: #-----скрытие подсказки-----
	if shop_hint_label == null:
		return

	shop_hint_label.visible = false

func _find_shop_mobile_button() -> void: #-----поиск мобильной кнопки-----
	var player_node := get_tree().get_first_node_in_group("player")

	if player_node == null:
		return

	shop_mobile_button = player_node.get_node_or_null("CanvasLayer2/ShopMobileButton") as Button

	if shop_mobile_button == null:
		return

	shop_mobile_button.visible = false

	if not shop_mobile_button.pressed.is_connected(_on_shop_mobile_button_pressed):
		shop_mobile_button.pressed.connect(_on_shop_mobile_button_pressed)


func _show_shop_mobile_button() -> void: #-----показ кнопки магазина-----
	if shop_mobile_button == null:
		_find_shop_mobile_button()

	if shop_mobile_button != null:
		shop_mobile_button.visible = true


func _hide_shop_mobile_button() -> void: #-----скрытие кнопки магазина-----
	if shop_mobile_button != null:
		shop_mobile_button.visible = false


func _on_shop_mobile_button_pressed() -> void: #-----нажатие мобильной кнопки-----
	if player_inside == null:
		return

	open_shop()
