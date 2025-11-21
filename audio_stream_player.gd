extends AudioStreamPlayer

# Preload de las canciones
const HOLOGRAM = preload("res://Musica Piola/Hologram [8 bit cover] - Fullmetal Alchemist Brotherhood OP 2.mp3")
const UNDEFEATABLE = preload("res://Musica Piola/Undefeatable [16 bit remix] - Sonic Frontiers.mp3")
const CHOUZETSU = preload("res://Musica Piola/ChouzetsuDynamic [8bit cover] - Dragon Ball Super OP 1.mp3")
const DRAGON_SOUL = preload("res://Musica Piola/Dragon Soul [8 bit cover] - Dragon Ball Z Kai OP 1 (ft. kenzonflo).mp3")

const JUJUTSU = preload("res://Musica Piola/Jujutsu Kaisen Season 2 Opening  - Ao no Sumika [8 bit Cover].mp3")
const DAN_DA_DAN = preload("res://Musica Piola/DAN DA DAN Opening - Otonoke [8bit cover].mp3")
const CHAINSAW_MAN = preload("res://Musica Piola/Chainsaw man Full OP - Kick Back (8-bit Remix).mp3")

# Orden de reproducción
var canciones = [HOLOGRAM, UNDEFEATABLE, CHOUZETSU, DRAGON_SOUL, CHAINSAW_MAN, DAN_DA_DAN, JUJUTSU]
var indice_cancion := 0

# Fade
var fade_speed := 1.5
var fading_out := false
var fading_in := false
var max_volume_db := -10  # volumen máximo permitido

func _ready() -> void:
	volume_db = max_volume_db
	reproducir_cancion(indice_cancion)

func reproducir_cancion(indice: int) -> void:
	stream = canciones[indice]
	play()
	volume_db = -80
	fading_in = true

func _process(delta: float) -> void:
	# --- Fade in ---
	if fading_in:
		volume_db += fade_speed * 20 * delta
		if volume_db >= max_volume_db:
			volume_db = max_volume_db
			fading_in = false

	# --- Fade out ---
	elif fading_out:
		volume_db -= fade_speed * 20 * delta
		if volume_db <= -80:
			volume_db = -80
			fading_out = false
			# Cambiar a la siguiente canción automáticamente
			indice_cancion = (indice_cancion + 1) % canciones.size()
			reproducir_cancion(indice_cancion)

	# --- Cambio automático si la canción casi termina ---
	if playing and (get_playback_position() >= (stream.get_length() - 1.5)) and not fading_out:
		fading_out = true
		fading_in = false

	# --- Cambio manual con la tecla P ---
	if Input.is_key_pressed(KEY_P) and not fading_out and not fading_in:
		fading_out = true  # iniciar fade out inmediato
		fading_in = false
		# Al terminar el fade out, reproducirá la siguiente canción
		indice_cancion = (indice_cancion + 1) % canciones.size()
