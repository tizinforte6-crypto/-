extends CanvasLayer

#________________________________Настройки________________________________
@export var hide_after_complete: bool = true # скрыть после выполнения
@export var complete_hide_delay: float = 1.5 # задержка перед скрытием
@export var main_menu_scene_path: String = "res://main_menu.tscn"
@export var final_message_time: float = 5.0
@export var tutorial_complete_message_time: float = 3.0

@export var required_actions: Array[StringName] = [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
	&"move_up",
	&"move_down",
	&"turn_right",
	&"turn_left",
	&"interact"
]

@export var action_labels: Array[String] = [
	"Вперёд: W",
	"Назад: S",
	"Влево: A",
	"Вправо: D",
	"Подняться: Space",
	"Опуститься: C",
	"Поворот вправо: колесо вверх",
	"Поворот влево: колесо вниз",
	"Взаимодействие: E"
]

@export var needed_spheres_count: int = 2 # сколько сфер надо собрать

#________________________________Узлы________________________________
@onready var panel: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var task_text: RichTextLabel = $PanelContainer/VBoxContainer/TaskText

#________________________________Состояние________________________________
var completed_actions: Dictionary = {}

var input_stage_completed: bool = false
var sphere_stage_completed: bool = false
var shop_stage_completed: bool = false

var collected_spheres_count: int = 0

# 0 — управление
# 1 — сбор сфер
# 2 — магазин
# 3 — завершено
var tutorial_stage: int = 0


func _ready() -> void: #-----подготовка обучения-----
	add_to_group("tutorial_input")

	visible = true
	tutorial_stage = 0

	input_stage_completed = false
	sphere_stage_completed = false
	shop_stage_completed = false
	collected_spheres_count = 0

	completed_actions.clear()

	for action in required_actions:
		completed_actions[action] = false

	_update_text()


func _process(_delta: float) -> void: #-----проверка кнопок управления-----
	if tutorial_stage != 0:
		return

	for action in required_actions:
		if Input.is_action_just_pressed(action):
			completed_actions[action] = true

	_check_input_stage_complete()
	_update_text()


func mark_action_done(action_name: StringName) -> void: #-----ручная отметка действия-----
	if tutorial_stage != 0:
		return

	if completed_actions.has(action_name):
		completed_actions[action_name] = true

	_check_input_stage_complete()
	_update_text()


func _check_input_stage_complete() -> void: #-----проверка управления-----
	for action in required_actions:
		if not bool(completed_actions.get(action, false)):
			return

	input_stage_completed = true
	tutorial_stage = 1
	_update_text()


func register_energy_sphere_collected() -> void: #-----сфера подобрана-----
	if tutorial_stage != 1:
		return

	collected_spheres_count += 1

	if collected_spheres_count >= needed_spheres_count:
		sphere_stage_completed = true
		tutorial_stage = 2

	_update_text()


func register_shop_purchase() -> void: #-----покупка в магазине-----
	if tutorial_stage != 2:
		return

	shop_stage_completed = true
	tutorial_stage = 3
	visible = true
	_update_text()

	await get_tree().create_timer(final_message_time).timeout

	if tutorial_stage == 3:
		visible = false

func _update_text() -> void: #-----обновление текста обучения-----
	if task_text == null:
		return

	var text := ""

	if tutorial_stage == 0:
		text += "[b]Обучение управлению[/b]\n\n"
		text += "Нажми все кнопки управления:\n\n"

		for i in range(required_actions.size()):
			var action: StringName = required_actions[i]
			var label := str(action)

			if i < action_labels.size():
				label = action_labels[i]

			if bool(completed_actions.get(action, false)):
				text += "[color=green]✓ " + label + "[/color]\n"
			else:
				text += "[color=gray]□ " + label + "[/color]\n"

	elif tutorial_stage == 1:
		text += "[b]Энергия дрона[/b]\n\n"
		text += "Батарейка дрона не бесконечна.\n"
		text += "Чтобы продолжать полёт, собирай синие энергосферы.\n\n"
		text += "Заряд батареи и кол-во своих энергосфер вы может увидеть в верхнем углу экрана.\n"
		text += "Энергосферы появляются на генераторах.\n"
		text += "Подлети к синей сфере и подбери её.\n\n"
		text += "Не забудь, ты не птица!\n"
		text += "[b]Задание:[/b] собрать 2 энергосферы.\n"
		text += "[color=cyan]Собрано: " + str(collected_spheres_count) + " / " + str(needed_spheres_count) + "[/color]\n"

	elif tutorial_stage == 2:
		text += "[b]Магазин улучшений[/b]\n\n"
		text += "Собранные энергосферы можно тратить в магазине.\n"
		text += "Подлети к магазину и нажми [b]E[/b].\n\n"
		text += "Купи любое доступное улучшение.\n\n"
		text += "[b]Задание:[/b] купить любой предмет."

	elif tutorial_stage == 3:
		text += "[b]Что-то вдалеке...[/b]\n\n"
		text += "Смотри, там впереди что-то летает.\n"
		text += "Вроде какая-то красивая птичка.\n\n"
		text += "Подлети поближе и посмотри, что это такое."

	elif tutorial_stage == 4:
		text += "[b]Обучение пройдено![/b]\n\n"
		text += "Теперь ты знаешь основы управления, сбора энергии, магазина и опасностей.\n\n"
		text += "[color=green]Возвращаемся в главное меню...[/color]"
		
	task_text.text = text


func handle_tutorial_death() -> void: #-----смерть в обучении-----
	visible = true
	tutorial_stage = 4
	_update_text()

	await get_tree().create_timer(tutorial_complete_message_time).timeout

	get_tree().change_scene_to_file(main_menu_scene_path)
