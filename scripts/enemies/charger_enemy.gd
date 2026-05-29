extends BaseEnemy

enum State { CHASE, CHARGE, STUNNED, COOLDOWN }

var state: State = State.CHASE
var charge_direction: Vector2 = Vector2.ZERO
var charge_distance: float = 0.0
var max_charge_distance: float = 500.0
var charge_speed_mult: float = 3.0
var charge_damage_mult: float = 1.5
var charge_trigger_dist: float = 300.0
var stun_duration: float = 1.5
var post_charge_cooldown: float = 4.0
var state_timer: float = 0.0
var facing_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	super._ready()
	body_sprite.rotation = facing_direction.angle() - PI / 2.0

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	if guard_idle:
		velocity = Vector2.ZERO
		return
	
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player") as Player
	
	if not player_ref or not player_ref.alive:
		return
	
	if state_timer > 0:
		state_timer -= delta
	
	if attack_timer > 0:
		attack_timer -= delta
	
	body_sprite.rotation = facing_direction.angle() - PI / 2.0
	_update_state_visual()
	
	match state:
		State.CHASE:
			_chase_behavior(delta)
		State.CHARGE:
			_charge_behavior(delta)
		State.STUNNED:
			_stunned_behavior()
		State.COOLDOWN:
			_cooldown_behavior(delta)


func _chase_behavior(delta: float) -> void:
	var direction = (player_ref.global_position - global_position).normalized()
	facing_direction = direction
	var dist = global_position.distance_to(player_ref.global_position)
	var contact_dist = size + 18.0
	
	if dist > contact_dist + 5.0:
		velocity = direction * current_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	dist = global_position.distance_to(player_ref.global_position)
	if dist <= contact_dist + 5.0 and attack_timer <= 0:
		player_ref.take_damage(current_damage)
		attack_timer = attack_cooldown
	
	# Trigger charge when in range but not point-blank
	if dist <= charge_trigger_dist and dist > contact_dist + 10.0:
		_start_charge(direction)


func _start_charge(dir: Vector2) -> void:
	state = State.CHARGE
	charge_direction = dir
	charge_distance = 0.0


func _charge_behavior(delta: float) -> void:
	var move_step = current_speed * charge_speed_mult * delta
	charge_distance += move_step
	
	velocity = charge_direction * current_speed * charge_speed_mult
	move_and_slide()
	
	# Hit obstacle → stunned
	if get_last_slide_collision():
		var collider = get_last_slide_collision().get_collider()
		if collider is StaticBody2D:
			_enter_stunned()
			return
	
	# Hit player → high damage + cooldown
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= size + 18.0 + 5.0:
			player_ref.take_damage(int(current_damage * charge_damage_mult))
			_enter_cooldown()
			return
	
	# Ran out of charge distance
	if charge_distance >= max_charge_distance:
		_enter_cooldown()


func _enter_stunned() -> void:
	state = State.STUNNED
	state_timer = stun_duration
	velocity = Vector2.ZERO


func _stunned_behavior() -> void:
	velocity = Vector2.ZERO
	if state_timer <= 0:
		_enter_cooldown()


func _enter_cooldown() -> void:
	state = State.COOLDOWN
	state_timer = post_charge_cooldown


func _cooldown_behavior(delta: float) -> void:
	var direction = (player_ref.global_position - global_position).normalized()
	facing_direction = direction
	var dist = global_position.distance_to(player_ref.global_position)
	var contact_dist = size + 18.0
	
	if dist > contact_dist + 5.0:
		velocity = direction * current_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	dist = global_position.distance_to(player_ref.global_position)
	if dist <= contact_dist + 5.0 and attack_timer <= 0:
		player_ref.take_damage(current_damage)
		attack_timer = attack_cooldown
	
	if state_timer <= 0:
		state = State.CHASE


func _update_state_visual() -> void:
	var c = Color.WHITE
	match state:
		State.CHARGE:
			c = Color(1.0, 0.25, 0.1)
		State.STUNNED:
			c = Color(0.45, 0.45, 0.5)
		State.COOLDOWN:
			c = color.darkened(0.3)
	body_sprite.modulate = c
	face_sprite.modulate = c
