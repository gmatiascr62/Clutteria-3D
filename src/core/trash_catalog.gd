class_name TrashCatalog
extends RefCounted
## Definiciones de basura. Cada variante tiene un ID EXACTO; dos variantes de
## la misma familia pueden parecerse mucho (misma forma y color) pero sólo
## forman trío objetos con el mismo ID.

## Tamaño en "pose de reposo" (x, y=alto, z) de cada forma, en metros.
## MeshKit construye las mallas dentro de estas cajas.
const SHAPES := {
	"bottle": Vector3(0.27, 0.08, 0.08),
	"flask": Vector3(0.10, 0.17, 0.07),
	"can": Vector3(0.07, 0.12, 0.07),
	"plate": Vector3(0.22, 0.03, 0.22),
	"mug": Vector3(0.12, 0.10, 0.09),
	"carton": Vector3(0.09, 0.19, 0.09),
	"jar": Vector3(0.09, 0.12, 0.09),
	"bowl": Vector3(0.15, 0.07, 0.15),
	"soap": Vector3(0.10, 0.04, 0.06),
	"tube": Vector3(0.18, 0.04, 0.05),
	"roll": Vector3(0.11, 0.11, 0.11),
	"brush": Vector3(0.19, 0.03, 0.03),
	"cloth": Vector3(0.24, 0.05, 0.20),
	"sock": Vector3(0.20, 0.04, 0.07),
	"shoe": Vector3(0.26, 0.10, 0.10),
	"ball": Vector3(0.13, 0.13, 0.13),
	"block": Vector3(0.08, 0.08, 0.08),
	"book": Vector3(0.18, 0.04, 0.13),
	"teddy": Vector3(0.12, 0.17, 0.10),
	"magazine": Vector3(0.21, 0.015, 0.15),
	"remote": Vector3(0.17, 0.025, 0.05),
	"pizza": Vector3(0.24, 0.04, 0.24),
	"cup": Vector3(0.08, 0.11, 0.08),
	"bag": Vector3(0.16, 0.12, 0.14),
	"box": Vector3(0.18, 0.12, 0.14),
	"paint": Vector3(0.14, 0.15, 0.14),
	"glove": Vector3(0.20, 0.03, 0.10),
}

