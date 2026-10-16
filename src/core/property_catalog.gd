class_name PropertyCatalog
extends RefCounted
## Habitaciones (layouts con muebles fijos), propiedades y barrios.
## Coordenadas: habitación centrada en el origen, piso en y=0.
## `pos` de un mueble es el centro (x, z) de su base; `size` = (ancho, alto, fondo).

const LAYOUTS := {
	"studio": {
		"fixtures": ["window", "lamp"], "max_items": 150, "name": "Monoambiente", "theme": "studio", "size": Vector3(5.0, 2.7, 4.4),
		"floor": "wood", "floor_color": "#9c7a55", "wall_color": "#d8cdb6",
		"window": {"wall": "west", "pos": Vector2(1.0, 1.5), "size": Vector2(1.2, 0.9)},
		"door": {"wall": "south", "pos": -1.0},
		"viewpoints": [Vector2(-0.5, 0.6), Vector2(1.6, 1.4), Vector2(0.3, -0.7)],
		"furniture": [
			{"type": "bed", "name": "Cama", "pos": Vector2(-1.7, -1.1), "size": Vector3(1.4, 0.5, 2.0), "color": "#7a5c45", "accent": "#5c7fa3", "surface": true, "value": 120},
			{"type": "counter", "name": "Mesada", "pos": Vector2(1.2, -1.9), "size": Vector3(2.2, 0.9, 0.6), "color": "#a98b6a", "accent": "#e8e2d6", "surface": true, "value": 160, "drawers": 3, "face": "+z"},
			{"type": "table", "name": "Mesa", "pos": Vector2(1.3, 0.3), "size": Vector3(1.0, 0.75, 0.7), "color": "#8b6847", "surface": true, "value": 90},
			{"type": "armchair", "name": "Sillón", "pos": Vector2(-1.9, 1.5), "size": Vector3(0.8, 0.8, 0.8), "color": "#6b8e5a", "value": 80},
			{"type": "dresser", "name": "Cómoda", "pos": Vector2(0.2, 1.95), "size": Vector3(1.0, 0.8, 0.45), "color": "#8d6e52", "surface": true, "value": 110, "drawers": 2, "face": "-z"},
			{"type": "shelf", "name": "Estante", "pos": Vector2(2.3, 1.2), "size": Vector3(0.35, 1.6, 1.0), "color": "#7d5f43", "value": 70},
		],
		"covers": [{"type": "box", "pos": Vector2(-0.4, -1.7), "size": Vector3(0.55, 0.45, 0.55)}],
		"stains": [
			{"surface": "floor", "pos": Vector2(0.5, 0.9), "size": Vector2(1.1, 0.8)},
			{"surface": "floor", "pos": Vector2(-0.6, -0.5), "size": Vector2(0.8, 0.7)},
			{"surface": "north", "pos": Vector2(-0.4, 1.4), "size": Vector2(1.0, 0.7)},
		],
	},
	"bathroom": {
		"fixtures": ["lamp"], "max_items": 75, "name": "Baño", "theme": "bathroom", "size": Vector3(3.9, 2.6, 3.4),
		"floor": "tile", "floor_color": "#cfd8dc", "wall_color": "#cfe3e6",
		"window": {"wall": "north", "pos": Vector2(0.9, 1.8), "size": Vector2(0.7, 0.5)},
		"door": {"wall": "south", "pos": 1.1},
		"viewpoints": [Vector2(0.6, -0.1), Vector2(-0.5, 0.5), Vector2(0.7, 1.15)],
		"furniture": [
			{"type": "bathtub", "name": "Bañera", "pos": Vector2(-1.1, -1.3), "size": Vector3(1.6, 0.55, 0.75), "color": "#f0f0f0", "accent": "#b0bec5", "value": 200},
			{"type": "counter", "name": "Vanitory", "pos": Vector2(1.25, -1.45), "size": Vector3(1.0, 0.85, 0.45), "color": "#e6e0d4", "accent": "#fafafa", "surface": true, "value": 140, "drawers": 2, "face": "+z"},
			{"type": "toilet", "name": "Inodoro", "pos": Vector2(1.65, 0.45), "size": Vector3(0.45, 0.75, 0.65), "color": "#f5f5f5", "value": 90},
			{"type": "dresser", "name": "Mueble alto", "pos": Vector2(-1.7, 0.85), "size": Vector3(0.45, 1.15, 0.8), "color": "#bfa98a", "surface": true, "value": 100, "drawers": 2, "face": "+x"},
		],
		"covers": [{"type": "basket", "pos": Vector2(-0.7, 1.4), "size": Vector3(0.5, 0.5, 0.5)}],
		"stains": [
			{"surface": "floor", "pos": Vector2(0.2, 0.2), "size": Vector2(0.9, 0.7)},
			{"surface": "floor", "pos": Vector2(-0.4, -0.3), "size": Vector2(0.6, 0.5)},
			{"surface": "east", "pos": Vector2(-0.6, 1.5), "size": Vector2(0.8, 0.6)},
		],
	},
	"kitchen": {
		"fixtures": ["window"], "max_items": 210, "name": "Cocina", "theme": "kitchen", "size": Vector3(5.0, 2.7, 4.0),
		"floor": "tile", "floor_color": "#bfae94", "wall_color": "#e9dfc5",
		"window": {"wall": "west", "pos": Vector2(0.3, 1.5), "size": Vector2(1.1, 0.9)},
		"door": {"wall": "south", "pos": -0.2},
		"viewpoints": [Vector2(-1.5, 0.3), Vector2(1.3, 1.4), Vector2(0.9, -0.6)],
		"furniture": [
			{"type": "counter", "name": "Mesada", "pos": Vector2(-0.3, -1.7), "size": Vector3(3.4, 0.9, 0.6), "color": "#a98b6a", "accent": "#e8e2d6", "surface": true, "value": 220, "drawers": 4, "face": "+z"},
			{"type": "fridge", "name": "Heladera", "pos": Vector2(2.1, -1.65), "size": Vector3(0.7, 1.8, 0.7), "color": "#e8e8e8", "value": 260},
			{"type": "table", "name": "Mesa", "pos": Vector2(-0.1, 0.4), "size": Vector3(1.4, 0.78, 0.8), "color": "#8b6847", "surface": true, "value": 110},
			{"type": "dresser", "name": "Alacena", "pos": Vector2(2.25, 0.6), "size": Vector3(0.5, 0.9, 1.4), "color": "#9a7b5a", "surface": true, "value": 130, "drawers": 3, "face": "-x"},
		],
		"covers": [{"type": "box", "pos": Vector2(-2.0, 1.45), "size": Vector3(0.5, 0.5, 0.5)}],
		"stains": [
			{"surface": "floor", "pos": Vector2(0.9, 1.2), "size": Vector2(1.0, 0.8)},
			{"surface": "floor", "pos": Vector2(-1.1, -0.6), "size": Vector2(0.9, 0.6)},
			{"surface": "north", "pos": Vector2(0.5, 1.55), "size": Vector2(1.2, 0.6)},
		],
	},
	"bedroom": {
		"fixtures": ["window", "lamp"], "max_items": 210, "name": "Dormitorio", "theme": "bedroom", "size": Vector3(4.6, 2.7, 4.2),
		"floor": "wood", "floor_color": "#a07d58", "wall_color": "#d9d2e4",
		"window": {"wall": "east", "pos": Vector2(-1.0, 1.5), "size": Vector2(1.1, 0.9)},
		"door": {"wall": "south", "pos": 1.4},
		"viewpoints": [Vector2(0.6, -0.6), Vector2(-0.4, 0.9), Vector2(1.0, 1.0)],
		"furniture": [
			{"type": "bed", "name": "Cama", "pos": Vector2(-1.1, -1.0), "size": Vector3(1.6, 0.55, 2.1), "color": "#6d4f3a", "accent": "#c06c84", "surface": true, "value": 160},
			{"type": "dresser", "name": "Mesa de luz", "pos": Vector2(0.05, -1.85), "size": Vector3(0.45, 0.55, 0.4), "color": "#8d6e52", "surface": true, "value": 50, "drawers": 1, "face": "+z"},
			{"type": "wardrobe", "name": "Ropero", "pos": Vector2(1.75, -1.75), "size": Vector3(1.1, 2.0, 0.6), "color": "#7a5a40", "value": 180},
			{"type": "dresser", "name": "Cómoda", "pos": Vector2(2.05, 0.6), "size": Vector3(0.5, 0.85, 1.2), "color": "#8d6e52", "surface": true, "value": 120, "drawers": 3, "face": "-x"},
			{"type": "table", "name": "Escritorio", "pos": Vector2(-1.6, 1.55), "size": Vector3(1.2, 0.75, 0.6), "color": "#9a7b5a", "surface": true, "value": 90},
		],
		"covers": [{"type": "box", "pos": Vector2(0.4, 1.7), "size": Vector3(0.6, 0.45, 0.5)}],
		"stains": [
			{"surface": "floor", "pos": Vector2(0.4, 0.2), "size": Vector2(1.0, 0.9)},
			{"surface": "floor", "pos": Vector2(-1.0, 0.7), "size": Vector2(0.7, 0.6)},
			{"surface": "south", "pos": Vector2(-0.2, 1.4), "size": Vector2(1.0, 0.7)},
		],
	},
	"living": {
		"fixtures": ["lamp", "window"], "max_items": 240, "name": "Living", "theme": "living", "size": Vector3(5.6, 2.8, 4.6),
		"floor": "wood", "floor_color": "#8f6c4c", "wall_color": "#e3d7c3",
		"window": {"wall": "east", "pos": Vector2(1.0, 1.5), "size": Vector2(1.4, 1.0)},
		"door": {"wall": "west", "pos": -1.2},
		"viewpoints": [Vector2(-1.6, -0.6), Vector2(1.3, -0.7), Vector2(0.5, 1.0), Vector2(-1.3, 1.3)],
		"furniture": [
			{"type": "sofa", "name": "Sofá", "pos": Vector2(-0.4, -1.8), "size": Vector3(2.2, 0.85, 0.9), "color": "#5d7a99", "value": 240},
			{"type": "table", "name": "Mesa ratona", "pos": Vector2(-0.4, -0.6), "size": Vector3(1.2, 0.45, 0.6), "color": "#7d5f43", "surface": true, "value": 80},
			{"type": "counter", "name": "Mueble TV", "pos": Vector2(-0.4, 2.05), "size": Vector3(1.8, 0.55, 0.45), "color": "#6f5440", "accent": "#3a2d22", "surface": true, "value": 130, "drawers": 2, "face": "-z"},
			{"type": "shelf", "name": "Biblioteca", "pos": Vector2(2.6, 0.2), "size": Vector3(0.35, 1.8, 1.4), "color": "#7d5f43", "value": 140},
			{"type": "armchair", "name": "Sillón", "pos": Vector2(-2.3, 0.35), "size": Vector3(0.85, 0.8, 0.85), "color": "#9c5a4a", "value": 100},
			{"type": "dresser", "name": "Aparador", "pos": Vector2(2.3, -1.9), "size": Vector3(0.9, 0.8, 0.45), "color": "#8d6e52", "surface": true, "value": 110, "drawers": 2, "face": "+z"},
		],
		"covers": [
			{"type": "box", "pos": Vector2(1.3, 1.6), "size": Vector3(0.55, 0.45, 0.55)},
			{"type": "cushion", "pos": Vector2(-2.2, 1.7), "size": Vector3(0.6, 0.22, 0.6)},
		],
		"stains": [
			{"surface": "floor", "pos": Vector2(0.6, 0.3), "size": Vector2(1.2, 0.9)},
			{"surface": "floor", "pos": Vector2(-1.2, 0.6), "size": Vector2(0.8, 0.6)},
			{"surface": "north", "pos": Vector2(1.4, 1.5), "size": Vector2(1.0, 0.8)},
		],
	},
	"attic": {
		"fixtures": ["window", "lamp"], "max_items": 240, "name": "Altillo", "theme": "attic", "size": Vector3(5.0, 2.5, 4.4),
		"floor": "wood", "floor_color": "#7f6448", "wall_color": "#cbbfa8",
		"window": {"wall": "east", "pos": Vector2(-0.6, 1.4), "size": Vector2(0.8, 0.6)},
		"door": {"wall": "south", "pos": 1.6},
		"viewpoints": [Vector2(0.1, 0.1), Vector2(-1.2, 1.0), Vector2(1.4, -0.4)],
		"furniture": [
			{"type": "shelf", "name": "Estante viejo", "pos": Vector2(-2.25, -0.2), "size": Vector3(0.4, 1.6, 1.6), "color": "#6d5238", "value": 90},
			{"type": "chest", "name": "Baúl", "pos": Vector2(1.6, -1.85), "size": Vector3(1.0, 0.6, 0.55), "color": "#7b4f2c", "accent": "#c9a227", "surface": true, "value": 150, "drawers": 1, "face": "+z"},
			{"type": "table", "name": "Escritorio viejo", "pos": Vector2(1.85, 1.4), "size": Vector3(1.1, 0.75, 0.6), "color": "#7d5f43", "surface": true, "value": 90},
			{"type": "dresser", "name": "Cómoda", "pos": Vector2(-0.6, -1.95), "size": Vector3(1.2, 0.9, 0.45), "color": "#8d6e52", "surface": true, "value": 120, "drawers": 3, "face": "+z"},
		],
		"covers": [
			{"type": "box", "pos": Vector2(0.0, 1.7), "size": Vector3(0.6, 0.5, 0.6)},
			{"type": "box", "pos": Vector2(-1.6, 1.7), "size": Vector3(0.55, 0.45, 0.55)},
		],
		"stains": [
			{"surface": "floor", "pos": Vector2(0.4, 0.8), "size": Vector2(1.1, 0.8)},
			{"surface": "floor", "pos": Vector2(-0.9, -0.6), "size": Vector2(0.8, 0.7)},
			{"surface": "north", "pos": Vector2(1.0, 1.4), "size": Vector2(1.0, 0.7)},
		],
	},
}

