extends Node2D

func _ready():
	# Le pedimos a MusicaFondo la lista del bosque
	# (Dragon Soul, Chainsaw Man, Dan Da Dan)
	MusicaFondo.cargar_playlist(MusicaFondo.playlist_bosque)
