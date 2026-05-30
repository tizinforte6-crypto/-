extends Control

var target_scene_path: String = ""

@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var loading_label: Label = $CenterContainer/VBoxContainer/LoadingLabel

var loading_started: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	target_scene_path = LoadingData.target_scene_path

	ResourceLoader.load_threaded_request(target_scene_path)
	loading_started = true


func _process(delta: float) -> void:
	if not loading_started:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, progress)

	if progress.size() > 0:
		progress_bar.value = progress[0] * 100.0

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_label.text = "Загрузка..."

		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			var scene_resource := ResourceLoader.load_threaded_get(target_scene_path)

			if scene_resource is PackedScene:
				get_tree().change_scene_to_packed(scene_resource)

		ResourceLoader.THREAD_LOAD_FAILED:
			loading_label.text = "Ошибка загрузки"
