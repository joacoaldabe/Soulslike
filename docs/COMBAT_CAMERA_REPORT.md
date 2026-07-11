# Núcleo de combate y cámara

## Resultado

La vertical slice conserva su escenario, modelos, materiales, HUD, inventario y progresión. El cambio se limita al núcleo de combate, cámara, animación procedural relacionada y pruebas.

La validación manual desde la cámara real confirmó:

- el jugador muestra la espalda a la cámara y su frente coincide con el movimiento;
- el ataque con lock-on conectó con el Hollow visible a 1,52 m, con 0 grados de error respecto del objetivo y 2,0 m de alcance;
- una esquiva intencional iniciada durante el wind-up terminó con salud `736 -> 736` y poise `80,4 -> 80,4`, mientras el enemigo pasó a recovery.

## Causa de la orientación invertida

No existía una única rotación local de 180 grados que pudiera corregirse en el modelo. La causa era la mezcla de responsabilidades: el mouse rotaba el `CharacterBody3D`, la cámara era hija directa de ese cuerpo, el movimiento se calculaba desde la base del cuerpo sin orientarlo hacia la dirección recorrida y el ataque volvía a consultar `-basis.z` al momento del impacto. Por eso la cámara, la dirección visual, el desplazamiento y el golpe podían comunicar frentes distintos.

La solución usa una sola convención y separa la órbita de cámara del cuerpo. No hay inversiones de signo repartidas entre scripts.

## Convención espacial

- Forward lógico del jugador: `Vector3.FORWARD`, equivalente a `-Z` en Godot.
- Forward visual del jugador: `Vector3.FORWARD` (`-Z`). Cara, pecho y arma se construyen hacia ese eje.
- Forward de enemigos: `-global_transform.basis.z`.
- Forward planar de cámara: `-camera_pivot.global_transform.basis.z`, proyectado en XZ.
- Dirección de movimiento: combinación del forward y right planares de cámara.
- Dirección de ataque: lock-on, input actual, movimiento reciente o forward de cámara, en ese orden.
- Lock-on y comprobaciones de alcance/arco consumen la misma dirección de ataque.
- Cualquier adaptación visual queda dentro de `PlayerModel` o `EnemyModel`; los controladores no agregan giros compensatorios de 180 grados.

## Cámara

El rig es top-level e independiente de la rotación del jugador: `CameraRig -> CameraPitch -> SpringArm3D -> Camera3D`.

| Parámetro | Valor |
| --- | ---: |
| Distancia normal | 5,35 m |
| Distancia lock-on | 6,25 m, hasta +1,0 m según separación |
| Altura de pivote | 1,62 m |
| Altura de enfoque | 1,15 m |
| Offset lateral | 0,42 m |
| Offset de yaw en lock-on | -10,5 grados |
| Pitch inicial | -14 grados |
| Límites de pitch | -42 / +18 grados |
| FOV normal | 68 grados |
| Sensibilidad horizontal / vertical | 0,0038 / 0,0030 |
| Seguimiento / rotación | 18 / 7,5 |
| Recuperación de colisión | 9 |
| Distancia mínima de colisión | 1,05 m |

El `SpringArm3D` colisiona sólo con escenario (capa 1), recupera distancia suavemente y amplía el FOV hasta 74 grados cuando queda cerca de una pared. El lock-on interpola yaw y distancia; no rota de forma instantánea.

## Modelo de acciones

`CombatAction` centraliza fases, duración, progreso total y por fase, rotación, movimiento, hitbox, encadenado, interrupción e invulnerabilidad.

- Ataque: `windup -> active -> recovery`.
- Roll: `prepare -> impulse -> invulnerable -> travel -> landing -> recovery`.
- Stagger: acción exclusiva que cancela ataque y desactiva inmediatamente su hitbox.
- Muerte: domina todas las capas y cancela cualquier acción pendiente.

Las capas procedurales se aplican en este orden: pose base, locomoción/acción principal, reacción de impacto y muerte. Cada frame parte de una pose neutral para evitar residuos o tweens competidores.

## Jugador

- Ligero: wind-up corto, swing acelerado, ventana activa breve, lunge moderado y recovery encadenable en su tramo tardío.
- Pesado: wind-up y recovery más largos, mayor coordinación de pelvis/torso/brazos/piernas, más daño de poise, hit stop y shake.
- El tracking sólo ocurre durante wind-up; la ventana activa no puede girar 180 grados.
- Espada, hacha, lanza y maza conservan poses propias y coordinan cadera, torso, cabeza, brazos, piernas y arma.
- El roll usa dirección de input. Sin input y con lock-on retrocede; los laterales respetan el eje de cámara.
- I-frames: sólo durante `invulnerable` (0,235 s), después de `prepare` (0,05 s) e `impulse` (0,035 s).
- El desplazamiento físico está separado de la rotación visual del rig.

