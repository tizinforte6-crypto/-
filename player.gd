#________________________________Игрок________________________________
extends CharacterBody3D


# Настройки
@export var move_speed : float = 20.0 # скорость дрона
@export var acceleration : float = 25.0
@export var deceleration : float = 5.0
@export var direction_change_drag : float = 9.0
@export var vertical_speed : float = 5.0
@export var vertical_acceleration : float = 3.0
@export var vertical_deceleration : float = 1.5
@export var mouse_sensitivity : float = 0.002 # чувствительность мыши
@export var drone_yaw_speed : float = 3.0
@export var yaw_drag : float = 3.0
@export var wind_resistance: float = 1.5 # как быстро ветер затухает
@export var wind_effect_multiplier: float = 0.2 # множитель силы ветра
var wind_velocity: Vector3 = Vector3.ZERO # отдельная скорость ветра
var saved_control_velocity: Vector3 = Vector3.ZERO

# Заряд дрона
@export var max_charge: int = 100 # максимум заряда
@export var current_charge: int = 100 # текущий заряд
@export var charge_loss_interval: float = 1.0 # разряд раз в несколько секунд
@export var sphere_charge_restore: int = 25 # заряд за одну сферу
@export var speed_upgrade_multiplier: float = 1.0

var charge_timer: float = 0.0

# Мобилки
var is_mobile := false
var mobile_move := Vector2.ZERO
var mobile_up := false
var mobile_down := false
var yaw_input : float = 0.0
var yaw_velocity : float = 0.0
var mobile_turn_input : float = 0.0

# Краш дрона
var crashed := false
var crash_spin := Vector3.ZERO
var crash_velocity := Vector3.ZERO
var crash_rotation_progress := 0.0
var crash_finished := false

# Интерфейс побрекушек
var energy: int = 0 # текущие сферы
var max_energy: int = 2 # лимит сфер
var controls_locked: bool = false # запрет управления

@export var charge_empty_color: Color = Color(0.15, 0.15, 0.18, 0.85)
@export var charge_low_color: Color = Color(0.8, 0.15, 0.1, 1.0)
@export var charge_middle_color: Color = Color(1.0, 0.75, 0.1, 1.0)
@export var charge_full_color: Color = Color(0.1, 0.8, 1.0, 1.0)


# Ветки
@export var energy_sphere_full_texture: Texture2D # цветная сфера
@export var energy_sphere_empty_texture: Texture2D # серая сфера
@export var energy_sphere_icon_size: Vector2 = Vector2(48, 48) # размер иконки
@onready var spring_arm : SpringArm3D = $CameraRoot/SpringArm3D
@onready var camera : Camera3D = $CameraRoot/SpringArm3D/Camera3D
@onready var canvas : CanvasLayer = $CanvasLayer
@onready var drone_mesh: Node3D = $AuxScene
@onready var drone_animation_player: AnimationPlayer = $AuxScene/AnimationPlayer
@onready var camera_root : Node3D = $CameraRoot
@onready var welding_particles: GPUParticles3D = $WeldingParticles
@onready var drone_hum_audio: AudioStreamPlayer3D = $DroneHumAudio
@onready var welding_audio: AudioStreamPlayer3D = $WeldingAudio
@onready var energy_sphere_bar: HBoxContainer = $CanvasLayer2/PlayerStatusPanel/VBoxContainer/EnergySphereBar
@onready var charge_progress_bar: ProgressBar = $CanvasLayer2/PlayerStatusPanel/VBoxContainer/ChargeProgressBar

# Наклоны
@export var tilt_angle : float = 12.0
@export var tilt_speed : float = 5.0
@export var drone_rotation_speed : float = 4.0
@export var turn_tilt_angle : float = 8.0
@export var movement_start_delay: float = 0.0 # задержка перед движением
var move_input_timer: float = 0.0 # время удержания направления
var tilt_input_dir: Vector2 = Vector2.ZERO # направление только для наклона

# Анимации
var hover_animation_name: String = "hover"
var drone_is_touching: bool = false

# Партиклы
var upgrade_animation_name: String = "exploded_view" # анимация покупки
var upgrade_model_lift: float = 0.5 # подъём модели перед анимацией костыль
var upgrade_in_process: bool = false # сейчас идёт покупка

