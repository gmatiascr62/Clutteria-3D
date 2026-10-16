# Clutteria 3D

Juego para Android (horizontal) en primera persona: limpiás casas abarrotadas
encontrando **tríos de objetos exactamente iguales**, restaurás cada habitación
y la casa se vende sola al terminarla. Hecho con **Godot 4.3** (renderer
*Compatibility*) y **GDScript**, sin dependencias de pago. Todos los gráficos
y sonidos se generan por código (ver [ATTRIBUTIONS.md](ATTRIBUTIONS.md)).

## Estado: qué está hecho y qué se verificó

**Jugable de punta a punta:** menú → mapa → habitación (basura) → resultados →
restauración → venta de la casa → barrio siguiente. Incluye encargos y el
desafío diario.

Verificado en este repositorio (no en un teléfono real):

| Verificación | Cómo |
|---|---|
| Todos los scripts compilan | `tools/check_scripts.gd` (local y CI) |
| 54 pruebas automáticas pasan | `tests/run_tests.gd` (local y CI) |
| Cada habitación del catálogo genera niveles válidos y resolubles con varias semillas | `test_generator.gd` (más de 150 niveles) |
| Todos los objetos se pueden tocar con raycast real, en orden de solución, desde algún punto de observación | `test_room_scene.gd` (660 objetos en 6 habitaciones, de 30 a 240 objetos) |
| La escena se ve bien | Capturas renderizadas con OpenGL (Mesa/Xvfb) usando `tools/screenshot.gd` |
| Se genera el APK debug firmado | GitHub Actions, artifact `clutteria-apk` |

**No verificado:** no se ejecutó en un dispositivo Android real, así que no hay
medición de FPS ni memoria en teléfono (para eso está el overlay de FPS, ver
abajo), ni se probó la sensación del tacto real. El equilibrio de tiempos y
economía es una **primera propuesta** que hay que calibrar con jugadores.

## Cómo se juega

- **Arrastrar un dedo:** girar la vista 360° (arriba/abajo con límites).
- **Pellizcar con dos dedos:** zoom (rueda del mouse en PC).
- **Botones 1-2-3 o círculos celestes del piso:** cambiar de punto de observación.
- **Respuesta al tocar:** el espacio de la bandeja donde cae el objeto late;
  los tríos tienen destello, estrellas y sonido que sube de tono en combos;
  la bandeja late en rojo con 6 ocupados; vibración opcional (Opciones).
- **Cajones:** tocarlos los abre; tocar el frente de uno abierto lo cierra.
- **Basura decorativa:** montones bajo cada pila, papeles, bolsas y cartones
  (MultiMesh). No se recogen y van desapareciendo a medida que limpiás.
- **Objetos tapados:** se ven más oscuros; al tocarlos se resalta lo que hay
  que sacar primero.
- **Velocidad de cámara:** por defecto casi al mínimo; se ajusta en Opciones.
- **Tocar basura:** desaparece al instante y va a la bandeja de 7 espacios.
  La selección es *asistida*: se elige el objeto visible más próximo al
  toque dentro de un radio chico, y nunca uno tapado por otro.
- **Tres objetos con el mismo ID exacto** se eliminan. Los parecidos (misma
  botella con otra etiqueta, otro tamaño, etc.) no forman trío.
- **Rombo amarillo:** cajones, cajas y almohadones que se abren o levantan.
  Explorar no ocupa la bandeja.
- **Caja violeta con "?":** caja misteriosa, se abre al tocarla
  (monedas 50 %, herramienta 30 %, tesoro 20 %; las probabilidades se muestran
  en la tienda; no se vende nada con dinero real).
- **Llave dorada:** desbloquea la habitación secreta de esa casa.
- **Herramientas:** Papelera (descarta un objeto de la bandeja junto con su
  trío), Imán (completa un trío válido), Mezclador (reordena la basura visible
  y sólo acepta mezclas que el solver confirma resolubles), Reloj (+30 s).
- **Bandeja llena sin trío:** se pausa y se ofrece Papelera o Imán. Si no
  tenés ninguna, perdés (y una vida si es un nivel nuevo).
- **Restauración (sin reloj):** frotá las manchas (mínimo 85 %); arreglos
  propios de cada habitación (vidrio roto, lámpara que parpadea) que se tocan
  en la habitación; los muebles también se eligen tocándolos, elegí pintura
  (básicas gratis, especiales con monedas; se pinta sola con animación) y
  reparar o reemplazar muebles. Al final se muestra antes/después y el valor
  agregado.

## Reglas de vidas y progreso

- 5 vidas máximo. Se pierde una **sólo** al perder un nivel nuevo del modo
  historia (tiempo agotado o bandeja bloqueada). Repetir habitaciones y los
  encargos nunca arriesgan vidas.
