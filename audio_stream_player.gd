extends AudioStreamPlayer

# ==========================================
# 1. CARGA DE TODAS LAS CANCIONES
# ==========================================
const HOLOGRAM = preload("res://Musica Piola/Hologram [8 bit cover] - Fullmetal Alchemist Brotherhood OP 2.mp3")
const UNDEFEATABLE = preload("res://Musica Piola/Undefeatable [16 bit remix] - Sonic Frontiers.mp3")
const CHOUZETSU = preload("res://Musica Piola/ChouzetsuDynamic [8bit cover] - Dragon Ball Super OP 1.mp3")
const DRAGON_SOUL = preload("res://Musica Piola/Dragon Soul [8 bit cover] - Dragon Ball Z Kai OP 1 (ft. kenzonflo).mp3")
const DAN_DA_DAN = preload("res://Musica Piola/DAN DA DAN Opening - Otonoke [8bit cover].mp3")
const CHAINSAW_MAN = preload("res://Musica Piola/Chainsaw man Full OP - Kick Back (8-bit Remix).mp3")
const ESCAPE_CITY = preload("res://Musica Piola/[16-bit Genesis] Escape from the city - Sonic Adventure 2.mp3")
const USUBENI = preload("res://Musica Piola/Dragonball Super ED Usubeni 8BIT.mp3")
const GOLDEN_TIME = preload("res://Musica Piola/Golden time lover [8 bit cover] - Fullmetal Alchemist Brotherhood OP 3.mp3")

# RECUERDA: Si esta da error, borra lo de abajo y arrastra el archivo mp3 aquí
const JUJUTSU = preload("res://Musica Piola/Jujutsu Kaisen Season 2 Opening  - Ao no Sumika [8 bit Cover].mp3")


# ==========================================
# 2. LAS PLAYLISTS (GRUPOS DE CANCIONES)
# ==========================================
# Estas variables las usaremos desde los mapas usando MusicaFondo.playlist_...
var playlist_mapa_nuevo = [HOLOGRAM, UNDEFEATABLE, CHOUZETSU]
var playlist_bosque = [DRAGON_SOUL, CHAINSAW_MAN, DAN_DA_DAN]
var playlist_mapa_3 = [JUJUTSU, ESCAPE_CITY, USUBENI, GOLDEN_TIME]

# Variables internas
var playlist_actual = []
var indice_actual = 0

# Variables de Fade (Transición)
var fade_speed := 1.5
var fading_out := false
var fading_in := false
var max_volume_db := -12.0 

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	volume_db = max_volume_db

# ==========================================
# 3. FUNCIÓN PARA QUE LOS MAPAS CAMBIEN LA LISTA
# ==========================================
func cargar_playlist(nueva_lista: Array):
	# Si ya estamos tocando esa lista, no hacemos nada (para no reiniciar)
	if playlist_actual == nueva_lista:
		return
	
	print("Detectado cambio de mapa: Cambiando música...")
	playlist_actual = nueva_lista
	indice_actual = 0 
	
	# Iniciamos la transición suave
	fading_out = true
	fading_in = false

# ==========================================
# 4. LÓGICA DE REPRODUCCIÓN Y CONTROL
# ==========================================
func _process(delta: float) -> void:
	# --- BAJAR VOLUMEN (Fade Out) ---
	if fading_out:
		volume_db = move_toward(volume_db, -80, fade_speed * 20 * delta)
		if volume_db <= -80:
			_tocar_cancion_actual() # Cambiamos el "disco" cuando está en silencio
			fading_out = false
			fading_in = true # Empezamos a subir volumen

	# --- SUBIR VOLUMEN (Fade In) ---
	elif fading_in:
		volume_db = move_toward(volume_db, max_volume_db, fade_speed * 20 * delta)
		if volume_db >= max_volume_db:
			fading_in = false

	# --- SIGUIENTE CANCIÓN AUTOMÁTICA ---
	if playing and not fading_out and not fading_in:
		# Si faltan menos de 2 segundos para terminar
		if get_playback_position() >= (stream.get_length() - 2.0):
			_avanzar_indice() 
			fading_out = true

func _input(event):
	# Tecla M para saltar canción manualmente
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			print("Saltando canción con tecla M...")
			_avanzar_indice()
			fading_out = true

# ==========================================
# 5. FUNCIONES AUXILIARES INTERNAS
# ==========================================
func _avanzar_indice():
	if playlist_actual.size() > 0:
		indice_actual = (indice_actual + 1) % playlist_actual.size()

func _tocar_cancion_actual():
	if playlist_actual.size() > 0:
		stream = playlist_actual[indice_actual]
		play()
