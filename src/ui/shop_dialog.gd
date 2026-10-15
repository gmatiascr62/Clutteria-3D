class_name ShopDialog
extends RefCounted
## Tienda de herramientas (sólo monedas del juego, sin dinero real).


static func open(parent: Node, on_change: Callable) -> void:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var coins := UiKit.label("", 22, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(coins)
	var rows := {}
	var desc := {
		"papelera": "Descarta un objeto de la bandeja junto con su trío.",
		"iman": "Completa automáticamente un trío válido.",
		"mezclador": "Reordena la basura visible, manteniéndola resoluble.",
		"reloj": "Suma 30 segundos.",
	}
	var update := func():
		coins.text = "Monedas: %d" % int(Game.profile.coins)
		for t in rows:
			rows[t].label.text = "%s (tenés %d)\n%s" % [Balance.TOOL_NAMES[t], int(Game.profile.tools.get(t, 0)), desc[t]]
			rows[t].button.disabled = int(Game.profile.coins) < Balance.TOOL_PRICES[t]
	for t in Balance.TOOL_PRICES:
		var hb := HBoxContainer.new()
		hb.add_child(VectorIcon.make(t, Color(0.95, 0.9, 0.75), 48))
		var l := UiKit.label("", 18, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 330)
		hb.add_child(l)
		var tool: String = t
		var b := UiKit.button("Comprar %d" % Balance.TOOL_PRICES[t], func():
			if Game.buy_tool(tool):
				Sfx.play("coin")
			update.call()
			on_change.call(), UiKit.GOOD.darkened(0.3), Vector2(170, 56))
		hb.add_child(b)
		rows[t] = {"label": l, "button": b}
		vb.add_child(hb)
	vb.add_child(UiKit.label("Las cajas misteriosas dan: monedas (50 %), una herramienta (30 %) o un tesoro (20 %). No se venden con dinero real.", 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 540))
	update.call()
	UiKit.dialog(parent, "Herramientas", "", [["Cerrar", func(): on_change.call()]], vb)
