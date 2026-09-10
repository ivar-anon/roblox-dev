---
description: Server-authoritative security patterns for Roblox games — validating RemoteEvents/RemoteFunctions, preventing exploits, rate limiting, and never trusting the client. Use when writing or reviewing any code that touches RemoteEvents, RemoteFunctions, player input, currency, damage, inventory, or purchases.
---

# Roblox Security: Never Trust the Client

Every Roblox client is fully controllable by its user. Exploiters can read all
client code, fire any RemoteEvent with arbitrary arguments, modify their own
character physics, and inspect everything replicated to them. Security exists
**only** on the server.

## The Iron Rules

1. **The server owns all state that matters.** Currency, inventory, damage,
   cooldowns, purchases, progression — computed and stored server-side only.
   The client *requests*; the server *decides*.
2. **Every remote argument is hostile until validated.** Exploiters fire
   remotes with `nil`, `NaN`, `math.huge`, negative numbers, wrong types,
   tables shaped to crash your handler, and Instances that don't exist.
3. **Anything replicated to the client is public.** Code in
   `ReplicatedStorage`, `StarterPlayerScripts`, `StarterGui`; all remote names;
   all attribute values. Never ship secrets, admin lists with privileges
   decided client-side, or "hidden" prices.
4. **The client may run nothing you sent, or run it modified.** Client-side
   anti-cheat is a speed bump, not a wall. It filters casual cheaters only.

## Validating Remote Arguments

Validate **type → range → permission → plausibility**, in that order, and
return early on any failure. Do not error loudly to the exploiter; just drop
the request (optionally log it).

```lua
--!strict
local function onBuyItem(player: Player, itemId: unknown, quantity: unknown)
	-- 1. TYPE: never assume types match your signature
	if typeof(itemId) ~= "string" then return end
	if typeof(quantity) ~= "number" then return end

	-- 2. RANGE: reject NaN, infinity, negatives, non-integers, absurd sizes
	if quantity ~= quantity then return end            -- NaN check: NaN ~= NaN
	if quantity ~= math.floor(quantity) then return end
	if quantity < 1 or quantity > 100 then return end

	-- 3. PERMISSION: does this item exist, can THIS player buy it?
	local item = ItemCatalog[itemId]
	if not item then return end
	local profile = PlayerData.get(player)
	if not profile then return end

	-- 4. PLAUSIBILITY: server-side price, server-side balance check
	local cost = item.price * quantity                 -- price from SERVER catalog
	if profile.coins < cost then return end

	-- All checks passed: mutate on server, then replicate the result
	profile.coins -= cost
	Inventory.grant(player, itemId, quantity)
end
```

Key traps:

- `NaN` passes `typeof(x) == "number"` and most comparisons. Check `x ~= x`.
- `math.huge` and `-math.huge` pass number checks. Clamp or bound everything.
- Tables sent through remotes lose metatables and can have mixed/sparse keys.
  If you accept a table, validate every field you read; better, avoid table
  arguments and send scalars.
- An `Instance` argument can be any instance the client can see — or one that
  no longer exists (arrives as the instance, but `Parent` may be nil). Verify
  it is the *kind* of instance you expect AND that the player may act on it.
- Never index a remote argument before type-checking it: `itemId.Name` on a
  non-Instance throws and kills your handler thread.

For larger games, centralize this in a guard module (or use a runtime type
library) so every remote handler starts with a declarative check.

## Distance and Line-of-Sight Checks

For world interactions (opening a chest, picking an item, attacking):

```lua
local MAX_REACH = 20 -- studs; tune per interaction

local function canReach(player: Player, target: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return false end
	return (root.Position - target.Position).Magnitude <= MAX_REACH
end
```

Also verify state: the chest is not already open, the mob is alive, the item
has not been claimed by someone else this frame (re-check inside the handler,
not just in the UI that fired it).

## Rate Limiting Remotes

Exploiters fire remotes thousands of times per second. Per-player, per-remote
budgets stop both damage and server load:

```lua
--!strict
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

local function allow(player: Player, key: string, ratePerSec: number, burst: number): boolean
	local now = os.clock()
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end
	local b = playerBuckets[key]
	if not b then
		b = { tokens = burst, last = now }
		playerBuckets[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * ratePerSec)
	b.last = now
	if b.tokens < 1 then return false end
	b.tokens -= 1
	return true
end

Players.PlayerRemoving:Connect(function(player) buckets[player] = nil end)
```

Use it as the first line of every remote handler:
`if not allow(player, "BuyItem", 3, 5) then return end`.

Track repeat offenders; a player tripping rate limits hundreds of times is
telemetry worth logging, but **do not auto-ban on it alone** (mobile lag and
retry loops cause false positives).

## RemoteFunction Hazards

- **Never call `RemoteFunction:InvokeClient` from the server for anything you
  need.** An exploiter (or a crashed client) can simply never return, leaking
  the server thread forever, or return garbage. If you must notify the client
  and get an answer, use two RemoteEvents with a server-side timeout.
- Server-side `OnServerInvoke` needs the same validation as events, plus: its
  return value is an information channel. Don't return internal state the
  client shouldn't see.

## Common Exploit Surfaces Checklist

When reviewing a codebase, look for these specific patterns:

| Pattern | Risk |
| --- | --- |
| `remote.OnServerEvent:Connect(function(player, dmg) humanoid:TakeDamage(dmg)` | Client chooses damage. Server must compute damage from server-known weapon stats. |
| Client tells server "I killed X, give reward" | Server must witness the kill (server-side hit detection or server-validated projectile). |
| Tool/weapon stats read from the Tool instance the client sends | Exploiter sends a modified tool. Look stats up server-side by item id. |
| Price/cost read from a GUI or client argument | Server catalog only. |
| `player.leaderstats.Coins.Value` mutated from a LocalScript | Only replicates locally — but if a server script later reads it back, it's an exploit path. Server state lives in server modules, not in replicated Value objects. |
| Teleport/CFrame requests without bounds | Validate destination is a legal teleport target for that player. |
| Remote named `GiveAdmin`, `SetCoins`, dev/test remotes left in production | Gate every privileged remote by a server-side allowlist of UserIds, and strip QA remotes outside Studio (`RunService:IsStudio()`). |

## Character Physics Reality

The client simulates and replicates its own character movement. This means
speed/fly/teleport hacks cannot be fully prevented, only detected and bounded
server-side:

- Periodically sample `HumanoidRootPart.Position` on the server; flag
  displacement that exceeds max legitimate speed × elapsed time (with margin
  for teleports you initiated and physics flings).
- Act on *accumulated* evidence, never a single sample. Rubber-band (snap back)
  before punishing.
- Keep valuable interactions server-gated by the distance checks above — then
  a fly hack gains nothing that matters.

## Secure-by-Default System Shape

When you (Claude) generate any new gameplay system, produce this shape without
being asked:

1. `Shared/Types.luau` — shared type definitions for payloads.
2. Server module owning all state, exposing handlers that validate first.
3. Client controller that only *renders* state and *requests* actions.
4. Remotes created by the server in a single folder, never by the client.
5. Rate limit + full argument validation on every handler.

If the user asks for something inherently insecure ("let the client set its
coins"), implement the secure version and explain the change in one sentence.
