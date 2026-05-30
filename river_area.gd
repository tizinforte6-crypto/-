extends Area3D

@export var only_player: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if only_player:
		if not body.is_in_group("player") and not body.is_in_group("drone"):
			return

	print("Дрон коснулся воды")

	if body.has_method("crash_drone"):
		body.crash_drone()
		return

	if body.has_method("fall_in_water"):
		body.fall_in_water()
		return
