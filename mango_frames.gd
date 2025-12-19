extends CharacterBody2D

# =========================================================
# I. CONFIGURACIÓN Y NODOS
# =========================================================

# --- Variables de Muerte y Estado ---
var is_dead := false 
const TIEMPO_ESPERA_MUERTE := 2.0 
const MAPA_INICIAL_PATH = "res://MapaNuevo.tscn" 

# --- Constantes de Movimiento ---
const SPEED := 300.0
const JUMP_VELOCITY := -420.0
const JUMP_HOLD_FORCE := -520.0
const MAX_JUMP_HOLD_TIME := 0.35
const GRAVITY := 980.0

# --- CONSTANTES DE VIDA ---
const DEATH_JUMP_FORCE := -500.0 
const MAX_HEALTH := 5 
var current_health := 5
var is_taking_damage := false 

# --- Ataque y Black Flash ---
const ATTACK_DURATION := 0.4 
const ATTACK_MOVEMENT_SPEED := 0.8 
const GHOST_INTERVAL := 0.03 
const EPIC_HIT_COOLDOWN := 7.0 
const CRIT_CHANCE := 0.05 
const IMPACT_FRAME_DURATION := 0.05 
const HITSTOP_DURATION := 0.15 
const DAMAGE_NORMAL := 1
const DAMAGE_BLACK_FLASH := 10 

# --- Nodos ---
@onready var anim_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D
@onready var sonido_salto: AudioStreamPlayer2D = $SonidoSalto
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var camera: Camera2D = $Camera2D2
@onready var sonido_black_flash: AudioStreamPlayer2D = $SonidoBlackFlash 
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar
@onready var dash_label: Label = $DashLabel

# --- Variables Visuales ---
var black_flash_rect: ColorRect
var black_flash_label: Label  # La etiqueta del texto
var lightning_gradient: Gradient
var heal_gradient: Gradient 

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
var is_current_attack_crit := false 
var is_current_attack_epic := false 
var epic_hit_timer := 0.0 
var shake_strength: float = 0.0 
const SHAKE_DECAY_RATE: float = 5.0 

var current_damage: int = 1

# --- CONFIGURACIÓN DEL DASH ---
const DASH_DISTANCE := 250.0
const DASH_TIME := 0.2        
const DASH_COOLDOWN := 3.0    
const SHADOW_LIFETIME := 0.3
const SHADOW_INTERVAL := 0.05
const WALK_ANIM_HOLD := 0.1
const AFK_DELAY := 35.0
const PUSH_FORCE_MULTIPLIER := 1200.0
const PUSH_MIN_IMPULSE := 100.0

# =========================================================
# II. INICIO
# =========================================================

func _ready():
	is_dead = false 
	is_taking_damage = false
	current_health = MAX_HEALTH 
	velocity = Vector2.ZERO          
	set_physics_process(true)        
	
	anim_sprite.show() 
	anim_sprite.play("Descansando") 
	collision_layer = 1; collision_mask = 1
	
	if is_instance_valid(attack_hitbox) and attack_hitbox.get_child_count() > 0:
		attack_hitbox.get_child(0).disabled = true
	
	if health_bar:
		health_bar.max_value = MAX_HEALTH
		health_bar.value = current_health

	if dash_label:
		dash_label.text = "" 
		dash_label.modulate.a = 0.0 

	_setup_impact_frame_nodes()
	_setup_lightning_gradient()
	_setup_heal_gradient() 
	epic_hit_timer = 0.0 

