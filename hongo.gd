extends CharacterBody2D 

# Ruta a tu escena de número de daño
const DAMAGE_POPUP_SCENE = preload("res://floating_damage.tscn")

# --- Nodos ---
@onready var anim_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D 
@onready var barra_vida: ProgressBar = $BarraVida 
@onready var raycast_ataque: RayCast2D = $RayCastAtaque

# --- Variables ---
var vida_actual: int = 3
const MAX_VIDA: int = 3
var is_dead := false
var is_receiving_damage := false
var is_attacking := false 
var is_stunned := false 

# --- Configuración ---
const DAÑO_ATAQUE := 1
const CHANCE_DE_STUN := 0.5 
const TIEMPO_STUN := 2.0 
const SPEED: float = 50.0 
const GRAVITY: float = 1200.0 
var direction: int = 1 
const PATROL_DURATION: float = 3.0 
var patrol_time_counter: float = 0.0 

func _ready():
	is_dead = false; is_receiving_damage = false; is_attacking = false; is_stunned = false
	set_physics_process(true); anim_sprite.play("idle"); patrol_time_counter = 0.0
	
	if barra_vida: 
		barra_vida.max_value = MAX_VIDA; barra_vida.value = vida_actual; barra_vida.visible = true 
	
	# Evitar que el rayo choque con el propio hongo
	if raycast_ataque: 
		raycast_ataque.add_exception(self)
		raycast_ataque.enabled = true

func _physics_process(delta: float) -> void:
	if is_dead: return 
	if not is_on_floor(): velocity.y += GRAVITY * delta
	else: velocity.y = 0
	
	# Si está ocupado (atacando/stun/herido), no se mueve
	if is_attacking or is_stunned or is_receiving_damage: 
		velocity.x = 0; move_and_slide(); return 

	# Detectar jugador
	if raycast_ataque.is_colliding():
		var collider = raycast_ataque.get_collider()
		if collider.has_method("recibir_danio"): 
			start_attack(collider)
			return 

	# Patrullaje
	patrol_time_counter += delta
	if patrol_time_counter >= PATROL_DURATION: change_direction()

	velocity.x = direction * SPEED
	anim_sprite.flip_h = (direction == 1) 
	move_and_slide()
	
	if is_on_floor():
		if velocity.x != 0: anim_sprite.play("walk")
		else: anim_sprite.play("idle")

func change_direction():
	direction *= -1; patrol_time_counter = 0.0
	# Voltear el raycast es clave para que ataque al lado correcto
	raycast_ataque.target_position.x *= -1

func start_attack(_target) -> void:
	if is_attacking or is_stunned: return
	is_attacking = true
	anim_sprite.play("attack")
	
	# Esperar a que termine la animación del golpe
	await anim_sprite.animation_finished
	
	# Verificar si sigue colisionando para hacer daño
	if raycast_ataque.is_colliding():
		var cuerpo = raycast_ataque.get_collider()
		if cuerpo.has_method("recibir_danio"): 
			cuerpo.recibir_danio(DAÑO_ATAQUE)
	
	# Calcular si se marea (50%)
	if randf() < CHANCE_DE_STUN: 
		enter_stun_state()
	else: 
		is_attacking = false; anim_sprite.play("idle")

func enter_stun_state() -> void:
	print("El hongo se mareó!")
	is_stunned = true; is_attacking = false
	anim_sprite.play("attack_stun")
	await get_tree().create_timer(TIEMPO_STUN).timeout
	if not is_dead: is_stunned = false; anim_sprite.play("idle")

func recibir_danio(cantidad_danio: int) -> void:
	if is_dead: return
	spawn_damage_number(cantidad_danio)
	vida_actual -= cantidad_danio
	if barra_vida: barra_vida.value = vida_actual
	
	# Interrumpir ataque si le pegan
	is_attacking = false; is_stunned = false
	
	if vida_actual <= 0: die()
	else: if not is_receiving_damage: hit_received()

func hit_received() -> void:
	is_receiving_damage = true; patrol_time_counter = 0.0; anim_sprite.play("hit")
	await get_tree().create_timer(0.25).timeout
	if is_dead: return
	is_receiving_damage = false

func die() -> void:
	if is_dead: return
	
	# 🔥 Curar al jugador (Grupo 'player') al morir 🔥
	get_tree().call_group("player", "curar_vida", 1)
	
	is_dead = true; set_physics_process(false); velocity = Vector2.ZERO
	if barra_vida: barra_vida.visible = false 
	anim_sprite.play("die")
	await get_tree().create_timer(1.5).timeout
	queue_free()

func spawn_damage_number(valor: int) -> void:
	var popup = DAMAGE_POPUP_SCENE.instantiate()
	popup.setup(valor)
	popup.global_position = global_position + Vector2(0, -30)
	get_tree().current_scene.add_child(popup)
