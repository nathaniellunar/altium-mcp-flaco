import { cpSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { computeBundledAltiumScriptsFingerprint } from "../src/altiumBundleFingerprint.js";
import { ensureAltiumScriptBundle } from "../src/workspaceLayout.js";

describe("computeBundledAltiumScriptsFingerprint", () => {
  const bundleRoot = join(process.cwd(), "altium-scripts");

  it("is stable for the repo bundle", () => {
    const a = computeBundledAltiumScriptsFingerprint(bundleRoot);
    const b = computeBundledAltiumScriptsFingerprint(bundleRoot);
    expect(a).toMatch(/^[a-f0-9]{64}$/);
    expect(a).toBe(b);
  });
});

describe("ensureAltiumScriptBundle", () => {
  let workspaceRoot: string;
  let bundledDir: string;

  afterEach(() => {
    /* temp dirs under OS tmp; no cleanup required for CI */
  });

  it("copies when fingerprint changes and skips when unchanged", () => {
    workspaceRoot = mkdtempSync(join(tmpdir(), "altium-mcp-ws-"));
    bundledDir = mkdtempSync(join(tmpdir(), "altium-mcp-bundle-"));
    writeFileSync(join(bundledDir, "Altium_API.PrjScr"), "[Design]\nVersion=1.0\n");
    writeFileSync(join(bundledDir, "a.pas"), "unit a;\ninterface implementation end.\n");

    ensureAltiumScriptBundle(workspaceRoot, bundledDir);
    const destA = join(workspaceRoot, "AltiumScript", "a.pas");
    expect(readFileSync(destA, "utf8")).toContain("unit a");

    ensureAltiumScriptBundle(workspaceRoot, bundledDir);
    expect(readFileSync(destA, "utf8")).toContain("unit a");

    writeFileSync(join(bundledDir, "a.pas"), "unit a;\ninterface implementation end.\n// v2\n");
    ensureAltiumScriptBundle(workspaceRoot, bundledDir);
    expect(readFileSync(destA, "utf8")).toContain("v2");
  });

  it("mirrors a real bundle subtree", () => {
    workspaceRoot = mkdtempSync(join(tmpdir(), "altium-mcp-ws2-"));
    bundledDir = mkdtempSync(join(tmpdir(), "altium-mcp-bundle2-"));
    const repoScripts = join(process.cwd(), "altium-scripts");
    cpSync(repoScripts, bundledDir, { recursive: true });

    ensureAltiumScriptBundle(workspaceRoot, bundledDir);
    const marker = join(workspaceRoot, "AltiumScript", "Altium_API.pas");
    expect(readFileSync(marker, "utf8")).toContain("ExecuteCommand");
  });
});
