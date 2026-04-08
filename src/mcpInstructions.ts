/**
 * MCP server `instructions` (sent on initialize). Keep aligned with:
 * - `src/toolDefinitions.ts` (canonical long descriptions on each tool)
 * - `skills/altium-mcp/SKILL.md` (Cursor skill)
 */
export const ALTIUM_MCP_INSTRUCTIONS = `
Altium MCP bridges Cursor to Altium Designer on Windows (AD 22+). The Node server writes JSON to the workspace, launches X2.EXE with DelphiScript (Altium_API.PrjScr), and reads the JSON response.

Each registered tool includes a detailed description (Purpose, When to use, Parameters, Returns, Prerequisites, Errors) plus schema hints for arguments—use the tool list from the client as the source of truth for parameters.

Setup order:
1) get_server_status — verify altiumExeFound, scriptProjectFound, paths. Fixes bundle sync into <workspace>/AltiumScript/.
2) If exe missing: configure_altium_exe { path } or env ALTIUM_MCP_ALTIUM_EXE.
3) altium_ping — confirm bridge pong inside Altium.
4) Data: use get_workspace_projects to discover paths; then schematic or PCB tools as needed.
5) After edit_schematic, use get_schematic_data on the same sheet to verify.

Schematic placement hints for agents:
- place_component: pass sch_library_path (absolute .SchLib) so Altium loads the real symbol; omitting it leaves a placeholder with no graphic.
- Use x_mils/y_mils consistent with get_schematic_data (mils on sheet). Anchor new parts near existing components' schematic_x/schematic_y instead of guessing small numbers.

Document focus in Altium UI:
- PCB tools (get_pcb_*, get_all_designators, get_component_pins): user must open and focus the target .PcbDoc.
- get_workspace_projects, altium_ping, get_schematic_data, edit_schematic: no PCB required; schematic tools accept schematic_full_path and/or project_full_path + schematic_sheet_file_name.

Tool quick map:
| Tool | Params | Altium |
|------|--------|--------|
| get_server_status | — | syncs scripts |
| configure_altium_exe | path | writes config |
| altium_ping | — | live |
| get_workspace_projects | — | live |
| get_schematic_data | optional paths + optional include_queries[] (omit = legacy components + drawing_objects; else filtered buckets: sheet, wires, buses, …) | live; JSON |
| edit_schematic | action + sheet targeting + mode-specific fields (incl. place_power_port / place_gnd / place_vcc + power_port_style) | live, command schematic_edit |
| get_pcb_layers / get_pcb_rules / get_all_nets / get_pcb_layer_stackup | — | live, needs PCB |
| get_all_designators | — | live, needs PCB |
| get_component_pins | designators[] | live, needs PCB |
| file_mode_capabilities | — | Node only |

Bridge JSON: { success, result?, error? }. Common errors: AD_NOT_FOUND, SCRIPT_PROJECT_NOT_FOUND, ALT_LAUNCH_FAILED, TIMEOUT, INVALID_BRIDGE_RESPONSE. Workspace .bridge.lock serializes concurrent calls (~60s lock wait; ~120s default command timeout; edit_schematic allows 240s).

On failed bridge responses (success: false), Altium writes workspace bridge_last_error.txt; the Node server appends that file into the tool error string when present so agents see the same detail. Compile-time DelphiScript errors are not emitted by Run: paste Altium Messages into workspace bridge_user_reported_error.txt, then call get_server_status (fields bridgeUserReportedError / bridgeLastError).

If tools time out while debugging Altium scripts: clear IDE breakpoints / stop debugging — a paused script never writes response.json.

Delphi implements more commands than are MCP-wrapped; extend Node index.ts to expose them if needed.
`.trim();