func _ready(): #-----стартовая настройка игрока-----	
	welding_particles.visible = false # скрываем частицы
	welding_particles.emitting = false # выключаем частицы
	add_to_group("player") # магазин и сферы ищут эту группу
	add_to_group("wind_affected") # объект может сдуваться ветром
	if drone_hum_audio != null:
		drone_hum_audio.stop()
	if welding_audio != null:
		welding_audio.stop()
	setup_platform()
	update_energy_ui()
	update_charge_ui()


func setup_platform(): #-----настройка платформы-----
	# Для теста мобилки махнуть местами
	is_mobile = OS.get_name() == "Android"#is_mobile = true
	canvas.visible = is_mobile # кнопки видны только на телефоне

	if is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		drone_yaw_speed = 1.0
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # мышь захвачена игрой


func _input(event): #-----обработка камеры-----
	if controls_locked: # магазин забирает управление
		return
	if is_mobile:
		handle_touch_look(event)
	else:
		handle_mouse_look(event)
		handle_drone_yaw(event)


func handle_mouse_look(event): #-----камера на пк-----
	if event is InputEventMouseMotion and not is_mobile:
		camera_root.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		clamp_camera()


func handle_touch_look(event): #-----камера на телефоне-----
	# Для теста мобилки махнуть местами
	if event is InputEventScreenDrag:#if event is InputEventScreenDrag or event is InputEventMouseMotion:
		camera_root.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		clamp_camera()

func clamp_camera(): #-----ограничение камеры-----
	spring_arm.rotation.x = clamp(spring_arm.rotation.x,deg_to_rad(-80),deg_to_rad(80))
	spring_arm.rotation.z = 0

#________________________________Физика________________________________
func _physics_process(delta): #-----физика дрона-----
	if not crashed:
		process_charge(delta)
	if controls_locked:
		move_and_slide()
		return
	#_____краш_____
	if crashed:
		crash_velocity.y -= 8.0 * delta # Гравитация
		velocity = crash_velocity # камнем
		if not crash_finished:# Один переворот
			var spin_speed = 2.0

			rotate_object_local(Vector3.RIGHT, crash_spin.x * spin_speed * delta)
			rotate_object_local(Vector3.FORWARD, crash_spin.z * spin_speed * delta)
			crash_rotation_progress += spin_speed * delta

			if crash_rotation_progress >= TAU:# Закончили переворот
				crash_finished = true
	# Двигаем дрон
		move_and_slide()
		if is_on_floor():
			_go_to_death_or_finish_tutorial()
		return
	#_____конец краш_____
	#Костыль
	mobile_turn_input = 0.0
	if is_mobile:
		if Input.is_action_pressed("turn_left"):
			mobile_turn_input -= 1.0
		if Input.is_action_pressed("turn_right"):
			mobile_turn_input += 1.0
	#Костыль_конец
	handle_horizontal_movement(delta)
	handle_vertical_movement(delta)
	handle_tilt(delta)
	update_yaw(delta)

	_apply_wind_velocity(delta)

	move_and_slide()

	_remove_wind_velocity_after_move()

	update_touch_state()
	update_drone_animation_state()
	update_drone_sound()

#________________________________Управление________________________________
func handle_horizontal_movement(delta): #-----горизонтальное движение-----
	if drone_is_touching:
		velocity.x = 0.0
		velocity.z = 0.0
		move_input_timer = 0.0
		tilt_input_dir = Vector2.ZERO
		return

	var input_dir := get_move_input_dir()
	tilt_input_dir = input_dir # наклон начинается сразу

	if input_dir == Vector2.ZERO:
		move_input_timer = 0.0
		velocity.x = move_toward(velocity.x,0.0,deceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z,0.0,deceleration * delta * move_speed)
		return

	move_input_timer += delta

	if move_input_timer < movement_start_delay:
		velocity.x = move_toward(velocity.x,0.0,deceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z,0.0,deceleration * delta * move_speed)
		return

	var direction := global_transform.basis * Vector3(input_dir.x,0,-input_dir.y)
	direction.y = 0.0
	direction = direction.normalized()

	var target_velocity := direction * move_speed * speed_upgrade_multiplier # скорость без ветра
	var current_horizontal_velocity := Vector3(velocity.x,0,velocity.z)
	var changing_direction := current_horizontal_velocity.dot(direction) < 0.0

	if changing_direction:
		velocity.x = move_toward(velocity.x,0.0,direction_change_drag * delta * move_speed)
		velocity.z = move_toward(velocity.z,0.0,direction_change_drag * delta * move_speed)
	else:
		velocity.x = move_toward(velocity.x,target_velocity.x,acceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z,target_velocity.z,acceleration * delta * move_speed)

