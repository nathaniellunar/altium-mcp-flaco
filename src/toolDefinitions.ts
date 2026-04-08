import type { ToolAnnotations } from "@modelcontextprotocol/sdk/types.js";

/** Live Altium queries: no design changes, safe to retry. */
export const annotationsReadOnlyLive: ToolAnnotations = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
};

/** Writes ~/.altium-mcp/config.json only. */
export const annotationsConfigWrite: ToolAnnotations = {
  readOnlyHint: false,
  destructiveHint: false,
  idempotentHint: true,
};

/** Node-only; no Altium process. */
export const annotationsNodeOnly: ToolAnnotations = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
};

/** Schematic edits: modifies open .SchDoc data (save in Altium as needed). */
export const annotationsSchematicEdit: ToolAnnotations = {
  readOnlyHint: false,
  destructiveHint: true,
  idempotentHint: false,
};

export const DESCRIPTION_GET_SERVER_STATUS = `
Purpose: Inspect MCP + Altium bridge setup before other tools.

When to use: First call in a session, or after MCP/Altium install or path errors.

Parameters: None.

Returns: JSON with platform, workspaceRoot, requestPath, responsePath, scriptProjectPath, altiumExePath, altiumExeFound, scriptProjectFound, bundledScriptsDir, bridgeLastError (contents of bridge_last_error.txt if present), bridgeUserReportedError (user-pasted Altium Messages / compile text from bridge_user_reported_error.txt), diagnosticsHint, env (ALTIUM_MCP_WORKSPACE, ALTIUM_MCP_ALTIUM_EXE).

Prerequisites: None. Triggers script bundle sync into workspace/AltiumScript.

How to interpret: If altiumExeFound or scriptProjectFound is false, fix paths (configure_altium_exe or env) before live tools. For DelphiScript compile errors Altium does not send to the bridge: paste the Messages output into workspace bridge_user_reported_error.txt, then re-run get_server_status so the agent can read it. Failed bridge runs also write bridge_last_error.txt and live tools append that file into the error field when success is false.
`.trim();

export const DESCRIPTION_CONFIGURE_ALTIUM_EXE = `
Purpose: Persist the absolute path to Altium X2.EXE for bridge launches.

When to use: get_server_status shows altiumExeFound false or wrong AD version path.

Parameters: path — absolute path to X2.EXE (file must exist).

Returns: { ok: true, altiumExePath } or MCP error text if file missing.

Prerequisites: Valid X2.EXE on disk.

Notes: Writes %USERPROFILE%\\.altium-mcp\\config.json (or equivalent). Env ALTIUM_MCP_ALTIUM_EXE overrides at runtime without persisting.
`.trim();

export const DESCRIPTION_ALTIUM_PING = `
Purpose: Verify the DelphiScript bridge responds inside Altium.

When to use: After get_server_status looks good; before expensive PCB/schematic reads.

Parameters: None.

Returns: Bridge JSON { success, result: { protocolVersion, pong: true } } on success.

Prerequisites: Altium may be started by the bridge. AD must be installed.

Errors: Same as other live tools (AD_NOT_FOUND, TIMEOUT, lock timeout, etc.).
`.trim();

export const DESCRIPTION_GET_WORKSPACE_PROJECTS = `
Purpose: List every open workspace entry (projects + logical documents).

When to use: Discover project_full_path, schematic_full_path, or confirm which .PrjPcb is focused.

Parameters: None.

Returns: JSON with projectCount, focusedProjectFullPath, focusedProjectIndex, projects[]. Each project has index, projectFullPath, projectFileName, logicalDocumentCount, focused, documents[] { kind, fullPath, fileName }.

Prerequisites: Altium running. Includes non-design entries (e.g. Free Documents, AltiumScript MCP project).

Notes: Logical documents are project members, not necessarily every editor tab.
`.trim();

