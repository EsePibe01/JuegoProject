# Archivo: AttackHitbox.gd
extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Verificamos si lo que tocamos es un enemigo
	if body.has_method("recibir_danio"):
		
		# 1. Buscamos al "padre" de este hitbox (que es el Player)
		var player = get_parent()
		
		# 2. Le preguntamos cuánto daño tiene cargado actualmente
		# (Si es golpe normal será 1, si es Black Flash será 10)
		var danio_a_aplicar = player.current_damage
		
		# 3. Aplicamos ese daño al enemigo
		body.recibir_danio(danio_a_aplicar)
