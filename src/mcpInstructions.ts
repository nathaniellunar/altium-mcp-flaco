/**
 * MCP server `instructions` (sent on initialize). Keep in sync with skills/altium-mcp/SKILL.md.
 */
export const ALTIUM_MCP_INSTRUCTIONS = `
Altium MCP bridges Cursor to Altium Designer on Windows (AD 22+). The Node server writes JSON to the workspace, launches X2.EXE with DelphiScript (Altium_API.PrjScr), and reads the JSON response.

Setup and order of operations:
1) Call get_server_status first. If altiumExePath is missing or altiumExeFound is false, use configure_altium_exe with the absolute path to X2.EXE (or set env ALTIUM_MCP_ALTIUM_EXE).
2) Workspace root defaults to ~/.altium-mcp/workspace (or ALTIUM_MCP_WORKSPACE). The server copies bundled scripts to <workspace>/AltiumScript/ and uses request.json / response.json in the workspace root.
3) Run altium_ping to confirm the Delphi bridge responds (pong).
4) For PCB data tools, open the correct project in Altium and focus the target .PcbDoc (active PCB). Schematic export does not require a focused PCB.

Exposed MCP tools (live Altium unless noted):
- get_server_status — paths, exe, script project, env.
- configure_altium_exe — persist X2.EXE path in ~/.altium-mcp/config.json.
- altium_ping — bridge health.
- get_workspace_projects — list_workspace (open projects and documents).
- get_schematic_data — components on sheets; optional schematic_full_path, project_full_path, schematic_sheet_file_name.
- get_pcb_layers, get_pcb_rules, get_all_nets, get_pcb_layer_stackup — active PCB.
- get_all_designators — designators from get_all_component_data on active PCB.
- get_component_pins — { designators: string[] } on active PCB.
- file_mode_capabilities — offline/file-mode feature flags (no Altium call).

Bridge responses use JSON with success, result, and error. Top-level launch/read failures include AD_NOT_FOUND, SCRIPT_PROJECT_NOT_FOUND, ALT_LAUNCH_FAILED, TIMEOUT, INVALID_BRIDGE_RESPONSE. Concurrent tool calls are serialized with a workspace lock (~60s wait).

The Delphi side supports additional commands not yet wrapped as MCP tools (e.g. move_components, create_net_class); extend the Node server to expose them if needed.
`.trim();
