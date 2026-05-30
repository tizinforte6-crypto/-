extends Control

@export var game_scene_path: String = "res://main.tscn"
@export var main_menu_scene_path: String = "res://main_menu.tscn"
@export var tutorial_scene_path: String = "res://tutorial_scene.tscn"
@export var loading_scene_path: String = "res://loading_screen.tscn"
@onready var tutorial_button: Button = $CenterContainer/VBoxContainer/TutorialButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/VBoxContainer/MenuButton


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	restart_button.pressed.connect(_on_restart_button_pressed)
	tutorial_button.pressed.connect(_on_tutorial_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)


func _on_restart_button_pressed() -> void:
	LoadingData.target_scene_path = game_scene_path
	get_tree().change_scene_to_file("res://loading_screen.tscn")


func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)

func _on_tutorial_button_pressed() -> void:
	LoadingData.target_scene_path = tutorial_scene_path
	get_tree().change_scene_to_file(loading_scene_path)