func handle_vertical_movement(delta): #-----вертикальное движение-----
	var vertical_input := 0.0

	if Input.is_action_pressed("move_up"):#пк
		vertical_input += 1.0
	if Input.is_action_pressed("move_down"):
		vertical_input -= 1.0

	if mobile_up:#Мобилка
		vertical_input += 1.0
	if mobile_down:
		vertical_input -= 1.0

	var target_vertical_velocity = (vertical_input * vertical_speed)

	if vertical_input != 0.0:
		velocity.y = move_toward(velocity.y,target_vertical_velocity,vertical_acceleration * delta * vertical_speed)
	else:
		velocity.y = move_toward(velocity.y,0.0,vertical_deceleration * delta * vertical_speed)

func get_move_input_dir() -> Vector2: #-----ввод движения-----
	var input_dir := Vector2.ZERO

	if is_mobile:
		input_dir.x = Input.get_axis("ui_left","ui_right")
		input_dir.y = Input.get_axis("ui_down","ui_up")
	else:
		input_dir.x = Input.get_axis("move_left","move_right")
		input_dir.y = Input.get_axis("move_back","move_forward")

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	return input_dir
	
#________________________________Наклоны________________________________
func handle_tilt(delta): #-----наклон корпуса-----
	if drone_is_touching:
		tilt_input_dir = Vector2.ZERO
		yaw_input = 0.0
		yaw_velocity = 0.0
		mobile_turn_input = 0.0
		drone_mesh.rotation.x = lerp_angle(drone_mesh.rotation.x, 0.0, tilt_speed * delta)
		drone_mesh.rotation.z = lerp_angle(drone_mesh.rotation.z, 0.0, tilt_speed * delta)
		return

	var forward_amount: float = tilt_input_dir.y
	var side_amount: float = tilt_input_dir.x

	var target_pitch: float = forward_amount * deg_to_rad(tilt_angle)
	var target_roll: float = side_amount * deg_to_rad(tilt_angle)

	var turn_input: float = yaw_input
	target_roll += turn_input * deg_to_rad(turn_tilt_angle)
	yaw_input = move_toward(yaw_input, 0.0, 5.0 * delta)

	drone_mesh.rotation.x = lerp_angle(drone_mesh.rotation.x, target_pitch, tilt_speed * delta)
	drone_mesh.rotation.z = lerp_angle(drone_mesh.rotation.z, target_roll, tilt_speed * delta)
	
	
#________________________________Поворот дрона________________________________
func handle_drone_yaw(event): #-----поворот колёсиком-----
	if drone_is_touching:
		yaw_input = 0.0
		yaw_velocity = 0.0
		return

	if controls_locked:
		yaw_input = 0.0
		yaw_velocity = 0.0
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: # Колесо вверх
			yaw_input = -1.0
			yaw_velocity -= drone_yaw_speed

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: # Колесо вниз
			yaw_input = 1.0
			yaw_velocity += drone_yaw_speed
			
			
#________________________________инерция________________________________
func update_yaw(delta): #-----инерция поворота-----
	if drone_is_touching:
		yaw_input = 0.0
		yaw_velocity = 0.0
		mobile_turn_input = 0.0
		return

	if controls_locked:
		yaw_input = 0.0
		yaw_velocity = 0.0
		mobile_turn_input = 0.0
		return

	# ПК + мобилка 
	var total_input = mobile_turn_input
	yaw_velocity += total_input * drone_yaw_speed

	var yaw_rotation = deg_to_rad(yaw_velocity * delta * 60.0)
	rotate_y(yaw_rotation)
	camera_root.rotate_y(-yaw_rotation) # Компенсируем поворот камеры

	yaw_velocity = move_toward(yaw_velocity, 0.0, yaw_drag * delta * 10.0)
	
#________________________________Краш дрона________________________________
func crash_drone(propeller_id: int): #-----поломка дрона-----
	if crashed:
		return

	crashed = true
	crash_rotation_progress = 0.0
	crash_finished = false
	# Направление падения зависит от винта
	match propeller_id:
		1:crash_spin = Vector3(1.2, 0.0, -0.8)
		2:crash_spin = Vector3(1.2, 0.0, 0.8)
		3:crash_spin = Vector3(-1.2, 0.0, -0.8)
		4:crash_spin = Vector3(-1.2, 0.0, 0.8)

	# Начальный импульс
	crash_velocity = velocity
	crash_velocity.y = 2.0
	
