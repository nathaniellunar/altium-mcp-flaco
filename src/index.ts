#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import * as z from "zod/v4";
import { existsSync } from "node:fs";
import { AltiumBridge, defaultBundledScriptsDir } from "./bridge/altiumBridge.js";
import { getFileModeCapabilities } from "./fileMode.js";
import { parseDesignatorsFromComponentData } from "./tools/designators.js";
import { errResult, jsonResult } from "./tools/helpers.js";
import { ALTIUM_MCP_INSTRUCTIONS } from "./mcpInstructions.js";

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
    description:
      "Returns workspace paths, Altium X2.EXE resolution, script project path, and bridge file locations. Use before other tools to verify setup (Windows + Altium Designer 22+).",
    inputSchema: z.object({}),
  },
  async () => {
    bridge.ensureLayout();
    const exe = bridge.resolveAltiumExePath();
    const script = bridge.getScriptProjectPath();
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
    description:
      "Persists the full path to Altium X2.EXE under the user config file (~/.altium-mcp/config.json). Required for launching the DelphiScript bridge.",
    inputSchema: {
      path: z.string().describe("Absolute path to X2.EXE, e.g. C:\\Program Files\\Altium\\AD24\\X2.EXE"),
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
    description:
      "Runs the DelphiScript bridge ping command. Altium Designer should be installed; it may be launched if not already running.",
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
  "Lists all open workspace projects (PrjPcb, PrjScr, etc.) and each project's logical documents with kind, full path, and file name. Identifies the focused project.",
  "list_workspace",
);

registerLiveCommand(
  "get_schematic_data",
  "Schematic components",
  "Returns placed components from schematic sheets (designator, sheet path, position, rotation, parameters). Use schematic_full_path for any open .SchDoc (project is resolved automatically). Or project_full_path + optional schematic_sheet_file_name. If both path args are omitted, uses the focused project and all sheets (or filter by schematic_sheet_file_name).",
  "get_schematic_data",
  {
    schematic_full_path: z
      .string()
      .optional()
      .describe("Absolute path to a .SchDoc that belongs to an open project, e.g. D:\\\\Design\\\\Sheet1.SchDoc"),
    project_full_path: z
      .string()
      .optional()
      .describe("Absolute path to an open .PrjPcb / .PrjScr when not using schematic_full_path"),
    schematic_sheet_file_name: z
      .string()
      .optional()
      .describe('File name only, e.g. Sheet1.SchDoc — applies with focused project or project_full_path'),
  },
);

function registerLiveCommand(
  name: string,
  title: string,
  description: string,
  command: string,
  shape: z.ZodRawShape = {},
) {
  server.registerTool(
    name,
    {
      title,
      description,
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
  "Returns electrical and mechanical layer metadata for the active PCB document in Altium.",
  "get_pcb_layers",
);

registerLiveCommand(
  "get_pcb_rules",
  "List PCB design rules",
  "Returns design rule descriptions from the active PCB.",
  "get_pcb_rules",
);

registerLiveCommand(
  "get_all_nets",
  "List PCB nets",
  "Returns unique net names from the active PCB.",
  "get_all_nets",
);

registerLiveCommand(
  "get_pcb_layer_stackup",
  "PCB layer stackup",
  "Returns stackup data (dielectric, thickness) for the active PCB.",
  "get_pcb_layer_stackup",
);

server.registerTool(
  "get_all_designators",
  {
    title: "Component designators",
    description: "Returns all component designators on the active PCB (via get_all_component_data).",
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
    description: "Returns pin information for the given component designators on the active PCB.",
    inputSchema: {
      designators: z
        .array(z.string())
        .describe('Designators e.g. ["U1","R2"]'),
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
    description:
      "Reports whether offline .PcbLib/.SchLib tools are available in this build (extension point for Rust sidecar).",
    inputSchema: z.object({}),
  },
  async () => jsonResult(getFileModeCapabilities()),
);

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
