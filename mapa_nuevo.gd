extends Node2D

func _ready():
	# Llamamos a tu autoload "MusicaFondo"
	MusicaFondo.cargar_playlist(MusicaFondo.playlist_mapa_nuevo)
