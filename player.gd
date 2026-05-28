#________________________________Игрок________________________________
extends CharacterBody3D


# Настройки
@export var move_speed : float = 10.0 # скорость дрона
@export var acceleration : float = 6.0
@export var deceleration : float = 1.0
@export var direction_change_drag : float = 4.0
@export var vertical_speed : float = 5.0
@export var vertical_acceleration : float = 3.0
@export var vertical_deceleration : float = 1.5
@export var mouse_sensitivity : float = 0.002 # чувствительность мыши
@export var drone_yaw_speed : float = 3.0
@export var yaw_drag : float = 3.0

# Заряд дрона
@export var max_charge: int = 100 # максимум заряда
@export var current_charge: int = 100 # текущий заряд
@export var charge_loss_interval: float = 2.0 # разряд раз в несколько секунд
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
# Ветки
@onready var charge_label: Label = $CanvasLayer2/ChargeLabel
@onready var energy_label: Label = $CanvasLayer2/EnergyLabel
@onready var spring_arm : SpringArm3D = $CameraRoot/SpringArm3D
@onready var camera : Camera3D = $CameraRoot/SpringArm3D/Camera3D
@onready var canvas : CanvasLayer = $CanvasLayer
@onready var drone_mesh : Node3D = $MeshInstance3D
@onready var camera_root : Node3D = $CameraRoot

# Наклоны
@export var tilt_angle : float = 12.0
@export var tilt_speed : float = 5.0
@export var drone_rotation_speed : float = 4.0
@export var turn_tilt_angle : float = 8.0

func _ready(): #-----стартовая настройка игрока-----
	add_to_group("player") # магазин и сферы ищут эту группу
	add_to_group("wind_affected") # объект может сдуваться ветром
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
			get_tree().change_scene_to_file("res://death_scene.tscn")
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
	move_and_slide()

#________________________________Управление________________________________
func handle_horizontal_movement(delta): #-----горизонтальное движение-----

	var input_dir := Vector2.ZERO
	# туда сюда
	if is_mobile:
		input_dir.x = Input.get_axis("ui_left","ui_right")
		input_dir.y = Input.get_axis("ui_down","ui_up")
	else:
		input_dir.x = Input.get_axis("move_left","move_right")
		input_dir.y = Input.get_axis("move_back","move_forward")

	# Градусы

	var direction := (global_transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
	direction.y = 0
	direction = direction.normalized()
	var target_velocity := direction * move_speed #Инерция

	if direction != Vector3.ZERO:
	# летим ли мы против нового направления
		var current_horizontal_velocity = Vector3(velocity.x,0,velocity.z)
		var changing_direction = (current_horizontal_velocity.dot(direction) < 0)

		if changing_direction:# Смена направления
			velocity.x = move_toward(velocity.x,0.0,direction_change_drag * delta * move_speed)
			velocity.z = move_toward(velocity.z,0.0,direction_change_drag * delta * move_speed)
		else:
			velocity.x = move_toward(velocity.x,target_velocity.x,acceleration * delta * move_speed)
			velocity.z = move_toward(velocity.z,target_velocity.z,acceleration * delta * move_speed)

	else:
		velocity.x = move_toward(velocity.x,0.0,deceleration * delta * move_speed)
		velocity.z = move_toward(velocity.z,0.0,deceleration * delta * move_speed)
	

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

#________________________________Наклоны________________________________
func handle_tilt(delta): #-----наклон корпуса-----

	var input_dir := Vector2.ZERO

	if is_mobile:
		input_dir.x = Input.get_axis("ui_left","ui_right")#ПК
		input_dir.y = Input.get_axis("ui_down","ui_up")
	else:
		input_dir.x = Input.get_axis("move_left","move_right")#андройд
		input_dir.y = Input.get_axis("move_back","move_forward")

	var local_velocity = (global_transform.basis.inverse() * velocity)#наклоны
	var forward_amount = clamp(local_velocity.z / move_speed,-1.0,1.0)
	var side_amount = clamp(local_velocity.x / move_speed,-1.0,1.0)
	var target_pitch = forward_amount * deg_to_rad(tilt_angle)
	var target_roll = -side_amount * deg_to_rad(tilt_angle)
	var turn_input = yaw_input
	target_roll += (-turn_input *deg_to_rad(turn_tilt_angle))
	yaw_input = move_toward(yaw_input,0.0,5.0 * delta)
	
	drone_mesh.rotation.x = lerp_angle(drone_mesh.rotation.x,target_pitch,tilt_speed * delta)
	drone_mesh.rotation.z = lerp_angle(drone_mesh.rotation.z,target_roll,tilt_speed * delta)
	
#________________________________Поворот дрона________________________________
func handle_drone_yaw(event): #-----поворот колёсиком-----
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:# Колесо вверх
			yaw_input = -1.0
			yaw_velocity -= drone_yaw_speed

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:# Колесо вниз
			yaw_input = 1.0
			yaw_velocity += drone_yaw_speed
			
			
#________________________________инерция________________________________
func update_yaw(delta): #-----инерция поворота-----
	# ПК + мобилка 
	var total_input = mobile_turn_input
	yaw_velocity += total_input * drone_yaw_speed
	var yaw_rotation = deg_to_rad(yaw_velocity * delta * 60.0)
	rotate_y(yaw_rotation)
	camera_root.rotate_y(-yaw_rotation)# Компенсируем поворот камеры
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


func update_energy_ui() -> void: #-----обновление счётчика сфер-----
	if energy_label != null:
		energy_label.text = "Energy: " + str(energy) + "/" + str(max_energy)

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


func update_charge_ui() -> void: #-----обновление заряда-----
	if charge_label != null:
		charge_label.text = "Charge: " + str(current_charge) + "%"
		
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
		
func apply_wind(direction: Vector3, force: float, delta: float) -> void: #-----сдувание ветром-----
	if crashed:
		return

	if controls_locked:
		return

	velocity += direction * force * delta
