# Menu principal y guardado persistente

## Arquitectura

- `SaveManager` coordina lectura, validacion, version y escritura segura del archivo. Obtiene datos serializables de los sistemas existentes y no conoce nodos visuales.
- `GameSession` conserva la solicitud de inicio (`NEW_GAME` o `LOAD_GAME`) durante el cambio de escena y entrega una carga pendiente una sola vez.
- `GameState` exporta e importa progreso, atributos, recursos y estado global del mundo.
- `Inventory` exporta e importa cantidades y equipamiento, validando que los identificadores existan y correspondan al slot.
- `MainMenu` controla solamente la interfaz, confirmaciones y navegacion hacia la escena jugable.
- `Main` aplica la carga en orden: clase predeterminada, inventario, estado del jugador/mundo y resolucion del bonfire de aparicion.

## Archivo de guardado

La partida unica se guarda en `user://soulslike_save.json`. La ruta fisica depende del sistema operativo y del nombre del proyecto. Las pruebas usan `user://soulslike_save_test.json` y lo eliminan al finalizar.

La version actual es `1`:

```json
{
  "save_version": 1,
  "player": {
    "class_id": "knight",
    "level": 8,
    "souls": 2345,
    "souls_to_next_level": 1360,
    "health": 568,
    "max_health": 568,
    "stamina": 178,
    "max_stamina": 178,
    "attributes": {},
    "effective_attributes": {},
    "lost_souls": 0,
    "has_bloodstain": false,
    "bloodstain_position": [0, 0, 0]
  },
  "inventory": {
    "item_counts": {},
    "equipment": {
      "right_weapon": "longsword",
      "armor": "knight_set",
      "ring_1": "",
      "ring_2": "",
      "consumable": "green_estus"
    }
  },
  "world": {
    "discovered_bonfires": ["ash_camp"],
    "last_bonfire_id": "ash_camp",
    "church_completed": false
  }
}
```

Solo se guardan valores primitivos, arrays, diccionarios e identificadores estables. La escritura usa un archivo `.tmp`; si ya existe una partida, la conserva temporalmente como `.bak` hasta publicar correctamente el reemplazo.

## Flujo

### Nuevo juego

`MainMenu` consulta si existe una partida valida. Si existe, muestra una confirmacion. Solo despues de confirmar se elimina el archivo anterior, se limpia el estado de runtime y se abre `Main` en modo nuevo. El creador de personaje existente define las estadisticas y el inventario iniciales.

### Guardado

Interactuar con un bonfire lo descubre y abre su menu, pero no guarda. Al confirmar `Descansar`, `Main` actualiza el ultimo bonfire, restaura vida y stamina, respawnea enemigos y finalmente llama a `SaveManager.save_game()`.

### Carga

`Cargar juego` solo se habilita si el JSON existe y su estructura base es valida. `GameSession` mantiene los datos durante el cambio de escena. `Main` construye el mundo, aplica inventario y progreso, busca el bonfire por `bonfire_id` y crea al jugador en su punto de aparicion. Si el identificador ya no existe, usa `ash_camp` y registra una advertencia.

## Extender el formato

1. Agregar el campo al metodo `get_save_data()` del sistema propietario.
2. Leerlo en `apply_save_data()` con `Dictionary.get(campo, valor_predeterminado)`.
3. Mantener la validacion del tipo y rango antes de aplicar el valor.
4. Agregar una prueba de ida y vuelta en `SaveAndMainMenuValidation.gd`.
5. Incrementar `SAVE_VERSION` si el cambio no es compatible con partidas anteriores.

Para una futura migracion, `SaveManager` debe transformar una copia del diccionario desde la version guardada hasta la version actual antes de entregarla a `GameSession`. Nunca se deben guardar rutas de nodos o referencias a instancias.

## Identificadores de bonfire

Cada recurso de `data/bonfires/` debe definir un `bonfire_id` unico y permanente. El recurso debe registrarse en `Database.BONFIRE_PATHS`. El identificador no debe derivarse del nombre del nodo, su posicion ni su orden en la escena.

## Validacion manual

1. Ejecutar el proyecto y comprobar que abre el menu principal.
2. Elegir `Nuevo juego`, crear un personaje y descansar desde el menu de un bonfire.
3. Volver a iniciar el proyecto y comprobar que `Cargar juego` esta habilitado.
4. Cargar y verificar nivel, souls, vida, stamina, inventario, equipo y posicion.
5. Descubrir otro bonfire, descansar en el y repetir la carga.
6. Elegir `Nuevo juego`, cancelar la confirmacion y comprobar que la partida anterior sigue disponible.
7. Confirmar la sobrescritura y comprobar que vuelve a aparecer el creador de personaje.

## Archivos

### Creados

- `scripts/autoload/SaveManager.gd`
- `scripts/autoload/GameSession.gd`
- `scripts/MainMenu.gd`
- `scenes/MainMenu.tscn`
- `tests/SaveAndMainMenuValidation.gd`
- `docs/SAVE_SYSTEM.md`

### Modificados

- `project.godot`
- `scripts/autoload/GameState.gd`
- `scripts/autoload/Inventory.gd`
- `scripts/Bonfire.gd`
- `scripts/Main.gd`
- `scripts/UI.gd`

## Limitaciones conocidas

- Existe un unico slot de guardado.
- La seccion Configuracion es un placeholder y no persiste opciones.
- El estado individual de cofres y enemigos no forma parte de la version 1; al cargar se reconstruyen con el comportamiento normal de la escena.
- Las migraciones estan preparadas a nivel de versionado y valores predeterminados, pero no hay migraciones historicas porque solo existe la version 1.