## Familias: forma + variantes. `themes` indica en qué habitaciones aparece.
## Cada variante: id, nombre visible, color principal, acento y escala.
const FAMILIES := [
	{"id": "botella_verde", "shape": "bottle", "themes": ["kitchen", "living", "studio"], "variants": [
		{"id": "botella_verde_blanca", "name": "Botella verde, etiqueta blanca", "color": "#2e7d32", "accent": "#f5f5f5"},
		{"id": "botella_verde_amarilla", "name": "Botella verde, etiqueta amarilla", "color": "#2e7d32", "accent": "#fdd835"},
		{"id": "botella_verde_roja", "name": "Botella verde, etiqueta roja", "color": "#2e7d32", "accent": "#e53935"},
	]},
	{"id": "botella_ambar", "shape": "bottle", "themes": ["kitchen", "attic", "living"], "variants": [
		{"id": "botella_ambar_crema", "name": "Botella ámbar, etiqueta crema", "color": "#9a4f1e", "accent": "#fff3c4"},
		{"id": "botella_ambar_azul", "name": "Botella ámbar, etiqueta azul", "color": "#9a4f1e", "accent": "#1e88e5"},
		{"id": "botella_ambar_corta", "name": "Botella ámbar corta", "color": "#9a4f1e", "accent": "#fff3c4", "scale": 0.8},
	]},
	{"id": "lata", "shape": "can", "themes": ["kitchen", "living", "studio", "attic"], "variants": [
		{"id": "lata_roja_blanca", "name": "Lata roja, banda blanca", "color": "#c62828", "accent": "#eeeeee"},
		{"id": "lata_roja_dorada", "name": "Lata roja, banda dorada", "color": "#c62828", "accent": "#ffb300"},
		{"id": "lata_azul_blanca", "name": "Lata azul, banda blanca", "color": "#1565c0", "accent": "#eeeeee"},
		{"id": "lata_verde", "name": "Lata verde", "color": "#2e7d32", "accent": "#c5e1a5"},
	]},
	{"id": "plato", "shape": "plate", "themes": ["kitchen", "studio"], "variants": [
		{"id": "plato_borde_azul", "name": "Plato, borde azul", "color": "#f2f2f2", "accent": "#1e88e5"},
		{"id": "plato_borde_rojo", "name": "Plato, borde rojo", "color": "#f2f2f2", "accent": "#e53935"},
		{"id": "plato_borde_verde", "name": "Plato, borde verde", "color": "#f2f2f2", "accent": "#43a047"},
	]},
	{"id": "taza", "shape": "mug", "themes": ["kitchen", "living", "studio"], "variants": [
		{"id": "taza_blanca", "name": "Taza blanca", "color": "#f4f4f4", "accent": "#f4f4f4"},
		{"id": "taza_amarilla", "name": "Taza amarilla", "color": "#fbc02d", "accent": "#fbc02d"},
		{"id": "taza_celeste", "name": "Taza celeste", "color": "#4fc3f7", "accent": "#4fc3f7"},
		{"id": "taza_blanca_asa_roja", "name": "Taza blanca, asa roja", "color": "#f4f4f4", "accent": "#e53935"},
	]},
	{"id": "envase", "shape": "carton", "themes": ["kitchen", "studio"], "variants": [
		{"id": "envase_azul", "name": "Envase de leche, franja azul", "color": "#fafafa", "accent": "#1e88e5"},
		{"id": "envase_rojo", "name": "Envase de leche, franja roja", "color": "#fafafa", "accent": "#e53935"},
		{"id": "envase_verde", "name": "Envase de leche, franja verde", "color": "#fafafa", "accent": "#43a047"},
	]},
	{"id": "frasco", "shape": "jar", "themes": ["kitchen", "attic"], "variants": [
		{"id": "frasco_tapa_roja", "name": "Frasco, tapa roja", "color": "#9fc5e8", "accent": "#d32f2f"},
		{"id": "frasco_tapa_dorada", "name": "Frasco, tapa dorada", "color": "#9fc5e8", "accent": "#ffb300"},
		{"id": "frasco_mermelada", "name": "Frasco de mermelada", "color": "#8e2443", "accent": "#d32f2f"},
	]},
	{"id": "bowl", "shape": "bowl", "themes": ["kitchen"], "variants": [
		{"id": "bowl_naranja", "name": "Bowl naranja", "color": "#ff8a65", "accent": "#ffccbc"},
		{"id": "bowl_verde", "name": "Bowl verde", "color": "#81c784", "accent": "#c8e6c9"},
		{"id": "bowl_blanco", "name": "Bowl blanco", "color": "#f5f5f5", "accent": "#e0e0e0"},
	]},
	{"id": "shampoo", "shape": "flask", "themes": ["bathroom"], "variants": [
		{"id": "shampoo_violeta_blanco", "name": "Shampoo violeta, etiqueta blanca", "color": "#8e44ad", "accent": "#f5f5f5"},
		{"id": "shampoo_violeta_rosa", "name": "Shampoo violeta, etiqueta rosa", "color": "#8e44ad", "accent": "#f48fb1"},
		{"id": "shampoo_turquesa", "name": "Shampoo turquesa", "color": "#26a69a", "accent": "#f5f5f5"},
		{"id": "shampoo_turquesa_chico", "name": "Shampoo turquesa chico", "color": "#26a69a", "accent": "#f5f5f5", "scale": 0.78},
	]},
	{"id": "jabon", "shape": "soap", "themes": ["bathroom"], "variants": [
		{"id": "jabon_salmon", "name": "Jabón salmón", "color": "#ffab91", "accent": "#ffccbc"},
		{"id": "jabon_menta", "name": "Jabón menta", "color": "#80cbc4", "accent": "#b2dfdb"},
		{"id": "jabon_limon", "name": "Jabón limón", "color": "#fff176", "accent": "#fff9c4"},
	]},
	{"id": "pasta", "shape": "tube", "themes": ["bathroom"], "variants": [
		{"id": "pasta_roja", "name": "Pasta dental, tapa roja", "color": "#fafafa", "accent": "#e53935"},
		{"id": "pasta_azul", "name": "Pasta dental, tapa azul", "color": "#fafafa", "accent": "#1e88e5"},
		{"id": "pasta_verde", "name": "Pasta dental, tapa verde", "color": "#fafafa", "accent": "#43a047"},
	]},
	{"id": "rollo", "shape": "roll", "themes": ["bathroom", "attic"], "variants": [
		{"id": "rollo_blanco", "name": "Rollo de papel blanco", "color": "#fafafa", "accent": "#8d6e63"},
		{"id": "rollo_rosa", "name": "Rollo de papel rosa", "color": "#f8bbd0", "accent": "#8d6e63"},
		{"id": "rollo_celeste", "name": "Rollo de papel celeste", "color": "#b3e5fc", "accent": "#8d6e63"},
	]},
	{"id": "cepillo", "shape": "brush", "themes": ["bathroom"], "variants": [
		{"id": "cepillo_azul", "name": "Cepillo azul", "color": "#42a5f5", "accent": "#fafafa"},
		{"id": "cepillo_rojo", "name": "Cepillo rojo", "color": "#ef5350", "accent": "#fafafa"},
		{"id": "cepillo_azul_cerdas_azules", "name": "Cepillo azul, cerdas celestes", "color": "#42a5f5", "accent": "#81d4fa"},
	]},
	{"id": "toalla", "shape": "cloth", "themes": ["bathroom", "bedroom"], "variants": [
		{"id": "toalla_celeste", "name": "Toalla celeste", "color": "#4fc3f7", "accent": "#4fc3f7"},
		{"id": "toalla_rosa", "name": "Toalla rosa", "color": "#f06292", "accent": "#f06292"},
		{"id": "toalla_celeste_raya", "name": "Toalla celeste con raya", "color": "#4fc3f7", "accent": "#fafafa"},
	]},
	{"id": "remera", "shape": "cloth", "themes": ["bedroom", "studio", "attic"], "variants": [
		{"id": "remera_roja", "name": "Remera roja", "color": "#e53935", "accent": "#e53935"},
		{"id": "remera_roja_raya", "name": "Remera roja con raya blanca", "color": "#e53935", "accent": "#fafafa"},
		{"id": "remera_azul", "name": "Remera azul", "color": "#1e88e5", "accent": "#1e88e5"},
		{"id": "remera_verde", "name": "Remera verde", "color": "#43a047", "accent": "#43a047"},
	]},
	{"id": "media", "shape": "sock", "themes": ["bedroom", "studio"], "variants": [
		{"id": "media_blanca_roja", "name": "Media blanca, puño rojo", "color": "#fafafa", "accent": "#e53935"},
		{"id": "media_blanca_azul", "name": "Media blanca, puño azul", "color": "#fafafa", "accent": "#1e88e5"},
		{"id": "media_gris", "name": "Media gris", "color": "#9e9e9e", "accent": "#616161"},
	]},
	{"id": "zapatilla", "shape": "shoe", "themes": ["bedroom", "living", "studio"], "variants": [
		{"id": "zapatilla_negra", "name": "Zapatilla negra, suela blanca", "color": "#263238", "accent": "#fafafa"},
		{"id": "zapatilla_blanca", "name": "Zapatilla blanca, suela negra", "color": "#fafafa", "accent": "#263238"},
		{"id": "zapatilla_roja", "name": "Zapatilla roja", "color": "#d32f2f", "accent": "#fafafa"},
	]},
	{"id": "pelota", "shape": "ball", "themes": ["bedroom", "living", "attic"], "variants": [
		{"id": "pelota_naranja", "name": "Pelota naranja", "color": "#ff7043", "accent": "#fafafa"},
		{"id": "pelota_azul", "name": "Pelota azul", "color": "#42a5f5", "accent": "#fafafa"},
		{"id": "pelota_amarilla", "name": "Pelota amarilla", "color": "#ffee58", "accent": "#fafafa"},
		{"id": "pelota_naranja_chica", "name": "Pelota naranja chica", "color": "#ff7043", "accent": "#fafafa", "scale": 0.75},
	]},
	{"id": "cubo", "shape": "block", "themes": ["bedroom", "living", "attic"], "variants": [
		{"id": "cubo_rojo", "name": "Cubo de juguete rojo", "color": "#e53935", "accent": "#fafafa"},
		{"id": "cubo_amarillo", "name": "Cubo de juguete amarillo", "color": "#fdd835", "accent": "#fafafa"},
		{"id": "cubo_azul", "name": "Cubo de juguete azul", "color": "#1e88e5", "accent": "#fafafa"},
	]},
	{"id": "libro", "shape": "book", "themes": ["bedroom", "living", "attic", "studio"], "variants": [
		{"id": "libro_marron", "name": "Libro marrón", "color": "#6d4c41", "accent": "#f5f0e1"},
		{"id": "libro_azul", "name": "Libro azul", "color": "#3949ab", "accent": "#f5f0e1"},
		{"id": "libro_verde", "name": "Libro verde", "color": "#00897b", "accent": "#f5f0e1"},
		{"id": "libro_azul_grueso", "name": "Libro azul grueso", "color": "#3949ab", "accent": "#f5f0e1", "scale": 1.2},
	]},
	{"id": "peluche", "shape": "teddy", "themes": ["bedroom", "attic"], "variants": [
		{"id": "peluche_marron", "name": "Osito marrón", "color": "#8d6e63", "accent": "#d7ccc8"},
		{"id": "peluche_beige", "name": "Osito beige", "color": "#bcaaa4", "accent": "#efebe9"},
		{"id": "peluche_rosa", "name": "Osito rosa", "color": "#f48fb1", "accent": "#fce4ec"},
	]},
	{"id": "revista", "shape": "magazine", "themes": ["living", "bathroom", "studio"], "variants": [
		{"id": "revista_roja", "name": "Revista de tapa roja", "color": "#e53935", "accent": "#fafafa"},
		{"id": "revista_amarilla", "name": "Revista de tapa amarilla", "color": "#fdd835", "accent": "#fafafa"},
		{"id": "revista_roja_negra", "name": "Revista roja, lomo negro", "color": "#e53935", "accent": "#212121"},
	]},
	{"id": "control", "shape": "remote", "themes": ["living"], "variants": [
		{"id": "control_negro_rojo", "name": "Control negro, botón rojo", "color": "#212121", "accent": "#e53935"},
		{"id": "control_negro_verde", "name": "Control negro, botón verde", "color": "#212121", "accent": "#43a047"},
		{"id": "control_gris", "name": "Control gris", "color": "#9e9e9e", "accent": "#e53935"},
	]},
	{"id": "pizza", "shape": "pizza", "themes": ["living", "studio", "kitchen"], "variants": [
		{"id": "pizza_roja", "name": "Caja de pizza, logo rojo", "color": "#d7ccc8", "accent": "#e53935"},
		{"id": "pizza_verde", "name": "Caja de pizza, logo verde", "color": "#d7ccc8", "accent": "#43a047"},
	]},
	{"id": "vaso", "shape": "cup", "themes": ["living", "kitchen", "bathroom"], "variants": [
		{"id": "vaso_rojo", "name": "Vaso descartable rojo", "color": "#e53935", "accent": "#fafafa"},
		{"id": "vaso_azul", "name": "Vaso descartable azul", "color": "#1e88e5", "accent": "#fafafa"},
		{"id": "vaso_blanco", "name": "Vaso descartable blanco", "color": "#fafafa", "accent": "#e0e0e0"},
	]},
	{"id": "bolsa", "shape": "bag", "themes": ["living", "attic", "studio", "kitchen"], "variants": [
		{"id": "bolsa_blanca", "name": "Bolsa blanca", "color": "#f5f5f5", "accent": "#bdbdbd"},
		{"id": "bolsa_amarilla", "name": "Bolsa amarilla", "color": "#fdd835", "accent": "#f9a825"},
		{"id": "bolsa_papel", "name": "Bolsa de papel", "color": "#a1887f", "accent": "#8d6e63"},
	]},
	{"id": "caja", "shape": "box", "themes": ["attic", "studio"], "variants": [
		{"id": "caja_carton", "name": "Caja de cartón", "color": "#b08560", "accent": "#e0c9a6"},
		{"id": "caja_carton_cinta_roja", "name": "Caja de cartón, cinta roja", "color": "#b08560", "accent": "#e53935"},
		{"id": "caja_blanca", "name": "Caja blanca", "color": "#eeeeee", "accent": "#bdbdbd"},
	]},
	{"id": "pintura", "shape": "paint", "themes": ["attic"], "variants": [
		{"id": "pintura_roja", "name": "Lata de pintura roja", "color": "#9e9e9e", "accent": "#e53935"},
		{"id": "pintura_azul", "name": "Lata de pintura azul", "color": "#9e9e9e", "accent": "#1e88e5"},
		{"id": "pintura_amarilla", "name": "Lata de pintura amarilla", "color": "#9e9e9e", "accent": "#fdd835"},
	]},
	{"id": "guante", "shape": "glove", "themes": ["attic", "kitchen", "bathroom"], "variants": [
		{"id": "guante_amarillo", "name": "Guante amarillo", "color": "#fdd835", "accent": "#fdd835"},
		{"id": "guante_verde", "name": "Guante verde", "color": "#66bb6a", "accent": "#66bb6a"},
		{"id": "guante_amarillo_puño", "name": "Guante amarillo, puño azul", "color": "#fdd835", "accent": "#1e88e5"},
	]},
]

static var _variants: Dictionary = {}


static func _ensure() -> void:
	if not _variants.is_empty():
		return
	for fam in FAMILIES:
		for v in fam.variants:
			var d: Dictionary = v.duplicate()
			d["family"] = fam.id
			d["shape"] = v.get("shape", fam.shape)
			d["scale"] = float(v.get("scale", 1.0))
			_variants[v.id] = d


static func variant(id: String) -> Dictionary:
	_ensure()
	return _variants.get(id, {})


static func all_variant_ids() -> Array:
	_ensure()
	return _variants.keys()


static func families_for_theme(theme: String) -> Array:
	var out := []
	for fam in FAMILIES:
		if theme in fam.themes:
			out.append(fam)
	return out


## Tamaño en reposo (con escala) de una variante.
static func size_of(id: String) -> Vector3:
	var v := variant(id)
	return SHAPES[v.shape] * v.scale


## Mitad de la diagonal horizontal: radio que ocupa en el piso con cualquier giro.
static func footprint_radius(id: String) -> float:
	var s := size_of(id)
	return Vector2(s.x, s.z).length() * 0.5