## challenge: find_mystery | tray_max5 | no_tools | all_containers
const PROPERTIES := {
	"mono_tutorial": {"name": "Monoambiente del centro", "kind": "Monoambiente", "price": 0, "base_value": 320, "rooms": [
		{"name": "Monoambiente", "layout": "studio", "items": 30, "difficulty": 0.0, "challenge": "find_mystery", "tutorial": true},
		{"name": "Baño", "layout": "bathroom", "items": 30, "difficulty": 0.05, "challenge": "tray_max5"},
	]},
	"depto_sol": {"name": "Departamento Calle Sol", "kind": "Departamento", "price": 0, "base_value": 560, "rooms": [
		{"name": "Cocina", "layout": "kitchen", "items": 45, "difficulty": 0.15, "challenge": "no_tools"},
		{"name": "Dormitorio", "layout": "bedroom", "items": 60, "difficulty": 0.2, "challenge": "find_mystery"},
		{"name": "Living", "layout": "living", "items": 60, "difficulty": 0.25, "challenge": "all_containers"},
	]},
	"depto_lago": {"name": "Departamento del Lago", "kind": "Departamento", "price": 350, "base_value": 760, "rooms": [
		{"name": "Living", "layout": "living", "items": 90, "difficulty": 0.3, "challenge": "tray_max5"},
		{"name": "Cocina", "layout": "kitchen", "items": 90, "difficulty": 0.35, "challenge": "find_mystery"},
		{"name": "Dormitorio", "layout": "bedroom", "items": 90, "difficulty": 0.35, "challenge": "no_tools"},
	]},
	"casa_jardin": {"name": "Casa del Jardín", "kind": "Casa familiar", "price": 600, "base_value": 1150, "rooms": [
		{"name": "Cocina", "layout": "kitchen", "items": 90, "difficulty": 0.35, "challenge": "all_containers"},
		{"name": "Living", "layout": "living", "items": 120, "difficulty": 0.4, "challenge": "find_mystery"},
		{"name": "Dormitorio", "layout": "bedroom", "items": 90, "difficulty": 0.4, "challenge": "tray_max5", "key_for": 4},
		{"name": "Baño", "layout": "bathroom", "items": 60, "difficulty": 0.4, "challenge": "no_tools"},
		{"name": "Altillo secreto", "layout": "attic", "items": 90, "difficulty": 0.45, "challenge": "find_mystery", "secret": true},
	]},
	"casa_dos_pisos": {"name": "Casa de dos pisos", "kind": "Casa de dos pisos", "price": 1500, "base_value": 2600, "rooms": [
		{"name": "Cocina (PB)", "layout": "kitchen", "items": 120, "difficulty": 0.5, "challenge": "find_mystery"},
		{"name": "Living (PB)", "layout": "living", "items": 150, "difficulty": 0.55, "challenge": "all_containers"},
		{"name": "Baño (PB)", "layout": "bathroom", "items": 75, "difficulty": 0.5, "challenge": "tray_max5"},
		{"name": "Dormitorio principal (PA)", "layout": "bedroom", "items": 150, "difficulty": 0.55, "challenge": "no_tools"},
		{"name": "Dormitorio niños (PA)", "layout": "bedroom", "items": 150, "difficulty": 0.6, "challenge": "find_mystery"},
		{"name": "Altillo (PA)", "layout": "attic", "items": 120, "difficulty": 0.55, "challenge": "tray_max5"},
	]},
	"mansion": {"name": "Mansión de las Lomas", "kind": "Mansión", "price": 4000, "base_value": 7200, "rooms": [
		{"name": "Cocina", "layout": "kitchen", "items": 180, "difficulty": 0.7, "challenge": "find_mystery"},
		{"name": "Gran living", "layout": "living", "items": 240, "difficulty": 0.8, "challenge": "tray_max5"},
		{"name": "Baño principal", "layout": "bathroom", "items": 75, "difficulty": 0.7, "challenge": "no_tools"},
		{"name": "Suite", "layout": "bedroom", "items": 180, "difficulty": 0.75, "challenge": "all_containers"},
		{"name": "Dormitorio de huéspedes", "layout": "bedroom", "items": 150, "difficulty": 0.75, "challenge": "find_mystery", "key_for": 7},
		{"name": "Biblioteca", "layout": "living", "items": 210, "difficulty": 0.8, "challenge": "tray_max5"},
		{"name": "Altillo", "layout": "attic", "items": 210, "difficulty": 0.8, "challenge": "no_tools"},
		{"name": "Sótano secreto", "layout": "attic", "items": 240, "difficulty": 0.85, "challenge": "find_mystery", "secret": true},
	]},
}