# =========================================================
# III. PHYSICS PROCESS
# =========================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += GRAVITY * delta
		move_and_slide()
		return 

	if shake_strength > 0 and camera:
		shake_strength = lerp(shake_strength, 0.0, SHAKE_DECAY_RATE * delta)
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		if shake_strength < 1.0: shake_strength = 0.0; camera.offset = Vector2.ZERO

	if epic_hit_timer > 0: epic_hit_timer -= delta

	# --- UI DASH ---
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		if dash_label:
			dash_label.text = "%.1f" % dash_cooldown_timer
			dash_label.modulate = Color(1, 1, 0, 1)
			dash_label.modulate.a = 1.0
		if dash_cooldown_timer <= 0:
			dash_cooldown_timer = 0
			if dash_label:
				dash_label.text = "Dash Listo"
				dash_label.modulate = Color(0, 1, 0, 1)
				var t = create_tween()
				t.tween_property(dash_label, "modulate:a", 0.0, 1.0).set_delay(0.5)

	# --- DAÑO ---
	if is_taking_damage:
		velocity.x = 0 
		if not is_on_floor(): velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# --- ATAQUE ---
	if is_attacking:
		attack_timer -= delta
		if not is_current_attack_crit and is_current_attack_epic:
			shadow_timer -= delta
			if shadow_timer <= 0: spawn_attack_ghost(); shadow_timer = GHOST_INTERVAL
		if attack_timer <= 0: stop_attack()

	if Input.is_key_pressed(KEY_P) and not is_dashing and not is_attacking:
		start_attack()

	# --- MOVIMIENTO ---
	var input_dir := 0
	if Input.is_key_pressed(KEY_A): input_dir -= 1
	if Input.is_key_pressed(KEY_D): input_dir += 1

	if input_dir != 0:
		anim_sprite.flip_h = input_dir < 0 
		walk_timer = WALK_ANIM_HOLD
		is_afk = false; idle_time = 0.0

	# --- CORRECCIÓN HITBOX (POSICIÓN) ---
	var distancia_hitbox = abs(attack_hitbox.position.x)
	if anim_sprite.flip_h:
		attack_hitbox.position.x = -distancia_hitbox
	else:
		attack_hitbox.position.x = distancia_hitbox

	if not is_dashing:
		var target_speed = input_dir * SPEED
		if is_attacking: target_speed *= ATTACK_MOVEMENT_SPEED
		velocity.x = target_speed
		if not is_on_floor(): velocity.y += GRAVITY * delta
	
	# --- SALTO ---
	if Input.is_key_pressed(KEY_W) and is_on_floor() and not is_dashing:
		velocity.y = JUMP_VELOCITY; sonido_salto.play(); is_jumping = true; jump_hold_time = 0.0; has_air_dashed = false; idle_time = 0.0
	if is_jumping:
		if Input.is_key_pressed(KEY_W) and jump_hold_time < MAX_JUMP_HOLD_TIME: velocity.y += JUMP_HOLD_FORCE * delta; jump_hold_time += delta
		else: is_jumping = false
	if not Input.is_key_pressed(KEY_W) and velocity.y < 0: is_jumping = false; velocity.y *= 0.5

	# --- DASH ---
	if Input.is_key_pressed(KEY_J) and not is_dashing and dash_cooldown_timer <= 0 and not has_air_dashed and not is_on_floor():
		start_dash(input_dir)
		
	if is_dashing:
		dash_timer -= delta; shadow_timer -= delta
		if shadow_timer <= 0: spawn_shadow(); shadow_timer = SHADOW_INTERVAL
		if dash_timer <= 0: stop_dash()

	move_and_slide()
	
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_collider() is RigidBody2D:
			collision.get_collider().apply_central_impulse(-collision.get_normal() * velocity.length() * PUSH_FORCE_MULTIPLIER * delta)

	# --- ANIMACIONES ---
	if is_attacking: _play_anim("OraOra") 
	elif is_dashing: pass 
	elif not is_on_floor(): _play_anim("Salto")
	elif walk_timer > 0 and input_dir != 0: _play_anim("Caminando"); walk_timer -= delta
	elif idle_time >= AFK_DELAY: _play_afk(delta)
	else: _play_anim("Descansando")

	if input_dir == 0 and is_on_floor() and not is_dashing and not is_attacking: idle_time += delta
	else: idle_time = 0.0

# =========================================================
# IV. COMBATE Y HABILIDADES
# =========================================================

func start_dash(input_dir: int) -> void:
	is_dashing = true
	dash_timer = DASH_TIME
	shadow_timer = 0.0
	dash_cooldown_timer = DASH_COOLDOWN 
	has_air_dashed = true
	
	if dash_label:
		dash_label.modulate.a = 1.0 
		dash_label.text = "3.0"
	
	var dir := input_dir
	if dir == 0: dir = -1 if anim_sprite.flip_h else 1
	velocity.x = dir * (DASH_DISTANCE / DASH_TIME)
	velocity.y = 0

func stop_dash() -> void:
	is_dashing = false
	velocity.x = 0

func start_attack() -> void:
	is_attacking = true; attack_timer = ATTACK_DURATION; shadow_timer = 0.0; is_current_attack_crit = randf() < CRIT_CHANCE
	if not is_current_attack_crit:
		if epic_hit_timer <= 0: is_current_attack_epic = true; epic_hit_timer = EPIC_HIT_COOLDOWN 
		else: is_current_attack_epic = false
	else: is_current_attack_epic = false 
	if is_current_attack_crit: print("¡BLACK FLASH!"); trigger_black_flash_effect(); current_damage = DAMAGE_BLACK_FLASH 
	else: if is_current_attack_epic: apply_shake(5.0); current_damage = DAMAGE_NORMAL 
	
	if is_instance_valid(attack_hitbox) and attack_hitbox.get_child_count() > 0: 
		attack_hitbox.get_child(0).disabled = false 
	_play_anim("OraOra") 

