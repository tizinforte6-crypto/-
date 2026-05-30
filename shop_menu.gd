#________________________________Меню магазина________________________________
extends Panel

@onready var title_label: Label = $TitleLabel
@onready var items_container: VBoxContainer = $ItemsContainer
@onready var close_button: Button = $CloseButton

var player: Node = null # игрок, открывший магазин
var bought_items: Array[String] = [] # одноразовые покупки

var shop_items: Array[Dictionary] = [ # список товаров
	{
		"id": "speed_1",
		"name": "Ускорение I",
		"description": "Увеличивает скорость дрона на 2.",
		"cost": 3,
		"icon": "res://ui/icons/speed.png",
		"type": "speed",
		"amount": 2.0
	},
	{
		"id": "speed_2",
		"name": "Ускорение II",
		"description": "Увеличивает скорость дрона ещё на 3.",
		"cost": 6,
		"icon": "res://ui/icons/speed.png",
		"type": "speed",
		"amount": 3.0
	},
	{
		"id": "battery_1",
		"name": "Ёмкая батарея",
		"description": "Увеличивает максимальный заряд на 25%.",
		"cost": 5,
		"icon": "res://ui/icons/battery.png",
		"type": "max_charge",
		"amount": 25
	},
	{
		"id": "max_energy",
		"name": "Контейнер сфер",
		"description": "Увеличивает максимум переносимых сфер на 1.",
		"cost": 0,
		"icon": "res://ui/icons/energy.png",
		"type": "max_energy",
		"amount": 1,
		"dynamic_cost": "max_energy",
		"one_time": false
	}
]


func _ready() -> void: #-----подготовка магазина-----
	visible = false # магазин скрыт

	if title_label != null:
		title_label.text = "Магазин"

	close_button.pressed.connect(_on_close_pressed)

	_build_shop_items()


func open_shop(player_node: Node) -> void: #-----открытие магазина-----
	player = player_node
	visible = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # курсор нужен для кнопок

	if player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(true)

	_refresh_shop_items()


func close_shop(unlock_controls: bool = true) -> void: #-----закрытие магазина-----
	visible = false

	if unlock_controls and player != null and player.has_method("set_controls_locked"):
		player.set_controls_locked(false)

	if unlock_controls:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _build_shop_items() -> void: #-----создание карточек товаров-----
	for child in items_container.get_children():
		child.queue_free()

	var player_energy: int = _get_player_energy() # сколько сфер у игрока

	for item in shop_items:
		var item_panel: PanelContainer = PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 100)
		item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		item_panel.add_child(row)

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(72, 72)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var icon_path: String = str(item.get("icon", ""))

		if icon_path != "" and ResourceLoader.exists(icon_path):
			icon_rect.texture = load(icon_path)

		row.add_child(icon_rect)

		var text_box: VBoxContainer = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)

		var name_label: Label = Label.new()
		name_label.text = str(item.get("name", "Товар"))
		text_box.add_child(name_label)

		var description_label: Label = Label.new()
		description_label.text = str(item.get("description", ""))
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_child(description_label)

		var cost: int = _get_item_cost(item)

		var cost_label: Label = Label.new()
		cost_label.text = "Цена: " + str(cost) + " сфер"
		text_box.add_child(cost_label)

		var buy_button: Button = Button.new()
		buy_button.custom_minimum_size = Vector2(110, 44)

		var item_id: String = str(item.get("id", ""))

		if bought_items.has(item_id):
			buy_button.text = "Куплено"
			buy_button.disabled = true
		else:
			buy_button.text = "Купить"
			buy_button.disabled = player_energy < cost
			buy_button.pressed.connect(_on_buy_item_pressed.bind(item))

		row.add_child(buy_button)

		items_container.add_child(item_panel)

func _refresh_shop_items() -> void: #-----обновление товаров-----
	_build_shop_items()

	if player == null:
		return

	var player_energy: int = _get_player_energy()
	var item_count: int = shop_items.size()
	var child_count: int = items_container.get_child_count()
	var count: int = mini(item_count, child_count)

	for i in range(count):
		var item_panel := items_container.get_child(i) as PanelContainer

		if item_panel == null:
			continue

		if item_panel.get_child_count() == 0:
			continue

		var row := item_panel.get_child(0) as HBoxContainer

		if row == null:
			continue

		if row.get_child_count() == 0:
			continue

		var buy_button := row.get_child(row.get_child_count() - 1) as Button

		if buy_button == null:
			continue

		var item: Dictionary = shop_items[i]
		var cost: int = _get_item_cost(item)

		buy_button.disabled = player_energy < cost


func _on_buy_item_pressed(item: Dictionary) -> void: #-----покупка товара-----
	if player == null:
		return

	var cost: int = _get_item_cost(item)
	var player_energy: int = _get_player_energy()

	if player_energy < cost:
		print("Недостаточно сфер")
		_refresh_shop_items()
		return

	_set_player_energy(player_energy - cost)

	var item_id: String = str(item.get("id", ""))
	var one_time: bool = bool(item.get("one_time", true))

	if one_time and item_id != "" and not bought_items.has(item_id):
		bought_items.append(item_id)

	_apply_item_effect(item)
	get_tree().call_group("tutorial_input", "register_shop_purchase")
	if player.has_method("update_energy_ui"):
		player.update_energy_ui()

	close_shop(false)

	if player.has_method("start_shop_upgrade_sequence"):
		player.start_shop_upgrade_sequence(self)
	else:
		open_shop(player)


func _apply_item_effect(item: Dictionary) -> void: #-----применение покупки-----
	var item_type: String = str(item.get("type", ""))
	var amount = item.get("amount", 0)

	match item_type:
		"max_energy":
			if player.has_method("upgrade_max_energy"):
				player.upgrade_max_energy(int(amount))
			else:
				print("У игрока нет метода upgrade_max_energy")
		"speed":
			if player.has_method("upgrade_speed"):
				player.upgrade_speed(float(amount))
			else:
				print("У игрока нет метода upgrade_speed")

		"max_charge":
			if player.has_method("upgrade_max_charge"):
				player.upgrade_max_charge(int(amount))
			else:
				print("У игрока нет метода upgrade_max_charge")

		_:
			print("Неизвестный тип товара: ", item_type)


func _get_player_energy() -> int: #-----получение сфер игрока-----
	if player == null:
		return 0

	if "energy" in player:
		return int(player.energy)

	return 0


func _set_player_energy(value: int) -> void: #-----запись сфер игрока-----
	if player == null:
		return

	if "energy" in player:
		player.energy = value


func _on_close_pressed() -> void: #-----кнопка закрытия-----
	close_shop()

func _get_item_cost(item: Dictionary) -> int: #-----расчёт цены-----
	var dynamic_cost_type: String = str(item.get("dynamic_cost", "")) # тип динамической цены

	if dynamic_cost_type == "max_energy":
		if player != null and "max_energy" in player:
			return int(player.max_energy)

		print("Меню магазина: max_energy игрока не найден, беру обычную цену")

	return int(item.get("cost", 0))
