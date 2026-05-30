extends Control

#________________________________Настройки________________________________
@export var game_scene_path: String = "res://main.tscn" # путь до основной сцены
@export var tutorial_scene_path: String = "res://tutorial_scene.tscn"
@export var loading_scene_path: String = "res://loading_screen.tscn"

#________________________________Кнопки________________________________
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var tutorial_button: Button = $VBoxContainer/TutorialButton

func _ready() -> void: #-----подготовка меню-----
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)


func _on_start_button_pressed() -> void: #-----начало игры-----
	LoadingData.target_scene_path = game_scene_path
	get_tree().change_scene_to_file("res://loading_screen.tscn")


func _on_quit_button_pressed() -> void: #-----выход из игры-----
	get_tree().quit()

func _on_tutorial_button_pressed() -> void:
	LoadingData.target_scene_path = tutorial_scene_path
	get_tree().change_scene_to_file(loading_scene_path)
