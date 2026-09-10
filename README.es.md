# roblox-dev

**Un plugin de Claude Code para desarrollo de juegos en Roblox.** Skills que
hacen que Claude escriba código Roblox/Luau como lo escriben los ingenieros
con experiencia real en Roblox: remotes a prueba de exploits, DataStores que
no pierden el progreso de los jugadores, loops de frame que no fugan memoria,
y tipado `--!strict` por defecto.

*Read in English: [README.md](README.md)*

## Por qué

Claude escribe buen Lua. Pero Roblox no es Lua: es un entorno de red hostil
donde cada cliente es un exploiter potencial, las llamadas a DataStore fallan
con regularidad, y una conexión de evento fugada por respawn termina en un
servidor caído. El código Roblox generado por IA genérica falla en estas
cosas de formas que solo descubrís en producción.

Este plugin codifica los patrones de los que un juego de Roblox en producción
vive o muere — extraídos de desarrollo real — para que Claude los aplique
automáticamente cada vez que trabajás en código Luau.

## Instalación

```
/plugin marketplace add ivar-anon/roblox-dev
/plugin install roblox-dev@roblox-dev
```

O probalo por una sesión:

```bash
git clone https://github.com/ivar-anon/roblox-dev
claude --plugin-dir ./roblox-dev
```

## Qué incluye

### Skills (se activan solas mientras trabajás)

| Skill | Qué hace bien Claude con ella |
| --- | --- |
| **roblox-security** | Autoridad del servidor, la escalera completa de validación de remotes (tipo → rango → permiso → plausibilidad), payloads NaN/infinito, rate limiting, chequeos de distancia, checklist de superficies de exploit |
| **roblox-datastores** | `UpdateAsync` en vez de Get+Set, reintentos con backoff, session locking, `BindToClose`, versionado y migración de esquemas, "carga fallida ≠ jugador nuevo" |
| **roblox-performance** | Prevención de fugas de conexiones con disciplina de cleanup, reglas de asignación por frame, batching de red, UnreliableRemoteEvents, supervivencia con StreamingEnabled, flujo de profiling |
| **luau-strict-typing** | `--!strict` por defecto, idiomas de narrowing de `Instance?`, declaraciones adelantadas, payloads de remotes tipados, el idioma de tipado OOP con metatables, arreglos de errores comunes |
| **roblox-architecture** | Bootstrap con un solo punto de entrada (init/start en dos fases), ModuleScripts en vez de `_G`, remotes como frontera de API tipada, managers con CollectionService, tabla de decisión de dónde vive el código |
| **roblox-ui** | Layout responsivo con Scale, vocabulario de animación con TweenService, clipping/fades con CanvasGroup, encuadre de ViewportFrames por bounding box, trampas de partículas, cheatsheet de game feel |
| **roblox-testing** | Cheat remotes con gate de servidor (y por qué la barra de comandos de Studio te miente), diseño núcleo-puro/cáscara-fina, specs con TestEZ, checklist de playtest multi-cliente |

### Comandos

- **`/roblox-dev:setup [nombre]`** — arma un proyecto Rojo + Wally + Selene +
  StyLua con CI, puntos de entrada en modo estricto y el layout canónico.
- **`/roblox-dev:new-system <Nombre>`** — genera una rebanada vertical
  completa: tipos compartidos + módulo de servidor validado + controlador de
  cliente + registro de remotes + cheats de QA. Nunca un solo archivo
  inseguro.
- **`/roblox-dev:review [objetivo]`** — auditoría estructurada (seguridad /
  datos / performance / tipado) con hallazgos ordenados por severidad.

### Agente

- **roblox-reviewer** — un auditor de solo lectura que Claude puede lanzar
  por su cuenta después de tocar código de gameplay, con las mismas cuatro
  lentes.

## Ejemplo

La carpeta [`examples/safe-remote`](examples/safe-remote) contiene
`SafeRemote.luau` — un wrapper de remotes con tipado estricto que implementa
la escalera de validación del plugin (rate limiting por token bucket,
validadores a prueba de NaN/infinito) — con su spec de TestEZ. Muestra el
estilo de código hacia el que empujan todas las skills.

## Filosofía

1. **El servidor es dueño de la verdad.** Cada sistema generado asume
   clientes hostiles.
2. **Perder datos es una falla de diseño**, no mala suerte.
3. **El cleanup se escribe junto con la conexión**, no "después".
4. **El modo estricto es el default**, no una mejora.
5. **Si Claude no puede llegar rápido a un estado del juego, no puede ayudarte
   a testearlo** — el tooling de QA es parte de cada sistema.

## Contribuir

Issues y PRs bienvenidos — en especial patrones de exploits reales, historias
de fallas de DataStore y trampas de performance que hayas sufrido. Ver
[CONTRIBUTING.md](CONTRIBUTING.md). Las contribuciones de documentación en
español son de primera clase: este plugin se mantiene bilingüe.

## Licencia

[MIT](LICENSE)