func stop_attack() -> void:
	is_attacking = false; is_current_attack_crit = false; is_current_attack_epic = false
	if is_instance_valid(attack_hitbox) and attack_hitbox.get_child_count() > 0: 
		attack_hitbox.get_child(0).disabled = true

func apply_shake(strength: float) -> void: shake_strength = strength

func recibir_danio(cantidad: int) -> void:
	if is_dead: return 
	current_health -= cantidad; print("Jugador herido! Vida: ", current_health)
	if health_bar: health_bar.value = current_health
	if current_health <= 0: die()
	else: _play_hit_reaction()

func curar_vida(cantidad: int) -> void:
	if is_dead: return
	if current_health < MAX_HEALTH: _spawn_heal_particles(); print("Jugador curado! +", cantidad)
	current_health += cantidad
	if current_health > MAX_HEALTH: current_health = MAX_HEALTH
	if health_bar: health_bar.value = current_health

func _play_hit_reaction() -> void:
	is_taking_damage = true; is_attacking = false; _play_anim("hit"); apply_shake(10.0) 
	await get_tree().create_timer(0.3).timeout; is_taking_damage = false

func die() -> void:
	if is_dead: return
	is_dead = true; velocity.y = DEATH_JUMP_FORCE; velocity.x = 0 
	collision_layer = 0; collision_mask = 0
	anim_sprite.play("fallecimiento")
	await get_tree().create_timer(TIEMPO_ESPERA_MUERTE).timeout
	queue_free(); get_tree().change_scene_to_file(MAPA_INICIAL_PATH)

func _setup_heal_gradient() -> void:
	heal_gradient = Gradient.new(); heal_gradient.set_color(0, Color(0.2, 1.0, 0.2, 1.0)); heal_gradient.set_color(1, Color(0.2, 1.0, 0.2, 0.0))

func _spawn_heal_particles() -> void:
	var particles = CPUParticles2D.new(); particles.emitting = false; particles.one_shot = true; particles.amount = 15; particles.lifetime = 1.0; particles.explosiveness = 0.8; particles.direction = Vector2(0, -1); particles.spread = 45.0; particles.gravity = Vector2(0, -50); particles.initial_velocity_min = 50; particles.initial_velocity_max = 100; particles.scale_amount_min = 3.0; particles.scale_amount_max = 5.0; particles.color_ramp = heal_gradient; particles.z_index = 20; add_child(particles); particles.emitting = true; await get_tree().create_timer(1.2).timeout; particles.queue_free()

func trigger_black_flash_effect() -> void:
	var offset_x = 45 if not anim_sprite.flip_h else -45; var impact_pos_global = anim_sprite.global_position + Vector2(offset_x, 0)
	
	if sonido_black_flash: sonido_black_flash.play()
	
	_create_impact_particles(impact_pos_global)
	spawn_black_flash_lightning(impact_pos_global)
	
	# --- ANIMACIÓN DEL TEXTO BLACK FLASH ---
	if black_flash_rect: black_flash_rect.visible = true
	if black_flash_label:
		black_flash_label.visible = true
		var text_tween = create_tween()
		text_tween.set_loops(6) # Parpadear 6 veces rápido
		text_tween.tween_property(black_flash_label, "modulate", Color(0.8, 0, 0), 0.04) # Rojo Sangre
		text_tween.tween_property(black_flash_label, "modulate", Color.BLACK, 0.04) # Negro Puro
		
		text_tween.finished.connect(func(): black_flash_label.visible = false)
	# ---------------------------------------

	await get_tree().create_timer(0.02, true, false, true).timeout
	apply_shake(25.0)
	var previous_time_scale = Engine.time_scale
	Engine.time_scale = 0.01
	await get_tree().create_timer(HITSTOP_DURATION, true, false, true).timeout
	Engine.time_scale = previous_time_scale
	if black_flash_rect: black_flash_rect.visible = false
	await get_tree().create_timer(0.2).timeout
	if camera: camera.offset = Vector2.ZERO 

func spawn_black_flash_lightning(impact_pos: Vector2) -> void:
	for i in range(25): var lightning = Line2D.new(); lightning.width = randf_range(2.0, 12.0); lightning.gradient = lightning_gradient; var start_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20)); var start_pos = impact_pos + start_offset; var angle = randf_range(0, TAU); var outward_vector = Vector2(randf_range(60, 150), 0).rotated(angle); var end_pos = start_pos + outward_vector; var mid_pos = start_pos.lerp(end_pos, randf_range(0.3, 0.7)) + Vector2(randf_range(-40, 40), randf_range(-40, 40)); lightning.add_point(start_pos); lightning.add_point(mid_pos); lightning.add_point(end_pos); lightning.z_index = 20; get_parent().add_child(lightning); var t = create_tween(); t.tween_property(lightning, "width", 0.0, 0.15).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN); t.tween_callback(Callable(lightning, "queue_free"))

