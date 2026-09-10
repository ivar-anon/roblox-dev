---
description: Scaffold a professional Roblox project with Rojo, Wally, Selene, StyLua, strict Luau, and GitHub Actions CI. Use when starting a new Roblox project or adding proper tooling to an existing one.
disable-model-invocation: false
---

# /roblox-dev:setup — Scaffold a Roblox Project

Scaffold (or retrofit) a Rojo-based Roblox project with linting, formatting,
strict typing, and CI. `$ARGUMENTS` may contain the project name and options;
if the current directory already contains a Roblox project (a
`*.project.json` or `src/` with Luau files), retrofit missing pieces instead
of overwriting — never clobber existing configuration without showing a diff.

## Steps

1. **Determine project name**: from `$ARGUMENTS`, or the directory name.
   Ask only if the directory is non-empty and ambiguous.

2. **Create the structure** (per the roblox-architecture skill):

   ```text
   <name>/
   ├── default.project.json
   ├── wally.toml
   ├── selene.toml
   ├── stylua.toml
   ├── .gitignore
   ├── .github/workflows/ci.yml
   ├── README.md
   └── src/
       ├── shared/
       │   ├── Types.luau
       │   ├── Config.luau
       │   └── Util/
       ├── server/
       │   ├── init.server.luau
       │   └── Systems/
       └── client/
           ├── init.client.luau
           └── Controllers/
   ```

3. **Write each config from the templates** in [references/templates.md](references/templates.md),
   substituting the project name. The templates define: the Rojo project
   mapping, Wally manifest, Selene config (Roblox std), StyLua config,
   the CI workflow (StyLua check + Selene lint), and starter entry points
   with the two-phase bootstrap.

4. **Explain the toolchain** briefly to the user, including install commands:

   - **Rojo** — syncs `src/` into Roblox Studio (`rojo serve` + Studio plugin).
   - **Wally** — package manager for Luau dependencies.
   - **Selene** — linter with Roblox-aware standard library.
   - **StyLua** — canonical Luau formatter.
   - Recommended installation via **Rokit** (toolchain manager):
     `rokit init && rokit add rojo-rbx/rojo && rokit add UpliftGames/wally && rokit add Kampfkarren/selene && rokit add JohnnyMorganz/StyLua`
     (or `aftman` equivalents if the user already uses it).

5. **Verify**: run `selene src` and `stylua --check src` if the tools are
   available locally; otherwise note that CI will enforce them.

## Rules

- All starter `.luau` files begin with `--!strict`.
- Do not add packages the project doesn't need yet; wally.toml starts with
  dependencies commented as examples.
- If the user's game is not on Rojo (pure Studio workflow), say so and offer
  the lighter path: just `selene.toml` + `stylua.toml` + the `src` conventions
  as a Studio folder structure, since Rojo adoption is a separate decision.
