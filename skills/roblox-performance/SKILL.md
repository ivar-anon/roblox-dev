---
description: Roblox performance and memory patterns — connection leak prevention, per-frame allocation discipline, StreamingEnabled, network traffic reduction, instance budgets, and profiling. Use when diagnosing lag/memory growth, writing RunService loops, or reviewing Roblox code for performance.
---

# Roblox Performance and Memory

Most "Roblox lag" is one of four things: leaked event connections, per-frame
garbage, unbatched network traffic, or too many instances doing too little.
Find which one before optimizing anything.

## Connection Leaks — the #1 memory bug

Every `:Connect()` holds its closure (and everything the closure captures)
alive until disconnected. Destroying an Instance disconnects *its own* signals
— but not connections you made on *other* objects on its behalf, and not
threads you spawned.

```lua
--!strict
-- LEAK: fires forever after the mob dies; captures `mob` forever
RunService.Heartbeat:Connect(function()
	updateHealthbar(mob)
end)
```

Pattern: every object that makes connections owns a cleanup list, executed
exactly once on destruction:

```lua
--!strict
type Cleanup = () -> ()

local function makeMaid()
	local tasks: { Cleanup } = {}
	return {
		add = function(c: RBXScriptConnection | Cleanup | Instance)
			table.insert(tasks, function()
				if typeof(c) == "RBXScriptConnection" then c:Disconnect()
				elseif typeof(c) == "Instance" then c:Destroy()
				else c() end
			end)
		end,
		clean = function()
			for _, t in tasks do t() end
			table.clear(tasks)
		end,
	}
end
```

(Or adopt a library: Trove / Janitor / Maid. The point is the discipline, not
the implementation.)

Checklist for every system:

- `Players.PlayerRemoving` clears everything keyed by that Player (tables
  keyed by Player instances leak the whole Player otherwise).
- Character connections cleaned on `CharacterRemoving` / respawn.
- `Instance.Destroying` (or your maid) tears down per-instance loops.
- Long-lived tables keyed by Instances: prefer keying by `instance:GetDebugId()`
  never — key by the instance but *guarantee* removal, or use weak tables
  knowingly.

## Per-Frame Discipline (`RenderStepped` / `Heartbeat`)

- **Allocate nothing per frame** in hot paths: no fresh tables, no closures,
  no string concatenation. Reuse buffers; hoist closures out of the loop.
- `RenderStepped` blocks the frame — only camera/input-critical work belongs
  there. Visual updates go in `Heartbeat` (or `PreRender` judiciously).
- Batch by cadence: not everything needs 60 Hz. Healthbars at 10 Hz, minimap
  at 4 Hz. Accumulate `dt` and early-return.
- Prefer **TweenService** over manual per-frame easing — it's C-side, smoother,
  and cancels cleanly. Keep a passive frame loop only for things tweens can't
  express (e.g. audio triggers synced to animation).
- Never `task.wait()` in a tight loop as a scheduler; drive off Heartbeat with
  accumulated time.

## Network Traffic

- **Never fire remotes per frame.** Batch state into snapshots (e.g. 10 Hz)
  or send events only on change.
- Use **UnreliableRemoteEvent** for transient, loss-tolerant data (VFX
  triggers, continuous position hints) — it skips retransmission overhead.
- Replicate *results*, not *simulation*: send "mob 12 died", not per-frame mob
  HP for every mob.
- Payload size: strings and table keys cost bytes on the wire. Send compact
  arrays / ids, not verbose dictionaries, for high-frequency data.
- Visual-only effects (tweens, particles) run client-side, triggered by one
  small event — never tween on the server (server tweens replicate a property
  change per step).

## Instance Count and the Workspace

- Every Instance costs memory and (if a BasePart) physics/render work. Merged
  meshes / fewer, larger parts beat thousands of tiny parts.
- One script per entity does not scale. Use **CollectionService tags + a
  single manager script** per behavior (see roblox-architecture skill).
- Anchor everything that doesn't need physics. Unanchored, CanCollide parts
  in piles are a physics tax.
- `Debris:AddItem` or `task.delay(n, function() part:Destroy() end)` for
  temporary objects — and cap concurrent VFX instances; pooled reuse beats
  create/destroy churn for frequent effects (bullets, damage numbers).
- SetNetworkOwner(nil) on server-driven NPCs/parts to stop ownership
  ping-ponging near players (and to prevent exploiters from physics-dragging
  them).

## StreamingEnabled

Modern default; assume it's on:

- Anything in Workspace can be absent on a client at any time. Client code
  must `WaitForChild` (with timeout + nil handling) or react to streaming
  signals, never `workspace.Map.Chest` directly.
- Server code always sees everything; only client access patterns change.
- Set appropriate `ModelStreamingMode` on models players interact with
  (Persistent for critical, Atomic to stream as a unit).
- Teleporting players far away: use `Player:RequestStreamAroundAsync` before
  the teleport so geometry is present on arrival.

## Measuring Before Optimizing

- **MicroProfiler** (Ctrl+F6 in Studio): find which frame band spikes —
  scripts, physics, render. Tag your own hot loops with
  `debug.profilebegin("MobAI") ... debug.profileend()` so they're visible.
- **Developer Console → Memory** (F9): watch `PlaceMemory` categories; steady
  growth in `LuaHeap` while idle = leaked closures/tables; growth in
  `Instances` = undestroyed objects.
- **Script Performance** panel: per-script rate and activity; a "small" script
  at 3% activity × 200 instances of it is your frame budget.
- Test with production-like load: Studio with 1 player and 30 mobs tells you
  nothing about 40 players and 600 mobs. Use test places with bot load.

## Review Red Flags

| Pattern | Problem |
| --- | --- |
| `:Connect` inside `PlayerAdded`/`CharacterAdded` without matching cleanup | Leak per respawn/rejoin. |
| `while true do task.wait() end` polling for a condition | Event exists for almost everything; poll at low Hz only as a last resort. |
| `FindFirstChild` chains every frame | Cache references outside the loop; they don't change per frame. |
| Server-side `TweenService` on world objects | Replicates continuously; tween on clients. |
| Remote fired inside `RenderStepped`/mouse-move | Batch to ≤10 Hz. |
| Tables keyed by `Player` or `Instance` with no removal path | Leaks the instance and everything under it. |
| Per-frame `Instance.new` for effects | Pool them. |
| `#part:GetChildren() > 0` style calls in loops | `GetChildren()` allocates a fresh table each call. |

When you (Claude) write frame loops, mob spawners, VFX, or anything that
connects to events, include the cleanup path in the same edit — cleanup added
"later" is a leak shipped now.
