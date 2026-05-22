extends CharacterBody3D


# Настройки
@export var move_speed : float = 10.0
@export var acceleration : float = 6.0
@export var deceleration : float = 1.0
@export var direction_change_drag : float = 4.0
@export var vertical_speed : float = 5.0
@export var vertical_acceleration : float = 3.0
@export var vertical_deceleration : float = 1.5
@export var mouse_sensitivity : float = 0.002
@export var drone_yaw_speed : float = 3.0
@export var yaw_drag : float = 3.0

# Мобилки
var is_mobile := false
var mobile_move := Vector2.ZERO
var mobile_up := false
var mobile_down := false
var yaw_input : float = 0.0
var yaw_velocity : float = 0.0
var mobile_turn_input : float = 0.0

# Ветки
@onready var spring_arm : SpringArm3D = $CameraRoot/SpringArm3D
@onready var camera : Camera3D = $CameraRoot/SpringArm3D/Camera3D
@onready var canvas : CanvasLayer = $CanvasLayer
@onready var drone_yaw : Node3D = $DroneYaw
@onready var drone_mesh : Node3D = $DroneYaw/MeshInstance3D
@onready var camera_root : Node3D = $CameraRoot

# Наклоны
@export var tilt_angle : float = 12.0
@export var tilt_speed : float = 5.0
@export var drone_rotation_speed : float = 4.0
@export var turn_tilt_angle : float = 8.0

func _ready():
	setup_platform()


func setup_platform():
	# Для теста мобилки махнуть местами
	is_mobile = OS.get_name() == "Android"#is_mobile = true
	canvas.visible = is_mobile

	if is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		drone_yaw_speed = 1.0
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event):
	if is_mobile:
		handle_touch_look(event)
	else:
		handle_mouse_look(event)
		handle_drone_yaw(event)


func handle_mouse_look(event): # под пк камера
	if event is InputEventMouseMotion and not is_mobile:
		camera_root.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		clamp_camera()


func handle_touch_look(event):# под мобилки камера
	# Для теста мобилки махнуть местами
	if event is InputEventScreenDrag:#if event is InputEventScreenDrag or event is InputEventMouseMotion:
		camera_root.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		clamp_camera()




func clamp_camera():# Камера
	spring_arm.rotation.x = clamp(spring_arm.rotation.x,deg_to_rad(-80),deg_to_rad(80))
	spring_arm.rotation.z = 0

#________________________________Физика________________________________
func _physics_process(delta):
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
func handle_horizontal_movement(delta): # WASD и джойстик

	var input_dir := Vector2.ZERO
	# туда сюда
	if is_mobile:
		input_dir.x = Input.get_axis("ui_left","ui_right")
		input_dir.y = Input.get_axis("ui_down","ui_up")
	else:
		input_dir.x = Input.get_axis("move_left","move_right")
		input_dir.y = Input.get_axis("move_back","move_forward")

	# Градусы

	var direction := (drone_yaw.global_transform.basis *Vector3(input_dir.x, 0, -input_dir.y)).normalized()
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
	

func handle_vertical_movement(delta): # (c клавиша) и пробел
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
func handle_tilt(delta):

	var input_dir := Vector2.ZERO

	if is_mobile:
		input_dir.x = Input.get_axis("ui_left","ui_right")#ПК
		input_dir.y = Input.get_axis("ui_down","ui_up")
	else:
		input_dir.x = Input.get_axis("move_left","move_right")#андройд
		input_dir.y = Input.get_axis("move_back","move_forward")

	var local_velocity = (drone_yaw.global_transform.basis.inverse()* velocity)#наклоны
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
func handle_drone_yaw(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:# Колесо вверх
			yaw_input = -1.0
			yaw_velocity -= drone_yaw_speed

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:# Колесо вниз
			yaw_input = 1.0
			yaw_velocity += drone_yaw_speed
			
			
#________________________________Yaw инерция________________________________
func update_yaw(delta):
	# ПК + мобилка 
	var total_input = mobile_turn_input
	yaw_velocity += total_input * drone_yaw_speed
	drone_yaw.rotate_y(deg_to_rad(yaw_velocity * delta * 60.0))
	yaw_velocity = move_toward(yaw_velocity, 0.0, yaw_drag * delta * 10.0)
