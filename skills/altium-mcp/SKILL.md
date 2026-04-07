---
name: altium-mcp
description: Uses the altium-mcp Model Context Protocol server to read PCB/schematic data from Altium Designer via a DelphiScript bridge on Windows. Apply when the user enables the altium-mcp MCP server, mentions Altium Designer, X2.EXE, PCB layers/rules/nets, schematic components, designators, workspace projects, or MCP tools get_server_status, altium_ping, get_schematic_data, get_pcb_*, get_all_designators, get_component_pins.
---

# Altium MCP

## Portable use

- **MCP `instructions`**: Compliant clients load server guidance automatically when the MCP session starts (no skill file required for that part).
- **Cursor Agent Skills**: Copy this folder to the client machine (see `INSTALL.md` here), or run `altium-mcp-install-skill` after installing the package.

## Scope

This skill documents the **published** altium-mcp server: Node orchestration plus DelphiScript bundled as `altium-scripts/` in the package (copied at runtime into the workspace `AltiumScript/` directory).

## Architecture (short)

1. **MCP server (Node)** registers tools and, on each live call, acquires a workspace file lock, syncs bundled scripts into `AltiumScript/`, writes `request.json`, and spawns **X2.EXE** with `-RScriptingSystem:RunScript(ProjectName="<workspace>\\AltiumScript\\Altium_API.PrjScr"|ProcName="Altium_API>Run")`.
2. **DelphiScript** (`Altium_API.pas` in the bundle) reads `request.json`, runs the command, writes `response.json` (`success`, `result`, `error`).
3. **Workspace root**: env `ALTIUM_MCP_WORKSPACE`, else `workspaceRoot` in `~/.altium-mcp/config.json` (Windows: `%USERPROFILE%\.altium-mcp\config.json`), else `~/.altium-mcp/workspace`.
4. **Altium EXE**: env `ALTIUM_MCP_ALTIUM_EXE`, else `altiumExePath` in that config file, else newest `AD*\X2.EXE` under `C:\Program Files\Altium`.

## Agent workflow

1. **get_server_status** — Confirm `altiumExeFound`, `scriptProjectFound`, paths. Stop and fix setup if false.
2. **configure_altium_exe** — Only if exe path is wrong or missing; path must exist on disk.
3. **altium_ping** — Expect JSON with `pong` / protocol version inside `result` from the bridge.
4. **Data tools** — Follow document focus rules below.

## Document focus (Altium UI)

| Situation | Requirement |
|-----------|-------------|
| `get_workspace_projects`, `altium_ping`, `get_schematic_data` | No PCB focus; schematic uses paths or focused project |
| `get_pcb_layers`, `get_pcb_rules`, `get_all_nets`, `get_pcb_layer_stackup`, `get_all_designators`, `get_component_pins` | **Active/focused PCB** in the **focused project** |

Tell the user to open and focus the correct `.PcbDoc` when PCB tools return empty or errors.

## MCP tools ↔ bridge commands

| MCP tool | Delphi `command` / notes |
|----------|---------------------------|
| altium_ping | `ping` |
| get_workspace_projects | `list_workspace` |
| get_schematic_data | `get_schematic_data` (+ optional path params) |
| get_pcb_layers | `get_pcb_layers` |
| get_pcb_rules | `get_pcb_rules` |
| get_all_nets | `get_all_nets` |
| get_pcb_layer_stackup | `get_pcb_layer_stackup` |
| get_all_designators | `get_all_component_data` (parsed in Node) |
| get_component_pins | `get_component_pins` + `designators` array |
| file_mode_capabilities | Node-only (no Altium) |

## get_schematic_data parameters

- `schematic_full_path`: absolute `.SchDoc` path for an open project.
- Or `project_full_path` + optional `schematic_sheet_file_name` (file name only).
- Omit both path forms to use focused project (optional sheet filter).

## Interpreting results

- Tool return shape is MCP text content with JSON (pretty-printed objects).
- Bridge: `{ "success": true, "result": ... }` or `success: false` with `error`.
- Node launch/path errors: `AD_NOT_FOUND`, `SCRIPT_PROJECT_NOT_FOUND`, `ALT_LAUNCH_FAILED`, `TIMEOUT`, `INVALID_BRIDGE_RESPONSE`, `RESPONSE_READ_FAILED`.
- Serialized access: `.bridge.lock` under workspace; long Altium operations can block other tools (~default 120s command timeout, ~60s lock wait).

## Delphi commands not yet MCP-exposed

The bridge script may implement additional commands (e.g. `move_components`, `create_net_class`, `take_view_screenshot`, output job helpers). Only the tools listed above are registered in the shipped MCP server until extended in a newer release.

## Authors (source repository)

When changing tools or bridge behavior, align the MCP `instructions` string in `src/mcpInstructions.ts` with this `SKILL.md`.
