extends Node3D

#________________________________настройки перерывов________________________________
@export var wind_interval_min: float = 5.0 # минимальный перерыв
@export var wind_interval_max: float = 12.0 # максимальный перерыв

#________________________________настройки длительности________________________________
@export var wind_duration_min: float = 1.5 # минимальная длительность
@export var wind_duration_max: float = 4.0 # максимальная длительность

#________________________________настройки силы________________________________
@export var wind_force_min: float = 15.0 # минимальная сила ветра
@export var wind_force_max: float = 30.0 # максимальная сила ветра
@export var affect_y: bool = false # сдувать ли по высоте

#________________________________состояние ветра________________________________
var wind_active: bool = false # сейчас есть ветер
var wind_timer: float = 0.0 # таймер ветра
var wait_timer: float = 0.0 # таймер перерыва
var current_wind_force: float = 0.0 # текущая сила ветра
var current_wind_direction: Vector3 = Vector3.ZERO # текущее направление


func _ready() -> void: #-----подготовка ветра-----
	randomize()
	_start_wait()


func _physics_process(delta: float) -> void: #-----цикл ветра-----
	if wind_active:
		_process_wind(delta)
	else:
		_process_wait(delta)


func _process_wait(delta: float) -> void: #-----перерыв между ветром-----
	wait_timer -= delta

	if wait_timer <= 0.0:
		_start_wind()


func _process_wind(delta: float) -> void: #-----сдувание объектов-----
	wind_timer -= delta

	for body in get_tree().get_nodes_in_group("wind_affected"):
		if body != null and body.has_method("apply_wind"):
			body.apply_wind(current_wind_direction, current_wind_force, delta)

	if wind_timer <= 0.0:
		_stop_wind()


func _start_wait() -> void: #-----запуск перерыва-----
	wait_timer = randf_range(wind_interval_min, wind_interval_max)


func _start_wind() -> void: #-----запуск ветра-----
	wind_active = true
	wind_timer = randf_range(wind_duration_min, wind_duration_max)
	current_wind_force = randf_range(wind_force_min, wind_force_max)

	var x: float = randf_range(-1.0, 1.0)
	var y: float = randf_range(-0.4, 0.4) if affect_y else 0.0
	var z: float = randf_range(-1.0, 1.0)

	current_wind_direction = Vector3(x, y, z).normalized()

	print("Начался ветер. Сила: " + str(round(current_wind_force)) + ", длительность: " + str(round(wind_timer)))


func _stop_wind() -> void: #-----остановка ветра-----
	wind_active = false
	current_wind_force = 0.0
	current_wind_direction = Vector3.ZERO

	print("Ветер закончился")

	_start_wait()
