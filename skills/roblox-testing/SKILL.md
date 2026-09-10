---
description: Testing and QA workflows for Roblox games — gated cheat remotes for live-state QA, TestEZ unit tests, pure-logic module design for testability, and multi-client playtesting. Use when setting up testing, debugging state-dependent bugs, verifying gameplay systems, or reviewing QA tooling.
---

# Roblox Testing & QA

Roblox games are stateful, networked, and hard to test from the outside. The
strategy: make logic pure where possible (unit-testable), and build **gated
cheat tooling** for everything that isn't.

## The Command-Bar Trap

`require()`-ing a ModuleScript from the Studio command bar returns a
**separate module instance** from the one your running game is using. Mutating
it does nothing to live game state — a classic source of "my test worked but
the game didn't change" confusion.

**Never use the command bar for state-dependent testing.** Use cheat remotes.

## Gated Cheat Remotes

A `CheatCommands` server module that registers QA remotes, active only for
authorized users:

```lua
--!strict
local RunService = game:GetService("RunService")

local DEV_USER_IDS: { [number]: true } = {
	[12345678] = true, -- your UserId
}

local function isAuthorized(player: Player): boolean
	if RunService:IsStudio() then return true end
	return DEV_USER_IDS[player.UserId] == true
end

-- register("GiveCoins", function(player, amount) ... end)
-- Every handler: if not isAuthorized(player) then return end
```

Rules:

- **The gate lives server-side** in every handler — never rely on hiding the
  cheat UI client-side (see roblox-security: remote names are public and any
  client can fire them).
- Cheat handlers go through the **same system APIs** as real gameplay
  (`Economy.addCoins(player, n)`), never poking raw data — otherwise your
  cheats test a code path players never run.
- Cover the test matrix: grant/remove currency and items, set progression
  level, trigger rare events (pity thresholds, level-ups), spawn/clear mobs,
  toggle god mode, and **reset profile to default**.
- In Studio these unlock automatically (`IsStudio`); in production only
  allowlisted UserIds. This lets you QA in real servers with real latency.
- A minimal client cheat panel (visible only when the server confirms
  authorization) beats typing into chat commands, but chat commands are fine
  early.

## Designing for Testability: Pure Core, Thin Shell

Logic that touches no Roblox APIs can be tested anywhere — including CI:

```lua
-- shared/Util/LevelCurve.luau  (pure: numbers in, numbers out)
--!strict
local LevelCurve = {}

function LevelCurve.xpForLevel(level: number): number
	return math.floor(100 * level ^ 1.5)
end

function LevelCurve.levelFromTotalXp(xp: number): number
	local level = 1
	while xp >= LevelCurve.xpForLevel(level + 1) do
		level += 1
	end
	return level
end

return LevelCurve
```

Push damage formulas, drop tables, economy math, level curves, and validation
predicates into pure modules under `shared/Util/`. The impure shell (services,
instances, remotes) stays thin and is tested by playing.

Determinism rule: pure modules take randomness as an injected function
(`rng: () -> number`), so tests pass a seeded generator and gameplay passes
`math.random`.

## Unit Tests with TestEZ

```lua
-- LevelCurve.spec.luau
return function()
	local LevelCurve = require(script.Parent.LevelCurve)

	describe("levelFromTotalXp", function()
		it("starts at level 1 with 0 xp", function()
			expect(LevelCurve.levelFromTotalXp(0)).to.equal(1)
		end)

		it("is consistent with xpForLevel at boundaries", function()
			for level = 2, 50 do
				local xp = LevelCurve.xpForLevel(level)
				expect(LevelCurve.levelFromTotalXp(xp)).to.equal(level)
				expect(LevelCurve.levelFromTotalXp(xp - 1)).to.equal(level - 1)
			end
		end)
	end)
end
```

- Name specs `<Module>.spec.luau` next to the module; run with a TestEZ
  runner script in Studio (or headlessly — pure Luau modules can also run
  under the Lune runtime in CI, with a small TestEZ-compatible shim or plain
  assertions).
- Property-style loops (like the boundary check above) catch curve/formula
  bugs far better than single-value assertions.
- Priority order for what to test first: money math, data migrations
  (see roblox-datastores — test every migration step against fixture
  profiles), drop/pity tables, and validation predicates. These are where
  silent bugs cost the most.

## Playtesting Multiplayer Behavior

- **Studio multi-client test** (Test tab → Clients and Servers, 2+ players)
  is the only way to catch replication assumptions: state you forgot to
  replicate, remotes assuming one player, UI showing player A's data to
  player B.
- Test **join order** both ways: feature works when A joins before B *and*
  after. Late-joiner state sync is the most common multiplayer bug — every
  system needs a "send full snapshot on join" path, not just incremental
  updates.
- Test leave/rejoin mid-interaction (trade, dungeon, shop open) — cleanup and
  session-lock behavior (see roblox-datastores) only break in these windows.
- With StreamingEnabled, walk a client far away and back: does the system
  survive its instances streaming out?

## Bug Reproduction Discipline

When investigating a reported bug:

1. Reproduce with cheat remotes to reach the exact state (level, items,
   currency) in seconds instead of grinding.
2. Add a temporary `debug.profilebegin`/log line at the suspect boundary,
   reproduce, read, remove.
3. Fix, then add the cheapest permanent guard: an assertion, a validation
   check, or a spec for pure logic.

## Review Red Flags

| Red flag | Problem |
| --- | --- |
| QA instructions that say "run this in the command bar" for live state | Separate module instance; results are fiction. Use cheat remotes. |
| Cheat remotes gated only by hiding the UI | Any client can fire them; gate server-side by UserId + IsStudio. |
| Cheat handlers mutating raw data tables directly | Untested real code paths; route through system APIs. |
| Economy/drop math inline in event handlers | Untestable; extract to pure `shared/Util` modules with specs. |
| No multi-client test before shipping a "multiplayer" feature | Late-joiner and replication bugs guaranteed. |
| `math.random` called inside formulas under test | Inject the rng. |

When you (Claude) implement a gameplay system, also produce: (a) its cheat
remote entries for QA, and (b) specs for any pure logic it contains. A system
without a way to reach its states quickly is a system that won't get tested.
