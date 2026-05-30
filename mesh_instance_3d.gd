extends MeshInstance3D

@export var water_speed: Vector2 = Vector2(-0.1, 0.0)

var water_material: StandardMaterial3D


func _ready() -> void:
	water_material = get_active_material(0) as StandardMaterial3D

	if water_material == null:
		print("На воде нет StandardMaterial3D")


func _process(delta: float) -> void:
	if water_material == null:
		return

	water_material.uv1_offset += Vector3(water_speed.x * delta, water_speed.y * delta, 0.0)
