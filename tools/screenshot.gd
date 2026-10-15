extends SceneTree
## Herramienta de desarrollo: abre escenas y guarda capturas.
## Uso: godot --path . -s tools/screenshot.gd -- <salida_dir> [escenario]

var out_dir := "user://shots"


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img:
		img.save_png(out_dir.path_join(name + ".png"))
		print("captura: ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scenario := args[1] if args.size() > 1 else "all"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game = root.get_node("Game")
	game.save_path = "user://screenshot_profile.json"
	game.reset_progress()
	change_scene_to_file("res://scenes/main_menu.tscn")
	for i in 5:
		await process_frame
	await _shot("01_menu")
	change_scene_to_file("res://scenes/map.tscn")
	for i in 5:
		await process_frame
	await _shot("02_map")
	game.debug_seed = 7
	game.start_room("mono_tutorial/0")
	change_scene_to_file("res://scenes/room.tscn")
	for i in 20:
		await process_frame
	await _shot("03_room")
	var room = current_scene
	room.go_to_viewpoint(1)
	for i in 30:
		await process_frame
	await _shot("04_room_vp2")
	# Abrir todos los contenedores y jugar la mitad de la solución.
	for ci in room.session.level.containers.size():
		room.session.open_container(ci)
	var sol: Array = Solver.solve(room.session.level, room.session.solver_state()).steps
	for k in 14:
		room._on_piece_tapped(sol[k])
	for i in 30:
		await process_frame
	await _shot("05_room_progress")
	for k in range(14, sol.size()):
		room._on_piece_tapped(sol[k])
	for p in room.session.level.pieces:
		if p.kind != "trash" and room.session.present[p.id]:
			room.session.take(p.id)
	for i in 30:
		await process_frame
	await _shot("06_results")
	room._start_restoration()
	for i in 10:
		await process_frame
	await _shot("07_restore")
	quit()
