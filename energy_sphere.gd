#________________________________Энергосфера________________________________
extends Area3D

var generator = null # генератор, который создал сферу
@onready var pickup_audio: AudioStreamPlayer3D = $PickupAudio

func _ready() -> void: #-----подключение сигнала сбора-----
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void: #-----подбор сферы-----
	if not body.is_in_group("player"):
		return

	var collected: bool = false # получилось ли подобрать сферу

	if body.has_method("add_energy"):
		collected = body.add_energy(1)
	else:
		if "energy" in body and "max_energy" in body:
			if body.energy < body.max_energy:
				body.energy += 1
				collected = true

	if not collected:
		print("Хранилище сфер заполнено")
		return

	if generator:
		generator.sphere_collected()
	_play_pickup_sound()
	get_tree().call_group("tutorial_input", "register_energy_sphere_collected")
	queue_free() # удаляем собранную сферу

func _play_pickup_sound() -> void: #-----звук подбора-----
	if pickup_audio == null or pickup_audio.stream == null:
		return

	var audio := AudioStreamPlayer3D.new()
	get_tree().current_scene.add_child(audio)
	audio.global_position = global_position
	audio.stream = pickup_audio.stream
	audio.volume_db = pickup_audio.volume_db
	audio.finished.connect(audio.queue_free)
	audio.play()
