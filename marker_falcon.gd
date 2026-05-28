extends CharacterBody3D

enum FalconState { PATROL, CHASE }

@export_category("Патруль")
@export var patrol_speed: float = 6.0
@export var arrive_distance: float = 0.4
@export var patrol_markers_path: NodePath = ^"../FalconPatrolMarkers"

@export_category("Игрок")
@export var detection_half_size: float = 5.0
@export var chase_speed_multiplier: float = 2.0

@export_category("Поворот")
@export var rotate_to_direction: bool = true
@export var rotation_lerp_speed: float = 8.0

var state: FalconState = FalconState.PATROL
var patrol_points: Array[Vector3] = []
var current_point_index: int = 0
var locked_y: float = 0.0
var player: Node3D = null


func _ready() -> void: #-----подготовка сокола-----
	player = _find_player()
	_load_patrol_points()

	if not patrol_points.is_empty():
		global_position = patrol_points[0] # старт на первом маркере
		current_point_index = 1 # следующая точка после старта

		if current_point_index >= patrol_points.size():
			current_point_index = 0


func _physics_process(delta: float) -> void: #-----движение сокола-----
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


func _load_patrol_points() -> void: #-----загрузка точек маршрута-----
	patrol_points.clear()

	var markers_root: Node3D = get_node_or_null(patrol_markers_path)

	if markers_root == null:
		push_warning("Точки маршрута сокола не найдены")
		return

	for child in markers_root.get_children():
		if child is Marker3D:
			patrol_points.append(child.global_position)

	if patrol_points.is_empty():
		push_warning("У сокола нет маркеров маршрута")


func _process_patrol(delta: float) -> void: #-----полёт по точкам-----
	if patrol_points.is_empty():
		velocity = Vector3.ZERO
		return

	var target_position: Vector3 = patrol_points[current_point_index]
	var direction: Vector3 = target_position - global_position

	if direction.length() <= arrive_distance:
		current_point_index += 1

		if current_point_index >= patrol_points.size():
			current_point_index = 0

		target_position = patrol_points[current_point_index]
		direction = target_position - global_position

	if direction.length() > 0.05:
		var move_dir: Vector3 = direction.normalized()
		velocity = move_dir * patrol_speed
		_rotate_towards(move_dir, delta)
	else:
		velocity = Vector3.ZERO

	_check_player_below()


func _check_player_below() -> void: #-----поиск игрока снизу-----
	if player == null:
		return

	var player_pos: Vector3 = player.global_position
	var falcon_pos: Vector3 = global_position

	if player_pos.y >= falcon_pos.y:
		return

	var dx: float = abs(player_pos.x - falcon_pos.x)
	var dz: float = abs(player_pos.z - falcon_pos.z)

	if dx <= detection_half_size and dz <= detection_half_size:
		state = FalconState.CHASE


func _process_chase(delta: float) -> void: #-----пикирование на игрока-----
	if player == null or not is_instance_valid(player):
		queue_free()
		return

	var direction: Vector3 = player.global_position - global_position

	if direction.length() < 0.05:
		queue_free()
		return

	var move_dir: Vector3 = direction.normalized()
	velocity = move_dir * patrol_speed * chase_speed_multiplier

	_rotate_towards(move_dir, delta)


func _check_collision_with_player() -> void: #-----проверка столкновения-----
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		if collider == null:
			continue

		if collider is Node:
			var node: Node = collider as Node

			if node.is_in_group("player") or node.is_in_group("drone"):
				print("Сокол врезался в игрока")
				queue_free()
				return


func _rotate_towards(direction: Vector3, delta: float) -> void: #-----поворот по движению-----
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
