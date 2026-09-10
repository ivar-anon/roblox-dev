---
description: Generate a complete, secure client/server gameplay system for Roblox — shared types, validated server module, client controller, and remote registration in one pass. Use when adding a feature like a shop, inventory, combat ability, quest, or any system that spans client and server.
---

# /roblox-dev:new-system — Generate a Complete System

Generate a full vertical slice of a gameplay system named in `$ARGUMENTS`
(e.g. `/roblox-dev:new-system DailyRewards`). A "system" is never one file —
it is the four pieces below, generated together so nothing is left insecure
or untyped.

## Before generating

1. Read the project's existing structure (per the roblox-architecture skill:
   `src/shared`, `src/server/Systems`, `src/client/Controllers`, the remotes
   list, `Types.luau`). **Match existing conventions** — if the project has a
   `Net` wrapper, a signal library, or a data layer (e.g. ProfileStore), use
   them rather than inventing parallel ones.
2. If the system's rules are ambiguous (costs, cooldowns, limits), ask the
   one or two questions that change the code; default the rest into
   `shared/Config.luau` entries that are easy to tune.

## The four pieces

### 1. Shared types — added to `Types.luau`

Request/response payload types and any state snapshot type the client renders.

### 2. Server module — `src/server/Systems/<Name>.luau`

- `--!strict`, two-phase shape (`init` wires remotes/state, `start` runs
  loops if any).
- Owns ALL state for this system in a server-side table (keyed by Player,
  cleaned on `PlayerRemoving` — see roblox-performance).
- Every remote handler: rate limit → type validation → range validation →
  permission/plausibility validation → mutate → replicate result
  (the exact ladder from the roblox-security skill).
- Persistent state goes through the project's data layer, never direct
  DataStore calls inline (see roblox-datastores).
- Exposes a clean module API (`<Name>.grant(player, ...)`) so cheat commands
  and other systems reuse the same code paths (see roblox-testing).

### 3. Client controller — `src/client/Controllers/<Name>UI.luau`

- Renders state received from the server; requests actions; **computes
  nothing authoritative**.
- Handles the late-join case: render from a full snapshot on join, then apply
  incremental updates.
- Optimistic UI is allowed for feel (button responds instantly) but must
  reconcile with the server result (revert on rejection).

### 4. Registration

- Remote names added to the project's remote list/creation point.
- Cheat-remote entries for QA (grant/reset/trigger) gated per roblox-testing.
- If the system has pure logic (curves, drop tables, price math), extract it
  to `shared/Util/<Name>Logic.luau` and add a `.spec.luau` with boundary
  tests.

## Output discipline

- Deliver complete files, not fragments, for anything new; targeted edits for
  existing files (remotes list, Types.luau).
- After generating, summarize the security posture in 2–3 bullets: what the
  server validates, what an exploiter could try, and why it fails.
- Flag any piece intentionally left simple (e.g. "no purchase receipt
  idempotency yet — needed if you sell this for Robux") so scope cuts are
  visible, not silent.