#________________________________Выведение кол-во энергии на экран________________________________
func add_energy(amount: int = 1) -> bool: #-----добавление сферы-----
	if energy >= max_energy:
		update_energy_ui()
		return false

	energy += amount
	energy = clampi(energy, 0, max_energy)

	restore_charge(sphere_charge_restore)
	update_energy_ui()

	return true


func update_energy_ui() -> void: #-----обновление иконок сфер-----
	if energy_sphere_bar == null:
		return

	for child in energy_sphere_bar.get_children():
		child.queue_free()

	for i in range(max_energy):
		var icon := TextureRect.new()

		if i < energy:
			icon.texture = energy_sphere_full_texture
		else:
			icon.texture = energy_sphere_empty_texture

		icon.custom_minimum_size = energy_sphere_icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		energy_sphere_bar.add_child(icon)
		
#________________________________Заряд дрона________________________________
func process_charge(delta: float) -> void: #-----расход заряда-----
	charge_timer += delta

	if charge_timer >= charge_loss_interval:
		charge_timer = 0.0
		current_charge -= 1
		current_charge = clampi(current_charge, 0, max_charge)

		update_charge_ui()

		if current_charge <= 0:
			# То же самое, что при столкновении пропеллера.
			# Передаём любой propeller_id, чтобы сработал уже готовый краш.
			crash_drone(1)


func restore_charge(amount: int) -> void: #-----восстановление заряда-----
	current_charge += amount
	current_charge = clampi(current_charge, 0, max_charge)

	update_charge_ui()


func update_charge_ui() -> void: #-----обновление прогресс-бара зарядки-----
	if charge_progress_bar == null:
		return

	var charge_percent: float = 0.0

	if max_charge > 0:
		charge_percent = float(current_charge) / float(max_charge)

	charge_percent = clamp(charge_percent, 0.0, 1.0)

	charge_progress_bar.min_value = 0.0
	charge_progress_bar.max_value = 100.0
	charge_progress_bar.value = charge_percent * 100.0

	_update_charge_bar_style(charge_percent)
		
func upgrade_speed(amount: float) -> void: #-----улучшение скорости-----
	move_speed += amount
	print("Скорость улучшена: ", move_speed)
	
func upgrade_max_charge(amount: int) -> void: #-----увеличение батареи-----
	max_charge += amount
	current_charge += amount
	current_charge = clampi(current_charge, 0, max_charge)
	update_charge_ui()
	print("Максимальный заряд улучшен: ", max_charge)
	
func upgrade_max_energy(amount: int = 1) -> void: #-----увеличение хранилища сфер-----
	max_energy += amount
	update_energy_ui()
	print("Максимум сфер улучшен: ", max_energy)
	
func set_controls_locked(value: bool) -> void: #-----блокировка управления-----
	controls_locked = value

	if controls_locked:
		velocity = Vector3.ZERO
		
func _update_charge_bar_style(charge_percent: float) -> void: #-----цвет зарядки-----
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = charge_empty_color
	background_style.corner_radius_top_left = 10
	background_style.corner_radius_top_right = 10
	background_style.corner_radius_bottom_left = 10
	background_style.corner_radius_bottom_right = 10
	background_style.border_width_left = 2
	background_style.border_width_top = 2
	background_style.border_width_right = 2
	background_style.border_width_bottom = 2
	background_style.border_color = Color(1.0, 1.0, 1.0, 0.45)

	var fill_style := StyleBoxFlat.new()
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8

	if charge_percent < 0.5:
		fill_style.bg_color = charge_low_color.lerp(charge_middle_color, charge_percent / 0.5)
	else:
		fill_style.bg_color = charge_middle_color.lerp(charge_full_color, (charge_percent - 0.5) / 0.5)

	charge_progress_bar.add_theme_stylebox_override("background", background_style)
	charge_progress_bar.add_theme_stylebox_override("fill", fill_style)
	
#________________________________Ветерок________________________________
func apply_wind(direction: Vector3, force: float, delta: float) -> void: #-----сдувание ветром-----
	if crashed:
		return

	if controls_locked:
		return

	if drone_is_touching:
		return

	var horizontal_direction := Vector3(direction.x, 0.0, direction.z)

	if horizontal_direction.length() < 0.01:
		return

	horizontal_direction = horizontal_direction.normalized()
	wind_velocity += horizontal_direction * force * wind_effect_multiplier * delta
	
