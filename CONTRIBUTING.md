# Contributing to roblox-dev

Thanks for helping make AI-assisted Roblox development safer. Contributions
in **English or Spanish** are equally welcome, for both code and docs.

## What we're most interested in

- **Real-world failure patterns**: an exploit you saw in the wild, a
  DataStore edge case that lost data, a memory leak that took down a server.
  These become skill content with the highest value per line.
- **Corrections**: Roblox APIs evolve. If a pattern here is outdated or a
  claim is wrong, open an issue with a link to the current behavior/docs.
- **New skills**: propose the scope in an issue first (one skill = one
  domain a reviewer can hold in their head).
- **Spanish docs parity**: README.es.md should stay in sync with README.md.

## Ground rules for skill content

1. **Every claim must be true in current Roblox.** No cargo-cult advice; if
   it's version-dependent, say so.
2. **Show the failure, not just the rule.** "Exploiters send NaN" teaches
   more than "validate your inputs".
3. **Dense beats long.** Skills are loaded into a working context; padding
   has a real cost. Cut anything Claude already does right without help.
4. **Code samples are `--!strict`** and must pass Selene + StyLua
   (`selene examples && stylua --check examples` — CI enforces this for
   `examples/`).

## Workflow

1. Fork, branch from `main`.
2. `node scripts/validate.mjs` must pass.
3. For Luau changes: `stylua examples && selene examples`.
4. Open a PR describing *what real problem* the change addresses.

## Testing the plugin locally

```bash
claude --plugin-dir ./roblox-dev
```

Then exercise a skill (`/roblox-dev:review examples`) or just write some
Luau and watch which skills activate.

## Conduct

Be kind, assume good faith, review the code not the person. Reports to the
maintainer's email in `plugin.json`.
