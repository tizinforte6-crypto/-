#________________________________Менеджер звуков________________________________
extends Node

@export var forest_sound: AudioStream # тихий лес
@export var wind_loop_sound: AudioStream # звук ветра
@export var button_sound: AudioStream # звук кнопки

@export var forest_volume_db: float = -24.0 # громкость леса
@export var wind_volume_db: float = -24.0 # громкость ветра
@export var button_volume_db: float = -8.0 # громкость кнопки

var forest_audio: AudioStreamPlayer = null # постоянный лес
var wind_audio: AudioStreamPlayer = null # разовый ветер
var button_audio: AudioStreamPlayer = null # кнопки


func _ready() -> void: #-----подготовка звуков-----
	add_to_group("audio_manager")

	forest_audio = _create_audio_player(forest_sound, forest_volume_db, true)
	wind_audio = _create_audio_player(wind_loop_sound, wind_volume_db, true)
	button_audio = _create_audio_player(button_sound, button_volume_db, false)

	if forest_audio != null:
		forest_audio.play()

	get_tree().node_added.connect(_on_node_added)
	call_deferred("_connect_existing_buttons")


func _create_audio_player(stream: AudioStream, volume_db: float, autoplay_loop: bool) -> AudioStreamPlayer: #-----создание плеера-----
	if stream == null:
		return null

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)

	return player


func start_wind_sound() -> void: #-----запуск звука ветра-----
	if wind_audio == null:
		return

	if not wind_audio.playing:
		wind_audio.play()


func stop_wind_sound() -> void: #-----остановка звука ветра-----
	if wind_audio == null:
		return

	if wind_audio.playing:
		wind_audio.stop()


func play_button_click() -> void: #-----звук кнопки-----
	if button_audio == null:
		return

	button_audio.stop()
	button_audio.play()


func _connect_existing_buttons() -> void: #-----поиск кнопок-----
	_connect_buttons_recursive(get_tree().current_scene)


func _connect_buttons_recursive(node: Node) -> void: #-----подключение кнопок-----
	if node == null:
		return

	if node is Button:
		_connect_button(node as Button)

	for child in node.get_children():
		_connect_buttons_recursive(child)


func _on_node_added(node: Node) -> void: #-----новая кнопка-----
	if node is Button:
		_connect_button(node as Button)


func _connect_button(button: Button) -> void: #-----подключение клика-----
	if button.is_in_group("mobile_control_button"):
		return

	if _has_parent_named(button, "CanvasLayer"):
		return

	if button.pressed.is_connected(_on_button_pressed):
		return

	button.pressed.connect(_on_button_pressed)


func _has_parent_named(node: Node, parent_name: String) -> bool: #-----проверка родителя-----
	var current := node.get_parent()

	while current != null:
		if current.name == parent_name:
			return true

		current = current.get_parent()

	return false


func _on_button_pressed() -> void: #-----клик кнопки-----
	play_button_click()
