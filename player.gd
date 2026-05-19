extends CharacterBody3D

@export var speed : float = 5.0
@export var mouse_sensitivity : float = 0.002
@export var rotation_speed : float = 120.0 

var is_mobile := false

func _ready():
	if OS.get_name() == "Android":
		is_mobile = true
		$CanvasLayer.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		is_mobile = false
		$CanvasLayer.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if !is_mobile:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			$SpringArm3D.rotate_object_local( Vector3.UP, -event.relative.x * mouse_sensitivity )
			$SpringArm3D.rotate_x( -event.relative.y * mouse_sensitivity )
			$SpringArm3D.rotation.x = clamp($SpringArm3D.rotation.x, -1.5, 1.5 )
			$SpringArm3D.rotation.z = 0

func _physics_process(delta):
	var up_down_dir = 0.0
	if Input.is_action_pressed("move_up"):   # Пробел Вверх
		up_down_dir += 1.0
	if Input.is_action_pressed("move_down"):  # Клавиша C Вниз
		up_down_dir -= 1.0
		
	if up_down_dir != 0.0:
		velocity.y = up_down_dir * speed
	else:
		velocity.y = move_toward(velocity.y, 0, speed)
		
	var turn_amount = 0.0
	
	if Input.is_action_pressed("move_left"):  # Клавиша A налево
		turn_amount += 1.0
	if Input.is_action_pressed("move_right"): # Клавиша D направо
		turn_amount -= 1.0
		
	if turn_amount != 0.0:
		$CollisionShape3D.rotate_y(deg_to_rad(rotation_speed * turn_amount * delta))

	var move_dir = 0.0
	if Input.is_action_pressed("move_forward"):   # Клавиша W вперёд
		move_dir += 1.0 
	if Input.is_action_pressed("move_back"): # Клавиша S назад
		move_dir -= 1.0 

	
	var direction = ($CollisionShape3D.transform.basis * Vector3(0, 0, -move_dir)).normalized() # Движение горизонтально в зависимости

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)


	move_and_slide()
