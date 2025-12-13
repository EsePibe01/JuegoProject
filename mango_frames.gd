# Archivo: Player.gd
extends CharacterBody2D

# =========================================================
# I. CONSTANTES Y VARIABLES DE ESTADO
# =========================================================

# --- Variables de Muerte y Reinicio ---
var is_dead := false 
const TIEMPO_ESPERA_MUERTE := 1.5 
const MAPA_INICIAL_PATH = "res://MapaNuevo.tscn" 

# --- Constantes de Movimiento ---
const SPEED := 300.0
const JUMP_VELOCITY := -420.0
const JUMP_HOLD_FORCE := -520.0
const MAX_JUMP_HOLD_TIME := 0.35
const GRAVITY := 980.0

# --- Constantes de Dash, AFK, Empuje y Ataque ---
const DASH_DISTANCE := 200.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 3.0
const SHADOW_LIFETIME := 0.3
const SHADOW_INTERVAL := 0.05
const WALK_ANIM_HOLD := 0.1
const AFK_DELAY := 35.0
const PUSH_FORCE_MULTIPLIER := 1200.0
const PUSH_MIN_IMPULSE := 100.0
const ATTACK_DURATION := 0.4 # Duración de la animación "OraOra"

# --- Nodos ---
@onready var anim_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D
@onready var sonido_salto: AudioStreamPlayer2D = $SonidoSalto
@onready var attack_hitbox: Area2D = $AttackHitbox # Nodo Area2D de ataque

# --- Variables de Flujo ---
var is_jumping := false
var jump_hold_time := 0.0
var is_dashing := false
var dash_timer := 0.0
var shadow_timer := 0.0
var dash_cooldown_timer := 0.0
var has_air_dashed := false
var is_attacking := false 
var attack_timer := 0.0    
var walk_timer := 0.0
var idle_time := 0.0
var is_afk := false
var afk_frame := 0
var afk_timer := 0.0

# =========================================================
# II. FUNCIÓN DE INICIO
# =========================================================

func _ready():
	is_dead = false 
	velocity = Vector2.ZERO         
	set_physics_process(true)       
	
	anim_sprite.show() 
	anim_sprite.play("Descansando") 
	
	# Desactiva la hitbox de ataque al inicio
	if is_instance_valid(attack_hitbox) and attack_hitbox.get_child_count() > 0:
		attack_hitbox.get_child(0).disabled = true

# =========================================================
# III. PROCESO FÍSICO
# =========================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 1. MANEJAR EL ATAQUE ACTIVO (KEY P)
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			stop_attack()
		velocity.x = 0
		return 

	# 2. MANEJAR INPUT DE ATAQUE (KEY P/Daño)
	# Usamos is_key_pressed para que detecte la pulsación.
	if Input.is_key_pressed(KEY_P) and not is_dashing and not is_attacking:
		start_attack()
		return 

	# --- Lógica de Movimiento y Dash ---
	
	var input_dir := 0
	if Input.is_key_pressed(KEY_A):
		input_dir -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir += 1

	# Lógica de input y actividad
	if input_dir != 0:
		anim_sprite.flip_h = input_dir < 0
		walk_timer = WALK_ANIM_HOLD
		is_afk = false
		idle_time = 0.0

	# Movimiento, Dash y Gravedad
	if not is_dashing:
		velocity.x = input_dir * SPEED
	
		if not is_on_floor():
			velocity.y += GRAVITY * delta
	
	# Salto inicial (W)
	if Input.is_key_pressed(KEY_W) and is_on_floor() and not is_dashing:
		velocity.y = JUMP_VELOCITY
		sonido_salto.play()
		is_jumping = true
		jump_hold_time = 0.0
		has_air_dashed = false
		idle_time = 0.0

	# Salto variable (Hold)
	if is_jumping:
		if Input.is_key_pressed(KEY_W) and jump_hold_time < MAX_JUMP_HOLD_TIME:
			velocity.y += JUMP_HOLD_FORCE * delta
			jump_hold_time += delta
		else:
			is_jumping = false

	# Salto corto (Release)
	if not Input.is_key_pressed(KEY_W) and velocity.y < 0:
		is_jumping = false
		velocity.y *= 0.5

	# Cooldown dash
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Dash aéreo (KEY J)
	if Input.is_key_pressed(KEY_J) and not is_dashing and dash_cooldown_timer <= 0 and not has_air_dashed and not is_on_floor():
		start_dash(input_dir)

	# Actualizar dash
	if is_dashing:
		dash_timer -= delta
		shadow_timer -= delta
		if shadow_timer <= 0:
			spawn_shadow()
			shadow_timer = SHADOW_INTERVAL
		if dash_timer <= 0:
			stop_dash()

	# Mueve y Colisiona
	move_and_slide()

	# LÓGICA DE EMPUJE DE RIGIDBODY2D
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is RigidBody2D:
			var push_direction = -collision.get_normal()
			var push_force = push_direction * velocity.length() * PUSH_FORCE_MULTIPLIER
			var final_impulse = push_force.limit_length(PUSH_MIN_IMPULSE)
			collider.apply_central_impulse(final_impulse * delta)
	
	# Animaciones
	if not is_on_floor():
		_play_anim("Salto")
	elif walk_timer > 0 and input_dir != 0:
		_play_anim("Caminando")
		walk_timer -= delta
	elif idle_time >= AFK_DELAY:
		_play_afk(delta)
	else:
		_play_anim("Descansando")

	# Inactividad
	if input_dir == 0 and is_on_floor() and not is_dashing:
		idle_time += delta
	else:
		idle_time = 0.0

