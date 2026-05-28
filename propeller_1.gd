#________________________________Пропеллер 1________________________________
extends Area3D

@export var propeller_id : int = 1 # номер винта для падения

var drone = null # ссылка на дрон

func _ready(): #-----подключение пропеллера-----
	drone = get_tree().get_first_node_in_group("drone") # ищем дрон по группе

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_body_entered(body): #-----удар о тело-----

	# Игнорируем самого себя
	if body == drone:
		return

	if drone:
		drone.crash_drone(propeller_id)

func _on_area_entered(area): #-----удар о область-----

	# Игнорируем свои пропеллеры
	if area.get_parent() == drone:
		return

	if drone:
		drone.crash_drone(propeller_id)
