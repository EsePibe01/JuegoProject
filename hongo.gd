extends CharacterBody2D 
# 🛑 El nodo raíz del Hongo debe ser un CharacterBody2D.

# =========================================================
# I. CONSTANTES Y VARIABLES DE ESTADO (SIN ERRORES DE SINTAXIS)
# =========================================================

# --- Nodos ---
@onready var anim_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D 

# --- Estado de Salud ---
var vida_actual: int = 3
const MAX_VIDA: int = 3

# --- Daño, Muerte y Tiempos ---
var is_dead := false
var is_receiving_damage := false
# Tiempo ajustado a 1.5s para asegurar que la animación de muerte se vea completa
const TIEMPO_ANIMACION_MUERTE := 1.5 
const TIEMPO_ANIMACION_HIT := 0.25

# --- Movimiento y Patrullaje ---
const SPEED: float = 50.0 
const GRAVITY: float = 1200.0 
var direction: int = 1 # 1 = derecha, -1 = izquierda

# Variables de Patrullaje sin nodo Timer:
const PATROL_DURATION: float = 3.0 # El hongo cambia de dirección cada 3.0 segundos
var patrol_time_counter: float = 0.0 # Contador para rastrear el tiempo de patrullaje

# =========================================================
# II. FUNCIÓN DE INICIO
# =========================================================

func _ready():
	is_dead = false
	is_receiving_damage = false
	set_physics_process(true) 
	anim_sprite.play("idle") # Inicia con animación "idle"
	patrol_time_counter = 0.0

# =========================================================
# III. PROCESO FÍSICO (Movimiento, Espejo y Patrullaje)
# =========================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# === LÓGICA DE PATRULLAJE BASADA EN TIEMPO ===
	patrol_time_counter += delta
	
	if patrol_time_counter >= PATROL_DURATION:
		direction *= -1 # Invierte la dirección (el "recorrido leve")
		patrol_time_counter = 0.0 # Reinicia el contador

	# 1. Aplicar Gravedad
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	# 2. Movimiento Horizontal
	velocity.x = direction * SPEED
	
	# 3. Orientar el Sprite (CORRECCIÓN DEL EFECTO ESPEJO)
	# Se voltea el sprite (flip_h = true) cuando la dirección es a la derecha (1)
	anim_sprite.flip_h = (direction == 1) 
	
	# 4. Mover y Deslizar
	move_and_slide()
	
	# 5. Animación
	if not is_receiving_damage:
		if is_on_floor():
			if velocity.x != 0:
				anim_sprite.play("walk") # Movimiento horizontal
			else:
				anim_sprite.play("idle") # Quieto


# =========================================================
# IV. FUNCIONES DE COMBATE Y ESTADO (die() GARANTIZA TIEMPO)
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
	patrol_time_counter = 0.0 
	
	# 1. Reproducir animación 'hit'
	anim_sprite.play("hit")
	
	# 2. Esperar la duración del golpe
	await get_tree().create_timer(TIEMPO_ANIMACION_HIT).timeout
	
	# 3. Regresar a 'walk'
	is_receiving_damage = false
	anim_sprite.play("walk") 


# --- Función de Muerte ('die') ---
func die() -> void:
	if is_dead:
		return

	is_dead = true
	set_physics_process(false) 
	
	# 1. Reproducir animación 'die'
	anim_sprite.play("die")

	# 2. Esperar el tiempo de la animación antes de desaparecer
	await get_tree().create_timer(TIEMPO_ANIMACION_MUERTE).timeout
	
	# 3. Eliminar el hongo
	queue_free()