## Enemigos

| Enemigo | Telegraph corporal | Wind-up | Activa | Recovery | Poise |
| --- | --- | ---: | ---: | ---: | ---: |
| Hollow Sword | retrasa hombro y espada, rota el torso | 0,48 s | 0,17 s | 0,62 s | 44 |
| Axe Brute | eleva el hacha por encima y carga el peso atrás | 0,86 s | 0,24 s | 0,94 s | 110 |
| Spear Guard | retrae y alinea la lanza antes de estocar | 0,64 s | 0,16 s | 0,74 s | 72 |
| Ash Hound | baja el cuerpo y se comprime antes de embestir | 0,38 s | 0,18 s | 0,48 s | 32 |

Los cuatro reducen o detienen persecución en wind-up, bloquean la dirección al entrar en active, aplican daño sólo en esa fase y quedan expuestos durante recovery. Cada ataque posee rango, arco, cooldown, tracking, lunge, daño de vida, daño de poise, fuerza e ID único.

## Poise e impacto

Jugador y enemigos tienen poise máximo/actual, demora de recuperación, tasa de recuperación, stagger e inmunidad breve posterior. La defensa equipada aumenta el poise del jugador. Los ataques pesados reducen más poise y el Brute necesita varios impactos para caer en stagger.

`CombatHit` transporta atacante, daño, daño de poise, dirección, punto, fuerza, tipo e ID. El receptor centraliza la aplicación, rechaza IDs repetidos, deriva la reacción de la dirección real y no tambalea si ya murió.

El feedback incluye reacción corporal direccional, partícula procedural de impacto, hit stop de 0,035 s para golpes comunes y hasta 0,07 s para pesados, y shake moderado de cámara. No se añadieron sonidos porque el proyecto no contiene recursos de audio apropiados.

## Archivos

Creados:

- `scripts/combat/CombatAction.gd`
- `scripts/combat/CombatHit.gd`
- `tests/CombatCoreValidation.gd`
- `tests/CombatAcceptanceValidation.gd`
- `tests/CombatVisualCapture.gd`
- `tests/ManualCombatPlaytest.gd`
- `docs/COMBAT_CAMERA_REPORT.md`
- `docs/screenshots/combat/*.png`

Modificados:

- `scripts/Player.gd`
- `scripts/PlayerModel.gd`
- `scripts/Enemy.gd`
- `scripts/visual/EnemyModel.gd`
- `scripts/Main.gd`
- `scripts/data/EnemyData.gd`
- `data/enemies/hollow_sword.tres`
- `data/enemies/axe_brute.tres`
- `data/enemies/spear_guard.tres`
- `data/enemies/ash_hound.tres`
- `tests/VisualSmoke.gd`

## Pruebas

- `CombatCoreValidation.gd`: `COMBAT_CORE_OK`.
- `CombatAcceptanceValidation.gd`: `COMBAT_ACCEPTANCE_OK` en dos ejecuciones finales consecutivas; cubre los 25 escenarios obligatorios, incluidos los cuatro arquetipos.
- `VisualSmoke.gd`: `VISUAL_SMOKE_OK`; ejecución con render Vulkan a 143 FPS y repetición headless a 145 FPS. En headless se omite sólo la escritura de PNG, no los checks de juego.
- Validación manual interactiva desde la cámara real: orientación, cámara relativa, lock-on, alcance, dirección de golpe, wind-up, roll, i-frames y recovery.
- `git diff --check`: sin errores de whitespace.

Capturas conservadas:

- `docs/screenshots/combat/camera_orientation.png`
- `docs/screenshots/combat/player_attack_active.png`
- `docs/screenshots/combat/enemy_windup.png`
- `docs/screenshots/combat/player_stagger.png`
- `docs/screenshots/combat/intentional_roll_dodge.png`

## Limitaciones y ajuste posterior

- Los modelos y animaciones siguen siendo procedurales low-poly, sin `Skeleton3D` ni motion capture.
- Las ventanas de golpe usan alcance y arco data-driven durante la fase activa, no volúmenes `Area3D` ligados al filo cuadro por cuadro.
- Cada arquetipo dispone de un ataque principal; todavía no hay cadenas o variaciones por distancia.
- Con debug activado, el `Label3D` puede tapar parcialmente al objetivo cercano. Está desactivado en juego normal.
- En una prueba anterior con renderer GL compatibility apareció un aviso de caché de shader; las ejecuciones finales Vulkan y headless no mostraron errores de proyecto.
- Ajustes recomendados después de playtesting: `camera_lock_distance`, `camera_lock_yaw_offset`, i-frames entre 0,21 y 0,25 s, lead de telegraph por enemigo y daño de poise según armadura.
