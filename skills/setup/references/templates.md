# Scaffold Templates

Substitute `{{NAME}}` with the project name everywhere.

## default.project.json

```json
{
  "name": "{{NAME}}",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": {
        "$path": "src/shared"
      }
    },
    "ServerScriptService": {
      "Server": {
        "$path": "src/server"
      }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "Client": {
          "$path": "src/client"
        }
      }
    }
  }
}
```

## wally.toml

```toml
[package]
name = "you/{{NAME}}"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
# Promise = "evaera/promise@4"
# Trove = "sleitnick/trove@1"

[server-dependencies]
# ProfileStore = "loleris/profilestore@1"
```

## selene.toml

```toml
std = "roblox"

[lints]
global_usage = "deny"
unused_variable = "warn"
shadowing = "warn"
```

Selene generates the Roblox standard library definition automatically on
first run (`selene generate-roblox-std` if prompted).

## stylua.toml

```toml
column_width = 100
line_endings = "Unix"
indent_type = "Tabs"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

## .gitignore

```gitignore
# Roblox build artifacts
*.rbxl
*.rbxlx
*.rbxl.lock
*.rbxlx.lock

# Wally
Packages/
ServerPackages/
DevPackages/
wally.lock

# Toolchain
sourcemap.json

# OS
.DS_Store
Thumbs.db
```

## .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install toolchain
        uses: CompeyDev/setup-rokit@v0.1.2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Check formatting
        run: stylua --check src

      - name: Lint
        run: selene src
```

If the repository does not use Rokit, install tools individually with their
setup actions or prebuilt binaries instead.

The Rokit manifest `rokit.toml` (commit it) pins tool versions:

```toml
[tools]
rojo = "rojo-rbx/rojo@7.4.4"
wally = "UpliftGames/wally@0.3.2"
selene = "Kampfkarren/selene@0.27.1"
stylua = "JohnnyMorganz/StyLua@0.20.0"
```

(Bump pins as needed; these are known-good starting points.)

## src/shared/Types.luau

```lua
--!strict
-- Shared type definitions. Types that cross the client/server boundary
-- (remote payloads, profile schema) live here so both sides agree.

export type PlayerProfile = {
	version: number,
	coins: number,
}

return nil
```

## src/shared/Config.luau

```lua
--!strict
-- Tunable gameplay values. NOTE: replicated to clients — nothing secret here,
-- and the server never trusts a client-reported value from this file.

return table.freeze({
	AUTOSAVE_INTERVAL = 60,
})
```

## src/server/init.server.luau

```lua
--!strict
-- {{NAME}} server entry point. Two-phase bootstrap: init() all systems,
-- then start() all systems (see roblox-dev architecture guidance).

local Systems = script:FindFirstChild("Systems")

local loaded: { [string]: any } = {}
if Systems then
	for _, child in Systems:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child)
		end
	end
end

for _, system in loaded do
	if typeof(system.init) == "function" then
		system.init()
	end
end

for _, system in loaded do
	if typeof(system.start) == "function" then
		task.spawn(system.start)
	end
end

print("[{{NAME}}] server started")
```

## src/client/init.client.luau

```lua
--!strict
-- {{NAME}} client entry point.

local Controllers = script:FindFirstChild("Controllers")

local loaded: { [string]: any } = {}
if Controllers then
	for _, child in Controllers:GetChildren() do
		if child:IsA("ModuleScript") then
			loaded[child.Name] = require(child)
		end
	end
end

for _, controller in loaded do
	if typeof(controller.init) == "function" then
		controller.init()
	end
end

for _, controller in loaded do
	if typeof(controller.start) == "function" then
		task.spawn(controller.start)
	end
end

print("[{{NAME}}] client started")
```

## README.md (project)

```markdown
# {{NAME}}

Roblox game built with [Rojo](https://rojo.space).

## Development

1. Install the toolchain: `rokit install`
2. Start syncing: `rojo serve`
3. In Roblox Studio, connect with the Rojo plugin.

## Structure

- `src/shared` → ReplicatedStorage/Shared — types, config, pure utilities
- `src/server` → ServerScriptService/Server — authoritative game systems
- `src/client` → StarterPlayerScripts/Client — rendering, input, UI

## Checks

- Format: `stylua src`
- Lint: `selene src`
```
