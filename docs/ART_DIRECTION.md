# Direccion artistica: Ruinas de Ceniza

## Paleta y contraste

- Mundo: piedra azul grisacea `#343A3D`, piedra clara `#565B58`, sombras `#171B1E`.
- Personajes: piel apagada, cuero marron oscuro, acero frio y telas vino, verde musgo o azul ceniza.
- Interactivos: fuego ambar `#FF7A24`; souls verde espectral `#55E889`.
- Saturacion baja en el mundo. El jugador conserva un valor medio mas claro que el fondo; los enemigos usan acentos oxidados.

## Forma

- Personajes de 7 a 7.5 cabezas, manos y pies levemente grandes para lectura en tercera persona.
- Siluetas asimetricas moderadas: hombrera, arma, capucha o espalda definen el arquetipo.
- Geometria facetada de 6 a 12 lados por volumen. Las articulaciones quedan solapadas bajo tela, cuero o placas.
- Armas con hoja, bisel, guarda, empunadura y pomo separados. Grosor visible desde cualquier angulo.
- Arquitectura modular en unidades de 1 m: muros de 2-4 m, columnas de 0.7 m y arcos de 3 m.

## Materiales

- Roughness alta: piedra 0.95, tela 1.0, cuero 0.85, madera 0.9.
- Metal envejecido 0.65 de roughness y metallic entre 0.45 y 0.8.
- Evitar blanco, negro y colores puros. Compartir materiales por familia.
- La variacion proviene de geometria, normales facetadas y dos tonos por material, no de ruido intenso.

## Luz y efectos

- Luz principal fria lateral, ambiente azul gris y niebla de profundidad moderada.
- Una sola luz local importante por bonfire, calida y pulsante sin sombras.
- Particulas escasas: brasas ascendentes, humo tenue y motas de souls.
- Emision reservada para fuego y souls; nunca debe borrar la forma del objeto.

## Reglas de produccion

- Visuales, colisiones y datos permanecen separados.
- Cada modelo mantiene un nodo raiz reemplazable por un GLB sin cambiar el controlador.
- Los puntos de montaje siguen `right_weapon`, `left_weapon`, cabeza, torso y extremidades.
- Priorizar la lectura desde la camara de juego: silueta, arma y direccion de ataque antes que detalle pequeno.
