# altium-mcp

**Model Context Protocol (MCP) server** that connects [Cursor](https://cursor.com) (and other MCP clients) to **Altium Designer** on **Windows**, so an assistant can query PCB data and drive DelphiScript automation.

This is a **third-party** project; it is not affiliated with Altium.

## Requirements

| Item | Notes |
|------|--------|
| OS | **Windows 10/11** (live bridge targets Altium on Windows) |
| Altium Designer | **22+** recommended (`X2.EXE`) |
| Node.js | **20+** |
| Cursor | MCP over stdio |

## Quick start

```bash
npm install
npm run build
```

Configure Cursor using [docs/cursor-mcp.md](docs/cursor-mcp.md).

First steps in the IDE:

1. Call MCP tool **`get_server_status`** — confirms workspace paths and `X2.EXE` discovery.
2. If needed, call **`configure_altium_exe`** with the full path to `X2.EXE`.
3. With a PCB open in Altium, call **`altium_ping`** then e.g. **`get_pcb_layers`**.

## How it works

- The server writes **`request.json`** under the workspace (default `%USERPROFILE%\.altium-mcp\workspace`).
- It launches Altium with **`-RScriptingSystem:RunScript`** pointing at the bundled **`Altium_API.PrjScr`** project.
- DelphiScript **`Run`** reads the request, runs PCB/SCH API calls, and writes **`response.json`**.
- A file lock **`.bridge.lock`** serializes concurrent tool calls.

See [docs/architecture.md](docs/architecture.md) and JSON schemas in [schemas/](schemas/).

## MCP tools (high level)

| Tool | Purpose |
|------|---------|
| `get_server_status` | Paths, env, whether `X2.EXE` and script project exist |
| `configure_altium_exe` | Save `X2.EXE` path to `%USERPROFILE%\.altium-mcp\config.json` |
| `altium_ping` | Health check via DelphiScript |
| `get_pcb_layers` / `get_pcb_rules` / `get_all_nets` / `get_pcb_layer_stackup` | Active PCB queries |
| `get_all_designators` | All component designators on the PCB |
| `get_component_pins` | Pins for given designators |
| `file_mode_capabilities` | Whether offline `.PcbLib`/`.SchLib` tools are wired (extension point) |

## DelphiScript source

The `altium-scripts/` tree is **MIT-licensed** code derived from [coffeenmusic/altium-mcp](https://github.com/coffeenmusic/altium-mcp), with a small **`ping`** addition. See [NOTICE](NOTICE).

## File-mode (offline libraries)

Not bundled by default. See [docs/file-mode.md](docs/file-mode.md) and [packages/file-ops/README.md](packages/file-ops/README.md).

## Scripts

| Command | Description |
|---------|-------------|
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run MCP server (stdio) |
| `npm test` | Vitest |
| `npm run lint` | `tsc --noEmit` |

## License

MIT — see [LICENSE](LICENSE).