func _apply_wind_velocity(delta: float) -> void: #-----применение скорости ветра-----
	if drone_is_touching or controls_locked or crashed:
		wind_velocity = Vector3.ZERO
		return

	saved_control_velocity = velocity

	velocity.x += wind_velocity.x
	velocity.z += wind_velocity.z

	wind_velocity = wind_velocity.move_toward(Vector3.ZERO, wind_resistance * delta)


func _remove_wind_velocity_after_move() -> void: #-----возврат скорости управления-----
	velocity.x = saved_control_velocity.x
	velocity.z = saved_control_velocity.z
	
#________________________________анимации дрона________________________________
func update_drone_animation_state() -> void: #-----анимация при касании-----
	if upgrade_in_process:
		return
	
	if drone_animation_player == null:
		return

	drone_is_touching = get_slide_collision_count() > 0 or is_on_floor() or is_on_wall() or is_on_ceiling()

	if drone_is_touching:
		drone_animation_player.pause()
		return

	if drone_animation_player.current_animation != hover_animation_name:
		drone_animation_player.play(hover_animation_name)
		return

	if not drone_animation_player.is_playing():
		drone_animation_player.play(hover_animation_name)

func update_touch_state() -> void: #-----проверка касания-----
	drone_is_touching = get_slide_collision_count() > 0 or is_on_floor() or is_on_wall() or is_on_ceiling()

func start_shop_upgrade_sequence(shop_menu: Node) -> void: #-----сцена покупки-----
	if upgrade_in_process:
		return

	upgrade_in_process = true
	set_controls_locked(true)

	var old_model_y: float = drone_mesh.position.y # старая высота модели
	drone_mesh.position.y = old_model_y + upgrade_model_lift # поднимаем модель

	if drone_animation_player == null:
		print("AnimationPlayer не найден")
		drone_mesh.position.y = old_model_y
		upgrade_in_process = false
		set_controls_locked(false)
		return

	if not drone_animation_player.has_animation(upgrade_animation_name):
		print("Анимация покупки не найдена")
		drone_mesh.position.y = old_model_y
		upgrade_in_process = false
		set_controls_locked(false)
		return

	drone_animation_player.speed_scale = 1.0
	drone_animation_player.play(upgrade_animation_name)

	if welding_audio != null:
		welding_audio.play()
		
	_start_welding_particles_delay()

	await drone_animation_player.animation_finished

	if welding_particles != null:
		welding_particles.emitting = false
		welding_particles.visible = false
		
	if welding_audio != null:
		welding_audio.stop()

	if drone_animation_player.has_animation(hover_animation_name):
		drone_animation_player.speed_scale = 1.0
		drone_animation_player.play(hover_animation_name)
		drone_animation_player.seek(0.0, true)
		drone_animation_player.advance(0.0)
		drone_animation_player.pause()

	drone_mesh.position.y = old_model_y # опускаем модель обратно
	upgrade_in_process = false

	if shop_menu != null and shop_menu.has_method("open_shop"):
		shop_menu.open_shop(self)
	else:
		set_controls_locked(false)

func _start_welding_particles_delay() -> void: #-----отложенные частицы-----
	await get_tree().create_timer(2.0).timeout

	if not upgrade_in_process:
		return

	if welding_particles != null:
		welding_particles.visible = true
		welding_particles.emitting = true

	await get_tree().create_timer(2.0).timeout

	if welding_particles != null:
		welding_particles.emitting = false
		welding_particles.visible = false
		
#________________________________звуки дрона________________________________
func update_drone_sound() -> void: #-----звук дрона-----
	if drone_hum_audio == null:
		return

	drone_hum_audio.volume_db = -20.0 # громкость жужжания

	var should_play: bool = not drone_is_touching and not crashed and not controls_locked

	if should_play:
		if not drone_hum_audio.playing:
			drone_hum_audio.play()
	else:
		if drone_hum_audio.playing:
			drone_hum_audio.stop()


func _go_to_death_or_finish_tutorial() -> void: #-----смерть или завершение обучения-----
	var tutorial_input := get_tree().get_first_node_in_group("tutorial_input")

	if tutorial_input != null and tutorial_input.has_method("handle_tutorial_death"):
		tutorial_input.handle_tutorial_death()
		return

	get_tree().change_scene_to_file("res://death_scene.tscn")