const NEIGHBORHOODS := [
	{"id": "centro", "name": "Barrio Centro", "stars": 0, "cost": 0, "properties": ["mono_tutorial", "depto_sol"]},
	{"id": "jardines", "name": "Barrio Jardines", "stars": 12, "cost": 300, "properties": ["depto_lago", "casa_jardin"]},
	{"id": "colinas", "name": "Barrio Colinas", "stars": 30, "cost": 1200, "properties": ["casa_dos_pisos"]},
	{"id": "lomas", "name": "Lomas Altas", "stars": 55, "cost": 3000, "properties": ["mansion"]},
]

const CHALLENGE_TEXT := {
	"find_mystery": "Abrir una caja misteriosa",
	"tray_max5": "No llenar más de 5 espacios de la bandeja",
	"no_tools": "Completar sin usar herramientas",
	"all_containers": "Abrir todos los cajones y cajas",
}


static func room_def(room_key: String) -> Dictionary:
	var parts := room_key.split("/")
	if parts.size() != 2 or not PROPERTIES.has(parts[0]):
		return {}
	var rooms: Array = PROPERTIES[parts[0]].rooms
	var idx := int(parts[1])
	if idx < 0 or idx >= rooms.size():
		return {}
	return rooms[idx]


static func room_keys(prop_id: String) -> Array:
	var out := []
	for i in PROPERTIES[prop_id].rooms.size():
		out.append("%s/%d" % [prop_id, i])
	return out


static func neighborhood_of(prop_id: String) -> Dictionary:
	for n in NEIGHBORHOODS:
		if prop_id in n.properties:
			return n
	return {}


static func mystery_count(items: int) -> int:
	return 1 + items / 90
