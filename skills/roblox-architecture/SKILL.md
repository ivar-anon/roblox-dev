---
description: Roblox project architecture — ModuleScript patterns over _G, client/server/shared layout, bootstrapping, CollectionService managers, remote organization, and Rojo-friendly structure. Use when starting a Roblox project, adding a new system, restructuring spaghetti scripts, or deciding where code should live.
---

# Roblox Architecture

A Roblox game that survives growth has: few entry points, modules everywhere,
one obvious home for every piece of code, and remotes treated as a typed API
boundary. This skill defines that shape.

## Canonical Layout (Rojo-friendly)

```text
src/
├── shared/          → ReplicatedStorage/Shared
│   ├── Types.luau        (shared type definitions; see luau-strict-typing)
│   ├── Config.luau       (tunables: prices, cooldowns, spawn tables)
│   └── Util/             (pure functions usable on both sides)
├── server/          → ServerScriptService/Server
│   ├── init.server.luau  (THE server entry point)
│   └── Systems/          (one ModuleScript per system)
│       ├── PlayerData.luau
│       ├── Shop.luau
│       └── Combat.luau
└── client/          → StarterPlayerScripts/Client
    ├── init.client.luau  (THE client entry point)
    └── Controllers/      (one ModuleScript per concern)
        ├── ShopUI.luau
        └── CombatFX.luau
```

- **Exactly one `Script` and one `LocalScript`** (the two `init` files).
  Everything else is a ModuleScript. Many loose Scripts = uncontrolled
  execution order and duplicated service lookups.
- Server-only code lives under `ServerScriptService`/`ServerStorage` — never
  in ReplicatedStorage "for convenience"; the client can read all of it
  (see roblox-security).
- `shared/Config.luau` holds gameplay numbers so designers/balancing touch one
  file — but remember the client copy is readable; authoritative checks still
  happen server-side.

## Bootstrapping

```lua
-- init.server.luau
--!strict
local Systems = script.Systems

local loaded: { [string]: any } = {}
for _, child in Systems:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = require(child)
	end
end
-- deterministic two-phase startup: construct all, then start all
for name, system in loaded do
	if typeof(system.init) == "function" then system.init() end
end
for name, system in loaded do
	if typeof(system.start) == "function" then task.spawn(system.start) end
end
```

Two phases matter: `init` (synchronous, wire dependencies, create remotes)
completes for *every* system before any `start` (long-running loops) begins.
This removes an entire class of "system A required system B before it was
ready" bugs without needing a framework. (If the team already uses a framework
with lifecycles, follow it — the phase discipline is the point.)

## Module Communication — never `_G`

- `_G`/`shared` create invisible dependencies, defeat the type checker, and
  break under require-order changes. **Always `require` explicitly.**
- A module required twice returns the same instance (modules are cached) — 
  this is your singleton mechanism; no globals needed.
- **Caveat**: `require`-ing a ModuleScript from the Studio command bar creates
  a *separate* instance from the one your running game uses. For live QA
  manipulation, use gated cheat remotes instead (see roblox-testing).
- Cross-system events: expose a signal on the module
  (`Shop.ItemPurchased:Connect(...)`) rather than having systems reach into
  each other's internals. A tiny Signal implementation or a library both work.
- Avoid require cycles: if A needs B and B needs A, extract the shared piece
  into a third module or pass callbacks at `init` time. Luau errors on cyclic
  requires at runtime.

## Remotes as a Typed API Boundary

Create remotes **on the server** at startup, in one folder, from one list:

```lua
-- shared/Remotes.luau (definition both sides require)
--!strict
export type RemoteName = "BuyItem" | "EquipItem" | "StateSnapshot"
local NAMES: { RemoteName } = { "BuyItem", "EquipItem", "StateSnapshot" }
return NAMES
```

Server creates them; client waits for the folder once. Wrap access in a small
module (`Net.fire(name, ...)`, `Net.on(name, handler)`) so:

- adding a remote is one line in one list,
- every server handler passes through shared validation/rate-limit middleware
  (see roblox-security),
- payload types live next to remote names (see luau-strict-typing).

Never let the client create remotes, and never scatter
`Instance.new("RemoteEvent")` across systems.

## CollectionService: One Manager per Behavior

For world objects with shared behavior (chests, doors, spawners), don't put a
Script inside each model. Tag instances and run one manager:

```lua
--!strict
local CollectionService = game:GetService("CollectionService")
local TAG = "Chest"

local function attach(chest: Instance)
	-- connect prompts, set up state; register cleanup (see roblox-performance)
end

for _, inst in CollectionService:GetTagged(TAG) do attach(inst) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(attach)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(detach)
```

Practical notes:

- Handle both "already tagged" and "added later" (the two lines above) — 
  with StreamingEnabled, client-side tagged instances stream in and out
  constantly; the Removed signal is not optional.
- Prefer applying tags **in code at startup** (e.g. iterating a folder of
  chests) or via attributes-driven setup over hand-tagging in the Studio Tag
  Editor for anything the server logic depends on — editor-applied tags are
  easy to miss on new instances and painful to audit in review. Iterating a
  well-known folder is the most explicit and debuggable source of truth.
- Per-instance *data* goes in Attributes (`chest:GetAttribute("Tier")`),
  per-instance *behavior* stays in the manager.

## Where Does This Code Go? (decision table)

| Code | Home |
| --- | --- |
| Validates, mutates, or stores game state | `server/Systems/` |
| Renders state, plays effects, reads input | `client/Controllers/` |
| Pure logic both sides run (damage formula, level curve) | `shared/Util/` — server result is authoritative; client copy is for prediction/UI only |
| Type definitions crossing the boundary | `shared/Types.luau` |
| Tunable numbers | `shared/Config.luau` (client-readable) or server-only config when secret |
| Per-instance parameters | Attributes on the instance |
| Assets (models, sounds) | `ReplicatedStorage/Assets` (client needs them) or `ServerStorage` (spawned server-side) |

## Growth Rules

- New feature = new module in the right folder + remotes added to the list +
  types added to `Types.luau`. If a feature needs edits in five unrelated
  files, the boundaries are wrong — fix the structure before adding more.
- When a script accumulates unrelated responsibilities, split it along the
  decision table above. Establish **one fully-worked exemplar system** (e.g.
  Shop: types + server module + client controller + remotes + validation) and
  make every later system copy its shape.
- Delete dead code paths when replacing systems; parallel old/new paths are
  where duplication bugs live.

When you (Claude) add any new system to a Roblox project, follow this file
layout and the two-phase bootstrap, and produce the server module, client
controller, shared types, and remote registration together — not just the
piece that was asked for, if the rest doesn't exist yet.
