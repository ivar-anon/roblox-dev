---
description: Safe player data persistence in Roblox — DataStore retry/backoff, session locking, autosaves, BindToClose, schema versioning and migration. Use when writing or reviewing any code that touches DataStoreService, player profiles, saving/loading, or data loss bugs.
---

# Roblox DataStores: Data Loss Is a Design Failure

Players quit games forever over lost progress. DataStore calls fail routinely
(throttling, outages, shutdowns mid-write), and naive save code *will*
eventually dupe items or wipe saves. Treat persistence as a system, not a
`SetAsync` call.

## Non-Negotiables

1. **Every DataStore call goes through `pcall` with retry + exponential
   backoff.** No exceptions.
2. **Read-modify-write uses `UpdateAsync`, never `GetAsync` + `SetAsync`.**
   `UpdateAsync` receives the latest stored value and lets you transform it
   atomically; Get+Set races against other servers and against yourself.
3. **One server owns a player's data at a time (session locking).** Without
   it, a player rejoining a different server before the old server's final
   save lands will dupe or lose data. This is the #1 cause of item duplication
   exploits — players trigger it deliberately.
4. **Save on: autosave interval, player leave, and `game:BindToClose`.**
   All three. Servers die without warning; `BindToClose` gives you ~30
   seconds to flush everyone.
5. **Store only JSON-encodable data.** No Instances, no CFrames, no mixed-key
   tables, no cyclic tables, no non-string keys alongside array parts. Convert
   at the boundary.

## Recommended: Use a Battle-Tested Library

For production games, prefer **ProfileStore** (successor to ProfileService) —
it implements session locking, retries, and release semantics correctly.
These patterns below are what such a library does for you; implement them by
hand only when you have a reason to.

## Retry with Backoff

```lua
--!strict
local function withRetry<T...>(attempts: number, fn: () -> T...): (boolean, T...)
	local delaySeconds = 1
	for attempt = 1, attempts do
		local results = table.pack(pcall(fn))
		if results[1] then
			return true, table.unpack(results, 2, results.n)
		end
		warn(`DataStore attempt {attempt}/{attempts} failed: {results[2]}`)
		if attempt < attempts then
			task.wait(delaySeconds)
			delaySeconds = math.min(delaySeconds * 2, 16)
		end
	end
	return false
end
```

Budget awareness: check
`DataStoreService:GetRequestBudgetForRequestType(...)` before non-critical
writes and defer if the budget is low. Writes to the *same key* are throttled
(one write per key per ~6 seconds) — design so each player maps to one key and
you never write it in a loop.

## Session Locking (the concept)

On load, atomically claim the profile via `UpdateAsync`:

- If the stored data has no active lock (or the lock is stale — older than,
  say, 2× the autosave interval), write your server's `JobId` + timestamp into
  a `lock` field and proceed.
- If another server holds a fresh lock, **do not load**. Retry a few times
  (the other server may be mid-release), then kick the player with a friendly
  "your data is still saving, rejoin in a moment" message. Loading anyway is
  how dupes happen.
- On leave/shutdown: final `UpdateAsync` writes data AND clears the lock.
- Every autosave refreshes the lock timestamp, so a crashed server's lock goes
  stale and self-heals.

## The Profile Lifecycle

```text
PlayerAdded ──▶ claim lock + load ──▶ in-memory profile (single source of truth)
                                          │  gameplay mutates ONLY this table
                                          ├─ autosave every 30–60s (staggered per player)
PlayerRemoving ─▶ final save + release lock
game:BindToClose ─▶ final save + release for EVERY remaining player, wait for all
```

Rules that fall out of this:

- Gameplay code never touches DataStores directly — it reads/writes the
  in-memory profile table. Persistence is one module's job.
- Stagger autosaves (`player joins → offset = hash(UserId) % interval`) so 50
  players don't all save on the same tick.
- In `BindToClose`, save players in parallel (`task.spawn` per player), then
  wait until all finish or ~25s elapse. In Studio, skip the wait
  (`RunService:IsStudio()`), or stopping playtests becomes painful.
- Never yield inside `UpdateAsync`'s transform function; compute the new value
  from the old synchronously and return it.
- Return `nil` from an `UpdateAsync` transform to abort the write (e.g. the
  stored data is newer than what you have).

## Schema Versioning and Migration

Data outlives your code. Version it from day one:

```lua
local CURRENT_VERSION = 3

local DEFAULT_PROFILE = {
	version = CURRENT_VERSION,
	coins = 0,
	inventory = {},
	settings = { music = true },
}

local MIGRATIONS: { [number]: (any) -> any } = {
	[1] = function(data) data.settings = { music = true } return data end,
	[2] = function(data) data.inventory = data.items or {} data.items = nil return data end,
}

local function migrate(data: any): any
	while data.version < CURRENT_VERSION do
		local step = MIGRATIONS[data.version]
		if not step then error(`missing migration from v{data.version}`) end
		data = step(data)
		data.version += 1
	end
	return data
end
```

- Run `migrate` on load, inside the same `UpdateAsync` that claims the lock.
- Never delete fields in place across a release without a migration — old
  servers and new servers run simultaneously during a rolling update.
- Deep-copy `DEFAULT_PROFILE` for new players (a shared table reference will
  corrupt across players).

## Value Limits and Serialization

- A single key's value has a hard size limit (~4 MB). Player profiles rarely
  approach it, but unbounded arrays (logs, full match histories) will. Cap or
  rotate them.
- Serialize special types at the boundary: `CFrame` → 12 numbers or
  position+orientation, `Color3` → hex string, `Vector3` → `{x, y, z}`,
  enum → `enum.Value`.
- Reject/strip `nil` holes in arrays before saving (JSON truncates at the
  first hole).

## What NOT To Do (review red flags)

| Red flag | Why |
| --- | --- |
| `SetAsync` for player data anywhere | Races; use `UpdateAsync`. |
| Saving inside gameplay events ("save on every coin pickup") | Throttled key writes; autosave instead. |
| `game:BindToClose` missing | Server shutdown wipes the last minutes of every session. |
| Data loaded without session lock, "we'll be fine" | Item dupes, discovered by players before you. |
| Storing the whole leaderstats folder / Instances | Not serializable; save plain tables and rebuild UI. |
| One giant DataStore key for all players | Size limit + write throttling + total loss blast radius. |
| Trusting client-sent data into the profile | See the roblox-security skill: validate first. |
| Wiping `nil` results as "new player" without checking the error | A failed `GetAsync`/`UpdateAsync` read looks like a new player if you don't distinguish "no data" from "call failed". Kick on load failure rather than starting a fresh profile over live data. |

That last one deserves emphasis: **if the load fails, do not let the player
play with a default profile** — their next save overwrites the real data.
Kick with a "data couldn't load, please rejoin" message.