# =========================================================
# IV. FUNCIONES AUXILIARES
# =========================================================

# --- Funciones de Ataque (KEY P) ---
func start_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_DURATION
	velocity.x = 0
	
	# 🛑 ACTIVA LA CAJA DE DAÑO 🛑
	if is_instance_valid(attack_hitbox) and attack_hitbox.get_child_count() > 0:
		attack_hitbox.get_child(0).disabled = false 
	
	_play_anim("OraOra") 
	
func stop_attack() -> void:
	is_attacking = false
	
	# 🛑 DESACTIVA LA CAJA DE DAÑO 🛑
	if is_instance_valid(attack_hitbox) and attack_hitbox.get_child_count() > 0:
		attack_hitbox.get_child(0).disabled = true
	
# --- Resto de Funciones Auxiliares ---
func _play_anim(anim_name: String) -> void:
	if anim_sprite.animation != anim_name:
		anim_sprite.play(anim_name)

func _play_afk(delta: float) -> void:
	if anim_sprite.animation != "afk":
		anim_sprite.animation = "afk"
		afk_frame = 0
		anim_sprite.frame = afk_frame
		is_afk = true
		afk_timer = 0.0

	if is_afk:
		afk_timer += delta
		if afk_timer >= 0.2:
			afk_timer = 0.0
			afk_frame += 1
			if afk_frame > 6:
				afk_frame = 3
			anim_sprite.frame = afk_frame

func start_dash(input_dir: int) -> void:
	is_dashing = true
	dash_timer = DASH_TIME
	shadow_timer = 0.0
	dash_cooldown_timer = DASH_COOLDOWN
	has_air_dashed = true

	var dir := input_dir
	if dir == 0:
		dir = -1 if anim_sprite.flip_h else 1

	velocity.x = dir * (DASH_DISTANCE / DASH_TIME)
	velocity.y = 0

func stop_dash() -> void:
	is_dashing = false
	velocity.x = 0

func spawn_shadow() -> void:
	var s := Sprite2D.new()
	s.texture = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
	s.position = anim_sprite.global_position
	s.scale = anim_sprite.scale
	s.flip_h = anim_sprite.flip_h
	s.modulate = Color(1, 1, 1, randf_range(0.3, 0.5))
	s.scale *= randf_range(0.95, 1.05)
	get_parent().add_child(s)

	var t = create_tween()
	t.tween_property(s, "modulate:a", 0.0, SHADOW_LIFETIME)
	t.tween_callback(Callable(s, "queue_free"))
	t.play()

# =========================================================
# V. LÓGICA DE MUERTE
# =========================================================

func die() -> void:
	if is_dead:
		return
		
	is_dead = true
	velocity = Vector2.ZERO 
	set_physics_process(false) 
	
	anim_sprite.play("fallecimiento")
	await get_tree().create_timer(TIEMPO_ESPERA_MUERTE).timeout
	queue_free()
	
	var error = get_tree().change_scene_to_file(MAPA_INICIAL_PATH)
	if error != OK:
		push_error("Error al cargar la escena de reinicio: " + MAPA_INICIAL_PATH)