- Regeneración: 1 vida cada `Balance.LIFE_REGEN_SECONDS` (20 min por defecto).
  También: desafío diario (2+ estrellas = +1 vida y +50 monedas, una vez por
  día) y anuncios recompensados **sólo si** se integra un SDK (ver abajo).
- Tras perder: *Reiniciar gratis* o *Continuar* por 60 monedas
  (+45 s si fue por tiempo; si fue por bandeja, devuelve 3 objetos a la
  habitación y suma 30 s). Elegir no descuenta otra vida.
- Estrellas: 1 por terminar, 1 por terminar con ≥30 % del tiempo sin
  continuar, 1 por el desafío de la habitación. La primera vez que se logran
  3 estrellas se gana una herramienta.
- Las primeras dos propiedades son gratis. Las demás se compran; al restaurar
  todas sus habitaciones (las secretas son opcionales) se venden
  automáticamente mostrando compra, inversión, venta y ganancia neta.
- Barrios: se desbloquean con estrellas + monedas. Si faltan monedas siempre
  hay encargos y habitaciones para repetir, así que no hay bloqueo económico.

## Estructura

```
project.godot, export_presets.cfg
scenes/                 main_menu, map, room (raíz + script; la UI se arma por código)
src/autoload/game.gd    perfil, progreso, partida en curso, guardado
src/autoload/sfx.gd     sonidos sintetizados, bus SFX, volumen/silencio
src/core/               lógica pura, sin render (se prueba en headless)
  balance.gd            todos los números de equilibrio
  trash_catalog.gd      familias y variantes de basura (IDs exactos)
  property_catalog.gd   layouts de habitaciones, propiedades, barrios
  layout_geometry.gd    celdas libres, cajones, visibilidad por punto de vista
  level_generator.gd    generación por semilla (construcción inversa)
  level_state.gd        accesibilidad y posiciones de reposo (reacomodamiento)
  solver.gd             simulador de solvencia independiente
  room_session.gd       reglas de partida (bandeja, tiempo, herramientas, estrellas)
  tray.gd, economy.gd, save_store.gd, rewarded_ads.gd
src/game/               escena 3D: mallas procedurales, vista, controlador, shaders
src/ui/                 HUD, bandeja con miniaturas 3D, restauración, menús, mapa
tests/                  pruebas automáticas
tools/                  check_scripts.gd, screenshot.gd
.github/workflows/      pruebas + APK
```

Agregar contenido sin tocar código del juego: nuevas variantes en
`trash_catalog.gd`, nuevos layouts/propiedades/barrios en
`property_catalog.gd`, valores en `balance.gd`. Las pruebas recorren todo el
catálogo, así que un layout inválido (sin espacio, objetos invisibles) falla
en CI.

### Tensión de la bandeja según la dificultad

- La solución intercala tríos: hasta 1, 2 o 3 tríos pueden quedar "a medias"
  (`LevelGenerator.max_open_for`). La bandeja nunca necesita más de 6 objetos.
  En habitaciones con el desafío "no más de 5 espacios" se usan como mucho 2.
- Con dificultad aparecen pilas "señuelo": piezas de los últimos tríos, a la
  vista desde el principio, cuyas compañeras están enterradas.
- Más dificultad = más variantes distintas. Medido en el living con 90
  objetos: lo visible que ya forma tríos listos baja de ~61 % (fácil) a ~42 %
  (difícil).

### Cómo se garantiza que los niveles son resolubles

1. Cada variante aparece en múltiplos de 3.
2. **Construcción inversa:** se arma una secuencia solución de tríos y se
   apilan las piezas de abajo hacia arriba en orden inverso, así lo que tapa a
   un objeto siempre pertenece a un trío anterior. Las pilas sólo usan celdas
   libres de muebles, fuera de las zonas de apertura de cajones, y visibles
   desde algún punto de observación; cada objeto cabe en su celda (sin
   intersecciones).
3. **Validación independiente:** `Solver` (búsqueda con heurística y
   presupuesto) resuelve el nivel respetando bandeja de 7, capas y tríos
   exactos. El Mezclador usa el mismo solver antes de aceptar una mezcla.
4. **Validación física:** la prueba de escena apunta la cámara a cada objeto
   desde los puntos de observación y comprueba con raycast + línea de visión
   que el toque lo selecciona.

## Ejecutar en Godot

1. Instalar **Godot 4.3 estable** (versión estándar, no .NET).
2. Abrir `project.godot` y ejecutar (F5). En PC el mouse emula el tacto;
   la rueda hace zoom.
3. Semilla fija para depurar: `godot --path . -- --seed=1234`. La semilla de
   la partida se muestra en el menú de pausa.

Pruebas y chequeos (headless):

```bash
godot --headless --path . --import
godot --headless --path . -s tools/check_scripts.gd
godot --headless --path . -s tests/run_tests.gd            # todas
godot --headless --path . -s tests/run_tests.gd -- session # filtrar por suite
```

