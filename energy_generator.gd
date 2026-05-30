#________________________________Генератор сфер________________________________
extends Node3D

@export var sphere_scene : PackedScene # сцена создаваемой сферы
@export var charge_time := 10.0 # время до появления сферы

@onready var timer = $Timer
@onready var spawn_point = $SpawnPoint
@onready var charge_audio: AudioStreamPlayer3D = $ChargeAudio
@onready var ready_audio: AudioStreamPlayer3D = $ReadyAudio
@onready var stage1 = $MeshStage1
@onready var stage2 = $MeshStage2
@onready var stage3 = $MeshStage3

var current_sphere = null # текущая созданная сфера


func _ready(): #-----подготовка генератора-----

	timer.wait_time = charge_time
	timer.one_shot = true # таймер срабатывает один раз

	timer.timeout.connect(_on_timer_timeout)

	start_charging()

func start_charging(): #-----запуск зарядки сферы-----

	# Стадия 1
	stage1.visible = true
	stage2.visible = false
	stage3.visible = false

	timer.start()
	if charge_audio != null:
		charge_audio.play()

	# Половина зарядки
	await get_tree().create_timer(charge_time * 0.5).timeout # ждём половину зарядки

	# Если сферы ещё нет
	if current_sphere == null:

		stage1.visible = false
		stage2.visible = true

func _on_timer_timeout(): #-----сфера готова-----

	# Если сфера уже существует
	if current_sphere != null:
		return

	# Стадия 3
	stage1.visible = false
	stage2.visible = false
	stage3.visible = true
	
	if charge_audio != null:
		charge_audio.stop()

	if ready_audio != null:
		ready_audio.play()
	spawn_sphere()

func spawn_sphere(): #-----создание сферы-----

	current_sphere = sphere_scene.instantiate()

	print(current_sphere.scene_file_path)
	print(current_sphere.get_class())

	get_tree().current_scene.add_child(current_sphere)

	current_sphere.global_position = spawn_point.global_position

	current_sphere.generator = self # сфера сможет сообщить о сборе

func sphere_collected(): #-----сфера собрана-----

	current_sphere = null

	start_charging()
