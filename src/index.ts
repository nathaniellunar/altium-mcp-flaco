#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import type { ToolAnnotations } from "@modelcontextprotocol/sdk/types.js";
import * as z from "zod/v4";
import { existsSync } from "node:fs";
import {
  AltiumBridge,
  defaultBundledScriptsDir,
  readBridgeDiagnosticSnippets,
} from "./bridge/altiumBridge.js";
import { getFileModeCapabilities } from "./fileMode.js";
import { ALTIUM_MCP_INSTRUCTIONS } from "./mcpInstructions.js";
import {
  annotationsConfigWrite,
  annotationsNodeOnly,
  annotationsReadOnlyLive,
  DESCRIPTION_ALTIUM_PING,
  DESCRIPTION_CONFIGURE_ALTIUM_EXE,
  DESCRIPTION_FILE_MODE_CAPABILITIES,
  DESCRIPTION_GET_ALL_DESIGNATORS,
  DESCRIPTION_GET_ALL_NETS,
  DESCRIPTION_GET_COMPONENT_PINS,
  DESCRIPTION_GET_PCB_LAYERS,
  DESCRIPTION_GET_PCB_LAYER_STACKUP,
  DESCRIPTION_GET_PCB_RULES,
  DESCRIPTION_EDIT_SCHEMATIC,
  DESCRIPTION_GET_SCHEMATIC_DATA,
  DESCRIPTION_GET_SERVER_STATUS,
  DESCRIPTION_GET_WORKSPACE_PROJECTS,
  annotationsSchematicEdit,
} from "./toolDefinitions.js";
import { editSchematicInputSchema } from "./tools/editSchematic.js";
import { getSchematicDataInputSchema } from "./tools/getSchematicData.js";
import { parseDesignatorsFromComponentData } from "./tools/designators.js";
import { errResult, jsonResult } from "./tools/helpers.js";

const bridge = new AltiumBridge({
  bundledScriptsDir: defaultBundledScriptsDir(),
});

const server = new McpServer(
  {
    name: "altium-mcp",
    version: "0.1.0",
  },
  {
    instructions: ALTIUM_MCP_INSTRUCTIONS,
  },
);

server.registerTool(
  "get_server_status",
  {
    title: "Altium MCP server status",
    description: DESCRIPTION_GET_SERVER_STATUS,
    annotations: annotationsReadOnlyLive,
    inputSchema: z.object({}),
  },
  async () => {
    bridge.ensureLayout();
    const exe = bridge.resolveAltiumExePath();
    const script = bridge.getScriptProjectPath();
    const diag = readBridgeDiagnosticSnippets(bridge.workspaceRoot);
    const data = {
      platform: process.platform,
      workspaceRoot: bridge.workspaceRoot,
      requestPath: bridge.getRequestPath(),
      responsePath: bridge.getResponsePath(),
      scriptProjectPath: script,
      altiumExePath: exe ?? null,
      altiumExeFound: exe ? existsSync(exe) : false,
      scriptProjectFound: existsSync(script),
      bundledScriptsDir: defaultBundledScriptsDir(),
      bridgeLastError: diag.bridgeLastError,
      bridgeUserReportedError: diag.bridgeUserReportedError,
      diagnosticsHint:
        "On Altium script compile/runtime errors: paste Messages panel text into workspace file bridge_user_reported_error.txt (UTF-8), then call get_server_status again. bridge_last_error.txt is written by the bridge on failed responses.",
      env: {
        ALTIUM_MCP_WORKSPACE: process.env.ALTIUM_MCP_WORKSPACE ?? null,
        ALTIUM_MCP_ALTIUM_EXE: process.env.ALTIUM_MCP_ALTIUM_EXE ?? null,
      },
    };
    return jsonResult(data);
  },
);

server.registerTool(
  "configure_altium_exe",
  {
    title: "Save Altium X2.EXE path",
    description: DESCRIPTION_CONFIGURE_ALTIUM_EXE,
    annotations: annotationsConfigWrite,
    inputSchema: {
      path: z
        .string()
        .describe(
          "Absolute path to Altium X2.EXE on disk (must exist). Example: C:\\Program Files\\Altium\\AD25\\X2.EXE",
        ),
    },
  },
  async ({ path: exePath }) => {
    if (!existsSync(exePath)) {
      return errResult(`File not found: ${exePath}`);
    }
    bridge.persistAltiumExePath(exePath);
    return jsonResult({ ok: true, altiumExePath: exePath });
  },
);

