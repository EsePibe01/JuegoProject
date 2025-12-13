# Archivo: AttackHitbox.gd
extends Area2D

const DANO_DE_JUGADOR := 1 

# ⚠️ Esta función debe estar conectada a la señal 'body_entered' del Area2D.
func _on_body_entered(body: Node2D) -> void:
	# Chequea si el cuerpo golpeado tiene la función para recibir daño (Hongo)
	if body.has_method("recibir_danio"):
		# Llama a la función de daño del enemigo
		body.recibir_danio(DANO_DE_JUGADOR)
