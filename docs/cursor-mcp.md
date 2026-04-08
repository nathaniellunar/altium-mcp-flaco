# Cursor MCP configuration

## Prerequisites

- **Windows** (Altium Designer is required for live tools).
- **Node.js 20+** on `PATH`.
- **Altium Designer 22+** installed; note the path to `X2.EXE`.

## Install

From the repository root:

```bash
npm install
npm run build
```

## `mcp.json` example

Use an **absolute** path to `dist/index.js` (adjust for your machine):

```json
{
  "mcpServers": {
    "altium-mcp": {
      "command": "node",
      "args": ["D:/Projects Cursor/altium-mcp/dist/index.js"],
      "env": {
        "ALTIUM_MCP_WORKSPACE": "",
        "ALTIUM_MCP_ALTIUM_EXE": ""
      }
    }
  }
}
```

- Leave `ALTIUM_MCP_WORKSPACE` empty to use `%USERPROFILE%\.altium-mcp\workspace`, or set a folder where the server may write `request.json` / `response.json`.
- Leave `ALTIUM_MCP_ALTIUM_EXE` empty for auto-discovery under `C:\Program Files\Altium\AD*\X2.EXE`, or set the full path.

After the first connection, you can call MCP tool `**configure_altium_exe**` once to persist the executable path in `%USERPROFILE%\.altium-mcp\config.json`.

## Verify

1. Open a PCB in Altium.
2. In Cursor, run tool `**get_server_status**` then `**altium_ping**`.

## Troubleshooting


| Symptom                    | Check                                                                                                                       |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `AD_NOT_FOUND`             | Run `**configure_altium_exe**` or set `ALTIUM_MCP_ALTIUM_EXE`.                                                              |
| `TIMEOUT`                  | Altium not running, script blocked, or **DelphiScript debugger paused** (breakpoint): the bridge never writes `response.json`. Clear breakpoints / stop debugging / Continue in Altium. If stuck after abort, delete `.bridge.lock` in the workspace folder. `edit_schematic` waits up to 240s; other tools ~120s. |
| `SCRIPT_PROJECT_NOT_FOUND` | Delete workspace `AltiumScript` folder and restart server to re-copy bundled scripts.                                       |
| MCP disconnects            | Ensure nothing writes to **stdout** except MCP JSON-RPC (logs must use stderr).                                             |