export const DESCRIPTION_GET_SCHEMATIC_DATA = `
Purpose: Export schematic sheet content with optional filtering so large sheets do not flood the agent context.

When to use: BOM/placement review, wiring checks, sheet size for placement, or verify edit_schematic results. Prefer include_queries with a small subset on busy designs.

Parameters (all optional):
- schematic_full_path: absolute path to one .SchDoc in an open project (slashes / or \\). Preferred for multi-project workspaces.
- project_full_path: absolute path to open .PrjPcb / .PrjScr. Use with schematic_sheet_file_name or alone for all SCH sheets in that project.
- schematic_sheet_file_name: file name only (e.g. Sheet1.SchDoc). Requires focused project or project_full_path.
- include_queries: string array selecting what to return. Omit entirely for legacy JSON (backward compatible): only { components, drawing_objects }. If present, response uses schematic_data_mode "filtered" and only the requested buckets (plus include_queries echo). Token all expands to every supported bucket. Supported tokens: sheet | components | wires | buses | net_labels | power_ports | text_labels | junctions | ports | off_sheet_connectors | sheet_symbols | directives | figures | harness | drawing_objects. harness currently returns an empty array (placeholder for future API). drawing_objects is the combined non-component list (same mix as legacy). sheet returns sheets[] with one object per matched .SchDoc (size in mils, grids, borders, template path, etc.).

Resolution order: schematic_full_path wins; else project_full_path + optional sheet file name; else focused project. Without schematic_full_path / sheet file name, all SCH documents in the chosen project are scanned (aggregated arrays / multiple sheets[] entries).

Primitive shape (per object): object_kind, object_id, bbox_*_mils, plus type-specific fields (vertices_mils for wire/bus/polyline, x1/y1/x2/y2 for line/bus entry, text for net labels / power / text labels, etc.) — same as legacy drawing_objects entries.

Prerequisites: Target project must be open in Altium. Does not require active PCB.

Errors: ERROR: NO_WORKSPACE, NO_FOCUSED_PROJECT, PROJECT_NOT_FOUND, SCHEMATIC_NOT_IN_OPEN_PROJECTS (Delphi); bridge errors otherwise.

Notes: Invalid include_queries tokens only (no matches) fall back to legacy mode. Does not flatten pins inside components or sheet entries inside sheet symbols.
`.trim();

export const DESCRIPTION_EDIT_SCHEMATIC = `
Purpose: Edit one schematic sheet (.SchDoc) via a single tool with multiple modes (action).

When to use: Move or rotate symbols, set parameters, place components, add text/net labels, wires, buses, bus entries. After editing, call get_schematic_data on the same sheet to verify.

Sheet targeting (required): Provide schematic_full_path (absolute .SchDoc, preferred) OR schematic_sheet_file_name (file name only, e.g. Sheet1.SchDoc) with project_full_path or Altium focused project.

Common parameters: action (string), schematic_full_path?, project_full_path?, schematic_sheet_file_name?

Actions:
- set_component_transform — designator (required); optional x_mils, y_mils, rotation_deg (at least one of position/rotation must be set). Coordinates in mils; rotation in degrees (snapped to 0/90/180/270).
- set_component_parameters — designator (required); parameter_names[] and parameter_values[] (same length; updates existing parameters or adds new ones).
- place_component — lib_reference, designator, x_mils, y_mils, rotation_deg (optional, default 0); sch_library_path (absolute .SchLib) strongly required for a real symbol. Without sch_library_path the bridge only creates an empty schematic component shell (designator + LibReference, no library graphics—pins/body do not appear). With sch_library_path the bridge uses PlaceSchComponent from that file. All coordinates are sheet mils in the same space as get_schematic_data schematic_x/schematic_y; place inside the white drawing area (use existing objects on the sheet as reference, typically thousands of mils, not pixel-scale values).
- add_text — text, x_mils, y_mils (free string on sheet).
- add_net_label — net_name, x_mils, y_mils; optional rotation_deg.
- place_net_label — alias of add_net_label (response echoes the action you sent).
- add_wire — wire_points_csv: comma-separated mils pairs for orthogonal polyline segments, e.g. "0,0,1000,0,1000,500" creates (0,0)-(1000,0) and (1000,0)-(1000,500).
- place_wire — alias of add_wire.
- add_bus — same wire_points_csv format as add_wire; creates bus segments (eBus) instead of wires.
- add_bus_entry — wire_points_csv must be exactly four numbers x1,y1,x2,y2 (mils) for one bus-entry segment (eBusEntry).
- place_power_port — power_port_style (required): circle | arrow | bar | wave | gnd_power | power_ground | gnd_signal | signal_ground | gnd_earth | earth; x_mils, y_mils; optional net_name (defaults by style: GND for ground styles, VCC for supply styles), rotation_deg, show_net_name (default true).
- place_gnd — same coordinates; optional power_port_style (default gnd_power in bridge), optional net_name (default GND if empty).
- place_vcc — same coordinates; optional power_port_style (default arrow in bridge), optional net_name (default VCC if empty).

Returns: Bridge JSON result object with action, sheet, details (mode-specific). On Delphi-side failure, error text may start with ERROR: (e.g. COMPONENT_NOT_FOUND, SHEET_REQUIRED).

Prerequisites: Target .SchDoc must belong to an open project. Bridge command schematic_edit.

Notes: Does not auto-save the document unless the user saves in Altium. API behavior may vary slightly by AD major version. Wires and buses use straight segments (Location–Corner per segment). Delphi errors for buses include FACTORY_BUS_FAILED, BUS_POINTS_CSV_REQUIRED, FACTORY_BUS_ENTRY_FAILED, BUS_ENTRY_POINTS_NEED_EXACTLY_FOUR_NUMBERS, BUS_ENTRY_POINTS_CSV_REQUIRED. Power ports (ISch_PowerObject): POWER_PORT_STYLE_REQUIRED, POWER_PORT_STYLE_INVALID, FACTORY_POWER_OBJECT_FAILED, X_Y_MILS_REQUIRED.

Debugging / freezes: If the Altium Script IDE has a breakpoint set in Altium_API or schematic_edit (or Run with debugger), the script stops before writing response.json and the MCP client will see TIMEOUT. Clear all breakpoints, use Run without debugging, or press Continue/Stop Debugging in Altium. After a TIMEOUT, if no later tool runs, delete .bridge.lock in the MCP workspace folder so the next call is not blocked by the lock wait.
`.trim();