En modo headless el motor puede imprimir `Parameter "m" is null` (renderer
"dummy" de Godot 4.3); es ruido de log, no una falla. CI lo filtra.

Capturas (requiere GPU o Xvfb + Mesa):

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/screenshot.gd -- /tmp/capturas
```

## Exportar el APK

### Con GitHub Actions (recomendado)

Cada push ejecuta `.github/workflows/android.yml`: descarga Godot 4.3 y las
plantillas oficiales, instala `build-tools;34.0.0`, genera un keystore de
depuración temporal, corre chequeos y pruebas, y exporta
`build/clutteria-debug.apk`. El APK queda en **Actions → la ejecución →
Artifacts → `clutteria-apk`**; los logs en el artifact `logs`.

**Versión firmada de publicación:** agregá en *Settings → Secrets and
variables → Actions*:

- `ANDROID_KEYSTORE_BASE64`: tu keystore en base64 (`base64 -w0 release.keystore`)
- `ANDROID_KEYSTORE_USER`: alias de la clave
- `ANDROID_KEYSTORE_PASSWORD`: contraseña

Con esos secretos el workflow también genera `clutteria-release.apk`
(Godot lee `GODOT_ANDROID_KEYSTORE_RELEASE_*`). Sin secretos ese paso se
omite. Nunca se guardan credenciales en el repositorio. Para crear un keystore:

```bash
keytool -genkeypair -v -keystore release.keystore -alias clutteria \
  -keyalg RSA -keysize 2048 -validity 10000
```

Para Google Play conviene AAB: activar `gradle_build/use_gradle_build`,
instalar la plantilla de build Android (`--install-android-build-template`)
y `gradle_build/export_format=1`.

### Local

Requisitos: JDK 17, Android SDK con `platform-tools` y `build-tools`
(34.0.0 sirve), plantillas de exportación 4.3 (Editor → Manage Export
Templates). En *Editor Settings → Export → Android* configurar la ruta del
SDK, la del JDK y un keystore de depuración. Luego:

```bash
godot --headless --path . --export-debug "Android" build/clutteria-debug.apk
```

## Rendimiento (Android gama media)

- Cada objeto de basura es **una sola malla** (primitivas combinadas con
  colores por vértice) con un material compartido: 1 draw call por objeto.
- Sin sombras dinámicas; 1 luz direccional + 1 omni + luz de ventana; luz
  ambiente simple. Sin texturas: el piso, las paredes y las manchas son shaders
  procedurales livianos.
- Sin cuerpos rígidos: sólo colisiones estáticas para el raycast. Las pilas
  se "reacomodan" bajando las piezas cuando falta la de abajo (decisión
  abierta: se podrían agregar físicas puntuales más adelante).
- La bandeja usa 7 SubViewports chicos que sólo se redibujan al cambiar.
- **Medir en dispositivo:** Opciones → *Mostrar FPS y memoria* muestra FPS,
  memoria estática y objetos dibujados en el HUD.

## Anuncios recompensados (opcional)

No se incluye ningún SDK. `src/core/rewarded_ads.gd` define la interfaz: si se
asigna `RewardedAds.provider` (un objeto con `is_ready()` y
`show_rewarded(callback)`), el menú muestra "Ver anuncio: +1 vida"; si no, el
botón no aparece y las vidas se recuperan esperando o con el desafío diario.

## Calibración (pendiente con jugadores)

`Balance.level_time()` estima el tiempo según cantidad de objetos, proporción
de variantes parecidas, profundidad de pilas, objetos escondidos, contenedores
y puntos de vista. Es un punto de partida (30 objetos ≈ 2:35; 90 ≈ 7:30; 240 ≈ 17 min).
Para calibrar: registrar tiempo real usado vs. disponible por habitación y
ajustar los coeficientes en `balance.gd`. Lo mismo para precios, recompensas
y costo de continuar.

## Limitaciones conocidas

- Arte provisional: mallas low-poly procedurales y sonidos sintetizados.
- Las "casas de dos pisos" y la mansión reutilizan los 6 layouts de
  habitación (no hay escaleras ni recorrido entre habitaciones).
- Los muebles reemplazados usan la misma forma con otra paleta.
- El tutorial es contextual (mensajes que avanzan con tus acciones), no
  bloquea el resto de la interfaz.
- No probado en dispositivo real (ver tabla de verificación).

## Próximos pasos sugeridos

1. Probar en 2-3 teléfonos de gama media: FPS, memoria, tamaño de botones y
   sensibilidad del giro.
2. Sesiones de juego para calibrar tiempos, precios y dificultad.
3. Arte final (modelos/texturas comprimidas ETC2/ASTC) manteniendo los IDs
   del catálogo; sonidos grabados.
4. Más layouts (cocinas y livings grandes para la mansión) y variantes.
5. AAB para Google Play e íconos de lanzador propios.
