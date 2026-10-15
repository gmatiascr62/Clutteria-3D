extends SceneTree
## Ejecutor de pruebas sin dependencias externas.
## Uso: godot --headless --path . -s tests/run_tests.gd [-- filtro]
## Sale con código 1 si alguna prueba falla.

const SUITES := [
	"res://tests/test_tray.gd",
	"res://tests/test_generator.gd",
	"res://tests/test_session.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_save.gd",
	"res://tests/test_room_scene.gd",
]

var failures := 0
var passed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var t0 := Time.get_ticks_msec()
	var game = root.get_node_or_null("Game")
	if game:
		game.save_path = "user://test_profile.json"
		game.reset_progress()
	for path in SUITES:
		if filter != "" and not path.contains(filter):
			continue
		var script: GDScript = load(path)
		var suite = script.new()
		suite.set("runner", self)
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			if suite.has_method("before_each"):
				suite.before_each()
			var before := failures
			await suite.call(name)
			if failures == before:
				passed += 1
				print("  ok   %s.%s" % [path.get_file().get_basename(), name])
			else:
				print("  FAIL %s.%s" % [path.get_file().get_basename(), name])
		if suite is Node:
			suite.queue_free()
	print("\n%d pruebas OK, %d fallas (%.1f s)" % [passed, failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failures > 0 else 0)


func fail(msg: String) -> void:
	failures += 1
	printerr("    -> " + msg)
