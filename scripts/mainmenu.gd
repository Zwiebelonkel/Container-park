extends Control

@onready var menu_panel: Panel = $CenterContainer/Panel
@onready var options_panel: Panel = $OptionsPanel
@onready var start_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/Start

func _ready() -> void:
	options_panel.visible = false
	start_button.grab_focus()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/base.tscn")

func _on_options_pressed() -> void:
	menu_panel.visible = false
	options_panel.visible = true

func _on_options_back_requested() -> void:
	options_panel.visible = false
	menu_panel.visible = true
	start_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
