---
description: Luau strict mode typing patterns — annotations, narrowing Instance? results, forward declarations, typed remotes, generics, and fixing common --!strict type errors. Use when writing Luau code, enabling --!strict, or resolving Luau type-checker warnings in Roblox projects.
---

# Luau Strict Typing

All new Luau files should start with `--!strict`. The type checker catches the
bug classes that dominate Roblox crash logs: nil indexing, wrong remote
payloads, and typo'd properties. These are the patterns that make strict mode
pleasant instead of a fight.

## File Header and Basics

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type ItemId = string

export type Item = {
	id: ItemId,
	price: number,
	stackable: boolean?,
}

local function priceOf(item: Item, quantity: number): number
	return item.price * quantity
end
```

- `export type` in a ModuleScript lets consumers do
  `local Types = require(...); local x: Types.Item`.
- Prefer a single `Shared/Types.luau` module for types that cross the
  client/server boundary (remote payloads, profile schema) so both sides agree
  by construction.

## Narrowing `Instance?` — the everyday battle

`FindFirstChild`, `WaitForChild` (in some contexts), and `.Character` return
optionals. Strict mode forces you to handle `nil` — good. Idioms:

```lua
-- 1. Early-return guard (preferred in handlers)
local root = character:FindFirstChild("HumanoidRootPart")
if not root or not root:IsA("BasePart") then return end
-- root is now BasePart

-- 2. assert when absence is a programmer error, not a runtime possibility
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
assert(remotes, "Remotes folder must exist — created by server bootstrap")

-- 3. :: type assertion ONLY when you have out-of-band certainty
local gui = player:WaitForChild("PlayerGui") :: PlayerGui
```

Rules of thumb:

- `:IsA("ClassName")` both checks and narrows to that class. Prefer it over
  `:: Cast` because it validates at runtime too.
- Use `::` assertions sparingly and only through a known-good type;
  `x :: any :: T` is a smell — if you need it, your types are lying somewhere.
- `WaitForChild` returns `Instance` (non-optional overload without timeout),
  but with a timeout argument it returns `Instance?` — handle it.

## Forward Declarations for Mutually Recursive Functions

`local function a()` cannot see `local function b()` declared later. In strict
mode, declare the variable with its type first, then assign:

```lua
--!strict
local openMenu: (menuId: string) -> ()
local closeMenu: () -> ()

closeMenu = function()
	-- ... may call openMenu
end

openMenu = function(menuId: string)
	-- ... may call closeMenu
end
```

Assign with `name = function(...)`, not `local function name(...)` (the latter
creates a *new* local shadowing your declaration).

## Typed Remote Payloads

Remotes are the untyped hole in every codebase. Close it with a shared types
module and validation at the boundary:

```lua
-- Shared/Types.luau
export type BuyItemRequest = {
	itemId: string,
	quantity: number,
}
```

```lua
-- Server: arguments arrive as unknown-shaped values regardless of your types.
-- The annotation documents intent; the VALIDATION enforces it (see the
-- roblox-security skill). Type the handler input as unknown and narrow:
remote.OnServerEvent:Connect(function(player: Player, payload: unknown)
	if typeof(payload) ~= "table" then return end
	local req = payload :: { [string]: unknown }
	if typeof(req.itemId) ~= "string" then return end
	if typeof(req.quantity) ~= "number" then return end
	handleBuy(player, req.itemId :: string, req.quantity :: number)
end)
```

Types are compile-time only — they never validate network input. Both layers,
always.

## Typing OOP Modules (metatable idiom)

```lua
--!strict
local Cooldown = {}
Cooldown.__index = Cooldown

export type Cooldown = typeof(setmetatable(
	{} :: { duration: number, lastUsed: number },
	Cooldown
))

function Cooldown.new(duration: number): Cooldown
	return setmetatable({ duration = duration, lastUsed = 0 }, Cooldown)
end

function Cooldown.ready(self: Cooldown): boolean
	return os.clock() - self.lastUsed >= self.duration
end

return Cooldown
```

- `typeof(setmetatable(...))` derives the instance type including methods.
- Annotate `self` explicitly in methods defined with dot syntax; or use colon
  syntax (`function Cooldown:ready()`) and let Luau infer `self` — but the
  explicit form gives better errors.

## Generics

```lua
local function map<T, U>(list: { T }, fn: (T) -> U): { U }
	local out: { U } = table.create(#list)
	for i, v in list do
		out[i] = fn(v)
	end
	return out
end
```

Generic functions cover most needs. Reach for `keyof`, indexers
(`{ [string]: number }`), and unions (`"sword" | "bow"` string literal types)
before reaching for `any`.

## Common Strict-Mode Errors and Fixes

| Error | Fix |
| --- | --- |
| `Type 'Instance' does not have key 'Humanoid'` | You indexed a generic Instance. Narrow: `local h = model:FindFirstChildOfClass("Humanoid"); if not h then return end`. |
| `Type 'Instance?' could be nil` | Guard, `assert`, or restructure so the value is non-optional. Do not sprinkle `::`. |
| `Cannot call non-function` on a forward-declared local | You used `local function name` for the assignment, shadowing the declaration. Use `name = function`. |
| `Key 'x' not found in table` when building tables incrementally | Declare the full type up front: `local t: Item = { id = "", price = 0, stackable = nil }` or build with a typed constructor. |
| Recursive type errors on self-referencing tables | Name the type first: `type Node = { value: number, next: Node? }`. |
| `never` types appearing after narrowing | Two narrowings contradicted (e.g. `typeof(x) == "string"` inside a branch where x is number). Re-check the logic — the checker found a real bug. |

## Practical Adoption Path for Untyped Codebases

1. Add `--!strict` to *new* files only; never big-bang the whole repo.
2. Convert shared modules first (types flow outward from them).
3. When converting a file, fix real bugs the checker reveals before
   suppressing anything.
4. `--!nonstrict` is the transitional mode; `--!nocheck` is a last resort for
   generated code only.

When you (Claude) write any new Luau file, default to `--!strict` with full
annotations on exported/public functions. Don't ask; it's the standard.
