# roblox-dev

**A Claude Code plugin for Roblox game development.** Skills that make Claude
write Roblox/Luau code the way experienced Roblox engineers do: exploit-proof
remotes, data stores that don't lose player data, frame loops that don't leak
memory, and `--!strict` typing by default.

*Leído en español: [README.es.md](README.es.md)*

## Why

Claude is good at Lua. Roblox is not Lua — it is a hostile networked
environment where every client is a potential exploiter, DataStore calls fail
routinely, and one leaked event connection per respawn adds up to a crashed
server. Generic AI-generated Roblox code gets these wrong in ways you only
discover in production.

This plugin encodes the patterns that production Roblox games live or die by,
extracted from real game development, so Claude applies them automatically
whenever you work on Luau code.

## Install

```
/plugin marketplace add ivar-anon/roblox-dev
/plugin install roblox-dev@roblox-dev
```

Or try it for one session:

```bash
git clone https://github.com/ivar-anon/roblox-dev
claude --plugin-dir ./roblox-dev
```

## What you get

### Skills (activate automatically while you work)

| Skill | What Claude gets right |
| --- | --- |
| **roblox-security** | Server authority, the full remote-validation ladder (type → range → permission → plausibility), NaN/infinity payloads, rate limiting, distance checks, the exploit-surface checklist |
| **roblox-datastores** | `UpdateAsync` over Get+Set, retry with backoff, session locking, `BindToClose`, schema versioning/migrations, "failed load ≠ new player" |
| **roblox-performance** | Connection-leak prevention with cleanup discipline, per-frame allocation rules, network batching, UnreliableRemoteEvents, StreamingEnabled survival, profiling workflow |
| **luau-strict-typing** | `--!strict` by default, `Instance?` narrowing idioms, forward declarations, typed remote payloads, the metatable OOP typing idiom, common error fixes |
| **roblox-architecture** | One-entry-point bootstrap (two-phase init/start), ModuleScripts over `_G`, remotes as a typed API boundary, CollectionService managers, a decision table for where code lives |
| **roblox-ui** | Scale-based responsive layout, TweenService animation vocabulary, CanvasGroup clipping/fades, ViewportFrame framing via bounding boxes, particle gotchas, game-feel cheatsheet |
| **roblox-testing** | Gated cheat remotes (and why the Studio command bar lies to you), pure-core/thin-shell design, TestEZ specs, multi-client playtest checklist |

### Commands

- **`/roblox-dev:setup [name]`** — scaffold a Rojo + Wally + Selene + StyLua
  project with CI, strict-mode entry points, and the canonical folder layout.
- **`/roblox-dev:new-system <Name>`** — generate a complete vertical slice:
  shared types + validated server module + client controller + remote
  registration + QA cheat entries. Never just one insecure file.
- **`/roblox-dev:review [target]`** — structured audit (security / data /
  performance / typing) with severity-ranked findings.

### Agent

- **roblox-reviewer** — a read-only auditor Claude can launch on its own
  after touching gameplay code, checking the same four lenses.

## Example

The [`examples/safe-remote`](examples/safe-remote) folder contains
`SafeRemote.luau` — a strict-typed remote wrapper implementing the plugin's
validation ladder (token-bucket rate limiting, NaN/infinity-safe validators)
— with its TestEZ spec. It shows the code style every skill pushes toward.

## Philosophy

1. **The server owns the truth.** Every generated system assumes hostile
   clients.
2. **Data loss is a design failure**, not bad luck.
3. **Cleanup ships with the connection**, not "later".
4. **Strict mode is the default**, not an upgrade.
5. **If Claude can't reach a game state quickly, it can't help you test it** —
   QA tooling is part of every system.

## Contributing

Issues and PRs welcome — especially real-world exploit patterns, DataStore
failure stories, and performance traps you've hit. See
[CONTRIBUTING.md](CONTRIBUTING.md). Docs contributions in Spanish are
first-class: this plugin is maintained bilingually.

## License

[MIT](LICENSE)
