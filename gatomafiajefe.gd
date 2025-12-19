extends CharacterBody2D

# =========================================================
# I. CONFIGURACIÓN
# =========================================================

const BULLET_SCENE = preload("res://bala_jefe.tscn") 
const DAMAGE_POPUP_SCENE = preload("res://floating_damage.tscn")

# --- Nodos ---
@onready var anim: AnimatedSprite2D = $Node2D/AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var area_melee: Area2D = $AreaMelee
@onready var barra_vida: ProgressBar = $BarraVida
@onready var player = get_tree().get_first_node_in_group("player") 

# --- ESTADÍSTICAS ---
const MAX_HP = 50      # <--- AJUSTE: Vida bajada a 50
var hp = 50
const SPEED = 100.0
const GRAVITY = 980.0

# --- IA de Combate ---
const DISTANCIA_DISPARO = 500.0 
const DISTANCIA_MELEE = 120.0   # <--- AJUSTE: Aumentado (antes 90) para que detecte mejor
const MAX_AMMO = 15             
var current_ammo = 15
var damage_melee = 2            

# --- Estados ---
var is_dead = false
var is_busy = false 

# =========================================================
# II. LÓGICA
# =========================================================

func _ready():
	hp = MAX_HP
	current_ammo = MAX_AMMO
	
	if barra_vida:
		barra_vida.max_value = MAX_HP
		barra_vida.value = hp
		barra_vida.visible = true 
	
	anim.play("idle")
	
	if not player:
		push_warning("⚠️ El Jefe no encuentra al jugador 'player'.")

func _physics_process(delta):
	if is_dead: return
	
	if not is_on_floor(): velocity.y += GRAVITY * delta
	
	if is_busy:
		velocity.x = 0
		move_and_slide()
		return

	if not player: 
		anim.play("idle")
		return

	var distancia = global_position.distance_to(player.global_position)
	var direccion_x = sign(player.global_position.x - global_position.x)

	# 1. Mirar al jugador
	if direccion_x != 0:
		if direccion_x > 0: transform.x.x = 1 
		else: transform.x.x = -1

	# 2. DECISIONES
	if distancia < DISTANCIA_MELEE:
		# Si estás cerca (menos de 120px), te golpea
		estado_melee()
		
	elif distancia < DISTANCIA_DISPARO:
		# Si estás lejos pero en rango, dispara
		if current_ammo > 0:
			estado_disparar()
		else:
			estado_recargar()
			
	else:
		# Si estás muy lejos, persigue
		velocity.x = direccion_x * SPEED
		anim.play("move")
	
	move_and_slide()

# =========================================================
# III. ESTADOS DE ATAQUE
# =========================================================

func estado_disparar():
	is_busy = true
	anim.play("shoot")
	await get_tree().create_timer(0.1).timeout 
	
	if not is_dead:
		spawn_bullet()
		current_ammo -= 1
	
	await anim.animation_finished
	is_busy = false
	await get_tree().create_timer(0.15).timeout

func estado_recargar():
	is_busy = true
	
	if anim.sprite_frames.has_animation("noammo"):
		anim.play("noammo")
		await anim.animation_finished
	
	if anim.sprite_frames.has_animation("idle_noammo"):
		anim.play("idle_noammo")
		await get_tree().create_timer(1.0).timeout 
	
	anim.play("reload")
	await anim.animation_finished
	
	current_ammo = MAX_AMMO
	is_busy = false

func estado_melee():
	is_busy = true
	anim.play("mele")
	
	# Esperar al frame del golpe
	await get_tree().create_timer(0.3).timeout 
	
	if area_melee:
		var cuerpos = area_melee.get_overlapping_bodies()
		for cuerpo in cuerpos:
			if cuerpo.is_in_group("player") and cuerpo.has_method("recibir_danio"):
				cuerpo.recibir_danio(damage_melee)
	
	await anim.animation_finished
	is_busy = false
	await get_tree().create_timer(0.8).timeout

func spawn_bullet():
	var bullet = BULLET_SCENE.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = transform.x.x 
	get_parent().add_child(bullet)

# =========================================================
# IV. DAÑO Y MUERTE (IMPORTANTE PARA QUE EL JUGADOR LE PEGUE)
# =========================================================

func recibir_danio(cantidad: int):
	if is_dead: return
	
	# Bajar vida
	hp -= cantidad
	if barra_vida: barra_vida.value = hp
	
	# Numerito flotante
	spawn_damage_number(cantidad)
	
	# Morir si hp <= 0
	if hp <= 0:
		die()
	else:
		# Animación de herido (hurt)
		if not anim.animation in ["reload", "noammo", "mele"]:
			var prev_state = is_busy
			is_busy = true
			anim.play("hurt")
			await get_tree().create_timer(0.2).timeout
			if not is_dead:
				is_busy = prev_state
				if not is_busy: anim.play("idle")

func die():
	is_dead = true
	is_busy = true
	velocity = Vector2.ZERO
	if barra_vida: barra_vida.visible = false
	
	if anim.sprite_frames.has_animation("die"):
		anim.play("die")
		await anim.animation_finished
	else:
		anim.play("hurt")
		await get_tree().create_timer(0.5).timeout
	
	# Curar al jugador y borrar al jefe
	get_tree().call_group("player", "curar_vida", 5)
	queue_free()

func spawn_damage_number(valor: int) -> void:
	# Asegúrate de que la escena floating_damage.tscn existe, si no, borra estas líneas
	if DAMAGE_POPUP_SCENE:
		var popup = DAMAGE_POPUP_SCENE.instantiate()
		popup.setup(valor)
		popup.global_position = global_position + Vector2(0, -60)
		get_tree().current_scene.add_child(popup)
