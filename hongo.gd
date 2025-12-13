# Archivo: Hongo.gd
extends CharacterBody2D 
# 🛑 El nodo raíz del Hongo debe ser un CharacterBody2D. 🛑

# =========================================================
# I. CONSTANTES Y VARIABLES DE ESTADO
# =========================================================

# --- Nodos: RUTA CORREGIDA (CharacterBody2D -> Node2D -> AnimatedSprite2D) ---
@onready var anim_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D 

# --- Estado de Salud ---
var vida_actual: int = 3
const MAX_VIDA: int = 3

# --- Daño, Muerte y Tiempos ---
var is_dead := false
var is_receiving_damage := false
const TIEMPO_ANIMACION_MUERTE := 0.7  # Ajustar según la duración de 'die'
const TIEMPO_ANIMACION_HIT := 0.25 # Ajustar según la duración de 'hit'

# =========================================================
# II. FUNCIÓN DE INICIO
# =========================================================

func _ready():
	is_dead = false
	is_receiving_damage = false
	set_physics_process(true) 
	anim_sprite.play("idle") 

# =========================================================
# III. PROCESO FÍSICO (Estático)
# =========================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# El Hongo está inmóvil.
	velocity = Vector2.ZERO
	move_and_slide()

# =========================================================
# IV. FUNCIONES DE COMBATE Y ESTADO
# =========================================================

# --- Función para recibir daño (Llamada por el ataque del jugador) ---
func recibir_danio(cantidad_danio: int) -> void:
	if is_dead or is_receiving_damage:
		return

	vida_actual -= cantidad_danio
	print("Hongo recibió ", cantidad_danio, " de daño. Vida restante: ", vida_actual)

	if vida_actual <= 0:
		die()
	else:
		hit_received()

# --- Reacción al Golpe ('hit') ---
func hit_received() -> void:
	is_receiving_damage = true
	
	# 1. Reproducir animación 'hit'
	anim_sprite.play("hit")
	
	# 2. Esperar la duración del golpe
	await get_tree().create_timer(TIEMPO_ANIMACION_HIT).timeout
	
	# 3. Regresar a 'idle'
	is_receiving_damage = false
	anim_sprite.play("idle")


# --- Función de Muerte ('die') ---
func die() -> void:
	if is_dead:
		return

	is_dead = true
	set_physics_process(false) 
	
	# 1. Reproducir animación 'die'
	anim_sprite.play("die")

	# 2. Esperar la duración de la animación
	await get_tree().create_timer(TIEMPO_ANIMACION_MUERTE).timeout
	
	# 3. Eliminar el hongo
	queue_free()
