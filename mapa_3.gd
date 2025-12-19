extends Node2D

func _ready():
	# Le pedimos a MusicaFondo la lista épica final
	# (Jujutsu Kaisen, Escape City, Usubeni, Golden Time)
	MusicaFondo.cargar_playlist(MusicaFondo.playlist_mapa_3)
