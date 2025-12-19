extends Control

@onready var video = $VideoStreamPlayer
@onready var label = $Label

# Asegúrate de que este nombre sea correcto en tus archivos
const RUTA_MENU = "res://menu_inicio.tscn" 

func _ready():
	label.visible = false
	
	# Conectamos la señal (Excelente uso de señales)
	video.finished.connect(_cuando_termina_video)
	
	# --- BORRA O COMENTA ESTA LÍNEA ---
	# video.play() <--- ¡QUITALA! El SistemaOleadas lo activará después.

func _cuando_termina_video():
	# video.visible = false # Opcional
	label.visible = true
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file(RUTA_MENU)
