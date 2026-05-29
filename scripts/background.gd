extends Node2D

var grid_size: int = 64
var view_margin: int = 300
var last_camera_pos: Vector2 = Vector2(-INF, -INF)

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera and camera.global_position.distance_squared_to(last_camera_pos) > grid_size * grid_size:
		last_camera_pos = camera.global_position
		queue_redraw()

func _draw() -> void:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var view_rect = camera.get_viewport_rect()
	var cam_pos = camera.global_position
	var half_w = view_rect.size.x / 2 + view_margin
	var half_h = view_rect.size.y / 2 + view_margin
	
	var left = cam_pos.x - half_w
	var right = cam_pos.x + half_w
	var top = cam_pos.y - half_h
	var bottom = cam_pos.y + half_h
	
	var color = Color(0.15, 0.15, 0.18, 0.4)
	var color_thick = Color(0.12, 0.12, 0.15, 0.5)
	
	# Snap to grid
	var start_x = floor(left / grid_size) * grid_size
	var start_y = floor(top / grid_size) * grid_size
	
	var x = start_x
	while x <= right:
		var is_major = int(x) % (grid_size * 4) == 0
		var local_x = x - global_position.x
		draw_line(Vector2(local_x, top - global_position.y), Vector2(local_x, bottom - global_position.y),
			color_thick if is_major else color, 6.0 if is_major else 3.0)
		x += grid_size
	
	var y = start_y
	while y <= bottom:
		var is_major = int(y) % (grid_size * 4) == 0
		var local_y = y - global_position.y
		draw_line(Vector2(left - global_position.x, local_y), Vector2(right - global_position.x, local_y),
			color_thick if is_major else color, 6.0 if is_major else 3.0)
		y += grid_size