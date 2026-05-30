extends Node3D

#________________________________настройки перерывов________________________________
@export var wind_interval_min: float = 5.0 # минимальный перерыв
@export var wind_interval_max: float = 12.0 # максимальный перерыв

#________________________________настройки длительности________________________________
@export var wind_duration_min: float = 5.5 # минимальная длительность
@export var wind_duration_max: float = 8.5 # максимальная длительность

#________________________________настройки силы________________________________
@export var wind_force_min: float = 10.0 # минимальная сила ветра
@export var wind_force_max: float = 20.0 # максимальная сила ветра
@export var affect_y: bool = false # сдувать ли по высоте

#________________________________настройки визуала________________________________
@export var normal_fall_speed_min: float = 4.0 # обычная скорость падения
@export var normal_fall_speed_max: float = 7.0 # обычная максимальная скорость
@export var wind_visual_speed_min: float = 14.0 # скорость частиц при ветре
@export var wind_visual_speed_max: float = 22.0 # максимальная скорость частиц при ветре
@export var wind_down_strength: float = 0.45 # насколько ветер сохраняет падение вниз
@export var wind_apply_delay: float = 0.0 # задержка действия ветра
var wind_affects_objects: bool = false # ветер уже двигает объекты

#________________________________состояние ветра________________________________
var wind_active: bool = false # сейчас есть ветер
var wind_timer: float = 0.0 # таймер ветра
var wait_timer: float = 0.0 # таймер перерыва
var current_wind_force: float = 0.0 # текущая сила ветра
var current_wind_direction: Vector3 = Vector3.ZERO # текущее направление

@onready var wind_particles: GPUParticles3D = $WindParticles # визуальные частицы ветра


func _ready() -> void: #-----подготовка ветра-----
	randomize()

	if wind_particles != null:
		wind_particles.visible = true
		wind_particles.emitting = true
		_set_particles_normal_fall()

	_start_wait()


func _physics_process(delta: float) -> void: #-----цикл ветра-----
	if wind_affects_objects:
		_apply_wind_to_objects(delta)

	if wind_active:
		_process_wind(delta)
	else:
		_process_wait(delta)


func _process_wait(delta: float) -> void: #-----перерыв между ветром-----
	wait_timer -= delta

	if wait_timer <= 0.0:
		_start_wind()


func _process_wind(delta: float) -> void: #-----таймер визуального ветра-----
	wind_timer -= delta

	if wind_timer <= 0.0:
		_stop_wind()


func _start_wait() -> void: #-----запуск перерыва-----
	wait_timer = randf_range(wind_interval_min,wind_interval_max)


func _start_wind() -> void: #-----запуск ветра-----
	wind_active = true
	wind_affects_objects = false
	wind_timer = randf_range(wind_duration_min,wind_duration_max)
	current_wind_force = randf_range(wind_force_min,wind_force_max)

	var x: float = randf_range(-1.0,1.0)
	var y: float = randf_range(-0.4,0.4) if affect_y else 0.0
	var z: float = randf_range(-1.0,1.0)

	current_wind_direction = Vector3(x,y,z).normalized()
	_set_particles_wind()
	_enable_wind_after_delay()
	_start_wind_sound()

	print("Начался ветер. Сила: " + str(round(current_wind_force)) + ", длительность: " + str(round(wind_timer)))

func _stop_wind() -> void: #-----остановка ветра-----
	wind_active = false
	_set_particles_normal_fall()
	_disable_wind_after_delay()
	_stop_wind_sound()

	print("Ветер закончился")
	_start_wait()


func _set_particles_normal_fall() -> void: #-----обычное падение частиц-----
	var material: ParticleProcessMaterial = wind_particles.process_material as ParticleProcessMaterial

	if material == null:
		return

	material.direction = Vector3(0.0,-1.0,0.0)
	material.spread = 12.0
	material.initial_velocity_min = normal_fall_speed_min
	material.initial_velocity_max = normal_fall_speed_max
	material.gravity = Vector3(0.0,-2.0,0.0)


func _set_particles_wind() -> void: #-----частицы при ветре-----
	var material: ParticleProcessMaterial = wind_particles.process_material as ParticleProcessMaterial

	if material == null:
		return

	var visual_direction: Vector3 = current_wind_direction + Vector3(0.0,-wind_down_strength,0.0)
	visual_direction = visual_direction.normalized()

	material.direction = visual_direction
	material.spread = 8.0
	material.initial_velocity_min = wind_visual_speed_min
	material.initial_velocity_max = wind_visual_speed_max
	material.gravity = Vector3(0.0,-1.0,0.0)


func _enable_wind_after_delay() -> void: #-----задержка включения ветра-----
	await get_tree().create_timer(wind_apply_delay).timeout

	if not wind_active:
		return

	wind_affects_objects = true


func _disable_wind_after_delay() -> void: #-----задержка выключения ветра-----
	await get_tree().create_timer(wind_apply_delay).timeout

	if wind_active:
		return

	wind_affects_objects = false
	current_wind_force = 0.0
	current_wind_direction = Vector3.ZERO

func _apply_wind_to_objects(delta: float) -> void: #-----действие ветра на объекты-----
	for body in get_tree().get_nodes_in_group("wind_affected"):
		if body == null:
			continue

		if body.is_in_group("bird") or body.is_in_group("falcon") or body.is_in_group("eagle"):
			continue

		if body.has_method("apply_wind"):
			body.apply_wind(current_wind_direction,current_wind_force,delta)
			
			
func _start_wind_sound() -> void: #-----звук ветра-----
	var audio_manager := get_tree().get_first_node_in_group("audio_manager")

	if audio_manager != null and audio_manager.has_method("start_wind_sound"):
		audio_manager.start_wind_sound()


func _stop_wind_sound() -> void: #-----остановка звука ветра-----
	var audio_manager := get_tree().get_first_node_in_group("audio_manager")

	if audio_manager != null and audio_manager.has_method("stop_wind_sound"):
		audio_manager.stop_wind_sound()
