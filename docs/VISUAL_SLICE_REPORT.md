# Informe de la vertical slice visual

## Diagnostico inicial

El prototipo utilizaba una arena plana de 38 metros, cuatro cajas como obstaculos, enemigos representados por CapsuleMesh, un bonfire formado por un cilindro y una esfera emissive, y una mancha de souls basada en una esfera achatada. El jugador ya tenia una jerarquia modular funcional, pero torso, manos, pies, extremidades y armas revelaban directamente las primitivas empleadas. El HUD mostraba valores tecnicos con el aspecto visual por defecto de Godot.

## Direccion elegida

La direccion `Ruinas de Ceniza` combina fantasia medieval oscura con geometria low-poly facetada, piedra azul grisacea, metal frio, cuero y tela desaturados. El fuego y las souls son los unicos elementos de alta saturacion. Las reglas completas se encuentran en `docs/ART_DIRECTION.md`.

## Placeholders reemplazados

- Arena plana y bloques de prueba por un patio medieval modular.
- Capsulas enemigas por cuatro modelos articulados con siluetas propias.
- Espada rectangular por una hoja perfilada con grosor y componentes separados.
- Bonfire cilindrico por un hogar de piedra, madera, espada, fuego y brasas.
- Mancha esferica por un charco espectral pulsante con motas ascendentes.
- Materiales planos del entorno por materiales compartidos con variacion procedural.
- HUD por defecto por una interfaz sobria con barras y paneles tematizados.

## Jugador y armaduras

El jugador conserva la jerarquia articulada de `PlayerModel`, pero utiliza volumenes con seccion variable para pelvis, abdomen, pecho, extremidades, manos y botas. La pose mantiene rodillas flexionadas, brazos cercanos al cuerpo y postura especifica por arma.

El kit visual incluye cinco apariencias reutilizables:

- ligera de cuero;
- media tipo brigantina;
- pesada con coraza, yelmo, visor, hombreras y brazales;
- tunica con falda y capucha para clases magicas o religiosas;
- envoltura minima para Deprived.

Las diez clases seleccionan una variante sin duplicar atributos ni datos jugables. Los slots de cabeza, rostro, torso, espalda, hombros, brazos, manos, cadera, piernas, pies y armas siguen disponibles.

## Armas

Se mantienen las cuatro familias existentes:

- Longsword con hoja convergente, nervio central, guarda, empunadura y pomo;
- Battle Axe con mango, nucleo, filo y contrapeso;
- Winged Spear con asta, punta y alas;
- Mace con mango, cabeza y bridas.

Cada familia conserva su montaje en `right_weapon` y sus poses de ataque ligero y pesado. Daño, requisitos, escalado y stamina no fueron modificados.

`WeaponData` incorpora metadatos exclusivamente visuales para PackedScene opcional, escala y transform en mano, transform guardada y efecto opcional. Un GLB puede asignarse sin intervenir en los calculos de combate.

## Enemigos

- Hollow con capucha, tela desgastada y espada.
- Guardia pesado de mayor escala, armadura y hacha.
- Lancero con cresta, silueta vertical y lanza larga.
- Ash Hound cuadrupedo con craneo, cuernos y proporciones no humanas.

Todos conservan CharacterBody3D, colision e IA independientes del mesh. Se agregaron marcador de lock-on y una caida visual breve antes de liberar el enemigo.

## Entorno

El patio incluye pavimento irregular mediante MultiMesh, muros perimetrales, columnas enteras y rotas, arco segmentado, escaleras, escombros, estandartes y una aguja lejana. Las colisiones siguen siendo simples. Toda la zona generada cuelga de `ReplaceableRuinedCourtyard`, lo que permite sustituirla por una escena o GLB sin cambiar spawns, enemigos, bonfires o UI.

## Materiales, shaders y efectos

`VisualLibrary` centraliza piedra clara, oscura y humeda; metal; cuero; madera; telas; piel; hueso; musgo; fuego y souls. La piedra utiliza un shader procedural compartido con variacion por posicion, orientacion y humedad. Fuego y souls emplean emision moderada.

Efectos creados:

- brasas ascendentes y luz pulsante del bonfire;
- motas, pulso de escala y luz verde de la mancha;
- marcador emissive de lock-on;
- reaccion de impacto y caida de enemigos.

## Iluminacion y UI

La escena usa luz direccional fria con sombras, ambiente azul gris, tonemapping filmic, niebla de altura y luces calidas locales. El HUD diferencia vida, energia, souls, nivel y arma sin mostrar calculos internos. Inventario, creador y menu de bonfire comparten paneles oscuros, bordes metalicos y estados de botones coherentes.

