#________________________________Спавнер соколов________________________________
extends Node3D

@onready var falcon_template: CharacterBody3D = $FalconTemplate # скрытый шаблон сокола

var falcon_spawn_positions: Array[Vector3] = [ # точки появления соколов
	Vector3(20.0, 30.0, 20.0),
]


func _ready() -> void: #-----создание всех соколов-----
	spawn_all_falcons()


func spawn_all_falcons() -> void: #-----расстановка копий сокола-----
	if falcon_template == null:
		push_warning("Спавнер соколов: шаблон сокола не найден.")
		return

	# Шаблон скрываем. Он нужен только для копирования.
	falcon_template.visible = false # сам шаблон не показываем
	falcon_template.set_physics_process(false) # шаблон не должен летать

	for spawn_pos in falcon_spawn_positions:
		var falcon_copy: CharacterBody3D = falcon_template.duplicate() as CharacterBody3D

		if falcon_copy == null:
			push_warning("Спавнер соколов: шаблон сокола должен быть CharacterBody3D.")
			continue

		add_child(falcon_copy)

		if falcon_copy.has_method("activate_at_position"):
			falcon_copy.activate_at_position(spawn_pos)
		else:
			falcon_copy.global_position = spawn_pos
			falcon_copy.visible = true
			falcon_copy.set_physics_process(true)
