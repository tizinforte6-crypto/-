#________________________________Сокол________________________________
extends CharacterBody3D

enum FalconState {
	PATROL,
	CHASE
}

@export var active: bool = false # включена ли эта копия

@export_category("Patrol")
@export var patrol_speed: float = 6.0 # скорость круга
@export var patrol_radius: float = 8.0 # радиус круга

@export_category("Detection")
@export var detection_half_size: float = 15.0 # проверка игрока по X и Z

@export_category("Chase")
@export var chase_speed_multiplier: float = 2.0 # множитель скорости погони

@export_category("Look")
@export var rotate_to_direction: bool = true
@export var rotation_lerp_speed: float = 8.0

var state: FalconState = FalconState.PATROL

var spawn_position: Vector3 = Vector3.ZERO
var locked_y: float = 0.0 # высота патруля
var patrol_time: float = 0.0

var player: Node3D = null
@onready var wing_audio: AudioStreamPlayer3D = $WingAudio
@onready var scream_audio: AudioStreamPlayer3D = $ScreamAudio
@onready var flap_animation_player: AnimationPlayer = $Flap/AnimationPlayer
var scream_played: bool = false # крик уже был


func _ready() -> void: #-----проверка шаблона-----
	if not active:
		visible = false
		set_physics_process(false)
		return

	_setup_falcon(global_position)
	_start_flap_animation()


func activate_at_position(pos: Vector3) -> void: #-----включение копии сокола-----
	active = true
	visible = true
	global_position = pos
	set_physics_process(true)

	_setup_falcon(pos)
	_start_flap_animation()


func _setup_falcon(pos: Vector3) -> void: #-----запоминание точки спавна-----
	scream_played = false
	if wing_audio != null and not wing_audio.playing:
		wing_audio.play()
	spawn_position = pos
	locked_y = pos.y
	patrol_time = 0.0
	state = FalconState.PATROL

	player = _find_player()


func _physics_process(delta: float) -> void: #-----логика полёта-----
	if not active:
		return

	if player == null or not is_instance_valid(player):
		player = _find_player()

	match state:
		FalconState.PATROL:
			_process_patrol(delta)

		FalconState.CHASE:
			_process_chase(delta)

	move_and_slide()

	if state == FalconState.CHASE:
		_check_collision_with_player()


func _process_patrol(delta: float) -> void: #-----полёт по кругу-----
	# Во время обычного полёта Y всегда неизменный.
	global_position.y = locked_y # высота не меняется

	patrol_time += delta

	var safe_radius: float = maxf(patrol_radius, 0.01) # защита от деления на ноль
	var angular_speed: float = patrol_speed / safe_radius # скорость обхода круга
	var angle: float = patrol_time * angular_speed

	var target_position: Vector3 = spawn_position + Vector3(cos(angle) * patrol_radius,0.0,sin(angle) * patrol_radius)

	target_position.y = locked_y

	var direction: Vector3 = target_position - global_position
	direction.y = 0.0

	if direction.length() > 0.05:
		var move_dir: Vector3 = direction.normalized()
		velocity = move_dir * patrol_speed
		_rotate_towards(move_dir, delta)
	else:
		velocity = Vector3.ZERO

	_check_player_below()


func _check_player_below() -> void: #-----проверка игрока снизу-----
	if player == null:
		return

	var player_pos: Vector3 = player.global_position
	var falcon_pos: Vector3 = global_position

	# Игрок должен быть ниже сокола.
	if player_pos.y >= falcon_pos.y:
		return

	# Игрок должен быть в пределах +-5 по X и Z.
	var dx: float = abs(player_pos.x - falcon_pos.x)
	var dz: float = abs(player_pos.z - falcon_pos.z)

	if dx <= detection_half_size and dz <= detection_half_size:
		_play_scream_once()
		state = FalconState.CHASE


func _process_chase(delta: float) -> void: #-----погоня за игроком-----
	if player == null or not is_instance_valid(player):
		queue_free() # сокол исчезает
		return

	var direction: Vector3 = player.global_position - global_position

	if direction.length() < 0.05:
		queue_free()
		return

	var move_dir: Vector3 = direction.normalized()
	var chase_speed: float = patrol_speed * chase_speed_multiplier

	velocity = move_dir * chase_speed

	_rotate_towards(move_dir, delta)


func _check_collision_with_player() -> void: #-----проверка удара телом-----
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		if collider == null:
			continue

		if collider is Node:
			var node := collider as Node

			if node.is_in_group("player") or node.is_in_group("drone"):
				print("Сокол врезался в игрока")

				if wing_audio != null:
					wing_audio.stop()

				queue_free()
				return


func _rotate_towards(direction: Vector3, delta: float) -> void: #-----поворот в сторону движения-----
	if not rotate_to_direction:
		return

	if direction.length() < 0.01:
		return

	var target_basis: Basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	global_basis = global_basis.slerp(target_basis, rotation_lerp_speed * delta)


func _find_player() -> Node3D: #-----поиск игрока-----
	var found_player: Node = get_tree().get_first_node_in_group("player")

	if found_player == null:
		found_player = get_tree().get_first_node_in_group("drone")

	if found_player is Node3D:
		return found_player as Node3D

	return null

func _play_scream_once() -> void: #-----крик сокола-----
	if scream_played:
		return

	scream_played = true

	if scream_audio != null:
		scream_audio.play()

func _start_flap_animation() -> void: #-----бесконечный взмах крыльев-----
	if flap_animation_player == null:
		print("AnimationPlayer не найден")
		return

	print("Анимации орла: ", flap_animation_player.get_animation_list())

	if not flap_animation_player.has_animation("Flap"):
		print("Анимация Flap не найдена")
		return

	var animation: Animation = flap_animation_player.get_animation("Flap")
	animation.loop_mode = Animation.LOOP_LINEAR

	flap_animation_player.play("Flap")
