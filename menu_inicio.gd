extends Control

const RUTA_MAPA = "res://MapaNuevo.tscn" 

func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file(RUTA_MAPA)

func _on_salir_pressed() -> void:
	get_tree().quit()