func _create_impact_particles(pos: Vector2) -> void:
	var particles = CPUParticles2D.new(); particles.emitting = false; particles.one_shot = true; particles.amount = 30; particles.lifetime = 0.4; particles.explosiveness = 1.0; particles.direction = Vector2(0, -1); particles.spread = 180.0; particles.gravity = Vector2(0, 0); particles.initial_velocity_min = 100; particles.initial_velocity_max = 250; particles.scale_amount_min = 3.0; particles.scale_amount_max = 6.0; particles.z_index = 21; var color_ramp = Gradient.new(); color_ramp.set_color(0, Color(1.5, 0.1, 0.1, 1.0)); color_ramp.set_color(1, Color(0, 0, 0, 0)); particles.color_ramp = color_ramp; get_parent().add_child(particles); particles.global_position = pos; particles.restart(); await get_tree().create_timer(particles.lifetime + 0.1).timeout; if is_instance_valid(particles): particles.queue_free()

func spawn_attack_ghost() -> void:
	var s := Sprite2D.new(); s.texture = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame); s.position = anim_sprite.global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5)); s.scale = anim_sprite.scale * 1.1; s.flip_h = anim_sprite.flip_h; s.modulate = Color(0.6, 0.3, 0.9, 0.5); s.z_index = -1; get_parent().add_child(s); var t = create_tween(); t.tween_property(s, "modulate:a", 0.0, 0.2); t.tween_callback(Callable(s, "queue_free")); t.play()

func _play_anim(anim_name: String) -> void: if anim_sprite.animation != anim_name: anim_sprite.play(anim_name)
func _play_afk(delta: float) -> void: if anim_sprite.animation != "afk": anim_sprite.animation = "afk"; afk_frame = 0; anim_sprite.frame = afk_frame; is_afk = true; afk_timer = 0.0; if is_afk: afk_timer += delta; if afk_timer >= 0.2: afk_timer = 0.0; afk_frame += 1; if afk_frame > 6: afk_frame = 3; anim_sprite.frame = afk_frame
func spawn_shadow() -> void: var s := Sprite2D.new(); s.texture = anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame); s.position = anim_sprite.global_position; s.scale = anim_sprite.scale * randf_range(0.95, 1.05); s.flip_h = anim_sprite.flip_h; s.modulate = Color(1, 1, 1, randf_range(0.3, 0.5)); get_parent().add_child(s); var t = create_tween(); t.tween_property(s, "modulate:a", 0.0, SHADOW_LIFETIME); t.tween_callback(Callable(s, "queue_free")); t.play()

func _setup_impact_frame_nodes() -> void:
	# --- FONDO NEGRO (PANTALLA COMPLETA) ---
	var canvas_layer = CanvasLayer.new(); canvas_layer.layer = 100; canvas_layer.name = "ImpactFrameCanvas"; add_child(canvas_layer); 
	black_flash_rect = ColorRect.new(); 
	black_flash_rect.color = Color.BLACK; 
	black_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT); 
	black_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; 
	black_flash_rect.visible = false; 
	canvas_layer.add_child(black_flash_rect)

	# --- 🔥 TEXTO BLACK FLASH (PEQUEÑO Y CERCA DEL GATO) 🔥 ---
	black_flash_label = Label.new()
	black_flash_label.text = "BLACK FLASH"
	black_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	black_flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# TAMAÑO MÁS PEQUEÑO (Antes 80)
	black_flash_label.add_theme_font_size_override("font_size", 36) 
	black_flash_label.add_theme_color_override("font_outline_color", Color.WHITE)
	black_flash_label.add_theme_constant_override("outline_size", 4)
	
	black_flash_label.visible = false
	black_flash_label.z_index = 110 # Que se vea encima de todo
	
	# AHORA ES HIJO DEL GATO, SE MOVERÁ CON ÉL
	add_child(black_flash_label)
	
	# POSICIÓN RELATIVA: Arriba de la cabeza. Ajusta el -100 si está muy arriba o abajo.
	black_flash_label.position = Vector2(-100, -100) 
	black_flash_label.size = Vector2(200, 50) # Un rectángulo ancho para centrar el texto

func _setup_lightning_gradient() -> void:
	lightning_gradient = Gradient.new(); lightning_gradient.set_color(0, Color(2.0, 0.1, 0.1, 1.0)); lightning_gradient.set_color(1, Color.BLACK)
