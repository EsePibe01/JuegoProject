extends AnimatableBody2D

@export var velocidad : float = 50.0      # qué tan rápido se mueve
@export var distancia : float = 100.0     # hasta dónde sube o baja

var direccion : int = 1
var posicion_inicial : Vector2

func _ready():
	posicion_inicial = position

func _physics_process(delta):
	# mover en Y
	position.y += direccion * velocidad * delta
	
	# si bajó más de la distancia, cambia de dirección
	if position.y > posicion_inicial.y + distancia:
		direccion = -1
	# si subió más de la distancia, cambia de dirección
	elif position.y < posicion_inicial.y - distancia:
		direccion = 1