export const DESCRIPTION_GET_PCB_LAYERS = `
Purpose: List electrical and mechanical layer metadata for the active PCB.

When to use: Layer stack review, export layer names/ids.

Parameters: None.

Returns: Bridge-specific JSON (layer names, kinds, etc.).

Prerequisites: Correct .PcbDoc open and active (focused) in Altium.

Errors: Empty or partial data if no board focused.
`.trim();

export const DESCRIPTION_GET_PCB_RULES = `
Purpose: List PCB design rules from the active board.

When to use: DRC-related questions, clearance/copper rules review.

Parameters: None.

Returns: JSON describing rules (short descriptors per rule).

Prerequisites: Active/focused PCB in Altium.
`.trim();

export const DESCRIPTION_GET_ALL_NETS = `
Purpose: Unique net names on the active PCB.

When to use: Netlist-style checks, signal naming audit.

Parameters: None.

Returns: JSON array of net name strings.

Prerequisites: Active/focused PCB.
`.trim();

export const DESCRIPTION_GET_PCB_LAYER_STACKUP = `
Purpose: Physical stackup (dielectrics, thicknesses) for the active PCB.

When to use: Impedance / SI questions tied to stackup.

Parameters: None.

Returns: JSON stackup structure from the bridge.

Prerequisites: Active/focused PCB.
`.trim();

export const DESCRIPTION_GET_ALL_DESIGNATORS = `
Purpose: All component reference designators on the active PCB.

When to use: Quick inventory before get_component_pins.

Parameters: None.

Returns: String array of designators (parsed in Node from get_all_component_data).

Prerequisites: Active/focused PCB.

Notes: Same underlying command as full component geometry data but lighter response.
`.trim();

export const DESCRIPTION_GET_COMPONENT_PINS = `
Purpose: Pin-level data for selected components on the active PCB.

When to use: After designators are known; net names per pin, etc.

Parameters: designators — string array, e.g. ["U1","R2"].

Returns: Bridge JSON with pin information per requested designator.

Prerequisites: Active/focused PCB; designators must exist on board.

Errors: Bridge may fail if designator missing or command errors.
`.trim();

export const DESCRIPTION_FILE_MODE_CAPABILITIES = `
Purpose: Report offline / file-mode features (e.g. future Rust sidecar for .PcbLib).

When to use: Check if non-live file tools exist in this build.

Parameters: None.

Returns: JSON capability flags (Node only, no Altium).

Prerequisites: None.
`.trim();