server.registerTool(
  "altium_ping",
  {
    title: "Ping Altium bridge",
    description: DESCRIPTION_ALTIUM_PING,
    annotations: annotationsReadOnlyLive,
    inputSchema: z.object({}),
  },
  async () => {
    const r = await bridge.executeCommand("ping", {});
    return jsonResult(r);
  },
);

registerLiveCommand(
  "get_workspace_projects",
  "Workspace projects and files",
  DESCRIPTION_GET_WORKSPACE_PROJECTS,
  "list_workspace",
  {},
  annotationsReadOnlyLive,
);

server.registerTool(
  "get_schematic_data",
  {
    title: "Schematic sheet (filtered export)",
    description: DESCRIPTION_GET_SCHEMATIC_DATA,
    annotations: annotationsReadOnlyLive,
    inputSchema: getSchematicDataInputSchema,
  },
  async (params) => {
    const r = await bridge.executeCommand(
      "get_schematic_data",
      params as Record<string, unknown>,
    );
    return jsonResult(r);
  },
);

server.registerTool(
  "edit_schematic",
  {
    title: "Edit schematic sheet",
    description: DESCRIPTION_EDIT_SCHEMATIC,
    annotations: annotationsSchematicEdit,
    inputSchema: editSchematicInputSchema,
  },
  async (params) => {
    const p = params as Record<string, unknown>;
    const r = await bridge.executeCommand("schematic_edit", p, { timeoutMs: 240_000 });
    return jsonResult(r);
  },
);

function registerLiveCommand(
  name: string,
  title: string,
  description: string,
  command: string,
  shape: z.ZodRawShape = {},
  annotations?: ToolAnnotations,
) {
  server.registerTool(
    name,
    {
      title,
      description,
      annotations,
      inputSchema: z.object(shape),
    },
    async (params) => {
      const r = await bridge.executeCommand(command, params as Record<string, unknown>);
      return jsonResult(r);
    },
  );
}

registerLiveCommand(
  "get_pcb_layers",
  "List PCB layers",
  DESCRIPTION_GET_PCB_LAYERS,
  "get_pcb_layers",
  {},
  annotationsReadOnlyLive,
);

registerLiveCommand(
  "get_pcb_rules",
  "List PCB design rules",
  DESCRIPTION_GET_PCB_RULES,
  "get_pcb_rules",
  {},
  annotationsReadOnlyLive,
);

registerLiveCommand(
  "get_all_nets",
  "List PCB nets",
  DESCRIPTION_GET_ALL_NETS,
  "get_all_nets",
  {},
  annotationsReadOnlyLive,
);

registerLiveCommand(
  "get_pcb_layer_stackup",
  "PCB layer stackup",
  DESCRIPTION_GET_PCB_LAYER_STACKUP,
  "get_pcb_layer_stackup",
  {},
  annotationsReadOnlyLive,
);

server.registerTool(
  "get_all_designators",
  {
    title: "Component designators",
    description: DESCRIPTION_GET_ALL_DESIGNATORS,
    annotations: annotationsReadOnlyLive,
    inputSchema: z.object({}),
  },
  async () => {
    const r = await bridge.executeCommand("get_all_component_data", {});
    if (!r.success) {
      return jsonResult(r);
    }
    const designators = parseDesignatorsFromComponentData(r.result);
    return jsonResult(designators);
  },
);

server.registerTool(
  "get_component_pins",
  {
    title: "Component pins",
    description: DESCRIPTION_GET_COMPONENT_PINS,
    annotations: annotationsReadOnlyLive,
    inputSchema: {
      designators: z
        .array(z.string())
        .min(1)
        .describe(
          "PCB reference designators to query (must exist on the active board). Example: [\"U1\",\"Q2\",\"C10\"]",
        ),
    },
  },
  async ({ designators }) => {
    const r = await bridge.executeCommand("get_component_pins", { designators });
    return jsonResult(r);
  },
);

server.registerTool(
  "file_mode_capabilities",
  {
    title: "File-mode capabilities",
    description: DESCRIPTION_FILE_MODE_CAPABILITIES,
    annotations: annotationsNodeOnly,
    inputSchema: z.object({}),
  },
  async () => jsonResult(getFileModeCapabilities()),
);

async function main(): Promise<void> {
  bridge.ensureLayout();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
