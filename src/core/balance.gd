class_name Balance
extends RefCounted
## Valores de equilibrio centralizados. Son un PUNTO DE PARTIDA: deben
## calibrarse con jugadores reales (ver README, sección "Calibración").

const TRAY_SIZE := 7
const MAX_LIVES := 5
## Intervalo de regeneración de una vida, en segundos (configurable).
const LIFE_REGEN_SECONDS := 20 * 60

const START_COINS := 150
const START_TOOLS := {"papelera": 1, "iman": 1, "mezclador": 1, "reloj": 1}
const TOOL_PRICES := {"papelera": 60, "iman": 90, "mezclador": 50, "reloj": 40}
const TOOL_NAMES := {"papelera": "Papelera", "iman": "Imán", "mezclador": "Mezclador", "reloj": "Reloj +30s"}
const CLOCK_BONUS := 30.0

## Continuar tras perder: costo en monedas y tiempo extra.
const CONTINUE_COST := 60
const CONTINUE_TIME_TIMEOUT := 45.0
const CONTINUE_TIME_TRAYFULL := 30.0
const CONTINUE_RETURN_ITEMS := 3

## Segunda estrella si queda al menos esta fracción del tiempo.
const STAR2_TIME_FRACTION := 0.30
## Limpieza mínima para dar por terminada la restauración.
const CLEAN_REQUIRED := 0.85

## Arreglos propios de cada habitación (ver "fixtures" en los layouts).
const FIXTURES := {
	"window": {"name": "Vidrio roto", "cost": 20, "value": 45},
	"lamp": {"name": "Lámpara que parpadea", "cost": 15, "value": 30},
}

const PAINT_COLORS := [
	{"id": "crema", "name": "Crema", "color": "#efe3c8", "price": 0, "value": 10},
	{"id": "blanco", "name": "Blanco", "color": "#f2f2ee", "price": 0, "value": 10},
	{"id": "gris", "name": "Gris perla", "color": "#c9ccd1", "price": 0, "value": 10},
	{"id": "salvia", "name": "Verde salvia", "color": "#b5c9a8", "price": 40, "value": 45},
	{"id": "cielo", "name": "Azul cielo", "color": "#a9cbe3", "price": 40, "value": 45},
	{"id": "terracota", "name": "Terracota", "color": "#d9a183", "price": 60, "value": 70},
	{"id": "lavanda", "name": "Lavanda", "color": "#c7b8e0", "price": 60, "value": 70},
]


## Tiempo de la fase de basura. Fórmula inicial documentada; NO es garantía
## de equilibrio. `info` lo produce LevelGenerator.difficulty_info().
static func level_time(info: Dictionary) -> float:
	var items: int = info.get("items", 30)
	var t := 25.0
	t += items * 2.6
	t += info.get("similar_ratio", 0.0) * items * 0.9
	t += info.get("avg_depth", 1.0) * items * 0.12
	t += info.get("hidden", 0) * 2.5
	t += info.get("containers", 0) * 2.0
	t += info.get("viewpoints", 1) * 4.0
	t *= lerpf(1.1, 0.95, clampf(info.get("difficulty", 0.0), 0.0, 1.0))
	return float(int(ceil(t / 5.0)) * 5)


static func room_reward(items: int, stars: int, mode: String) -> int:
	var base := items * 1.2 * (0.6 + 0.2 * float(clampi(stars, 1, 3) - 1))
	match mode:
		"replay":
			base *= 0.5
		"contract":
			base *= 0.9
	return int(round(base))


static func paint_by_id(id: String) -> Dictionary:
	for p in PAINT_COLORS:
		if p.id == id:
			return p
	return PAINT_COLORS[0]
