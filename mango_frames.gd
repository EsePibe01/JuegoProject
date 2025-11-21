extends CharacterBody2D

# --- Constantes de Movimiento ---
const SPEED := 300.0
const JUMP_VELOCITY := -420.0
const JUMP_HOLD_FORCE := -520.0
const MAX_JUMP_HOLD_TIME := 0.35
const GRAVITY := 980.0

# --- Constantes de Dash ---
const DASH_DISTANCE := 200.0
const DASH_TIME := 0.15
const DASH_COOLDOWN := 3.0
const SHADOW_LIFETIME := 0.3
const SHADOW_INTERVAL := 0.05

# --- Constantes de Animación/AFK ---
const WALK_ANIM_HOLD := 0.1
const AFK_DELAY := 35.0

# 💥 CONSTANTES DE EMPUJE (Ajusta estos valores para cambiar la sensación) 💥
const PUSH_FORCE_MULTIPLIER := 1200.0 
const PUSH_MIN_IMPULSE := 100.0

# --- Nodos ---
@onready var anim_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D
@onready var sonido_salto: AudioStreamPlayer2D = $SonidoSalto

# --- Variables ---
var is_jumping := false
var jump_hold_time := 0.0
var is_dashing := false
var dash_timer := 0.0
var shadow_timer := 0.0
var dash_cooldown_timer := 0.0
var has_air_dashed := false

var walk_timer := 0.0
var idle_time := 0.0
var is_afk := false
var afk_frame := 0
var afk_timer := 0.0

func _physics_process(delta: float) -> void:
	var input_dir := 0
	if Input.is_key_pressed(KEY_A):
		input_dir -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir += 1

	# Flip del sprite y detección de actividad
	if input_dir != 0:
		anim_sprite.flip_h = input_dir < 0
		walk_timer = WALK_ANIM_HOLD
		is_afk = false
		idle_time = 0.0

	# Movimiento normal
	if not is_dashing:
		velocity.x = input_dir * SPEED

	# Salto inicial
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

	# Gravedad
	if not is_on_floor() and not is_dashing:
		velocity.y += GRAVITY * delta

	# Cooldown dash
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Dash aéreo
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

	# 📦 Mueve y Colisiona
	move_and_slide()

	# ----------------------------------------------------
	# 💥 LÓGICA DE EMPUJE DE RIGIDBODY2D (Corregida para Godot 4) 💥
	# ----------------------------------------------------
	
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider is RigidBody2D:
			# 1. Dirección de empuje (opuesta a la normal)
			var push_direction = -collision.get_normal()
			
			# 2. Fuerza proporcional a la velocidad del CharacterBody2D
			var push_force = push_direction * velocity.length() * PUSH_FORCE_MULTIPLIER
			
			# 3. Limitar la fuerza para asegurar un mínimo (usando limit_length en Godot 4)
			var final_impulse = push_force.limit_length(PUSH_MIN_IMPULSE)
			
			# 4. Aplicar el impulso
			collider.apply_central_impulse(final_impulse * delta)
			
	# ----------------------------------------------------
	
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

# --- Funciones de Animaciones ---
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

# --- Funciones de Dash ---
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

# --- Sombra del dash / afterimage ---
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