## Archivos principales

Nuevos:

- `docs/ART_DIRECTION.md`
- `docs/VISUAL_SLICE_REPORT.md`
- `docs/screenshots/vertical_slice_after.png`
- `docs/screenshots/bonfire_world.png`
- `docs/screenshots/bonfire.png`
- `docs/screenshots/bloodstain.png`
- `docs/screenshots/prototype_before_reconstruction.png`
- `docs/screenshots/visual_comparison.png`
- `scripts/visual/VisualLibrary.gd`
- `scripts/visual/EnemyModel.gd`
- `tests/VisualSmoke.gd`
- `tests/BaselineVisualReference.gd`

Modificados:

- `scripts/Main.gd`
- `scripts/Player.gd`
- `scripts/PlayerModel.gd`
- `scripts/Enemy.gd`
- `scripts/Bonfire.gd`
- `scripts/Bloodstain.gd`
- `scripts/UI.gd`

## Pruebas ejecutadas

Godot 4.7 estable cargo el proyecto y `Main.tscn` sin errores de parseo, recursos faltantes o referencias nulas. `tests/VisualSmoke.gd` valido:

- las diez clases y sus apariencias;
- las cuatro armas visibles y sus ataques pesados;
- caminar, roll, ataque ligero y stamina;
- lock-on y correccion de camara contra muros;
- cuatro enemigos, daño, muerte, recompensa y caida;
- muerte del jugador, respawn, bloodstain y recuperacion de souls;
- descubrimiento, descanso y viaje entre bonfires;
- subida de nivel y gasto de souls;
- apertura de inventario;
- captura renderizada desde la camara real;
- 174 FPS medidos durante la prueba en una RTX 3080 con renderer Compatibility.

Resultado: `VISUAL_SMOKE_OK`.

La comparacion `docs/screenshots/visual_comparison.png` enfrenta una reconstruccion renderizada a partir de las primitivas y parametros del codigo inicial con la captura actual de `Main.tscn`. La referencia anterior esta identificada explicitamente como reconstruccion y no como captura historica original.

## Sustitucion por GLB

1. Importar el GLB en una carpeta de assets sin modificar sus escalas de importacion despues de ajustar el montaje.
2. Para el jugador, conservar la escena `PlayerModel.tscn` como adaptador y reemplazar solamente los MeshInstance3D bajo sus joints. Mantener los nombres de slots y los metodos publicos de pose/equipamiento.
3. Para enemigos, reemplazar el contenido de `EnemyModel/ReplaceableModel`; no mover CharacterBody3D ni CollisionShape3D.
4. Para armas, instanciar el GLB dentro de `right_weapon`, ajustando transform local en el constructor visual de la familia. No conectar hitboxes al mesh.
5. Para el entorno, reemplazar `ReplaceableRuinedCourtyard` por la escena importada y conservar fuera de ella bonfires y spawn points.
6. Aplicar materiales al GLB desde su escena visual. Los Resources de gameplay no necesitan cambios.

## Limitaciones conocidas

- Las animaciones son poses procedurales articuladas, no clips capturados o animaciones esqueletales de un artista.
- No existen UVs ni texturas pintadas; la riqueza superficial depende de materiales y geometria.
- Cabeza y manos no poseen rig facial ni dedos individuales.
- El escenario esta pensado como una unica arena, no como kit terminado para un mundo completo.
- La prueba automatizada confirma contratos y rendimiento de esta escena, pero el feel de combate y clipping en sesiones prolongadas requiere revision manual.

## Revision manual pendiente

- Jugar varios minutos con cada familia de arma y evaluar lectura de anticipacion e impacto.
- Recorrer lentamente todos los limites mientras se rota la camara.
- Revisar HUD, inventario y menus en 1280x720, 1920x1080 y formato ultrawide.
- Confirmar que la niebla y emision se mantienen legibles en Forward+ y Compatibility.
- Revisar transiciones entre todas las poses desde angulos laterales y frontales.

## Proximos pasos por impacto

1. Sustituir el rig procedural por un humano GLB low-poly con Skeleton3D y clips pulidos.
2. Crear texturas pintadas y trimsheets compartidos para piedra, metal, cuero y tela.
3. Añadir animaciones de anticipacion, impacto, recuperacion y stagger especificas por arma.
4. Incorporar decals, vegetacion seca y variaciones de ruinas para romper la repeticion restante.
5. Crear VFX de golpe, polvo, chispas y trails discretos sincronizados con el combate.
