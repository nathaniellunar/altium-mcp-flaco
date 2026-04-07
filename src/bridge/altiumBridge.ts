import { spawn } from "node:child_process";
import { existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod/v4";
import { discoverAltiumExe } from "../altiumPaths.js";
import {
  BRIDGE_PROTOCOL_VERSION,
  loadUserConfig,
  resolveAltiumExe,
  resolveWorkspaceRoot,
  saveUserConfig,
  type UserConfig,
} from "../config.js";
import { ensureAltiumScriptBundle, scriptProjectPath } from "../workspaceLayout.js";
import { withBridgeLock } from "./lock.js";

const BridgeResponseSchema = z.object({
  success: z.boolean(),
  result: z.unknown().optional(),
  error: z.string().optional(),
});

export type BridgeResponse = z.infer<typeof BridgeResponseSchema>;

export interface AltiumBridgeOptions {
  bundledScriptsDir: string;
  timeoutMs?: number;
}

export function defaultBundledScriptsDir(): string {
  /* dist/bridge/altiumBridge.js -> ../../altium-scripts */
  const u = new URL("../../altium-scripts", import.meta.url);
  if (u.protocol === "file:") {
    return fileURLToPath(u);
  }
  return join(process.cwd(), "altium-scripts");
}

export class AltiumBridge {
  private readonly bundledScriptsDir: string;
  private readonly timeoutMs: number;

  constructor(options: AltiumBridgeOptions) {
    this.bundledScriptsDir = options.bundledScriptsDir;
    this.timeoutMs = options.timeoutMs ?? 120_000;
  }

  get workspaceRoot(): string {
    return resolveWorkspaceRoot(loadUserConfig());
  }

  getRequestPath(): string {
    return join(this.workspaceRoot, "request.json");
  }

  getResponsePath(): string {
    return join(this.workspaceRoot, "response.json");
  }

  getScriptProjectPath(): string {
    return scriptProjectPath(this.workspaceRoot);
  }

  resolveAltiumExePath(): string | undefined {
    const cfg = loadUserConfig();
    return resolveAltiumExe(cfg) ?? discoverAltiumExe();
  }

  persistAltiumExePath(exe: string): void {
    const cfg = loadUserConfig();
    saveUserConfig({ ...cfg, altiumExePath: exe });
  }

  ensureLayout(): void {
    ensureAltiumScriptBundle(this.workspaceRoot, this.bundledScriptsDir);
  }

  /**
   * Writes request.json, launches X2.EXE with ScriptingSystem:RunScript, waits for response.json.
   */
  async executeCommand(
    command: string,
    params: Record<string, unknown> = {},
  ): Promise<BridgeResponse> {
    return withBridgeLock(this.workspaceRoot, async () => {
      this.ensureLayout();
      const exe = this.resolveAltiumExePath();
      const scriptPrj = this.getScriptProjectPath();

      if (!exe || !existsSync(exe)) {
        return {
          success: false,
          error: "AD_NOT_FOUND",
        };
      }
      if (!existsSync(scriptPrj)) {
        return {
          success: false,
          error: "SCRIPT_PROJECT_NOT_FOUND",
        };
      }

      const requestPath = this.getRequestPath();
      const responsePath = this.getResponsePath();

      try {
        if (existsSync(responsePath)) unlinkSync(responsePath);
      } catch {
        /* ignore */
      }

      const body = {
        protocolVersion: BRIDGE_PROTOCOL_VERSION,
        command,
        ...params,
      };
      writeFileSync(requestPath, JSON.stringify(body, null, 2), "utf8");

      const launched = await launchAltiumRunScript(exe, scriptPrj);
      if (!launched) {
        return { success: false, error: "ALT_LAUNCH_FAILED" };
      }

      const deadline = Date.now() + this.timeoutMs;
      while (Date.now() < deadline) {
        if (existsSync(responsePath)) {
          try {
            const raw = readFileSync(responsePath, "utf8");
            const parsed = JSON.parse(raw) as unknown;
            const res = BridgeResponseSchema.safeParse(parsed);
            if (res.success) return res.data;
            return {
              success: false,
              error: "INVALID_BRIDGE_RESPONSE",
            };
          } catch {
            return { success: false, error: "RESPONSE_READ_FAILED" };
          }
        }
        await new Promise((r) => setTimeout(r, 500));
      }

      return { success: false, error: "TIMEOUT" };
    });
  }
}

/**
 * Windows cmd: pipe must be escaped as ^| for -RScriptingSystem:RunScript(...)
 */
export async function launchAltiumRunScript(
  altiumExe: string,
  scriptPrjPath: string,
): Promise<boolean> {
  const projectArg = scriptPrjPath.replace(/\//g, "\\");
  const inner = `ProjectName="${projectArg}"^|ProcName="Altium_API>Run"`;
  const cmd = `"${altiumExe}" -RScriptingSystem:RunScript(${inner})`;

  return new Promise((resolve) => {
    const child = spawn(cmd, {
      shell: true,
      detached: true,
      stdio: "ignore",
      windowsHide: true,
    });
    child.once("error", () => resolve(false));
    child.unref();
    resolve(child.pid !== undefined);
  });
}
